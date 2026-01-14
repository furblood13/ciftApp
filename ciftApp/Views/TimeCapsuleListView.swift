//
//  TimeCapsuleListView.swift
//  ciftApp
//
//  Us & Time - Time Capsule List
//

import SwiftUI

struct TimeCapsuleListView: View {
    @State private var capsuleManager = TimeCapsuleManager()
    @State private var showCreateSheet = false
    @State private var selectedCapsule: TimeCapsule?
    @State private var selectedTab = 0 // 0: Gelen, 1: Gönderilen
    @State private var capsuleToDelete: TimeCapsule?
    @State private var showDeleteAlert = false
    
    var body: some View {
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
            
            VStack(spacing: 0) {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text(String(localized: "capsule.received")).tag(0)
                    Text(String(localized: "capsule.sent")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                if capsuleManager.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if currentCapsules.isEmpty {
                    emptyState
                } else {
                    capsuleList
                }
            }
        }
        .navigationTitle(String(localized: "capsule.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCapsuleView(capsuleManager: capsuleManager)
        }
        .sheet(item: $selectedCapsule) { capsule in
            CapsuleDetailView(
                capsule: capsule,
                capsuleManager: capsuleManager,
                currentUserId: capsuleManager.currentUserId
            )
        }
        .alert(String(localized: "common.delete"), isPresented: $showDeleteAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) { }
            Button(String(localized: "common.delete"), role: .destructive) {
                if let capsule = capsuleToDelete {
                    Task {
                        await capsuleManager.deleteCapsule(id: capsule.id)
                    }
                }
            }
        } message: {
            Text(String(localized: "capsule.deleteConfirm"))
        }
        .task {
            await capsuleManager.loadCapsules()
        }
    }
    
