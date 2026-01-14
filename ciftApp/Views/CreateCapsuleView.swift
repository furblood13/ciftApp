//
//  CreateCapsuleView.swift
//  ciftApp
//
//  Us & Time - Create Time Capsule
//

import SwiftUI

struct CreateCapsuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var capsuleManager: TimeCapsuleManager
    
    @State private var title = ""
    @State private var message = ""
    @State private var unlockDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var isCreating = false
    
    // Privacy options
    @State private var hideTitle = false
    @State private var hideCountdown = false
    @State private var hidePreview = false
    
    // Minimum date: 5 minutes from now
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Image
                        Image("capsulenobg")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .padding(.top, 20)
                        
                        Text(String(localized: "capsule.createTitle"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                        
                        Text(String(localized: "capsule.createSubtitle"))
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                            .multilineTextAlignment(.center)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Title
                            inputSection(title: String(localized: "capsule.title")) {
                                TextField(String(localized: "capsule.titlePlaceholder"), text: $title)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.white)
                                    )
                            }
                            
                            // Message
                            inputSection(title: String(localized: "capsule.message")) {
                                TextEditor(text: $message)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.white)
                                    )
                            }
                            
                            // Date Picker
                            inputSection(title: String(localized: "capsule.unlockDate")) {
                                DatePicker(
                                    "",
                                    selection: $unlockDate,
                                    in: minimumDate...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white)
                                )
                            }
                            
                            // Privacy Options
                            privacySection
                        }
                        .padding(.horizontal, 20)
                        
                        // Create Button
                        Button {
                            createCapsule()
                        } label: {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text(String(localized: "capsule.sendCapsule"))
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        canCreate
                                            ? Color(red: 0.96, green: 0.69, blue: 0.69)
                                            : Color.gray.opacity(0.5)
                                    )
                            )
                        }
                        .disabled(!canCreate || isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(String(localized: "capsule.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
            }
        }
    }
    
    // MARK: - Input Section
    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            content()
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "capsule.privacy"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            VStack(spacing: 0) {
                privacyToggle(
                    icon: "textformat",
                    title: String(localized: "capsule.hideTitle"),
                    subtitle: String(localized: "capsule.hideTitleDesc"),
                    isOn: $hideTitle
                )
                
                Divider().padding(.leading, 44)
                
                privacyToggle(
                    icon: "clock",
                    title: String(localized: "capsule.hideCountdown"),
                    subtitle: String(localized: "capsule.hideCountdownDesc"),
                    isOn: $hideCountdown
                )
                
                Divider().padding(.leading, 44)
                
                privacyToggle(
                    icon: "eye.slash",
                    title: String(localized: "capsule.hideCompletely"),
                    subtitle: String(localized: "capsule.hideCompletelyDesc"),
                    isOn: $hidePreview
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
            )
        }
    }
    
    private func privacyToggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.96, green: 0.69, blue: 0.69)))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var canCreate: Bool {
        !title.isEmpty && !message.isEmpty
    }
    
    private func createCapsule() {
        isCreating = true
        
        Task {
            let success = await capsuleManager.createCapsule(
                title: title,
                message: message,
                unlockDate: unlockDate,
                hideTitle: hideTitle,
                hideCountdown: hideCountdown,
                hidePreview: hidePreview
            )
            
            isCreating = false
            
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    CreateCapsuleView(capsuleManager: TimeCapsuleManager())
}
