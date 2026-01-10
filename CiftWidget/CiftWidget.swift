//
//  CiftWidget.swift
//  CiftWidget
//
//  Created by furkan buğra karcı on 21.12.2025.
//  Us & Time - Partner Mood + Days Counter Widget
//

import WidgetKit
import SwiftUI

// MARK: - Theme Colors
extension Color {
    static let widgetBgLight = Color(red: 0.99, green: 0.97, blue: 0.97) // FCF8F8
    static let widgetBgMid = Color(red: 0.98, green: 0.94, blue: 0.94)   // FBEFEF
    static let widgetBgDark = Color(red: 0.98, green: 0.87, blue: 0.87)  // F9DFDF
    static let widgetAccent = Color(red: 0.96, green: 0.69, blue: 0.69)  // F5AFAF
    static let widgetAccentDark = Color(red: 0.85, green: 0.5, blue: 0.55)
    static let widgetTextPrimary = Color(red: 0.3, green: 0.2, blue: 0.25)
    static let widgetTextSecondary = Color(red: 0.5, green: 0.4, blue: 0.45)
}

// MARK: - Image Helper
struct ResizedImage: View {
    let name: String
    let size: CGSize
    
    var body: some View {
        if let uiImage = UIImage(named: name) {
            Image(uiImage: resize(image: uiImage, targetSize: size))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "photo")
        }
    }
    
    // Memory-safe resizing
    func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Widget Data
struct CoupleWidgetData {
    let daysTogether: Int
    let partnerMoodImage: String
    let partnerMoodLabel: String
    let partnerName: String
    let myMoodImage: String
    let myMoodLabel: String
    
    static let placeholder = CoupleWidgetData(
        daysTogether: 365,
        partnerMoodImage: "happy",
        partnerMoodLabel: "Mutlu",
        partnerName: "Partner",
        myMoodImage: "loved",
        myMoodLabel: "Aşık"
    )
    
    static func load() -> CoupleWidgetData {
        print("🔄 [Widget] Loading from File...")
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.furkanbugrakarci.ciftApp") else {
            print("🔴 [Widget] Failed to access App Group Container")
             return CoupleWidgetData(
                daysTogether: 0,
                partnerMoodImage: "sad",
                partnerMoodLabel: "Err:Group",
                partnerName: "Provisioning",
                myMoodImage: "sad",
                myMoodLabel: "Err"
            )
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_data.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let widgetData = try decoder.decode(WidgetDataPayload.self, from: data)
            
            print("🟢 [Widget] Loaded JSON - Days: \(widgetData.daysTogether)")
            
            return CoupleWidgetData(
                daysTogether: widgetData.daysTogether,
                partnerMoodImage: widgetData.partnerMoodImage,
                partnerMoodLabel: widgetData.partnerMoodLabel,
                partnerName: widgetData.partnerName,
                myMoodImage: widgetData.myMoodImage,
                myMoodLabel: widgetData.myMoodLabel
            )
        } catch {
            print("🔴 [Widget] Failed to read/decode JSON: \(error)")
             return CoupleWidgetData(
                daysTogether: 0,
                partnerMoodImage: "tired",
                partnerMoodLabel: "NoData",
                partnerName: "Waiting...",
                myMoodImage: "tired",
                myMoodLabel: "NoData"
            )
        }
    }
    
    struct WidgetDataPayload: Codable {
        let daysTogether: Int
        let partnerMoodImage: String
        let partnerMoodLabel: String
        let partnerName: String
        let myMoodImage: String
        let myMoodLabel: String
        let lastUpdated: TimeInterval
    }
}

// MARK: - Timeline Entry
struct CoupleEntry: TimelineEntry {
    let date: Date
    let data: CoupleWidgetData
}

// MARK: - Timeline Provider
struct CoupleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), data: .placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) {
        let entry = CoupleEntry(date: Date(), data: CoupleWidgetData.load())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        let data = CoupleWidgetData.load()
        let entry = CoupleEntry(date: Date(), data: data)
        
        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

// MARK: - Widget Definition
struct CiftWidget: Widget {
    let kind: String = "CiftWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleTimelineProvider()) { entry in
            CiftWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.widgetBgLight, Color.widgetBgMid, Color.widgetBgDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Us & Time")
        .description("Partnerinin ruh hali ve birliktelik sayacı")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Views
struct CiftWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CoupleEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let data: CoupleWidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // Moods Row (Me & Partner)
            HStack(spacing: 6) {
                // My Mood
                VStack(spacing: 2) {
                    ResizedImage(name: data.myMoodImage, size: CGSize(width: 80, height: 80))
                        .frame(width: 40, height: 40)
                    Text("Ben")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.widgetTextSecondary)
                }
                
                // Heart
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.widgetAccent)
                
                // Partner Mood
                VStack(spacing: 2) {
                    ResizedImage(name: data.partnerMoodImage, size: CGSize(width: 80, height: 80))
                        .frame(width: 40, height: 40)
                    Text(data.partnerName) // Might truncate if long
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.widgetTextSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 4)
            
            Spacer()
            
            // Days Counter
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color.widgetAccent)
                Text("\(data.daysTogether)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.widgetAccentDark)
                Text("gün")
                    .font(.system(size: 10))
                    .foregroundColor(Color.widgetTextSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.7))
            .clipShape(Capsule())
        }
        .padding(12)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let data: CoupleWidgetData
    
    var body: some View {
        HStack(spacing: 12) {
            // Moods Section
            HStack(spacing: 8) {
                // My Mood
                VStack(spacing: 6) {
                    ResizedImage(name: data.myMoodImage, size: CGSize(width: 120, height: 120))
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 1) {
                        Text("Ben")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.widgetTextPrimary)
                        Text(data.myMoodLabel)
                            .font(.caption2)
                            .foregroundStyle(Color.widgetTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Heart Center
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(Color.widgetAccent)
                
                // Partner Mood
                VStack(spacing: 6) {
                    ResizedImage(name: data.partnerMoodImage, size: CGSize(width: 120, height: 120))
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 1) {
                        Text(data.partnerName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.widgetTextPrimary)
                            .lineLimit(1)
                        Text(data.partnerMoodLabel)
                            .font(.caption2)
                            .foregroundStyle(Color.widgetTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity) // Take available space
            
            // Days Counter Section
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(Color.widgetAccent)
                
                Text("\(data.daysTogether)")
                    .font(.system(size: 38, weight: .bold, design: .rounded)) // Slightly smaller
                    .foregroundStyle(Color.widgetAccentDark)
                    .minimumScaleFactor(0.8)
                
                Text("gün")
                    .font(.caption)
                    .foregroundStyle(Color.widgetTextSecondary)
            }
            .frame(width: 90) // Fixed width for counter
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CiftWidget()
} timeline: {
    CoupleEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    CiftWidget()
} timeline: {
    CoupleEntry(date: .now, data: .placeholder)
}
