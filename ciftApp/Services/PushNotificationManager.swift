//
//  PushNotificationManager.swift
//  ciftApp
//
//  Us & Time - Push Notification Manager (APNs)
//

import Foundation
import UserNotifications
import UIKit
import Supabase

@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()
    
    var isAuthorized = false
    var deviceToken: String?
    
    private let supabase = SupabaseManager.shared.client
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission
    func requestPermission() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                isAuthorized = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("🟢 [Push] Permission granted")
            } else {
                print("🔵 [Push] Permission denied")
            }
            
            return granted
        } catch {
            print("🔴 [Push] Permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Handle Device Token
    @MainActor
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("🟢 [Push] Device token: \(token)")
        
        // Save to Supabase
        Task {
            await saveTokenToDatabase(token)
        }
    }
    
    // MARK: - Save Token to Database
    @MainActor
    private func saveTokenToDatabase(_ token: String) async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            try await supabase
                .from("profiles")
                .update(["apns_token": token])
                .eq("id", value: userId)
                .execute()
            
            print("🟢 [Push] Token saved to database")
            
        } catch {
            print("🔴 [Push] Error saving token: \(error)")
        }
    }
    
    // MARK: - Handle Notification
    func handleNotification(userInfo: [AnyHashable: Any]) {
        // Check if it's a capsule notification
        if let capsuleId = userInfo["capsule_id"] as? String {
            print("🔵 [Push] Capsule notification: \(capsuleId)")
            
            // Post notification for deep linking
            NotificationCenter.default.post(
                name: .openCapsule,
                object: nil,
                userInfo: ["capsuleId": capsuleId]
            )
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openCapsule = Notification.Name("openCapsule")
}
