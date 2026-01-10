//
//  MilestonesView.swift
//  ciftApp
//
//  Us & Time - Milestones (Visual Countdown Design)
//

import SwiftUI

struct MilestonesView: View {
    @Bindable var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAddMilestone = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Featured Countdown (Next Big Milestone)
                    if let next = nextMajorMilestone {
                        featuredCountdownCard(next)
                    } else {
                        emptyCountdownState
                    }
                    
                    // 2. Upcoming Section
                    if !upcomingMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(String(localized: "milestones.upcoming"))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(upcomingMilestones) { event in
                                        UpcomingMilestoneCard(event: event)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // 3. Past Milestones (Timeline Style)
                    if !pastMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(String(localized: "milestones.past"))
                            LazyVStack(spacing: 16) {
                                ForEach(pastMilestones) { event in
                                    PastMilestoneRow(event: event)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle(String(localized: "milestones.title"))
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
    
    // MARK: - Components
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }
    
    private func featuredCountdownCard(_ event: TimelineEvent) -> some View {
        let days = daysUntil(event.dateValue)
        
        return ZStack {
            // Background Blur Image
            if let url = event.photoUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                     Color.pink.opacity(0.1)
                }
            } else {
                LinearGradient(colors: [.pink.opacity(0.2), .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            
            // Overlay
            Rectangle().fill(.ultraThinMaterial).opacity(0.8)
            
            VStack(spacing: 16) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: 0.75) // Static for now, can be dynamic based on year progress
                        .stroke(
                            AngularGradient(colors: [.pink, .orange], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 150, height: 150)
                    
                    VStack {
                        Text("\(days)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.pink)
                        Text(String(localized: "milestones.daysLeft"))
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(event.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
    
    private var emptyCountdownState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.largeTitle)
                .foregroundStyle(.gray)
            Text(String(localized: "milestones.noUpcoming"))
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Logic Helpers
    
    private var nextMajorMilestone: TimelineEvent? {
        // Simple logic: Find first upcoming anniversary or milestone
        // For now, returning the first upcoming milestone
        return upcomingMilestones.first
    }
    
    private var upcomingMilestones: [TimelineEvent] {
         let today = Date()
         let calendar = Calendar.current
         
         // Milestone'lar genellikle geçmiş tarihlidir (evlilik tarihi gibi), ama biz onların "gelecekteki yıldönümlerini" hesaplamalıyız.
         // Şimdilik basitçe: Gelecek tarihli eventleri veya yıldönümlerini alalım.
         // Demo için: Yılın geri kalanındaki milestone'ları filtreleyelim.
         
         // Basitleştirilmiş: Tüm milestones'ları alıp, onların bu yılki yıldönümlerine göre sıralayalım.
         return timelineManager.milestones.sorted {
             daysUntil($0.dateValue) < daysUntil($1.dateValue)
         }
    }
    
    private var pastMilestones: [TimelineEvent] {
        // Geçmişte kalmış ve "Tek Seferlik" olanlar (ör: İlk Buluşma)
        // Eğer yıldönümü tipi ise upcoming'de gösteriyoruz.
        // Ama burada demo olarak timeline'da geride kalanları listeyelim.
        return timelineManager.milestones.filter { $0.dateValue < Date() }
    }
    
    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        let eventMonth = calendar.component(.month, from: date)
        let eventDay = calendar.component(.day, from: date)
        
        var nextDate = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: today),
            month: eventMonth,
            day: eventDay
        ))!
        
        if nextDate < today {
            nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate)!
        }
        
        return calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
    }
}

// MARK: - Upcoming Card
struct UpcomingMilestoneCard: View {
    let event: TimelineEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: event.milestoneType?.icon ?? "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Spacer()
                Text(event.shortDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(event.title)
                .font(.headline)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                .lineLimit(2)
            
            Spacer()
            
            HStack {
                Label(String(localized: "milestones.custom"), systemImage: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.pink)
            }
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Past Row
struct PastMilestoneRow: View {
    let event: TimelineEvent
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                 Text(event.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 5)
    }
}

#Preview {
    MilestonesView(timelineManager: TimelineManager())
}
