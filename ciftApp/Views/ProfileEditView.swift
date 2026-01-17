//
//  ProfileEditView.swift
//  ciftApp
//
//  Us & Time - Profile Editing Screen
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profileManager: ProfileManager
    @Bindable var pairingManager: CouplePairingManager
    var onSignOut: (() async -> Void)?
    var onDeleteCouple: (() -> Void)?
    
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var showSignOutAlert = false
    @State private var showDeleteCoupleAlert = false
    @State private var showPaywall = false
    @State private var isDeleting = false
    
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    
    // Theme Colors
    private let primaryText = Color(red: 0.3, green: 0.2, blue: 0.25)
    private let secondaryText = Color(red: 0.5, green: 0.4, blue: 0.45)
    private let accentPink = Color(red: 0.96, green: 0.69, blue: 0.69) // F5AFAF
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - Soft Pink
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.97), // FCF8F8
                        Color(red: 0.98, green: 0.94, blue: 0.94), // FBEFEF
                        Color(red: 0.98, green: 0.87, blue: 0.87)  // F9DFDF
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Avatar Placeholder
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentPink, Color(red: 0.85, green: 0.5, blue: 0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(username.prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accentPink.opacity(0.4), radius: 15, x: 0, y: 8)
                    .padding(.top, 40)
                    
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "profile.username"))
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                        
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(secondaryText)
                                .frame(width: 24)
                            
                            TextField(String(localized: "profile.username"), text: $username)
                                .foregroundStyle(primaryText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                        }
                        .padding()
                        .background(.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let error = profileManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Premium Button (if not premium)
                    if !subscriptionManager.isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "profile.goPremium"))
                                        .font(.headline)
                                        .foregroundStyle(primaryText)
                                    Text(String(localized: "profile.premiumSubtitle"))
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(secondaryText)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.yellow.opacity(0.1),
                                                Color.orange.opacity(0.1)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.yellow.opacity(0.5), .orange.opacity(0.5)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Delete Couple Button
                    Button {
                        showDeleteCoupleAlert = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "trash.fill")
                                Text(String(localized: "profile.deleteCouple"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, 24)
                    
                    // Sign Out Button
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(String(localized: "profile.logout"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.9))
                        .foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(String(localized: "profile.editProfile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.99, green: 0.97, blue: 0.97), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(accentPink)
                        } else {
                            Text(String(localized: "common.save"))
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(accentPink)
                    .disabled(isSaving || username.isEmpty)
                }
            }
            .alert(String(localized: "profile.logout"), isPresented: $showSignOutAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) { }
                Button(String(localized: "profile.logout"), role: .destructive) {
                    Task {
                        await onSignOut?()
                    }
                }
            } message: {
                Text(String(localized: "profile.logoutConfirm"))
            }
            .alert(String(localized: "profile.deleteCouple"), isPresented: $showDeleteCoupleAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) { }
                Button(String(localized: "common.delete"), role: .destructive) {
                    Task {
                        isDeleting = true
                        let success = await pairingManager.deleteCouple()
                        isDeleting = false
                        if success {
                            dismiss()
                            onDeleteCouple?()
                        }
                    }
                }
            } message: {
                Text(String(localized: "profile.deleteCoupleConfirm"))
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                username = profileManager.profile?.username ?? ""
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        
        await profileManager.updateUsername(username)
        
        if profileManager.errorMessage == nil {
            dismiss()
        }
    }
}

#Preview {
    ProfileEditView(profileManager: ProfileManager(), pairingManager: CouplePairingManager())
}
