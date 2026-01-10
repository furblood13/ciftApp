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
        defer { 
            isLoading = false
            // Note: We deliberately do NOT set initialCheckDone = true here in defer.
            // We only set it on successful execution.
        }
        print("🔵 [Check] Checking pairing status...")
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            isPaired = profile.partnerId != nil
            print("🔵 [Check] isPaired: \(isPaired)")
            
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

