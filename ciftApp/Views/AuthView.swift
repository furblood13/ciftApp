//
//  AuthView.swift
//  ciftApp
//
//  Us & Time - Login & Register View
//

import SwiftUI

struct AuthView: View {
    @Bindable var authManager: AuthManager
    
    @State private var isLoginMode = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Theme Colors
    private let primaryText = Color(red: 0.3, green: 0.2, blue: 0.25)
    private let secondaryText = Color(red: 0.5, green: 0.4, blue: 0.45)
    private let accentPink = Color(red: 0.96, green: 0.69, blue: 0.69)
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.97),
                    Color(red: 0.98, green: 0.94, blue: 0.94),
                    Color(red: 0.98, green: 0.87, blue: 0.87)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Logo & Title - Compact
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentPink, Color(red: 0.85, green: 0.5, blue: 0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: accentPink.opacity(0.4), radius: 15, x: 0, y: 8)
                        
                        VStack(spacing: 4) {
                            Text(String(localized: "app.name"))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryText)
                            
                            Text(String(localized: "app.tagline"))
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Mode Picker
                    Picker("", selection: $isLoginMode) {
                        Text(String(localized: "auth.login")).tag(true)
                        Text(String(localized: "auth.signup")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    
                    // Form Fields
                    VStack(spacing: 12) {
                        // Name Field (Register only)
                        if !isLoginMode {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(secondaryText)
                                    .frame(width: 20)
                                
                                TextField(String(localized: "profile.username"), text: $name)
                                    .textContentType(.name)
                                    .foregroundStyle(primaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Email Field
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(secondaryText)
                                .frame(width: 20)
                            
                            TextField(String(localized: "auth.email"), text: $email)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .foregroundStyle(primaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Password Field
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(secondaryText)
                                .frame(width: 20)
                            
                            SecureField(String(localized: "auth.password"), text: $password)
                                .textContentType(isLoginMode ? .password : .newPassword)
                                .foregroundStyle(primaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Confirm Password (Register only)
                        if !isLoginMode {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(secondaryText)
                                    .frame(width: 20)
                                
                                SecureField(String(localized: "auth.confirmPassword"), text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .foregroundStyle(primaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Submit Button
                    Button {
                        Task {
                            if isLoginMode {
                                await authManager.signIn(email: email, password: password)
                            } else {
                                if password == confirmPassword {
                                    await authManager.signUp(email: email, password: password, name: name)
                                } else {
                                    authManager.errorMessage = String(localized: "error.passwordMismatch")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isLoginMode ? String(localized: "auth.login") : String(localized: "auth.signup"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || (!isLoginMode && (name.isEmpty || confirmPassword.isEmpty)))
                    .padding(.horizontal, 24)
                    
                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(secondaryText.opacity(0.3))
                            .frame(height: 1)
                        
                        Text(String(localized: "auth.or"))
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        
                        Rectangle()
                            .fill(secondaryText.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    
                    // Social Sign-In Buttons
                    VStack(spacing: 12) {
                        // Google Sign-In
                        Button {
                            Task {
                                await authManager.signInWithGoogle()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image("googlelogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                
                                Text(isLoginMode ? String(localized: "auth.googleSignIn") : String(localized: "auth.googleSignUp"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .foregroundStyle(primaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(secondaryText.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(authManager.isLoading)
                        
                        // Apple Sign-In
                        Button {
                            Task {
                                await authManager.signInWithApple()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text(isLoginMode ? String(localized: "auth.appleSignIn") : String(localized: "auth.appleSignUp"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(authManager.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoginMode)
    }
}

#Preview {
    AuthView(authManager: AuthManager())
}
