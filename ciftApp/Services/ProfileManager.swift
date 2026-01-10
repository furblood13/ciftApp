//
//  ProfileManager.swift
//  ciftApp
//
//  Us & Time - Profile Operations
//

import Foundation
import Observation
import Supabase

@Observable
final class ProfileManager {
    var profile: Profile?
    var isLoading = false
    var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Fetch Current User Profile
    @MainActor
    func fetchProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            let response: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            profile = response
        } catch {
            errorMessage = "Profil yüklenemedi: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Update Username
    @MainActor
    func updateUsername(_ username: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            try await supabase
                .from("profiles")
                .update(["username": username])
                .eq("id", value: userId)
                .execute()
            
            // Refresh profile
            await fetchProfile()
        } catch {
            errorMessage = "Profil güncellenemedi: \(error.localizedDescription)"
        }
    }
}

