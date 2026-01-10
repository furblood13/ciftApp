//
//  Todo.swift
//  ciftApp
//
//  Us & Time - Shared Todo Model
//

import Foundation

struct Todo: Identifiable, Codable, Equatable {
    let id: UUID
    var coupleId: UUID
    var title: String
    var isCompleted: Bool
    var createdBy: UUID?
    var completedBy: UUID?
    var createdAt: Date?
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case title
        case isCompleted = "is_completed"
        case createdBy = "created_by"
        case completedBy = "completed_by"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}
