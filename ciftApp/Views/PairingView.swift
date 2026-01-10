//
//  PairingView.swift
//  ciftApp
//
//  Us & Time - Couple Pairing Screen
//

import SwiftUI

struct PairingView: View {
    @Bindable var authManager: AuthManager
    @Bindable var pairingManager: CouplePairingManager
    
    @State private var partnerCode = ""
    @State private var showCodeEntry = false
    
    // Theme Colors
    private let primaryText = Color(red: 0.3, green: 0.2, blue: 0.25)
    private let secondaryText = Color(red: 0.5, green: 0.4, blue: 0.45)
    private let accentPink = Color(red: 0.96, green: 0.69, blue: 0.69) // F5AFAF
    
    var body: some View {
        ZStack {
            // Background Gradient - Soft Pink
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
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentPink, Color(red: 0.85, green: 0.5, blue: 0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }
                .shadow(color: accentPink.opacity(0.5), radius: 20, x: 0, y: 10)
                
                // Title
                VStack(spacing: 12) {
                    Text(String(localized: "pairing.title"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                    
                    Text(String(localized: "pairing.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                
                Spacer()
                
                // Generated Code Display
                if let code = pairingManager.generatedCode {
                    VStack(spacing: 16) {
                        Text(String(localized: "pairing.yourCode"))
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                        
                        Text(code)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(primaryText)
                            .kerning(8)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text(String(localized: "pairing.shareCode"))
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        
                        HStack(spacing: 16) {
                            Button {
                                UIPasteboard.general.string = code
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text(String(localized: "common.copy"))
                                }
                                .font(.subheadline)
                                .foregroundStyle(accentPink)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(accentPink.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            
                            Button {
                                Task {
                                    await pairingManager.cancelPendingCode()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text(String(localized: "common.cancel"))
                                }
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.5))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(24)
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                }
                
                // Code Entry
                if showCodeEntry {
                    VStack(spacing: 16) {
                        Text(String(localized: "pairing.enterCode"))
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                        
                        TextField("XXXXXX", text: $partnerCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(primaryText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .padding()
                            .background(.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: partnerCode) { _, newValue in
                                partnerCode = String(newValue.prefix(6)).uppercased()
                            }
                        
                        Button {
                            Task {
                                await pairingManager.joinWithCode(partnerCode)
                            }
                        } label: {
                            HStack {
                                if pairingManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(String(localized: "pairing.connect"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [accentPink, Color(red: 0.85, green: 0.5, blue: 0.55)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(partnerCode.count != 6 || pairingManager.isLoading)
                    }
                    .padding(24)
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                }
                
                // Error Message
                if let error = pairingManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                if pairingManager.generatedCode == nil && !showCodeEntry {
                    VStack(spacing: 16) {
                        // Generate Code Button
                        Button {
                            Task {
                                await pairingManager.generateInviteCode()
                            }
                        } label: {
                            HStack {
                                if pairingManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text(String(localized: "pairing.generateNew"))
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [accentPink, Color(red: 0.85, green: 0.5, blue: 0.55)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(pairingManager.isLoading)
                        
                        // Enter Code Button
                        Button {
                            withAnimation {
                                showCodeEntry = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "keyboard")
                                Text(String(localized: "pairing.enterCodeBtn"))
                            }
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white.opacity(0.7))
                            .foregroundStyle(primaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Sign Out Button
                Button {
                    Task {
                        await authManager.signOut()
                    }
                } label: {
                    Text(String(localized: "profile.logout"))
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    PairingView(authManager: AuthManager(), pairingManager: CouplePairingManager())
}
