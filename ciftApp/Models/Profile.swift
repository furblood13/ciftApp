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
    }
}
