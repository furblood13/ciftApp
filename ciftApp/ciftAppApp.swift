//
//  ciftAppApp.swift
//  ciftApp
//
//  Created by furkan buğra karcı on 21.12.2025.
//

import SwiftUI
import UserNotifications
import Lottie
import GoogleSignIn

// MARK: - Deep Link Destination
enum DeepLinkDestination: Hashable {
    case timeCapsule
    case timeCapsuleDetail(capsuleId: String)
}

@main
struct ciftAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @State private var pairingManager = CouplePairingManager()
    @State private var navigateToTimeCapsule = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    // Splash/Loading Screen
                    splashView
                } else if authManager.isAuthenticated {
                    // Check if we are still verifying pairing status
                    if !pairingManager.initialCheckDone {
                        splashView
                            .task {
                                // Retry loop for Splash Screen
                                while !pairingManager.initialCheckDone {
                                    await pairingManager.checkPairingStatus()
                                    if !pairingManager.initialCheckDone {
                                        try? await Task.sleep(nanoseconds: 3_000_000_000) // Wait 3s before retry
                                    }
                                }
                            }
                    } else if pairingManager.isPaired {
                        HomeView(authManager: authManager, pairingManager: pairingManager, navigateToTimeCapsule: $navigateToTimeCapsule)
                            .task {
                                // Request push notification permission
                                await PushNotificationManager.shared.requestPermission()
                            }
                    } else {
                        PairingView(authManager: authManager, pairingManager: pairingManager)
                            .task {
                                // Only start listening if user has a pending code
                                // This prevents unnecessary polling before code generation
                                if pairingManager.generatedCode != nil {
                                    await pairingManager.startListeningForPairing()
                                }
                            }
                            .onChange(of: pairingManager.generatedCode) { _, newCode in
                                // Start listening when a code is generated
                                if newCode != nil {
                                    Task {
                                        await pairingManager.startListeningForPairing()
                                    }
                                } else {
                                    pairingManager.stopListening()
                                }
                            }
                    }
                } else {
                    AuthView(authManager: authManager)
                }
            }
            .task {
                // Initial kick-off
                if authManager.isAuthenticated {
                    await pairingManager.checkPairingStatus()
                }
            }
            // Reset pairing state when auth changes
            .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
                if newValue {
                     // User just logged in - check pairing status
                    Task {
                        await pairingManager.reset()
                        await pairingManager.checkPairingStatus()
                    }
                } else {
                    // User logged out - reset everything
                    Task {
                        await pairingManager.reset()
                    }
                }
            }
            // Listen for capsule notification
            .onReceive(NotificationCenter.default.publisher(for: .openCapsule)) { notification in
                print("🔔 [DeepLink] Received openCapsule notification")
                navigateToTimeCapsule = true
            }
        }
    }
    
    private var splashView: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Animated Mascot
                LottieView(filename: "mascot_animation",loopMode: .loop)
                    .frame(width: 200, height: 200)
                    
                
                Text("ciftApp")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.black)
                
                Spacer()
                
                ProgressView()
                    .tint(.black)
                    .scaleEffect(1.2)
                    .padding(.bottom, 50)
            }
        }
        .transition(.opacity) // Smooth fade out when done
    }
}

// MARK: - App Delegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle Google Sign-In URL callback
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // Handle device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.handleDeviceToken(deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("🔴 [Push] Failed to register: \(error)")
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        PushNotificationManager.shared.handleNotification(userInfo: userInfo)
        completionHandler()
    }
}
