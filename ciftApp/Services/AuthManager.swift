//
//  AuthManager.swift
//  ciftApp
//
//  Us & Time - Authentication State Management
//

import Foundation
import Observation
import Supabase

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
}
