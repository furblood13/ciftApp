//
//  Couple.swift
//  ciftApp
//
//  Us & Time - Couple Model
//

import Foundation

struct Couple: Codable, Identifiable {
    let id: UUID
    var startDate: String?
    var inviteCode: String
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDate = "start_date"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