    private var currentCapsules: [TimeCapsule] {
        selectedTab == 0 ? capsuleManager.receivedCapsules : capsuleManager.sentCapsules
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("capsulenobg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
            
            Text(selectedTab == 0 ? String(localized: "capsule.noReceived") : String(localized: "capsule.noSent"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            Text(selectedTab == 0 
                 ? String(localized: "capsule.waitingFromPartner")
                 : String(localized: "capsule.sendSecret"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                .multilineTextAlignment(.center)
            
            if selectedTab == 1 {
                Button {
                    showCreateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(String(localized: "capsule.create"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.96, green: 0.69, blue: 0.69))
                    )
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Capsule List
    private var capsuleList: some View {
        List {
            if selectedTab == 0 {
                // Gelen - Bölümlerle
                receivedCapsulesList
            } else {
                // Gönderilen - Tek liste
                ForEach(capsuleManager.sentCapsules) { capsule in
                    sentCapsuleCard(capsule)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                capsuleToDelete = capsule
                                showDeleteAlert = true
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Received Capsules (Sectioned)
    @ViewBuilder
    private var receivedCapsulesList: some View {
        let userId = capsuleManager.currentUserId ?? UUID()
        
        // Bekleyen/Kilitli kapsüller (henüz açılmamış)
        let pendingCapsules = capsuleManager.receivedCapsules.filter { $0.isLocked }
        // Açılan kapsüller
        let openedCapsules = capsuleManager.receivedCapsules.filter { !$0.isLocked }
        
        // Bekleyen bölümü - SİLİNEMEZ
        if !pendingCapsules.isEmpty {
            Section {
                ForEach(pendingCapsules) { capsule in
                    receivedCapsuleCard(capsule, userId: userId)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    // Bekleyen mesajlar silinemez - swipe yok
                }
            } header: {
                sectionHeader("Bekleyen Mesajlar", icon: "clock.fill", color: .orange)
            }
        }
        
        // Açılan bölümü - SİLİNEBİLİR
        if !openedCapsules.isEmpty {
            Section {
                ForEach(openedCapsules) { capsule in
                    receivedCapsuleCard(capsule, userId: userId)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                capsuleToDelete = capsule
                                showDeleteAlert = true
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.open.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                        Text(String(localized: "capsule.openedMessages"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    }
                    Text(String(localized: "capsule.swipeToDelete"))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.55))
                }
                .padding(.leading, 4)
                .padding(.top, 8)
            }
        }
    }
    
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }
    
    // MARK: - Capsule Row
    @ViewBuilder
    private func capsuleRow(_ capsule: TimeCapsule) -> some View {
        let userId = capsuleManager.currentUserId ?? UUID()
        let isCreator = capsule.isCreator(userId: userId)
        
        if selectedTab == 0 {
            // Gelen kapsül - alıcı görünümü
            receivedCapsuleCard(capsule, userId: userId)
        } else {
            // Gönderilen kapsül - gönderen görünümü
            sentCapsuleCard(capsule)
        }
    }
    
    // MARK: - Received Capsule Card
    @ViewBuilder
    private func receivedCapsuleCard(_ capsule: TimeCapsule, userId: UUID) -> some View {
        let canUnlock = capsule.canUnlock
        let isHidden = (capsule.hidePreview ?? false) && !canUnlock
        
        Button {
            if !isHidden {
                if canUnlock {
                Task {
                        await capsuleManager.unlockCapsule(id: capsule.id)
                        }
                }
                selectedCapsule = capsule
            }
        } label: {
            HStack(spacing: 16) {
                // Icon - Custom images
                if !capsule.isLocked {
                    // Açıldı
                    Image("messageSent")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    // Kilitli veya açılmaya hazır
                    Image("bekleyen")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if capsule.shouldShowTitle(for: userId) {
                        Text(capsule.title ?? String(localized: "capsule.secretMessage"))
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    } else {
                        Text(String(localized: "capsule.secretCapsule"))
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    }
                    
                    // Subtitle
                    if canUnlock {
                        Text(String(localized: "capsule.tapToOpen"))
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.4))
                    } else if capsule.shouldShowCountdown(for: userId) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(capsule.timeRemaining)
                                .font(.caption)
                        }
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    } else {
                        Text(String(localized: "capsule.surprise"))
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    }
                }
                
                Spacer()
                
                if !isHidden {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.65))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isHidden ? 0.6 : 0.9))
            )
        }
        .buttonStyle(.plain)
        .disabled(isHidden)
    }
    
    // MARK: - Sent Capsule Card (Creator View)
    private func sentCapsuleCard(_ capsule: TimeCapsule) -> some View {
        HStack(spacing: 16) {
            // Status Icon
            if capsule.canUnlock || !capsule.isLocked {
                // Açıldı - custom image
                Image("messageSent")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                // Bekliyor - custom image
                Image("bekleyen")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(capsule.title ?? String(localized: "capsule.secretMessage"))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                if capsule.canUnlock || !capsule.isLocked {
                    Text(String(localized: "capsule.opened"))
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(capsule.timeRemaining)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
            }
            
            Spacer()
            
            // Privacy indicators
            HStack(spacing: 4) {
                if capsule.hideTitle ?? false {
                    privacyBadge("T")
                }
                if capsule.hideCountdown ?? false {
                    privacyBadge("⏱")
                }
                if capsule.hidePreview ?? false {
                    privacyBadge("👁")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.9))
        )
    }
    
    private func privacyBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(4)
            .background(Circle().fill(Color.gray.opacity(0.2)))
    }
    
    // MARK: - Helper Functions
    private func iconBackgroundColor(for capsule: TimeCapsule) -> Color {
        if capsule.canUnlock {
            return Color(red: 0.4, green: 0.8, blue: 0.4).opacity(0.2)
        } else if !capsule.isLocked {
            return Color(red: 0.96, green: 0.69, blue: 0.69).opacity(0.2)
        } else {
            return Color(red: 0.5, green: 0.4, blue: 0.45).opacity(0.2)
        }
    }
    
    private func iconName(for capsule: TimeCapsule, isHidden: Bool) -> String {
        if isHidden {
            return "questionmark"
        } else if capsule.canUnlock {
            return "gift.fill"
        } else if !capsule.isLocked {
            return "envelope.open.fill"
        } else {
            return "lock.fill"
        }
    }
    
    private func iconColor(for capsule: TimeCapsule, isHidden: Bool) -> Color {
        if isHidden {
            return Color(red: 0.5, green: 0.4, blue: 0.45)
        } else if capsule.canUnlock {
            return Color(red: 0.4, green: 0.8, blue: 0.4)
        } else if !capsule.isLocked {
            return Color(red: 0.96, green: 0.69, blue: 0.69)
        } else {
            return Color(red: 0.5, green: 0.4, blue: 0.45)
        }
    }
}

#Preview {
    NavigationStack {
        TimeCapsuleListView()
    }
}
