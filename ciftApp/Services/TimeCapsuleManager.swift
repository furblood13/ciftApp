//
//  TimeCapsuleManager.swift
//  ciftApp
//
//  Us & Time - Time Capsule Manager
//

import Foundation
import Observation
import Supabase

@Observable
final class TimeCapsuleManager {
    var capsules: [TimeCapsule] = []
    var isLoading = false
    var errorMessage: String?
    var currentUserId: UUID?
    
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Load All Capsules
    @MainActor
    func loadCapsules() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            currentUserId = userId
            
            // Get my couple_id first
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId else {
                print("🔵 [Capsule] No couple found")
                return
            }
            
            // Load all capsules for this couple
            let allCapsules: [TimeCapsule] = try await supabase
                .from("time_capsules")
                .select()
                .eq("couple_id", value: coupleId)
                .order("unlock_date", ascending: false)
                .execute()
                .value
            
            capsules = allCapsules
            print("🟢 [Capsule] Loaded \(capsules.count) capsules")
            
        } catch {
            print("🔴 [Capsule] Error loading: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Create Capsule
    @MainActor
    func createCapsule(
        title: String,
        message: String,
        unlockDate: Date,
        hideTitle: Bool = false,
        hideCountdown: Bool = false,
        hidePreview: Bool = false
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // Get my profile for couple_id and partner_id
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let coupleId = profile.coupleId,
                  let partnerId = profile.partnerId else {
                print("🔴 [Capsule] No couple or partner found")
                errorMessage = "Partner bulunamadı"
                return false
            }
            
            // Format date for Supabase
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: unlockDate)
            
            let request = CreateCapsuleRequest(
                couple_id: coupleId,
                created_by: userId,
                recipient_id: partnerId,
                title: title,
                message_content: message,
                unlock_date: dateString,
                is_locked: true,
                hide_title: hideTitle,
                hide_countdown: hideCountdown,
                hide_preview: hidePreview
            )
            
            try await supabase
                .from("time_capsules")
                .insert(request)
                .execute()
            
            print("🟢 [Capsule] Created capsule for \(unlockDate)")
            
            // Reload capsules
            await loadCapsules()
            return true
            
        } catch {
            print("🔴 [Capsule] Error creating: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Delete Capsule
    @MainActor
    func deleteCapsule(id: UUID) async -> Bool {
        do {
            try await supabase
                .from("time_capsules")
                .delete()
                .eq("id", value: id)
                .execute()
            
            print("🟢 [Capsule] Deleted capsule: \(id)")
            
            // Remove from local array
            capsules.removeAll { $0.id == id }
            return true
            
        } catch {
            print("🔴 [Capsule] Error deleting: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Get Capsule Detail
    @MainActor
    func getCapsule(id: UUID) async -> TimeCapsule? {
        do {
            let capsule: TimeCapsule = try await supabase
                .from("time_capsules")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            return capsule
        } catch {
            print("🔴 [Capsule] Error getting capsule: \(error)")
            return nil
        }
    }
    
    // MARK: - Unlock Capsule (when time comes)
    @MainActor
    func unlockCapsule(id: UUID) async {
        do {
            // Set is_locked: false AND notification_sent: true
            // This prevents Edge Function from sending notification for already-opened capsules
            try await supabase
                .from("time_capsules")
                .update([
                    "is_locked": false,
                    "notification_sent": true
                ])
                .eq("id", value: id)
                .execute()
            
            print("🟢 [Capsule] Unlocked capsule: \(id)")
            await loadCapsules()
            
        } catch {
            print("🔴 [Capsule] Error unlocking: \(error)")
        }
    }
    
    // MARK: - Filtered Capsules
    
    /// Benim gönderdiğim kapsüller
    var sentCapsules: [TimeCapsule] {
        guard let userId = currentUserId else { return [] }
        return capsules.filter { $0.createdBy == userId }
    }
    
    /// Bana gelen kapsüller (tamamen gizli olanlar açılana kadar görünmez)
    var receivedCapsules: [TimeCapsule] {
        guard let userId = currentUserId else { return [] }
        return capsules.filter { capsule in
            guard capsule.recipientId == userId else { return false }
            
            // Eğer tamamen gizli ve henüz açılmamışsa, listede gösterme
            if (capsule.hidePreview ?? false) && capsule.isLocked && !capsule.canUnlock {
                return false
            }
            return true
        }
    }
    
    /// Kilitli kapsüller (bana gelenler)
    var lockedCapsules: [TimeCapsule] {
        receivedCapsules.filter { $0.isLocked && !$0.canUnlock }
    }
    
    /// Açık kapsüller (bana gelenler)
    var unlockedCapsules: [TimeCapsule] {
        receivedCapsules.filter { !$0.isLocked || $0.canUnlock }
    }
    
    /// Açılmayı bekleyenler (bana gelenler)
    var pendingUnlock: [TimeCapsule] {
        receivedCapsules.filter { $0.isLocked && $0.canUnlock }
    }
}
