
//
//  HomeManager.swift
//  ciftApp
//
//  Us & Time - Home Data Manager
//

import Foundation
import Observation
import Supabase
import WidgetKit

@Observable
final class HomeManager {
    var isLoading = false
    var errorMessage: String?
    
    // User data
    var myProfile: Profile?
    var partnerProfile: Profile?
    var couple: CoupleInfo?
    
    // Computed properties
    var daysTogether: Int {
        guard let startDateString = couple?.startDate,
              let startDate = parseDate(startDateString) else {
            return 0
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return components.day ?? 0
    }
    
    var myMood: MoodType {
        get { MoodType(rawValue: myProfile?.currentMood ?? "Happy") ?? .happy }
        set { 
            Task { await updateMyMood(newValue) }
        }
    }
    
    var partnerMood: MoodType {
        MoodType(rawValue: partnerProfile?.currentMood ?? "Happy") ?? .happy
    }
    
    private let supabase = SupabaseManager.shared.client
    private var refreshTask: Task<Void, Never>?
    
    // MARK: - Load All Data
    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            print("🔵 [Home] Loading data for user: \(userId)")
            
            // Load my profile
            myProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("🔵 [Home] My profile loaded: \(myProfile?.username ?? "no name")")
            
            // Load partner profile if exists
            if let partnerId = myProfile?.partnerId {
                let partners: [Profile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: partnerId)
                    .execute()
                    .value
                
                partnerProfile = partners.first
                print("🔵 [Home] Partner loaded: \(partnerProfile?.username ?? "no name")")
            }
            
            // Load couple info
            if let coupleId = myProfile?.coupleId {
                let couples: [CoupleInfo] = try await supabase
                    .from("couples")
                    .select()
                    .eq("id", value: coupleId)
                    .execute()
                    .value
                
                couple = couples.first
                print("🔵 [Home] Couple loaded, start date: \(couple?.startDate ?? "nil")")
            }
            
            // Sync widget
            updateWidget()
            
        } catch {
            print("🔴 [Home] Error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Update My Mood
    @MainActor
    func updateMyMood(_ mood: MoodType) async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            try await supabase
                .from("profiles")
                .update(["current_mood": mood.rawValue])
                .eq("id", value: userId)
                .execute()
            
            myProfile?.currentMood = mood.rawValue
            print("🟢 [Home] Mood updated to: \(mood.rawValue)")
            
            // Sync widget
            updateWidget()
            
        } catch {
            print("🔴 [Home] Error updating mood: \(error)")
        }
    }
    
    // MARK: - Update Relationship Start Date
    @MainActor
    func updateStartDate(_ date: Date) async {
        guard let coupleId = myProfile?.coupleId else {
            print("🔴 [Home] No couple ID found")
            return
        }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            
            try await supabase
                .from("couples")
                .update(["start_date": dateString])
                .eq("id", value: coupleId)
                .execute()
            
            couple?.startDate = dateString
            print("🟢 [Home] Start date updated to: \(dateString)")
            
            // Update widget
            updateWidget()
            
        } catch {
            print("🔴 [Home] Error updating start date: \(error)")
        }
    }
    
    // MARK: - Start Auto-Refresh (for partner mood updates)
    func startAutoRefresh() {
        refreshTask?.cancel()
        
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                if Task.isCancelled { break }
                
                // Refresh partner profile only
                if let partnerId = myProfile?.partnerId {
                    if let partners: [Profile] = try? await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: partnerId)
                        .execute()
                        .value {
                        partnerProfile = partners.first
                        print("🔵 [Home] Partner refreshed, mood: \(partnerProfile?.currentMood ?? "nil")")
                        
                        // Update widget with new partner data
                        self.updateWidget()
                    }
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    // MARK: - Update Widget Data
    func updateWidget() {
        print("🔄 [Widget] Attempting to update widget data (File Based)...")
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.furkanbugrakarci.ciftApp") else {
            print("🔴 [Widget] CRITICAL: Failed to access App Group Container. Check Entitlements & Provisioning.")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_data.json")
        print("📝 [Widget] Writing to file: \(fileURL.path)")
        
        // Prepare Payload
        let pMoodImage = partnerMood.imageName
        let pMoodLabel = partnerMood.label
        let pName = partnerProfile?.username ?? "Partner"
        
        // My Mood
        let mMoodImage = myMood.imageName
        let mMoodLabel = myMood.label
        
        let widgetData = WidgetDataPayload(
            daysTogether: daysTogether,
            partnerMoodImage: pMoodImage,
            partnerMoodLabel: pMoodLabel,
            partnerName: pName,
            myMoodImage: mMoodImage,
            myMoodLabel: mMoodLabel,
            lastUpdated: Date().timeIntervalSince1970
        )
        
        do {
            let data = try JSONEncoder().encode(widgetData)
            try data.write(to: fileURL)
            print("💾 [Widget] Saved JSON - Days: \(daysTogether), PartnerMood: \(pMoodImage), MyMood: \(mMoodImage)")
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadAllTimelines()
            print("🟢 [Widget] Reload requested")
        } catch {
            print("🔴 [Widget] Failed to write JSON: \(error)")
        }
    }
    
    struct WidgetDataPayload: Codable {
        let daysTogether: Int
        let partnerMoodImage: String
        let partnerMoodLabel: String
        let partnerName: String
        let myMoodImage: String
        let myMoodLabel: String
        let lastUpdated: TimeInterval
    }

    
    // MARK: - Helper
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Mood Type Enum
enum MoodType: String, CaseIterable {
    case happy = "Happy"
    case loved = "Loved"
    case tired = "Tired"
    case needAttention = "NeedAttention"
    case sad = "Sad"
    
    /// Asset image name for the mascot
    var imageName: String {
        switch self {
        case .happy: return "happy"
        case .loved: return "loved"
        case .tired: return "tired"
        case .needAttention: return "needAttention"
        case .sad: return "sad"
        }
    }
    
    /// Emoji fallback (for notifications, etc.)
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .loved: return "😍"
        case .tired: return "😴"
        case .needAttention: return "🥺"
        case .sad: return "😢"
        }
    }
    
    var label: String {
        switch self {
        case .happy: return String(localized: "mood.happy")
        case .loved: return String(localized: "mood.inLove")
        case .tired: return String(localized: "mood.tired")
        case .needAttention: return String(localized: "mood.leaveMeAlone")
        case .sad: return String(localized: "mood.happy") // fallback, can add mood.sad
        }
    }
    
    var color: String {
        switch self {
        case .happy: return "green"
        case .loved: return "pink"
        case .tired: return "gray"
        case .needAttention: return "orange"
        case .sad: return "blue"
        }
    }
}


// MARK: - Couple Info Model
struct CoupleInfo: Codable {
    let id: UUID
    var startDate: String?
    var inviteCode: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
        case inviteCode = "invite_code"
    }
}
