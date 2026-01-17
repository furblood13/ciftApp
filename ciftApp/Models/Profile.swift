//
//  Profile.swift
//  ciftApp
//
//  Us & Time - Profile Model
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    var username: String?
    var avatarUrl: String?
    var partnerId: UUID?
    var coupleId: UUID?
    var currentMood: String?
    var lastLatitude: Double?
    var lastLongitude: Double?
    var lastLocationUpdated: Date?
    var createdAt: Date?
    var updatedAt: Date?
    
    // Premium fields (Source of Truth)
    var isPremium: Bool?
    var subscriptionType: String?
    var subscriptionEndDate: String?  // Changed to String to avoid decode issues
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case partnerId = "partner_id"
        case coupleId = "couple_id"
        case currentMood = "current_mood"
        case lastLatitude = "last_latitude"
        case lastLongitude = "last_longitude"
        case lastLocationUpdated = "last_location_updated"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isPremium = "is_premium"
        case subscriptionType = "subscription_type"
        case subscriptionEndDate = "subscription_end_date"
    }
}
