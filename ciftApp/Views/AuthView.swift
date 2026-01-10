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
                
                // Logo & Title
                VStack(spacing: 16) {
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
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accentPink.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    Text(String(localized: "app.name"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                    
                    Text(String(localized: "app.tagline"))
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                
                Spacer()
                
                // Mode Picker
                Picker("", selection: $isLoginMode) {
                    Text(String(localized: "auth.login")).tag(true)
                    Text(String(localized: "auth.signup")).tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                
                // Form
                VStack(spacing: 16) {
                    // Name Field (Register only)
                    if !isLoginMode {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(secondaryText)
                                .frame(width: 24)
                            
                            TextField(String(localized: "profile.username"), text: $name)
                                .textContentType(.name)
                                .foregroundStyle(primaryText)
                        }
                        .padding()
                        .background(.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Email Field
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(secondaryText)
                            .frame(width: 24)
                        
                        TextField(String(localized: "auth.email"), text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .foregroundStyle(primaryText)
                    }
                    .padding()
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Password Field
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(secondaryText)
                            .frame(width: 24)
                        
                        SecureField(String(localized: "auth.password"), text: $password)
                            .textContentType(isLoginMode ? .password : .newPassword)
                            .foregroundStyle(primaryText)
                    }
                    .padding()
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Confirm Password (Register only)
                    if !isLoginMode {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(secondaryText)
                                .frame(width: 24)
                            
                            SecureField(String(localized: "auth.password"), text: $confirmPassword)
                                .textContentType(.newPassword)
                                .foregroundStyle(primaryText)
                        }
                        .padding()
                        .background(.white.opacity(0.7))
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
                        .padding(.horizontal)
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
                                authManager.errorMessage = String(localized: "error.invalidInput")
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
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || (!isLoginMode && name.isEmpty))
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

#Preview {
    AuthView(authManager: AuthManager())
}
