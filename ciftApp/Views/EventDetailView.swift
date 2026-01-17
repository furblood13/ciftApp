//
//  EventDetailView.swift
//  ciftApp
//
//  Us & Time - Event Detail View (Phase 12 Update)
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let eventId: UUID
    @Bindable var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showResolveSheet = false
    
    // Live lookup for event to ensure updates (Fixes sync bug)
    private var event: TimelineEvent? {
        timelineManager.events.first(where: { $0.id == eventId })
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let event = event {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Photo Gallery
                            if event.hasPhoto {
                                photoGallery(for: event)
                            }
                            
                            // Event Info Card
                            VStack(alignment: .leading, spacing: 16) {
                                // Type & Date
                                HStack {
                                    EventTag(text: event.type.label, color: eventColor(for: event))
                                    
                                    if event.isMilestone ?? false, let milestone = event.milestoneType {
                                        EventTag(text: milestone.label, icon: milestone.icon, color: .yellow)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(event.formattedDate)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                                }
                                
                                // Title
                                Text(event.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                                
                                // Description
                                if let description = event.description, !description.isEmpty {
                                    Text(description)
                                        .font(.body)
                                        .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                                }
                                
                                // Conflict specific
                                if event.type == .conflict {
                                    conflictSection(for: event)
                                }
                                
                                // Peace specific (Old events) or Resolved Conflict info
                                if event.type == .peace, let lesson = event.lessonLearned {
                                    peaceSection(lesson)
                                }
                                
                                // Location
                                if let locationName = event.locationName {
                                    locationSection(locationName)
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.9))
                            )
                            .padding(.horizontal, 20)
                            
                            // Delete Button
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(String(localized: "common.delete"))
                                }
                                .font(.headline)
                                .foregroundStyle(.red)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.red.opacity(0.1))
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                        .padding(.vertical, 20)
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.97, blue: 0.97),
                                Color(red: 0.98, green: 0.94, blue: 0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                    .navigationTitle(String(localized: "eventDetail.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.65))
                            }
                        }
                    }
                    .alert(String(localized: "common.delete"), isPresented: $showDeleteAlert) {
                        Button(String(localized: "common.cancel"), role: .cancel) { }
                        Button(String(localized: "common.delete"), role: .destructive) {
                            Task {
                                await timelineManager.deleteEvent(id: eventId)
                                dismiss()
                            }
                        }
                    } message: {
                        Text(String(localized: "eventDetail.deleteConfirm"))
                    }
                    .sheet(isPresented: $showResolveSheet) {
                        ResolveConflictSheet(eventId: eventId, timelineManager: timelineManager)
                    }
                } else {
                    ContentUnavailableView(String(localized: "error.notFound"), systemImage: "questionmark.folder")
                }
            }
        }
    }
    
    // MARK: - Photo Gallery
    @ViewBuilder
    private func photoGallery(for event: TimelineEvent) -> some View {
        if let urls = event.photoUrls, urls.count > 1 {
            TabView {
                ForEach(urls, id: \.self) { url in
                    if let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color.gray.opacity(0.1)
                            }
                        }
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            
        } else if let urlString = event.displayPhotoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                case .failure, .empty:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Conflict Section (Premium Design)
    private func conflictSection(for event: TimelineEvent) -> some View {
        VStack(spacing: 16) {
            // Severity Indicator Card
            if let severity = event.severity {
                HStack(spacing: 16) {
                    // Severity Circle
                    ZStack {
                        Circle()
                            .stroke(severityColor(severity).opacity(0.3), lineWidth: 8)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(severity) / 10)
                            .stroke(severityColor(severity), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(severity)")
                                .font(.title2.bold())
                                .foregroundStyle(severityColor(severity))
                            Text("/10")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "eventDetail.severity"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(severityText(severity))
                            .font(.headline)
                            .foregroundStyle(severityColor(severity))
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(severityColor(severity).opacity(0.08))
                )
            }
            
            // Info Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Category
                if let category = event.conflictCategory {
                    infoCard(
                        icon: category.icon,
                        title: String(localized: "eventDetail.category"),
                        value: category.label,
                        color: .orange
                    )
                }
                
                // Who Started
                if let starterId = event.whoStarted {
                    infoCard(
                        icon: "person.fill",
                        title: String(localized: "eventDetail.startedBy"),
                        value: starterId == timelineManager.currentUserId ? String(localized: "addEvent.me") : (timelineManager.partnerName ?? String(localized: "addEvent.partner")),
                        color: .purple
                    )
                }
            }
            
            // Resolution Status Card
            HStack(spacing: 12) {
                Image(systemName: event.isResolved ?? false ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(event.isResolved ?? false ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.isResolved ?? false ? String(localized: "eventDetail.resolved") : String(localized: "eventDetail.unresolved"))
                        .font(.headline)
                        .foregroundStyle(event.isResolved ?? false ? .green : .orange)
                    
                    Text(event.isResolved ?? false ? String(localized: "eventDetail.resolvedDesc") : String(localized: "eventDetail.unresolvedDesc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if event.isResolved ?? false {
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(.green.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((event.isResolved ?? false ? Color.green : Color.orange).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((event.isResolved ?? false ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Lesson Learned (if resolved)
            if event.isResolved ?? false, let lesson = event.lessonLearned, !lesson.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(String(localized: "eventDetail.lessonLearned"))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    }
                    
                    Text(lesson)
                        .font(.body)
                        .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.08))
                        )
                }
            }
            
            // Resolve Button (if not resolved)
            if !(event.isResolved ?? false) {
                Button {
                    showResolveSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text(String(localized: "eventDetail.resolve"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.6, blue: 0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Info Card Helper
    private func infoCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
    
    // MARK: - Severity Helpers
    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...10: return .red
        default: return .gray
        }
    }
    
    private func severityText(_ severity: Int) -> String {
        switch severity {
        case 1...3: return String(localized: "severity.low")
        case 4...6: return String(localized: "severity.medium")
        case 7...10: return String(localized: "severity.high")
        default: return "-"
        }
    }
    
    // MARK: - Peace Section (Legacy support)
    private func peaceSection(_ lesson: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text(String(localized: "eventDetail.lessonLearned"))
                .font(.headline)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            Text(lesson)
                .font(.body)
                .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green.opacity(0.1))
                )
        }
    }
    
    // MARK: - Location Section
    private func locationSection(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                Text(name)
                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func eventColor(for event: TimelineEvent) -> Color {
        if event.type == .conflict && (event.isResolved ?? false) { return .green }
        switch event.type {
        case .memory: return .pink
        case .conflict: return .orange
        case .peace: return .green
        }
    }
}

// MARK: - Resolve Conflict Sheet
struct ResolveConflictSheet: View {
    let eventId: UUID // Changed to ID
    var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    @State private var lessonLearned = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(localized: "eventDetail.resolveSuccess"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                VStack(alignment: .leading) {
                    Text(String(localized: "eventDetail.resolveMessage"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $lessonLearned)
                        .frame(height: 150)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    saveResolution()
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(String(localized: "eventDetail.saveResolve"))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(16)
                .padding(.horizontal)
                .disabled(isSaving) // Removed text check
            }
            .navigationTitle(String(localized: "eventDetail.resolveTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
            }
        }
    }
    
    private func saveResolution() {
        isSaving = true
        Task {
            // Optional lesson is fine, send empty string or nil logic handled in manager
            let success = await timelineManager.resolveConflict(eventId: eventId, lesson: lessonLearned)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
