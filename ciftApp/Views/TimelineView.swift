//
//  TimelineView.swift
//  ciftApp
//
//  Us & Time - Timeline Main View (Living Story Design)
//

import SwiftUI

struct TimelineView: View {
    @State private var timelineManager = TimelineManager()
    @State private var showAddEvent = false
    @State private var showStats = false
    @State private var showMilestones = false
    @State private var showGallery = false
    @State private var showPaywall = false
    @State private var showConflictTip = true
    @State private var selectedFilter: EventType? = nil
    @State private var selectedEvent: TimelineEvent?
    
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    
    // Total photo count across all events (only count photoUrls array)
    private var totalPhotoCount: Int {
        timelineManager.events.reduce(0) { total, event in
            total + (event.photoUrls?.count ?? 0)
        }
    }
    
    // Check if user can add more photos (free: 5 total)
    private var canAddMorePhotos: Bool {
        subscriptionManager.isPremium || totalPhotoCount < subscriptionManager.photoLimit
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            
            // Main Content
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Dashboard Header
                    TimelineHeader(
                        timelineManager: timelineManager,
                        onStatsTap: { showStats = true },
                        onMilestonesTap: { showMilestones = true },
                        onGalleryTap: { showGallery = true }
                    )
                    
                    // 2. Filter Section
                    filterSection
                    
                    // Conflict Resolution Tip
                    if showConflictTip && hasUnresolvedConflicts {
                        conflictTipBanner
                    }
                    
                    if timelineManager.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if filteredEvents.isEmpty {
                        emptyState
                    } else {
                        // 3. Events List
                        eventsList
                    }
                }
                .padding(.bottom, 100) // Padding for FAB
            }
            .refreshable {
                await timelineManager.loadEvents()
            }
            
            // 4. Floating Action Button (FAB) - always allow adding events
            Button {
                showAddEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.69, blue: 0.69), Color(red: 0.86, green: 0.59, blue: 0.59)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                    )
            }
            .padding(24)
        }
        .navigationTitle(String(localized: "timeline.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(timelineManager: timelineManager)
        }
        .sheet(isPresented: $showStats) {
            TimelineStatsView(timelineManager: timelineManager)
        }
        .sheet(isPresented: $showMilestones) {
            MilestonesView(timelineManager: timelineManager)
        }
        .sheet(isPresented: $showGallery) {
            PhotoGalleryView(timelineManager: timelineManager)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(eventId: event.id, timelineManager: timelineManager)
        }
        .task {
            await timelineManager.loadEvents()
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterPill(title: String(localized: "timeline.filter.all"), icon: "list.bullet", isSelected: selectedFilter == nil, color: .gray) {
                    selectedFilter = nil
                }
                
                FilterPill(title: String(localized: "timeline.filter.memory"), icon: EventType.memory.icon, isSelected: selectedFilter == .memory, color: .pink) {
                    selectedFilter = .memory
                }
                
                FilterPill(title: String(localized: "timeline.filter.conflict"), icon: EventType.conflict.icon, isSelected: selectedFilter == .conflict, color: .orange) {
                    selectedFilter = .conflict
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Conflict Tip
    private var hasUnresolvedConflicts: Bool {
        timelineManager.events.contains { $0.type == .conflict && $0.isResolved != true }
    }
    
    private var conflictTipBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
            
            Text(String(localized: "timeline.conflictTip"))
                .font(.caption)
                .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
            
            Spacer()
            
            Button {
                withAnimation {
                    showConflictTip = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Filtered Events
    private var filteredEvents: [TimelineEvent] {
        if let filter = selectedFilter {
            return timelineManager.events.filter { $0.type == filter }
        }
        return timelineManager.events
    }
    
    // MARK: - Events List
    private var eventsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(groupedEvents, id: \.key) { group in
                Section {
                    ForEach(group.events) { event in
                        TimelineEventCard(event: event, timelineManager: timelineManager) {
                            selectedEvent = event
                        }
                        .padding(.horizontal, 20)
                    }
                } header: {
                    monthHeader(group.key)
                }
            }
        }
    }
    
    // MARK: - Grouped Events by Month
    private var groupedEvents: [(key: String, events: [TimelineEvent])] {
        let grouped = Dictionary(grouping: filteredEvents) { $0.monthYear }
        return grouped.map { (key: $0.key, events: $0.value) }
            .sorted { $0.events.first?.dateValue ?? Date() > $1.events.first?.dateValue ?? Date() }
    }
    
    // MARK: - Month Header
    private func monthHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                )
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.pages.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.8))
            
            Text(String(localized: "timeline.empty.title"))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
            
            Text(String(localized: "timeline.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
            
            Spacer()
        }
        .frame(height: 300)
    }
}

// MARK: - Filter Pill Component
struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? color : Color(red: 0.4, green: 0.3, blue: 0.35))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
