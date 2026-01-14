//
//  HomeView.swift
//  ciftApp
//
//  Us & Time - Home Dashboard
//

import SwiftUI

struct HomeView: View {
    @Bindable var authManager: AuthManager
    @Bindable var pairingManager: CouplePairingManager
    var navigateToTimeCapsule: Binding<Bool>? = nil
    @State private var homeManager = HomeManager()
    @State private var profileManager = ProfileManager()
    @State private var todoManager = TodoManager()
    @State private var showProfileEdit = false
    @State private var showMoodPicker = false
    @State private var showDateEditor = false
    @State private var showTodoList = false
    @State private var localNavigateToTimeCapsule = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient - Soft Pink
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
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Days Counter Card
                            daysCounterCard
                            
                            // Couple Card (Both partners)
                            coupleCard
                            
                            // Mood Section
                            moodSection
                            
                            
                            // Quick Actions
                            quickActionsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
                

            }
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(profileManager: profileManager, pairingManager: pairingManager) {
                await authManager.signOut()
            } onDeleteCouple: {
                // Reset pairing state - this will navigate to PairingView
                pairingManager.isPaired = false
                pairingManager.initialCheckDone = false
            }
        }
        .onChange(of: showProfileEdit) { oldValue, newValue in
            // Refresh home data after profile edit sheet closes
            if oldValue == true && newValue == false {
                Task {
                    await homeManager.loadData()
                }
            }
        }
        .sheet(isPresented: $showMoodPicker) {
            moodPickerSheet
        }
        .sheet(isPresented: $showDateEditor) {
            RelationshipDateView(homeManager: homeManager)
        }
        .task {
            await homeManager.loadData()
            await profileManager.fetchProfile()
            await todoManager.fetchTodos()
            homeManager.updateWidget()
            homeManager.startAutoRefresh()
        }
        .onChange(of: homeManager.isCoupleDeleted) { _, isDeleted in
            // Partner deleted the couple - navigate back to pairing
            if isDeleted {
                pairingManager.isPaired = false
                pairingManager.initialCheckDone = false
            }
        }
        .onDisappear {
            homeManager.stopAutoRefresh()
        }
        .navigationDestination(isPresented: navigateToTimeCapsule ?? $localNavigateToTimeCapsule) {
            TimeCapsuleListView()
        }
        .navigationDestination(isPresented: $showTodoList) {
            TodoListView(todoManager: todoManager)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "app.name"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                if let partnerName = homeManager.partnerProfile?.username {
                    Text("❤️ " + partnerName)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
            }
            
            Spacer()
            
            // Profile Button
            Button {
                showProfileEdit = true
            } label: {
                avatarView(name: homeManager.myProfile?.username, size: 44, fontSize: 18)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Days Counter Card
    private var daysCounterCard: some View {
        Button {
            showDateEditor = true
        } label: {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69)) // F5AFAF
                    Text(String(localized: "home.together"))
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    Spacer()
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.65))
                }
                .font(.subheadline)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(homeManager.daysTogether)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.69, blue: 0.69), // F5AFAF
                                    Color(red: 0.85, green: 0.5, blue: 0.55)   // darker pink
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(String(localized: "home.days"))
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
                
                if homeManager.daysTogether > 0 {
                    Text(dayCounterMessage)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.55))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var dayCounterMessage: String {
        let days = homeManager.daysTogether
        if days < 30 { return String(localized: "home.dayMessage.new") }
        if days < 100 { return String(localized: "home.dayMessage.good") }
        if days < 365 { return String(localized: "home.dayMessage.wonderful") }
        if days < 730 { return String(localized: "home.dayMessage.year") }
        return String(localized: "home.dayMessage.legend")
    }
    
    // MARK: - Couple Card
    private var coupleCard: some View {
        HStack(spacing: 20) {
            // Me
            VStack(spacing: 8) {
                Image(homeManager.myMood.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                Text(homeManager.myProfile?.username ?? "Ben")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                Text(homeManager.myMood.label)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
            }
            
            // Heart
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                .symbolEffect(.pulse)
            
            // Partner
            VStack(spacing: 8) {
                Image(homeManager.partnerMood.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                Text(homeManager.partnerProfile?.username ?? "Partner")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                Text(homeManager.partnerMood.label)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white.opacity(0.7))
        )
    }
    
    // MARK: - Mood Section
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.yourMood"))
                .font(.headline)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button {
                            Task {
                                await homeManager.updateMyMood(mood)
                                homeManager.updateWidget()
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(mood.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                Text(mood.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                                    .lineLimit(1)
                            }
                            .frame(width: 75)
                            .padding(.vertical, 10)
                            .background(
                                homeManager.myMood == mood
                                    ? Color(red: 0.96, green: 0.69, blue: 0.69).opacity(0.4)
                                    : .white.opacity(0.7)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        homeManager.myMood == mood 
                                            ? Color(red: 0.96, green: 0.69, blue: 0.69) 
                                            : .clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                }
            }
            
            // Partner mood info
            if let partnerName = homeManager.partnerProfile?.username {
                HStack(spacing: 8) {
                    Image(homeManager.partnerMood.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("\(partnerName): \(homeManager.partnerMood.label)")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.7))
        )
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                TimelineView()
            } label: {
                featureCardWithImage(
                    imageName: "timeline",
                    title: String(localized: "home.timeline"),
                    subtitle: String(localized: "home.timeline.subtitle"),
                    isComingSoon: false
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                LocationView()
            } label: {
                featureCardWithImage(
                    imageName: "location",
                    title: String(localized: "home.location"),
                    subtitle: String(localized: "home.location.subtitle"),
                    isComingSoon: false
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                TimeCapsuleListView()
            } label: {
                featureCardWithImage(
                    imageName: "capsule",
                    title: String(localized: "home.capsule"),
                    subtitle: String(localized: "home.capsule.subtitle"),
                    isComingSoon: false
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                TodoListView(todoManager: todoManager)
            } label: {
                featureCardWithImage(
                    imageName: "todo",
                    title: String(localized: "home.todo"),
                    subtitle: String(localized: "home.todo.subtitle"),
                    isComingSoon: false
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                if let userId = homeManager.myProfile?.id.uuidString {
                    GiftListView(userId: userId)
                }
            } label: {
                featureCardWithImage(
                    imageName: "gift",
                    title: String(localized: "home.gift"),
                    subtitle: String(localized: "home.gift.subtitle"),
                    isComingSoon: false
                )
            }
            .buttonStyle(.plain)
        }
    }
    

    // MARK: - Mood Picker Sheet
    private var moodPickerSheet: some View {
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
                
                VStack(spacing: 16) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button {
                            Task {
                                await homeManager.updateMyMood(mood)
                                homeManager.updateWidget()
                                showMoodPicker = false
                            }
                        } label: {
                            HStack {
                                Image(mood.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                Text(mood.label)
                                    .font(.title3)
                                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                                Spacer()
                                if homeManager.myMood == mood {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                                }
                            }
                            .padding()
                            .background(.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "home.yourMood"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Views
    private func avatarView(name: String?, size: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.69, blue: 0.69), // F5AFAF
                            Color(red: 0.85, green: 0.5, blue: 0.55)   // darker pink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Text(String((name ?? "?").prefix(1)).uppercased())
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
    
    private func featureCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
                        Text(String(localized: "common.comingSoon"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func featureCardWithImage(imageName: String, title: String, subtitle: String, isComingSoon: Bool = true) -> some View {
        ZStack {
            // Soft gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.94, blue: 0.94), // FBEFEF
                            Color(red: 0.96, green: 0.87, blue: 0.87)  // F9DFDF
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Mascot image with fade gradient mask
            HStack {
                Spacer()
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 130)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.3),
                                .init(color: .white, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16)) // Matching style
                    .padding(.trailing, 8)
            }
            
            // Text content overlay on left
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    
                    Spacer()
                    
                    if isComingSoon {
                                    Text(String(localized: "common.comingSoon"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.96, green: 0.69, blue: 0.69)) // F5AFAF
                            )
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 16)
                
                Spacer()
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    HomeView(authManager: AuthManager(), pairingManager: CouplePairingManager())
}
