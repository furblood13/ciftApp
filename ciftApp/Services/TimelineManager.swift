//
//  TimelineManager.swift
//  ciftApp
//
//  Us & Time - Timeline Manager Service (Updated Phase 12)
//

import Foundation
import Observation
import Supabase
import PhotosUI
import SwiftUI

@Observable
final class TimelineManager {
    var events: [TimelineEvent] = []
    var isLoading = false
    var errorMessage: String?
    var currentUserId: UUID?
    var currentUserName: String? // Added for sharing
    var coupleId: UUID?
    var partnerId: UUID?
    var partnerName: String?
    
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Load All Events
    @MainActor
    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            currentUserId = userId
            
            // Get couple_id
            // Assuming Profile is defined globally or we use a local struct for decoding
            struct LocalProfile: Decodable {
                let id: UUID
                let couple_id: UUID?
                let username: String?
            }
            
            let profile: LocalProfile = try await supabase
                .from("profiles")
                .select("id, couple_id, username")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            currentUserName = profile.username // Store current user name
            
            guard let cId = profile.couple_id else {
                print("🔵 [Timeline] No couple found")
                return
            }
            coupleId = cId
            
            // Fetch Partner Info directly from profiles (safer)
            struct PartnerProfile: Decodable {
                let id: UUID
                let username: String?
            }
            
            // Find user in same couple who is NOT me
            do {
                let partner: PartnerProfile = try await supabase
                    .from("profiles")
                    .select("id, username")
                    .eq("couple_id", value: cId)
                    .neq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                partnerId = partner.id
                partnerName = partner.username
            } catch {
                print("🟡 [Timeline] Partner not found or single fetch error: \(error)")
                // It's possible partner hasn't joined yet
            }
            
            // Load events (newest first)
            let allEvents: [TimelineEvent] = try await supabase
                .from("timeline_events")
                .select()
                .eq("couple_id", value: cId)
                .order("date", ascending: false)
                .execute()
                .value
            
