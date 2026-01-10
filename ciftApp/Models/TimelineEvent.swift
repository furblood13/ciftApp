//
//  TimelineEvent.swift
//  ciftApp
//
//  Us & Time - Timeline Event Model
//

import Foundation
import SwiftUI

// MARK: - Enums
enum EventType: String, Codable, CaseIterable {
    case memory = "memory"
    case conflict = "conflict"
    case peace = "peace"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        // Handle case-insensitivity (e.g. "Memory" -> "memory")
        guard let value = EventType(rawValue: string.lowercased()) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot initialize EventType from invalid String value \(string)")
        }
        self = value
    }
    
    var label: String {
        switch self {
        case .memory: return "Anı"
        case .conflict: return "Tartışma"
        case .peace: return "Barış"
        }
    }
    
    var icon: String {
        switch self {
        case .memory: return "heart.fill"
        case .conflict: return "bolt.fill"
        case .peace: return "leaf.fill"
        }
    }
}

enum ConflictCategory: String, Codable, CaseIterable {
    case communication = "communication"
    case jealousy = "jealousy"
    case finance = "finance"
    case family = "family"
    case time = "time"
    case other = "other"
    case food = "food"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = ConflictCategory(rawValue: string.lowercased()) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot initialize ConflictCategory from invalid String value \(string)")
        }
        self = value
    }
    
    var label: String {
        switch self {
        case .communication: return String(localized: "conflict.communication")
        case .jealousy: return String(localized: "conflict.jealousy")
        case .finance: return String(localized: "conflict.finance")
        case .family: return String(localized: "conflict.family")
        case .time: return String(localized: "conflict.time")
        case .other: return String(localized: "conflict.other")
        case .food: return String(localized: "conflict.food")
        }
    }
    
    var icon: String {
        switch self {
        case .communication: return "message.fill"
        case .jealousy: return "eye.fill"
        case .finance: return "banknote.fill"
        case .family: return "house.fill"
        case .time: return "clock.fill"
        case .other: return "questionmark.circle.fill"
        case .food: return "fork.knife"
        }
    }
}

enum MilestoneType: String, Codable, CaseIterable {
    case anniversary = "anniversary"
    case firstDate = "first_date"
    case proposal = "proposal"
    case wedding = "wedding"
    case trip = "trip"
    case other = "other"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = MilestoneType(rawValue: string.lowercased()) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot initialize MilestoneType from invalid String value \(string)")
        }
        self = value
    }
    
    var label: String {
        switch self {
        case .anniversary: return String(localized: "milestones.anniversary")
        case .firstDate: return String(localized: "milestones.firstDate")
        case .proposal: return String(localized: "milestones.proposal")
        case .wedding: return String(localized: "milestones.wedding")
        case .trip: return String(localized: "milestones.trip")
        case .other: return String(localized: "milestones.other")
        }
    }
    
    var icon: String {
        switch self {
        case .anniversary: return "heart.circle.fill"
        case .firstDate: return "figure.2.and.child.holdinghands"
        case .proposal: return "star.circle.fill"
        case .wedding: return "heart.fill"
        case .trip: return "airplane"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Timeline Event Model
struct TimelineEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let coupleId: UUID?
    let type: EventType
    let date: String
    let title: String
    let description: String?
    
    // Media & Location
    let photoUrl: String?
    let photoUrls: [String]?
    let locationName: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    
    // Conflict specific
    let conflictCategory: ConflictCategory?
    let severity: Int?
    let isResolved: Bool?
    let whoStarted: UUID?
    
    // Peace specific
    let lessonLearned: String?
    let linkedConflictId: UUID?
    
    // Milestone
    let isMilestone: Bool?
    let milestoneType: MilestoneType?
    
    // Metadata
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case type
        case date
        case title
        case description
        case photoUrl = "photo_url"
        case photoUrls = "photo_urls"
        case locationName = "location_name"
        case locationLatitude = "location_latitude"
        case locationLongitude = "location_longitude"
        case conflictCategory = "conflict_category"
        case severity
        case isResolved = "is_resolved"
        case whoStarted = "who_started"
        case lessonLearned = "lesson_learned"
        case linkedConflictId = "linked_conflict_id"
        case isMilestone = "is_milestone"
        case milestoneType = "milestone_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed Properties
    
    /// Converts date string to Date object
    var dateValue: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
    
    var hasLocation: Bool {
        locationLatitude != nil && locationLongitude != nil
    }
    
    var hasPhoto: Bool {
        (photoUrl != nil && !photoUrl!.isEmpty) || (photoUrls != nil && !photoUrls!.isEmpty)
    }
    
    var displayPhotoUrl: String? {
        if let url = photoUrl, !url.isEmpty { return url }
        return photoUrls?.first
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: dateValue)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale.current
        return formatter.string(from: dateValue)
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: dateValue)
    }
}

// MARK: - Create Request
struct CreateTimelineEventRequest: Encodable {
    let couple_id: UUID
    let type: String
    let date: String
    let title: String
    let description: String?
    let photo_url: String?
    let photo_urls: [String]?
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let conflict_category: String?
    let severity: Int?
    let is_resolved: Bool?
    let who_started: UUID?
    let lesson_learned: String?
    let linked_conflict_id: UUID?
    let is_milestone: Bool?
    let milestone_type: String?
    let created_by: UUID
}
