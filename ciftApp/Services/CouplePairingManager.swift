//
//  CouplePairingManager.swift
//  ciftApp
//
//  Us & Time - Couple Pairing Operations
//

import Foundation
import Observation
import Supabase

@Observable
final class CouplePairingManager {
    var isLoading = false
    var errorMessage: String?
    var generatedCode: String?
    var isPaired = false
    var partnerName: String?
    var initialCheckDone = false // Track if we've performed the initial check
    
    private var listeningTask: Task<Void, Never>?
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Reset State
    @MainActor
    func reset() async {
        print("🔵 [Reset] Resetting pairing manager state")
        stopListening()
        isLoading = false
        errorMessage = nil
        generatedCode = nil
        isPaired = false
        partnerName = nil
        initialCheckDone = false
    }
    
    // MARK: - Generate Invite Code
    @MainActor
    func generateInviteCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            print("🔵 [Pairing] Generating code for user: \(userId)")
            
            // Check if user already has a PARTNER
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            if profile.partnerId != nil {
                print("🔴 [Pairing] User already has a partner")
                errorMessage = "Zaten bir partneriniz var!"
                return
            }
            
            // Check if user already has a pending code THEY created
            let existingCouples: [CoupleWithCreator] = try await supabase
                .from("couples")
                .select()
                .eq("creator_id", value: userId)
                .execute()
                .value
            
            print("🔵 [Pairing] User's existing couples: \(existingCouples.count)")
            
            if let existingCouple = existingCouples.first {
                print("🔵 [Pairing] Returning existing code: \(existingCouple.inviteCode)")
                generatedCode = existingCouple.inviteCode
                return
            }
            
            // Generate unique 6-character code
            let code = generateUniqueCode()
            print("🔵 [Pairing] Generated new code: \(code)")
            
            // Create couple
            try await supabase
                .from("couples")
                .insert([
                    "invite_code": code,
                    "creator_id": userId.uuidString
                ])
                .execute()
            
            print("🟢 [Pairing] Code created successfully")
            generatedCode = code
            
        } catch {
            print("🔴 [Pairing] Error: \(error)")
            errorMessage = "Kod oluşturulamadı: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Join with Code
    @MainActor
    func joinWithCode(_ code: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            print("🔵 [Join] User \(userId) joining with code: \(code)")
            
            // Call the pair_users database function
            let response: PairUsersResponse = try await supabase
                .rpc("pair_users", params: [
                    "p_invite_code": code,
                    "p_joiner_id": userId.uuidString
                ])
                .execute()
                .value
            
            print("🔵 [Join] Response: success=\(response.success), error=\(response.error ?? "none")")
            
            if response.success {
                print("🟢 [Join] Pairing complete!")
                isPaired = true
                
                // Sync premium status after pairing
                await syncPremiumAfterPairing(userId: userId)
            } else {
                switch response.error {
                case "Already have a partner":
                    errorMessage = "Zaten bir partneriniz var!"
                case "Invalid code":
                    errorMessage = "Geçersiz kod!"
                case "Cannot use own code":
                    errorMessage = "Kendi kodunuzu kullanamazsınız!"
                default:
                    errorMessage = response.error ?? "Bilinmeyen hata"
                }
            }
            
        } catch {
            print("🔴 [Join] Error: \(error)")
            errorMessage = "Eşleşme başarısız: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Check Pairing Status
    @MainActor
    func checkPairingStatus() async {
        isLoading = true
        defer { isLoading = false }
        print("🔵 [Check] Checking pairing status...")
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Use a simple struct for pairing check - avoids decode issues with new fields
            struct SimpleProfile: Codable {
                let id: UUID
                let partnerId: UUID?
                let coupleId: UUID?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case partnerId = "partner_id"
                    case coupleId = "couple_id"
                }
            }
            
            // Fetch only essential fields for pairing check
            let profiles: [SimpleProfile] = try await supabase
                .from("profiles")
                .select("id, partner_id, couple_id")
                .eq("id", value: userId)
                .execute()
                .value
            
            guard let profile = profiles.first else {
                print("🔴 [Check] No profile found for user")
                isPaired = false
                initialCheckDone = true  // Profile doesn't exist, this is a valid state
                return
            }
            
            isPaired = profile.partnerId != nil
            print("🔵 [Check] isPaired: \(isPaired), partnerId: \(profile.partnerId?.uuidString ?? "nil")")
            
            // Only mark as done if we successfully got a response
            initialCheckDone = true
            
            // Only check for pending code if not paired
            if !isPaired {
                // Check for codes THIS USER created
                let myCreatedCouples: [CoupleWithCreator] = try await supabase
                    .from("couples")
                    .select()
                    .eq("creator_id", value: userId)
                    .execute()
                    .value
                
                if let myCouple = myCreatedCouples.first {
                    print("🔵 [Check] Found my pending code: \(myCouple.inviteCode)")
                    generatedCode = myCouple.inviteCode
                } else {
                    print("🔵 [Check] No pending code found")
                    generatedCode = nil
                }
            }
            
        } catch {
            print("🔴 [Check] Error: \(error)")
            // DO NOT set initialCheckDone = true here
            // This allows the retry loop in ciftAppApp to retry
            // The error is likely due to session not being ready yet
            isPaired = false
            generatedCode = nil
        }
    }
    
    // MARK: - Start Listening
    func startListeningForPairing() async {
        // Cancel any existing listener
        listeningTask?.cancel()
        
        guard let userId = try? await supabase.auth.session.user.id else {
            print("🔴 [Listen] No user session")
            return
        }
        
        print("🔵 [Listen] Starting listener for user: \(userId)")
        
        listeningTask = Task { @MainActor in
            var pollCount = 0
            
            while !Task.isCancelled && !self.isPaired {
                pollCount += 1
                
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    if Task.isCancelled { 
                        print("🔵 [Listen] Task cancelled")
                        break 
                    }
                    
                    print("🔵 [Listen] Poll #\(pollCount) checking partner...")
                    
                    let profile: Profile = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value
                    
                    print("🔵 [Listen] Poll #\(pollCount) partnerId: \(profile.partnerId?.uuidString ?? "nil")")
                    
                    if profile.partnerId != nil {
                        print("🟢 [Listen] Partner detected! Updating isPaired...")
                        self.isPaired = true
                        self.generatedCode = nil
                        print("🟢 [Listen] isPaired is now: \(self.isPaired)")
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        print("🔴 [Listen] Poll error: \(error)")
                    }
                }
            }
            
            print("🔵 [Listen] Listener stopped. isPaired: \(self.isPaired)")
        }
    }
    
    // MARK: - Cancel Pending Code
    @MainActor
    func cancelPendingCode() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            try await supabase
                .from("couples")
                .delete()
                .eq("creator_id", value: userId)
                .execute()
            
            generatedCode = nil
            print("� [Cancel] Code cancelled")
            
        } catch {
            print("🔴 [Cancel] Error: \(error)")
            errorMessage = "Kod iptal edilemedi"
        }
    }
    
    // MARK: - Delete Couple Permanently
    @MainActor
    func deleteCouple() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            print("🔵 [Delete] Deleting couple for user: \(userId)")
            
            // Call the delete_couple database function
            let response: DeleteCoupleResponse = try await supabase
                .rpc("delete_couple", params: ["p_user_id": userId.uuidString])
                .execute()
                .value
            
            if response.success {
                print("🟢 [Delete] Couple deleted successfully")
                // Reset local state
                isPaired = false
                generatedCode = nil
                partnerName = nil
                initialCheckDone = false
                return true
            } else if response.error == "Not in a couple" {
                // Partner already deleted the couple - treat as success
                print("🟡 [Delete] Already not in a couple, navigating to pairing...")
                isPaired = false
                generatedCode = nil
                partnerName = nil
                initialCheckDone = false
                return true
            } else {
                print("🔴 [Delete] Error: \(response.error ?? "Unknown")")
                errorMessage = response.error ?? "Silme işlemi başarısız"
                return false
            }
            
        } catch {
            print("🔴 [Delete] Error: \(error)")
            errorMessage = "Silme hatası: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
    }
    
    // MARK: - Helper
    private func generateUniqueCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Delete Response Model
