//
//  AddEventView.swift
//  ciftApp
//
//  Us & Time - Add Event (Phase 12 Update)
//

import SwiftUI
import PhotosUI

// UI Specific Event Type
enum AddEventType: String, CaseIterable {
    case memory = "memory"
    case conflict = "conflict"
    case milestone = "milestone"
    
    var localizedLabel: String {
        switch self {
        case .memory: return String(localized: "addEvent.memory")
        case .conflict: return String(localized: "addEvent.conflict")
        case .milestone: return String(localized: "addEvent.milestone")
        }
    }
    
    var assetName: String {
        switch self {
        case .memory: return "ani"
        case .conflict: return "confligt"
        case .milestone: return "special"
        }
    }
    
    // All use app's pink theme color
    var color: Color {
        Color(red: 0.86, green: 0.59, blue: 0.59) // App pink theme
    }
}

struct AddEventView: View {
    @Bindable var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    
    // Form States
    @State private var selectedType: AddEventType = .memory
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var locationName = ""
    
    // Photo Picker (Multi-Select for Memory)
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []
    
    // Milestone Specific
    @State private var milestoneType: MilestoneType = .anniversary
    
    // Conflict Specific
    @State private var conflictCategory: ConflictCategory = .communication
    @State private var severity: Double = 5
    @State private var whoStartedSelection: String = "me" // "me" or "partner"
    
    // Loading State
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Visual Type Selector
                    HStack(spacing: 20) {
                        ForEach(AddEventType.allCases, id: \.self) { type in
                            EventTypeCard(
                                label: type.localizedLabel,
                                assetName: type.assetName,
                                color: type.color,
                                isSelected: selectedType == type
                            ) {
                                withAnimation { selectedType = type }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    
                    // 2. Main Form Areas
                    VStack(spacing: 20) {
                        // Common Fields
                        TextField(String(localized: "addEvent.eventTitle.placeholder"), text: $title)
                            .font(.title3.bold())
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.03), radius: 5)
                        
                        DatePicker(String(localized: "addEvent.date"), selection: $date, displayedComponents: [.date])
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                        
                        // Type Specific Fields
                        if selectedType == .conflict {
                            conflictFields
                        } else if selectedType == .milestone {
                            milestoneFields
                        } else {
                            // Memory fields
                            TextField(String(localized: "addEvent.location"), text: $locationName)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                        }
                        
                        // Photo Picker Section (Only for Memory/Milestone)
                        if selectedType == .memory || selectedType == .milestone {
                            photoPickerSection
                        }
                        
                        // Description
                        VStack(alignment: .leading) {
                            Text(String(localized: "addEvent.notes"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 3. Save Button
                    Button {
                        saveEvent()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(String(localized: "common.save"))
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.96, green: 0.69, blue: 0.69)) // App Theme Color
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .disabled(title.isEmpty || isSaving)
                    .opacity(title.isEmpty ? 0.6 : 1)
                }
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle(String(localized: "addEvent.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundStyle(.gray)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var conflictFields: some View {
        VStack(spacing: 16) {
            Picker(String(localized: "addEvent.category"), selection: $conflictCategory) {
                ForEach(ConflictCategory.allCases, id: \.self) { category in
                    Label(category.label, systemImage: category.icon).tag(category)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            
            // Who Started Picker
            HStack {
                Text(String(localized: "addEvent.whoStarted"))
                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                Spacer()
                
                Picker(String(localized: "addEvent.whoStarted"), selection: $whoStartedSelection) {
                    Text(String(localized: "addEvent.me")).tag("me")
                    Text(timelineManager.partnerName ?? String(localized: "addEvent.partner")).tag("partner")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(String(localized: "addEvent.severity"))
                    Spacer()
                    Text("\(Int(severity))/10")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                }
                Slider(value: $severity, in: 1...10, step: 1)
                    .tint(.orange)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private var milestoneFields: some View {
        VStack(spacing: 16) {
            Picker(String(localized: "addEvent.milestoneType"), selection: $milestoneType) {
                ForEach(MilestoneType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            
            TextField(String(localized: "addEvent.location"), text: $locationName)
                .padding()
                .background(Color.white)
                .cornerRadius(16)
        }
    }
    
    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "addEvent.photos"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Picker Button
                    if selectedImagesData.count < 3 {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 3,
                            matching: .images
                        ) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .foregroundStyle(.gray)
                                )
                        }
                    }
                    
                    // Selected Photos
                    ForEach(Array(selectedImagesData.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                Button {
                                    removePhoto(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var newData: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newData.append(data)
                    }
                }
                selectedImagesData = newData
            }
        }
    }
    
    private func removePhoto(at index: Int) {
        if index < selectedImagesData.count {
            selectedImagesData.remove(at: index)
            // Sync selection (Limitations: cannot easily sync back to PhotosPicker items, but we keep data)
            // Note: PhotosPickerItem sync is tricky, so we rely on data. 
            // Better UX: Clearing picker selection if data cleared.
            if selectedImagesData.isEmpty {
                selectedItems.removeAll()
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveEvent() {
        isSaving = true
        
        Task {
            var success = false
            
            // Determine who started
            var starterId: UUID? = nil
            if selectedType == .conflict {
                if whoStartedSelection == "me" {
                    starterId = timelineManager.currentUserId
                } else {
                    starterId = timelineManager.partnerId
                }
            }
            
            switch selectedType {
            case .memory:
                success = await timelineManager.createMemory(
                    title: title,
                    description: description,
                    date: date,
                    photoData: selectedImagesData, // Pass array
                    locationName: locationName.isEmpty ? nil : locationName,
                    latitude: nil,
                    longitude: nil,
                    isMilestone: false,
                    milestoneType: nil
                )
                
            case .milestone:
                success = await timelineManager.createMemory(
                    title: title,
                    description: description,
                    date: date,
                    photoData: selectedImagesData, // Pass array
                    locationName: locationName.isEmpty ? nil : locationName,
                    latitude: nil,
                    longitude: nil,
                    isMilestone: true,
                    milestoneType: milestoneType
                )
                
            case .conflict:
                success = await timelineManager.createConflict(
                    title: title,
                    description: description,
                    date: date,
                    category: conflictCategory,
                    severity: Int(severity),
                    whoStarted: starterId
                )
            }
            
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Component Reused
struct EventTypeCard: View {
    let label: String
    let assetName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 8, y: 2)
                
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? color : Color(red: 0.4, green: 0.3, blue: 0.35))
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddEventView(timelineManager: TimelineManager())
}