            events = allEvents
            print("🟢 [Timeline] Loaded \(events.count) events")
            
        } catch {
            print("🔴 [Timeline] Error loading: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Create Memory Event (Multi-Photo Supported)
    @MainActor
    func createMemory(
        title: String,
        description: String?,
        date: Date,
        photoData: [Data]?, // Changed to array
        locationName: String?,
        latitude: Double?,
        longitude: Double?,
        isMilestone: Bool = false,
        milestoneType: MilestoneType? = nil
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let userId = currentUserId, let cId = coupleId else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User veya couple bulunamadı"])
            }
            
            // Upload photos if exist
            var photoUrls: [String] = []
            if let dataItems = photoData, !dataItems.isEmpty {
                photoUrls = try await uploadPhotos(dataItems: dataItems, coupleId: cId)
            }
            
            let request = CreateTimelineEventRequest(
                couple_id: cId,
                type: EventType.memory.rawValue.capitalized,
                date: formatDate(date),
                title: title,
                description: description,
                photo_url: photoUrls.first, // Legacy support
                photo_urls: photoUrls, // New Multi-photo
                location_name: locationName,
                location_latitude: latitude,
                location_longitude: longitude,
                conflict_category: nil,
                severity: nil,
                is_resolved: nil,
                who_started: nil,
                lesson_learned: nil,
                linked_conflict_id: nil,
                is_milestone: isMilestone,
                milestone_type: milestoneType?.rawValue,
                created_by: userId
            )
            
            try await supabase
                .from("timeline_events")
                .insert(request)
                .execute()
            
            print("🟢 [Timeline] Memory created: \(title) with \(photoUrls.count) photos")
            await loadEvents()
            return true
            
        } catch {
            print("🔴 [Timeline] Error creating memory: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Create Conflict Event
    @MainActor
    func createConflict(
        title: String,
        description: String?,
        date: Date,
        category: ConflictCategory,
        severity: Int,
        whoStarted: UUID?
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let userId = currentUserId, let cId = coupleId else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User veya couple bulunamadı"])
            }
            
            let request = CreateTimelineEventRequest(
                couple_id: cId,
                type: EventType.conflict.rawValue.capitalized,
                date: formatDate(date),
                title: title,
                description: description,
                photo_url: nil,
                photo_urls: nil,
                location_name: nil,
                location_latitude: nil,
                location_longitude: nil,
                conflict_category: category.rawValue.capitalized,
                severity: severity,
                is_resolved: false,
                who_started: whoStarted,
                lesson_learned: nil,
                linked_conflict_id: nil,
                is_milestone: false,
                milestone_type: nil,
                created_by: userId
            )
            
            try await supabase
                .from("timeline_events")
                .insert(request)
                .execute()
            
            print("🟢 [Timeline] Conflict created: \(title)")
            await loadEvents()
            return true
            
        } catch {
            print("🔴 [Timeline] Error creating conflict: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Create Peace Event
    @MainActor
    func createPeace(
        title: String,
        lessonLearned: String?,
        date: Date,
        linkedConflictId: UUID?
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let userId = currentUserId, let cId = coupleId else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User veya couple bulunamadı"])
            }
            
            let request = CreateTimelineEventRequest(
                couple_id: cId,
                type: EventType.peace.rawValue.capitalized,
                date: formatDate(date),
                title: title,
                description: nil,
                photo_url: nil,
                photo_urls: nil,
                location_name: nil,
                location_latitude: nil,
                location_longitude: nil,
                conflict_category: nil,
                severity: nil,
                is_resolved: nil,
                who_started: nil,
                lesson_learned: lessonLearned,
                linked_conflict_id: linkedConflictId,
                is_milestone: false,
                milestone_type: nil,
                created_by: userId
            )
            
            try await supabase
                .from("timeline_events")
                .insert(request)
                .execute()
            
            // If linked to conflict, mark it as resolved
            if let conflictId = linkedConflictId {
                try await supabase
                    .from("timeline_events")
                    .update(["is_resolved": true])
                    .eq("id", value: conflictId)
                    .execute()
            }
            
            print("🟢 [Timeline] Peace created: \(title)")
            await loadEvents()
            return true
            
        } catch {
            print("🔴 [Timeline] Error creating peace: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Resolve Conflict
    @MainActor
    func resolveConflict(eventId: UUID, lesson: String?) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Optional lesson learned
            struct ResolveUpdate: Encodable {
                let is_resolved: Bool
                let lesson_learned: String?
            }
            
            let update = ResolveUpdate(is_resolved: true, lesson_learned: lesson)
            
            try await supabase
                .from("timeline_events")
                .update(update)
                .eq("id", value: eventId)
                .execute()
            
            print("🟢 [Timeline] Conflict resolved: \(eventId)")
            await loadEvents()
            return true
            
        } catch {
            print("🔴 [Timeline] Error resolving conflict: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Delete Event
    @MainActor
    func deleteEvent(id: UUID) async -> Bool {
        do {
            try await supabase
                .from("timeline_events")
                .delete()
                .eq("id", value: id)
                .execute()
            
            events.removeAll { $0.id == id }
            print("🟢 [Timeline] Deleted event: \(id)")
            return true
            
        } catch {
            print("🔴 [Timeline] Error deleting: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Upload Photos
    private func uploadPhotos(dataItems: [Data], coupleId: UUID) async throws -> [String] {
        var urls: [String] = []
        for data in dataItems {
            let url = try await uploadPhoto(data: data, coupleId: coupleId)
            urls.append(url)
        }
        return urls
    }
    
    private func uploadPhoto(data: Data, coupleId: UUID) async throws -> String {
        let fileName = "\(coupleId)/\(UUID().uuidString).jpg"
        
        try await supabase.storage
            .from("timeline-photos")
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        let publicUrl = try supabase.storage
            .from("timeline-photos")
            .getPublicURL(path: fileName)
        
        return publicUrl.absoluteString
    }
    
    // MARK: - Filtered Events
    
    var memories: [TimelineEvent] {
        events.filter { $0.type == .memory }
    }
    
    var conflicts: [TimelineEvent] {
        events.filter { $0.type == .conflict }
    }
    
    var peaceEvents: [TimelineEvent] {
        events.filter { $0.type == .peace }
    }
    
    var unresolvedConflicts: [TimelineEvent] {
        conflicts.filter { !($0.isResolved ?? false) }
    }
    
    var milestones: [TimelineEvent] {
        events.filter { $0.isMilestone ?? false }
    }
    
    /// Group events by month/year
    var eventsByMonth: [(key: String, events: [TimelineEvent])] {
        let grouped = Dictionary(grouping: events) { $0.monthYear }
        return grouped.map { (key: $0.key, events: $0.value) }
            .sorted { $0.events.first?.dateValue ?? Date() > $1.events.first?.dateValue ?? Date() }
    }
    
    // MARK: - Statistics
    
    var totalMemories: Int { memories.count }
    var totalConflicts: Int { conflicts.count }
    var resolvedConflicts: Int { conflicts.filter { $0.isResolved ?? false }.count }
    
    var mostCommonConflictCategory: ConflictCategory? {
        let categories = conflicts.compactMap { $0.conflictCategory }
        let counts = Dictionary(grouping: categories) { $0 }.mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    var averageSeverity: Double {
        let severities = conflicts.compactMap { $0.severity }
        guard !severities.isEmpty else { return 0 }
        return Double(severities.reduce(0, +)) / Double(severities.count)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
