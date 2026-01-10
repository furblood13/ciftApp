//
//  TimelineStatsView.swift
//  ciftApp
//
//  Us & Time - Statistics (Bento Grid Style)
//

import SwiftUI
import Charts

struct TimelineStatsView: View {
    @Bindable var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRange: TimeRange = .thisMonth
    
    enum TimeRange: String, CaseIterable {
        case thisMonth
        case lastMonth
        case thisYear
        case allTime
        
        var localizedLabel: String {
            switch self {
            case .thisMonth: return String(localized: "stats.thisMonth")
            case .lastMonth: return String(localized: "stats.lastMonth")
            case .thisYear: return String(localized: "stats.thisYear")
            case .allTime: return String(localized: "stats.allTime")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date Filter Picker
                    Picker(String(localized: "stats.timeRange"), selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.localizedLabel).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 1. Top Large Card: Total Memories
                    totalMemoriesCard
                    
                    // 2. Bento Grid: Conflict/Peace/Resolution
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatBentoCard(
                            title: String(localized: "stats.conflicts"),
                            value: "\(filteredConflicts.count)",
                            assetName: "confligt",
                            color: .orange
                        )
                        
                        StatBentoCard(
                            title: String(localized: "stats.peace"),
                            value: "\(resolvedConflictsCount)",
                            assetName: "holdingHands",
                            color: .green
                        )
                        
                        resolutionRateCard
                        
                        StatBentoCard(
                            title: String(localized: "stats.avgSeverity"),
                            value: String(format: "%.1f", averageSeverity),
                            assetName: "confligt",
                            color: .red,
                            suffix: "/ 10"
                        )
                    }
                    
                    // 3. Wide Chart Card
                    if !filteredConflicts.isEmpty {
                        categoryBreakdownCard
                    }
                    
                    // 4. Trend Chart
                    if !filteredConflicts.isEmpty {
                        trendChartCard
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle(String(localized: "stats.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .font(.title2)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Data
    
    private var filteredEvents: [TimelineEvent] {
        let allEvents = timelineManager.events
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedRange {
        case .allTime:
            return allEvents
            
        case .thisMonth:
            return allEvents.filter {
                calendar.isDate($0.dateValue, equalTo: now, toGranularity: .month)
            }
            
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return [] }
            return allEvents.filter {
                calendar.isDate($0.dateValue, equalTo: lastMonth, toGranularity: .month)
            }
            
        case .thisYear:
            return allEvents.filter {
                calendar.isDate($0.dateValue, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var filteredMemories: [TimelineEvent] {
        filteredEvents.filter { $0.type == .memory || ($0.isMilestone ?? false) }
    }
    
    private var filteredConflicts: [TimelineEvent] {
        filteredEvents.filter { $0.type == .conflict }
    }
    
    private var filteredPeaceEvents: [TimelineEvent] {
        filteredEvents.filter { $0.type == .peace }
    }
    
    private var resolvedConflictsCount: Int {
        filteredConflicts.filter { $0.isResolved ?? false }.count
    }
    
    private var averageSeverity: Double {
        let conflicts = filteredConflicts
        guard !conflicts.isEmpty else { return 0 }
        let totalSeverity = conflicts.compactMap { $0.severity }.reduce(0, +)
        return Double(totalSeverity) / Double(conflicts.count)
    }
    
    // MARK: - Components
    
    private var totalMemoriesCard: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.96, blue: 0.96),
                            Color(red: 0.97, green: 0.92, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Image on right with gradient
            HStack {
                Spacer()
                Image("ani")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.15), location: 0),
                                .init(color: .white, location: 0.3),
                                .init(color: .white, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.trailing, 8)
            }
            
            // Text content on left
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "stats.totalMemories"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(filteredMemories.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pink.gradient)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private var resolutionRateCard: some View {
        let total = filteredConflicts.count
        let resolved = resolvedConflictsCount
        let rate = total > 0 ? Double(resolved) / Double(total) * 100 : 0
            
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(Int(rate))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            Text(String(localized: "stats.resolutionRate"))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.blue.opacity(0.1))
                    Capsule().fill(Color.blue)
                        .frame(width: geo.size.width * (rate / 100))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
    
    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "stats.conflictReasons"))
                .font(.headline)
            
            Chart(categoryStats, id: \.category) { stat in
                BarMark(
                    x: .value("Kategori", stat.count),
                    y: .value("Sebep", stat.category.label)
                )
                .foregroundStyle(by: .value("Kategori", stat.category.label))
                .cornerRadius(4)
            }
            .chartLegend(.hidden)
            .frame(height: 200)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedRange == .thisYear || selectedRange == .allTime ? String(localized: "stats.monthlyTrend") : String(localized: "stats.dailyTrend"))
                .font(.headline)
            
            Chart(trendData, id: \.date) { item in
                LineMark(
                    x: .value("Time", item.label),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.orange.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", item.label),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.orange.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 150)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    // MARK: - Helpers
    private var categoryStats: [(category: ConflictCategory, count: Int)] {
        let categories = filteredConflicts.compactMap { $0.conflictCategory }
        let grouped = Dictionary(grouping: categories) { $0 }
        return grouped.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    private var trendData: [(date: Date, label: String, count: Int)] {
        let calendar = Calendar.current
        let events = filteredConflicts
        
        // If range is short (Month), group by Day. If long (Year/All), group by Month.
        let isShortRange = selectedRange == .thisMonth || selectedRange == .lastMonth
        
        let grouped = Dictionary(grouping: events) { event -> Date in
            let components = calendar.dateComponents(
                isShortRange ? [.year, .month, .day] : [.year, .month],
                from: event.dateValue
            )
            return calendar.date(from: components) ?? Date()
        }
        
        let sortedDates = grouped.keys.sorted()
        
        return sortedDates.map { date in
            let count = grouped[date]?.count ?? 0
            
            // Just format label
            let formatter = DateFormatter()
            formatter.dateFormat = isShortRange ? "d MMM" : "MMM"
            formatter.locale = Locale.current
            let label = formatter.string(from: date)
            
            return (date: date, label: label, count: count)
        }
    }
}

// MARK: - Stat Bento Card
struct StatBentoCard: View {
    let title: String
    let value: String
    let assetName: String
    let color: Color
    var suffix: String? = nil
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.96, blue: 0.96),
                            Color(red: 0.97, green: 0.92, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Image on right with gradient
            HStack {
                Spacer()
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.15), location: 0),
                                .init(color: .white, location: 0.35),
                                .init(color: .white, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.trailing, 8)
            }
            
            // Text content on left
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.3))
                    
                    if let suffix = suffix {
                        Text(suffix)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

#Preview {
    TimelineStatsView(timelineManager: TimelineManager())
}
