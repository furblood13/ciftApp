//
//  TimelineEventCard.swift
//  ciftApp
//
//  Display individual timeline events with a "connector line" style
//

import SwiftUI

struct TimelineEventCard: View {
    let event: TimelineEvent
    let timelineManager: TimelineManager
    let onTap: () -> Void
    
    // MARK: - State for Sharing
    @State private var isSharing = false
    @State private var showShareSheet = false
    @State private var itemsToShare: [Any] = []
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // MARK: - Connector & Icon
                VStack(spacing: 0) {
                    // Top Line
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 20)
                    
                    // Icon Circle - Image fills entirely
                    Image(eventAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .shadow(color: eventColor.opacity(0.3), radius: 4, y: 2)
                    
                    // Bottom Line (extends to bottom of card)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 40)
                
                // MARK: - Content Card
                VStack(alignment: .leading, spacing: 8) {
                    // Header: Date & Title
                    HStack {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(event.formattedDate)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.55))
                        
                        // Share Button
                        if event.hasPhoto {
                            shareButton
                        }
                    }
                    
                    // Description
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Photo Collage (if exists)
                    if event.hasPhoto {
                        if let urls = event.photoUrls, urls.count > 1 {
                            HStack(spacing: -15) {
                                ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { index, urlString in
                                    if let url = URL(string: urlString) {
                                        ZStack {
                                            // Photo
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 75)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 60, height: 75)
                                                    .cornerRadius(6)
                                            }
                                            
                                            // Frame overlay
                                            Image("cerceve")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 80, height: 100)
                                        }
                                        .rotationEffect(.degrees(index == 0 ? -6 : (index == 1 ? 0 : 6)))
                                        .zIndex(Double(index == 1 ? 10 : 0))
                                        .offset(y: index == 1 ? -5 : 0)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                        } else if let urlString = event.displayPhotoUrl, let url = URL(string: urlString) {
                            // Single Photo with Frame
                            ZStack {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 120, height: 150)
                                        .cornerRadius(8)
                                }
                                
                                // Frame overlay
                                Image("cerceve")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 185)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // Footer: Tags (Location, Category, etc)
                    if hasFooterContent {
                        HStack(spacing: 8) {
                            if let location = event.locationName {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.caption2)
                            }
                            
                            if let category = event.conflictCategory {
                                Label(category.label, systemImage: category.icon)
                                    .font(.caption2)
                            }
                            
                            if event.isMilestone ?? false {
                                Label(String(localized: "milestones.custom"), systemImage: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .foregroundStyle(Color.gray)
                        .padding(.top, 4)
                    }
                    
                    Spacer(minLength: 24) // Spacing for next event
                }
                .padding(.top, 8)
            }
            .contentShape(Rectangle()) // Make entire area tappable
        }
        .buttonStyle(.plain) // Remove default button fade effect
        // Share Sheet
        .sheet(isPresented: $showShareSheet, content: {
            if let image = itemsToShare.first as? UIImage {
                ShareSheet(activityItems: [image])
            }
        })
    }
    
    // MARK: - Integration Logic (Outside Body)
    
    private var shareButton: some View {
        Button {
            Task {
                await shareEvent()
            }
        } label: {
            if isSharing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    @MainActor
    private func shareEvent() async {
        guard !isSharing else { return }
        isSharing = true
        defer { isSharing = false }
        
        // 1. Prepare Images
        var images: [UIImage] = []
        
        // Only for memories with photos
        if let urls = event.photoUrls, !urls.isEmpty {
            images = await downloadImages(urls: Array(urls.prefix(3)))
        } else if let url = event.displayPhotoUrl {
             images = await downloadImages(urls: [url])
        }
        
        // 2. Prepare Metadata
        let myName = timelineManager.currentUserName ?? "Ben"
        let partnerName = timelineManager.partnerName ?? "Partnerim"
        let coupleNames = "\(myName) & \(partnerName)"
        
        // 3. Render View
        let renderer = ImageRenderer(content: StoryTemplateView(
            title: event.title,
            date: event.dateValue,
            images: images,
            locationName: event.locationName,
            coupleNames: coupleNames
        ))
        
        // High resolution for Instagram
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            itemsToShare = [image]
            showShareSheet = true
        }
    }
    
    // Simple Image Downloader
    private func downloadImages(urls: [String]) async -> [UIImage] {
        var result: [UIImage] = []
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    result.append(image)
                }
            } catch {
                print("Failed to dl image: \(error)")
            }
        }
        return result
    }
    
    // MARK: - Helpers
    
    private var eventColor: Color {
        if event.type == .conflict && (event.isResolved ?? false) { return .green }
        
        switch event.type {
        case .memory: return .pink
        case .conflict: return .orange
        case .peace: return .green
        }
    }
    
    private var eventAssetName: String {
        if event.isMilestone ?? false { return "special" }
        if event.type == .conflict && (event.isResolved ?? false) { return "holdingHands" }
        
        switch event.type {
        case .memory: return "ani"
        case .conflict: return "confligt"
        case .peace: return "holdingHands"
        }
    }
    
    private var hasFooterContent: Bool {
        event.locationName != nil || event.conflictCategory != nil || (event.isMilestone ?? false)
    }
}

#Preview {
    VStack(spacing: 0) {
        TimelineEventCard(
            event: TimelineEvent(
                id: UUID(),
                coupleId: nil,
                type: .memory,
                date: "2025-01-05",
                title: "İlk Buluşmamız",
                description: "Kafede buluştuk, çok güzel bir gündü!",
                photoUrl: nil, photoUrls: nil,
                locationName: "Starbucks",
                locationLatitude: nil,
                locationLongitude: nil,
                conflictCategory: nil,
                severity: nil,
                isResolved: nil,
                whoStarted: nil,
                lessonLearned: nil,
                linkedConflictId: nil,
                isMilestone: true,
                milestoneType: .firstDate,
                createdBy: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            timelineManager: TimelineManager()
        ) { }
        
        TimelineEventCard(
            event: TimelineEvent(
                id: UUID(),
                coupleId: nil,
                type: .conflict,
                date: "2025-01-04",
                title: "Yemek Tartışması",
                description: "Ne yiyeceğimize karar veremedik",
                photoUrl: nil, photoUrls: nil,
                locationName: nil,
                locationLatitude: nil,
                locationLongitude: nil,
                conflictCategory: .food,
                severity: 4,
                isResolved: false,
                whoStarted: nil,
                lessonLearned: nil,
                linkedConflictId: nil,
                isMilestone: false,
                milestoneType: nil,
                createdBy: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            timelineManager: TimelineManager()
        ) { }
    }
    .padding()
}