private struct DeleteCoupleResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Helper Model
private struct CoupleWithCreator: Codable {
    let id: UUID
    var startDate: String?
    var inviteCode: String
    var creatorId: UUID?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
        case inviteCode = "invite_code"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Response from pair_users database function
private struct PairUsersResponse: Codable {
    let success: Bool
    let error: String?
    let coupleId: String?
    let partnerId: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case error
        case coupleId = "couple_id"
        case partnerId = "partner_id"
    }
}

// MARK: - Premium Sync Extension
extension CouplePairingManager {
    /// Syncs premium status to new couple after pairing
    @MainActor
    func syncPremiumAfterPairing(userId: UUID) async {
        do {
            // Get user's profile
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            guard let profile = profiles.first,
                  let coupleId = profile.coupleId else {
                print("🔴 [Premium] No profile or couple to sync")
                return
            }
            
            // If user has premium, sync to couple
            if profile.isPremium == true {
                print("🔵 [Premium] User has premium, syncing to couple...")
                
                try await supabase
                    .from("couples")
                    .update(["is_premium": true])
                    .eq("id", value: coupleId)
                    .execute()
                
                print("🟢 [Premium] Synced premium to new couple")
            }
            
            // Also check partner's premium
            if let partnerId = profile.partnerId {
                let partnerProfiles: [Profile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: partnerId)
                    .execute()
                    .value
                
                if let partnerProfile = partnerProfiles.first,
                   partnerProfile.isPremium == true {
                    print("🔵 [Premium] Partner has premium, syncing to couple...")
                    
                    try await supabase
                        .from("couples")
                        .update(["is_premium": true])
                        .eq("id", value: coupleId)
                        .execute()
                    
                    print("🟢 [Premium] Synced partner premium to couple")
                }
            }
            
            // Refresh subscription status
            await SubscriptionManager.shared.checkSubscriptionStatus()
            
        } catch {
            print("🔴 [Premium] Sync error: \(error)")
        }
    }
}
