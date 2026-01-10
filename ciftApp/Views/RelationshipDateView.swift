//
//  RelationshipDateView.swift
//  ciftApp
//
//  Us & Time - Edit Relationship Start Date
//

import SwiftUI

struct RelationshipDateView: View {
    @Bindable var homeManager: HomeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var isSaving = false
    
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
                
                VStack(spacing: 24) {
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
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accentPink.opacity(0.4), radius: 12, x: 0, y: 6)
                    .padding(.top, 24)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text(String(localized: "relationshipDate.title"))
                            .font(.title2.bold())
                            .foregroundStyle(primaryText)
                        
                        Text(String(localized: "relationshipDate.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                    }
                    
                    // Date Picker
                    DatePicker(
                        String(localized: "relationshipDate.startDate"),
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(accentPink)
                    .colorScheme(.light)
                    .padding()
                    .background(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Info
                    HStack {
                        Image(systemName: "info.circle")
                        Text(String(localized: "relationshipDate.info"))
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    
                    Spacer()
                    
                    // Save Button
                    Button {
                        Task {
                            isSaving = true
                            await homeManager.updateStartDate(selectedDate)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(String(localized: "common.save"))
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
                    .disabled(isSaving)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.99, green: 0.97, blue: 0.97), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(secondaryText)
                }
            }
        }
        .onAppear {
            // Set initial date from couple's start_date
            if let startDateString = homeManager.couple?.startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                selectedDate = formatter.date(from: startDateString) ?? Date()
            }
        }
    }
}

#Preview {
    RelationshipDateView(homeManager: HomeManager())
}
