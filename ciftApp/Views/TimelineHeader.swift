//
//  TimelineHeader.swift
//  ciftApp
//
//  Us & Time - Timeline Dashboard Header
//

import SwiftUI

struct TimelineHeader: View {
    let timelineManager: TimelineManager
    let onStatsTap: () -> Void
    let onMilestonesTap: () -> Void
    let onGalleryTap: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Stats Card
                DashboardCard(
                    assetName: "stats",
                    color: .orange,
                    title: String(localized: "stats.title"),
                    subtitle: statsSubtitle,
                    action: onStatsTap
                )
                
                // Milestones Card
                DashboardCard(
                    assetName: "special",
                    color: .yellow,
                    title: String(localized: "milestones.title"),
                    subtitle: milestoneSubtitle,
                    action: onMilestonesTap
                )
                
                // Gallery Card
                DashboardCard(
                    assetName: "gallery",
                    color: .pink,
                    title: String(localized: "gallery.title"),
                    subtitle: gallerySubtitle,
                    action: onGalleryTap
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Computed Texts
    
    private var statsSubtitle: String {
        let count = timelineManager.events.filter { 
            Calendar.current.isDate($0.dateValue, equalTo: Date(), toGranularity: .month) 
        }.count
        return String(localized: "stats.monthMemories \(count)")
    }
    
    private var milestoneSubtitle: String {
        // Find closest upcoming anniversary
        let calendar = Calendar.current
        let today = Date()
        
        let upcoming = timelineManager.milestones.compactMap { event -> Int? in
            let eventDate = event.dateValue
            let eventMonth = calendar.component(.month, from: eventDate)
            let eventDay = calendar.component(.day, from: eventDate)
            
            var nextDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: today),
                month: eventMonth,
                day: eventDay
            ))!
            
            if nextDate < today {
                nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate)!
            }
            
            return calendar.dateComponents([.day], from: today, to: nextDate).day
        }.min()
        
        if let days = upcoming {
            return days == 0 ? String(localized: "milestones.todaySpecial") : String(localized: "milestones.daysRemaining \(days)")
        }
        return String(localized: "milestones.noUpcoming")
    }
    
    private var gallerySubtitle: String {
        let count = timelineManager.events.filter { $0.hasPhoto }.count
        return String(localized: "gallery.photoCount \(count)")
    }
}

// MARK: - Dashboard Card
struct DashboardCard: View {
    let assetName: String
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.94, blue: 0.94),
                                Color(red: 0.96, green: 0.90, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Image fills right side
                HStack {
                    Spacer()
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 85, height: 85)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.5), location: 0.25),
                                    .init(color: .white, location: 0.4),
                                    .init(color: .white, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.trailing, 8)
                }
                
                // Text overlay
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                        
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    }
                    .padding(.leading, 12)
                    Spacer()
                }
            }
            .frame(width: 180, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: color.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.scale)
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}

#Preview {
    TimelineHeader(
        timelineManager: TimelineManager(),
        onStatsTap: {},
        onMilestonesTap: {},
        onGalleryTap: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
