//
//  SubscriptionManager.swift
//  ciftApp
//
//  Us & Time - Subscription Manager (StoreKit 2)
//

import Foundation
import Observation
import StoreKit
import Supabase

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    // MARK: - Properties
    var isPremium = false
    var isTrialActive = false
    var subscriptionType: SubscriptionType?
    var trialEndDate: Date?
    var subscriptionEndDate: Date?
    var isLoading = false
    
    // Products
    var products: [Product] = []
    var monthlyProduct: Product?
    var yearlyProduct: Product?
    
    // Product IDs
    private let productIds = [
        "usandtime.premium.monthly",
        "usandtime.premium.yearly"
    ]
    
    private let supabase = SupabaseManager.shared.client
    private var updateListenerTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var currentCoupleId: UUID?
    
    // MARK: - Subscription Type
    enum SubscriptionType: String {
        case trial = "trial"
        case monthly = "monthly"
        case yearly = "yearly"
    }
    
    // MARK: - Init
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    @MainActor
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            monthlyProduct = products.first { $0.id == "usandtime.premium.monthly" }
            yearlyProduct = products.first { $0.id == "usandtime.premium.yearly" }
            print("🟢 [Sub] Loaded \(products.count) products")
        } catch {
            print("🔴 [Sub] Failed to load products: \(error)")
        }
    }
    
    // MARK: - Check Subscription Status
    @MainActor
    func checkSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Get profile
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // Check if user has couple
            guard let coupleId = profile.coupleId else {
                // No couple - check profile's own premium status
                // (Premium persists in profile even after couple deletion)
                isPremium = profile.isPremium ?? false
                print("🔵 [Sub] No couple - Profile premium: \(isPremium)")
                return
            }
            
            // Get couple subscription info (this is synced by trigger)
            struct CoupleSubscription: Codable {
                let is_premium: Bool?
                let subscription_type: String?
                let subscription_end_date: String?
            }
            
            let couple: CoupleSubscription = try await supabase
                .from("couples")
                .select("is_premium, subscription_type, subscription_end_date")
                .eq("id", value: coupleId)
                .single()
                .execute()
                .value
            
            // Set premium from couple (either partner's premium applies)
            isPremium = couple.is_premium ?? false
            
            if let endDateStr = couple.subscription_end_date,
               let endDate = ISO8601DateFormatter().date(from: endDateStr) {
                subscriptionEndDate = endDate
                
                if endDate > Date() {
                    if let type = couple.subscription_type {
                        subscriptionType = SubscriptionType(rawValue: type)
                        isTrialActive = (type == "trial")
                    }
                    print("🟢 [Sub] Premium active: \(subscriptionType?.rawValue ?? "unknown")")
                } else {
                    // Subscription expired
                    isPremium = false
                    isTrialActive = false
                    print("🔴 [Sub] Subscription expired")
                }
            }
            
            // Start realtime listener if not already
            if currentCoupleId != coupleId {
                currentCoupleId = coupleId
                await subscribeToCoupleChanges(coupleId: coupleId)
            }
            
        } catch {
            print("🔴 [Sub] Error checking status: \(error)")
        }
    }
    
    // MARK: - Start Trial
    @MainActor
    func startTrial() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else {
                print("🔴 [Sub] No couple for trial")
                return false
            }
            
            // Set trial for 7 days
            let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            
            await updateSubscriptionInDatabase(
                coupleId: coupleId,
                isPremium: true,
                type: .trial,
                endDate: trialEnd
            )
            
            isPremium = true
            isTrialActive = true
            subscriptionType = .trial
            trialEndDate = trialEnd
            subscriptionEndDate = trialEnd
            
            print("🟢 [Sub] Trial started until \(trialEnd)")
            return true
            
        } catch {
            print("🔴 [Sub] Trial start error: \(error)")
            return false
        }
    }
    
    // MARK: - Purchase
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update database
                await handleSuccessfulPurchase(product: product, transactionId: String(transaction.id))
                
                await transaction.finish()
                print("🟢 [Sub] Purchase successful: \(product.id)")
                return true
                
            case .userCancelled:
                print("🔵 [Sub] User cancelled")
                return false
                
            case .pending:
                print("🔵 [Sub] Purchase pending")
                return false
                
            @unknown default:
                return false
            }
            
        } catch {
            print("🔴 [Sub] Purchase error: \(error)")
            return false
        }
    }
    
    // MARK: - Handle Successful Purchase
    @MainActor
    private func handleSuccessfulPurchase(product: Product, transactionId: String) async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            let type: SubscriptionType = product.id.contains("yearly") ? .yearly : .monthly
            let duration = type == .yearly ? 365 : 30
            let endDate = Calendar.current.date(byAdding: .day, value: duration, to: Date())!
            
            // 1. Update PROFILES table first (Source of Truth)
            await updateProfilePremium(
                userId: userId,
                isPremium: true,
                type: type,
                endDate: endDate,
                transactionId: transactionId
            )
            
            // 2. Get profile to check if in a couple
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // 3. If in a couple, sync to COUPLES table (Cache)
            if let coupleId = profile.coupleId {
                await updateCouplesPremium(coupleId: coupleId, isPremium: true)
            }
            
            // 4. Update local state
            isPremium = true
            isTrialActive = false
            subscriptionType = type
            subscriptionEndDate = endDate
            
            print("🟢 [Sub] Purchase completed - Profile and Couple updated")
            
        } catch {
            print("🔴 [Sub] Handle purchase error: \(error)")
        }
    }
    
    // MARK: - Update Profile Premium (Source of Truth)
    private func updateProfilePremium(
        userId: UUID,
        isPremium: Bool,
        type: SubscriptionType?,
        endDate: Date?,
        transactionId: String? = nil
    ) async {
        do {
            var updateData: [String: AnyJSON] = [
                "is_premium": .bool(isPremium)
            ]
            
            if let type = type {
                updateData["subscription_type"] = .string(type.rawValue)
            } else {
                updateData["subscription_type"] = .null
            }
            
            if let endDate = endDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                updateData["subscription_end_date"] = .string(formatter.string(from: endDate))
            } else {
                updateData["subscription_end_date"] = .null
            }
            
            if let transactionId = transactionId {
                updateData["original_transaction_id"] = .string(transactionId)
            }
            
            try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            print("🟢 [Sub] Profile premium updated")
            
        } catch {
            print("🔴 [Sub] Profile update error: \(error)")
        }
    }
    
    // MARK: - Update Couples Premium (Cache/Sync)
    private func updateCouplesPremium(coupleId: UUID, isPremium: Bool) async {
        do {
            try await supabase
                .from("couples")
                .update(["is_premium": isPremium])
                .eq("id", value: coupleId)
                .execute()
            
            print("🟢 [Sub] Couples premium synced")
            
        } catch {
            print("🔴 [Sub] Couples sync error: \(error)")
        }
    }
    
    // MARK: - Update Database
    private func updateSubscriptionInDatabase(
        coupleId: UUID,
        isPremium: Bool,
        type: SubscriptionType?,
        endDate: Date?,
        transactionId: String? = nil
    ) async {
        do {
            var updateData: [String: AnyJSON] = [
                "is_premium": .bool(isPremium)
            ]
            
            if let type = type {
                updateData["subscription_type"] = .string(type.rawValue)
            } else {
                updateData["subscription_type"] = .null
            }
            
            if let endDate = endDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                updateData["subscription_end_date"] = .string(formatter.string(from: endDate))
                updateData["subscription_start_date"] = .string(formatter.string(from: Date()))
            } else {
                updateData["subscription_end_date"] = .null
            }
            
            if let transactionId = transactionId {
                updateData["original_transaction_id"] = .string(transactionId)
            }
            
            try await supabase
                .from("couples")
                .update(updateData)
                .eq("id", value: coupleId)
                .execute()
            
            print("🟢 [Sub] Database updated")
            
        } catch {
            print("🔴 [Sub] Database update error: \(error)")
        }
    }
    
    // MARK: - StoreKit Transaction Listener
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.checkSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("🔴 [Sub] Transaction failed verification")
                }
            }
        }
    }
    
    // MARK: - Check StoreKit Subscriptions
    @MainActor
    private func checkStoreKitSubscriptions() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID.contains("premium") {
                    if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        isPremium = true
                        subscriptionEndDate = expirationDate
                        
                        if transaction.productID.contains("yearly") {
                            subscriptionType = .yearly
                        } else {
                            subscriptionType = .monthly
                        }
                    }
                }
            } catch {
                print("🔴 [Sub] Entitlement check error")
            }
        }
    }
    
    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    @MainActor
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await checkStoreKitSubscriptions()
            await checkSubscriptionStatus()
            print("🟢 [Sub] Purchases restored")
        } catch {
            print("🔴 [Sub] Restore error: \(error)")
        }
    }
    
    // MARK: - Subscribe to Couple Changes (Realtime)
    /// Listens for changes to the couple's premium status in real-time
    @MainActor
    func subscribeToCoupleChanges(coupleId: UUID) async {
        // Cancel existing subscription if any
        realtimeTask?.cancel()
        if let existingChannel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(existingChannel)
        }
        
        let channel = supabase.realtimeV2.channel("couple_\(coupleId.uuidString)")
        
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "couples",
            filter: "id=eq.\(coupleId.uuidString)"
        )
        
        // Subscribe first
        await channel.subscribe()
        realtimeChannel = channel
        
        // Then start listening
        realtimeTask = Task {
            for await _ in changes {
                print("🔔 [Sub] Realtime: Couple premium status changed")
                // Re-fetch from database
                await self.checkSubscriptionStatus()
            }
        }
        
        print("🟢 [Sub] Realtime: Listening to couple \(coupleId)")
    }
    
    // MARK: - Feature Limits
    
    /// Timeline photo limit (free: 5, premium: unlimited)
    var photoLimit: Int {
        isPremium ? Int.max : 5
    }
    
    /// Active capsule limit (free: 1 pending, premium: unlimited)
    var capsuleLimit: Int {
        isPremium ? Int.max : 1
    }
    
    /// Todo limit (free: 5, premium: unlimited)
    var todoLimit: Int {
        isPremium ? Int.max : 5
    }
    
    /// Capsule privacy features (premium only)
    var canUseCapsulePrivacy: Bool {
        isPremium
    }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
}
