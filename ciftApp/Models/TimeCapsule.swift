//
//  TimeCapsule.swift
//  ciftApp
//
//  Us & Time - Time Capsule Model
//

import Foundation

struct TimeCapsule: Codable, Identifiable {
    let id: UUID
    let coupleId: UUID?
    let createdBy: UUID?
    let recipientId: UUID?
    let title: String?
    let messageContent: String?
    let mediaUrl: String?
    let unlockDate: Date
    let isLocked: Bool
    let notificationSent: Bool?
    let createdAt: Date?
    
    // Privacy options
    let hideTitle: Bool?
    let hideCountdown: Bool?
    let hidePreview: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case createdBy = "created_by"
        case recipientId = "recipient_id"
        case title
        case messageContent = "message_content"
        case mediaUrl = "media_url"
        case unlockDate = "unlock_date"
        case isLocked = "is_locked"
        case notificationSent = "notification_sent"
        case createdAt = "created_at"
        case hideTitle = "hide_title"
        case hideCountdown = "hide_countdown"
        case hidePreview = "hide_preview"
    }
    
    /// Kapsül açılabilir mi?
    var canUnlock: Bool {
        Date() >= unlockDate
    }
    
    /// Kalan süre
    var timeRemaining: String {
        guard isLocked && !canUnlock else { return "Açıldı! 🎉" }
        
        let interval = unlockDate.timeIntervalSince(Date())
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days) gün \(hours) saat"
        } else if hours > 0 {
            return "\(hours) saat \(minutes) dk"
        } else if minutes > 0 {
            return "\(minutes) dakika"
        } else {
            return "Birazdan açılacak..."
        }
    }
    
    /// Kullanıcı bu kapsülün yaratıcısı mı?
    func isCreator(userId: UUID) -> Bool {
        createdBy == userId
    }
    
    /// Kullanıcı bu kapsülün alıcısı mı?
    func isRecipient(userId: UUID) -> Bool {
        recipientId == userId
    }
    
    /// Başlık görünür mü?
    func shouldShowTitle(for userId: UUID) -> Bool {
        if isCreator(userId: userId) { return true }
        if canUnlock || !isLocked { return true }
        return !(hideTitle ?? false)
    }
    
    /// Geri sayım görünür mü?
    func shouldShowCountdown(for userId: UUID) -> Bool {
        if isCreator(userId: userId) { return true }
        return !(hideCountdown ?? false)
    }
    
    /// Mesaj önizlemesi görünür mü?
    func shouldShowPreview(for userId: UUID) -> Bool {
        if isCreator(userId: userId) { return true }
        if canUnlock || !isLocked { return true }
        return !(hidePreview ?? false)
    }
}

// MARK: - Create Request
struct CreateCapsuleRequest: Encodable {
    let couple_id: UUID
    let created_by: UUID
    let recipient_id: UUID
    let title: String
    let message_content: String
    let unlock_date: String
    let is_locked: Bool
    let hide_title: Bool
    let hide_countdown: Bool
    let hide_preview: Bool
}
