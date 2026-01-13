//
//  AuthManager.swift
//  ciftApp
//
//  Us & Time - Authentication State Management
//

import Foundation
import Observation
import Supabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isLoading = true // Default to true to prevent flash of login screen
    var errorMessage: String?
    var currentUserEmail: String?
    
    private let supabase = SupabaseManager.shared.client
    
    init() {
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Check Existing Session
    @MainActor
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            currentUserEmail = session.user.email
        } catch {
            isAuthenticated = false
            currentUserEmail = nil
        }
    }
    
    // MARK: - Sign Up
    @MainActor
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            if response.session != nil {
                // Update profile with name
                try await supabase
                    .from("profiles")
                    .update(["username": name])
                    .eq("id", value: response.user.id)
                    .execute()
                
                isAuthenticated = true
                currentUserEmail = email
            } else {
                // Email confirmation required
                errorMessage = "Kayıt başarılı! Lütfen email adresinizi doğrulayın."
            }
        } catch {
            errorMessage = "Kayıt hatası: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Sign In
    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            isAuthenticated = true
            currentUserEmail = session.user.email
        } catch {
            errorMessage = "Giriş hatası: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Sign Out
    @MainActor
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUserEmail = nil
        } catch {
            errorMessage = "Çıkış hatası: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Google Sign-In
    @MainActor
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Get the root view controller for presenting Google Sign-In
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Uygulama penceresi bulunamadı"
                return
            }
            
            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            // Get the ID token from Google
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google kimlik bilgisi alınamadı"
                return
            }
            
            // Get access token for Supabase
            let accessToken = result.user.accessToken.tokenString
            
            // Sign in to Supabase with Google credentials
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            
            // Update profile with Google name if available
            if let googleName = result.user.profile?.name {
                try? await supabase
                    .from("profiles")
                    .update(["username": googleName])
                    .eq("id", value: session.user.id)
                    .execute()
            }
            
            isAuthenticated = true
            currentUserEmail = session.user.email
            print("🟢 [Auth] Google Sign-In successful: \(session.user.email ?? "no email")")
            
        } catch {
            print("🔴 [Auth] Google Sign-In error: \(error)")
            errorMessage = "Google ile giriş hatası: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Apple Sign-In
    
    /// Current nonce for Apple Sign-In (needed for security)
    private var currentNonce: String?
    
    /// Generate a random nonce for Apple Sign-In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    /// SHA256 hash of the nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    @MainActor
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        // Generate nonce
        let nonce = randomNonceString()
        currentNonce = nonce
        let hashedNonce = sha256(nonce)
        
        // Create Apple ID request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        // Create and configure authorization controller
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        do {
            // Perform the request using async/await wrapper
            let result = try await performAppleSignIn(controller: authorizationController)
            
            guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple kimlik bilgisi alınamadı"
                isLoading = false
                return
            }
            
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Apple token alınamadı"
                isLoading = false
                return
            }
            
            // Sign in to Supabase with Apple credentials
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: nonce
                )
            )
            
            // Save Apple user's name if available (only provided on first sign-in)
            if let fullName = appleIDCredential.fullName {
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                let displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                
                if !displayName.isEmpty {
                    try? await supabase
                        .from("profiles")
                        .update(["username": displayName])
                        .eq("id", value: session.user.id)
                        .execute()
                }
            }
            
            isAuthenticated = true
            currentUserEmail = session.user.email
            isLoading = false
            print("🟢 [Auth] Apple Sign-In successful: \(session.user.email ?? "no email")")
            
        } catch {
            print("🔴 [Auth] Apple Sign-In error: \(error)")
            errorMessage = "Apple ile giriş hatası: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Wrapper to make ASAuthorizationController work with async/await
    private func performAppleSignIn(controller: ASAuthorizationController) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            
            // Store delegate to keep it alive during the async operation
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            
            controller.performRequests()
        }
    }
}

// MARK: - Apple Sign-In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
