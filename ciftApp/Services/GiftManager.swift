
//
//  GiftManager.swift
//  ciftApp
//
//  Us & Time - Gift Ideas Manager
//

import Foundation
import Observation
import SwiftUI

struct GiftIdea: Identifiable, Codable {
    let id: UUID
    var title: String
    var isPurchased: Bool
    let createdAt: Date
    
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isPurchased = false
        self.createdAt = Date()
    }
}

@Observable
class GiftManager {
    var gifts: [GiftIdea] = []
    private var currentUserId: String?
    
    // MARK: - Loading
    func loadGifts(for userId: String) {
        self.currentUserId = userId
        let key = "gift_ideas_\(userId)"
        
        if let data = UserDefaults.standard.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode([GiftIdea].self, from: data) {
                self.gifts = decoded.sorted(by: { $0.createdAt > $1.createdAt })
                return
            }
        }
        self.gifts = []
    }
    
    // MARK: - Actions
    func addGift(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newGift = GiftIdea(title: trimmed)
        gifts.insert(newGift, at: 0)
        save()
    }
    
    func toggleGift(_ gift: GiftIdea) {
        if let index = gifts.firstIndex(where: { $0.id == gift.id }) {
            gifts[index].isPurchased.toggle()
            save()
        }
    }
    
    func deleteGift(at offsets: IndexSet) {
        gifts.remove(atOffsets: offsets)
        save()
    }
    
    // MARK: - Persistence
    private func save() {
        guard let userId = currentUserId else { return }
        let key = "gift_ideas_\(userId)"
        
        if let encoded = try? JSONEncoder().encode(gifts) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
