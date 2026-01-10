//
//  CapsuleDetailView.swift
//  ciftApp
//
//  Us & Time - Capsule Detail (Unlocked)
//

import SwiftUI

struct CapsuleDetailView: View {
    let capsule: TimeCapsule
    @Bindable var capsuleManager: TimeCapsuleManager
    let currentUserId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    private var isCreator: Bool {
        guard let userId = currentUserId else { return false }
        return capsule.isCreator(userId: userId)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
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
                
                if isCreator {
                    // Gönderen görünümü - sadece durum bilgisi
                    senderView
                } else if capsule.canUnlock || !capsule.isLocked {
                    // Alıcı görünümü - mesaj açıldı
                    recipientUnlockedView
                } else {
                    // Alıcı görünümü - henüz kilitli
                    lockedContent
                }
            }
            .navigationTitle(isCreator ? String(localized: "capsule.sentCapsule") : (capsule.title ?? String(localized: "capsule.secretMessage")))
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
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showContent = true
                }
            }
        }
    }
    
    // MARK: - Sender View (Creator sees this)
    private var senderView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Status Icon
            ZStack {
                Circle()
                    .fill(capsule.canUnlock || !capsule.isLocked 
                          ? Color.green.opacity(0.2)
                          : Color.orange.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: capsule.canUnlock || !capsule.isLocked 
                      ? "checkmark.circle.fill"
                      : "clock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(capsule.canUnlock || !capsule.isLocked 
                                     ? Color.green
                                     : Color.orange)
            }
            .scaleEffect(showContent ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showContent)
            
            VStack(spacing: 8) {
                Text(capsule.title ?? String(localized: "capsule.secretMessage"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                if capsule.canUnlock || !capsule.isLocked {
                    Text(String(localized: "capsule.partnerOpened"))
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Text(String(localized: "capsule.waitingToOpen"))
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    
                    Text(capsule.timeRemaining)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                        .padding(.top, 4)
                }
            }
            .opacity(showContent ? 1 : 0)
            
            // Privacy settings info
            VStack(spacing: 12) {
                Text(String(localized: "capsule.privacy"))
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                
                HStack(spacing: 16) {
                    privacyIndicator(String(localized: "capsule.privacyTitle"), isHidden: capsule.hideTitle ?? false)
                    privacyIndicator(String(localized: "capsule.privacyDuration"), isHidden: capsule.hideCountdown ?? false)
                    privacyIndicator(String(localized: "capsule.privacyPreview"), isHidden: capsule.hidePreview ?? false)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.8))
            )
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            
            Spacer()
            
            // Message preview for sender
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "capsule.sentMessage"))
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                
                Text(capsule.messageContent ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    .lineLimit(3)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.6))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
        }
    }
    
    private func privacyIndicator(_ title: String, isHidden: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                .font(.body)
                .foregroundStyle(isHidden ? Color.orange : Color.green)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
        }
    }
    
    // MARK: - Recipient Unlocked View (Full animation)
    private var recipientUnlockedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celebration Animation
                celebrationAnimation
                
                // Header
                VStack(spacing: 8) {
                    Text(String(localized: "capsule.secretOpened"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                    
                    Text(formatDate(capsule.createdAt ?? Date()))
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                // Message Card
                messageCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                
                // Floating hearts
                floatingHearts
                
                Spacer()
            }
        }
    }
    
    // MARK: - Celebration Animation
    private var celebrationAnimation: some View {
        ZStack {
            // Sparkles rotating outward
            ForEach(0..<12, id: \.self) { index in
                Image(systemName: index % 2 == 0 ? "sparkle" : "heart.fill")
                    .font(index % 3 == 0 ? .title : .title2)
                    .foregroundStyle(
                        index % 2 == 0 
                            ? Color(red: 0.96, green: 0.69, blue: 0.69)
                            : Color(red: 0.85, green: 0.5, blue: 0.55)
                    )
                    .offset(
                        x: cos(Double(index) * .pi / 6) * (60 + Double(index % 3) * 20),
                        y: sin(Double(index) * .pi / 6) * (60 + Double(index % 3) * 20)
                    )
                    .opacity(showContent ? 0.8 : 0)
                    .scaleEffect(showContent ? 1 : 0)
                    .rotationEffect(.degrees(showContent ? 0 : 180))
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.5)
                            .delay(Double(index) * 0.05),
                        value: showContent
                    )
            }
            
            // Confetti burst
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(confettiColors[index % confettiColors.count])
                    .frame(width: 8, height: 8)
                    .offset(
                        x: showContent ? cos(Double(index) * .pi / 10) * 120 : 0,
                        y: showContent ? sin(Double(index) * .pi / 10) * 120 - 50 : 0
                    )
                    .opacity(showContent ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).delay(Double(index) * 0.02),
                        value: showContent
                    )
            }
            
            // Main capsule image
            Image("capsule")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(showContent ? 1 : 0.3)
                .rotationEffect(.degrees(showContent ? 0 : -20))
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showContent)
        }
        .padding(.top, 40)
    }
    
    private var confettiColors: [Color] {
        [
            Color(red: 0.96, green: 0.69, blue: 0.69),
            Color(red: 0.85, green: 0.5, blue: 0.55),
            Color(red: 1.0, green: 0.8, blue: 0.4),
            Color(red: 0.6, green: 0.8, blue: 0.9),
            Color(red: 0.7, green: 0.9, blue: 0.7)
        ]
    }
    
    // MARK: - Message Card
    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
            
            Text(capsule.messageContent ?? "")
                .font(.body)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                .lineSpacing(6)
            
            HStack {
                Spacer()
                Image(systemName: "quote.closing")
                    .font(.title)
                    .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Floating Hearts
    private var floatingHearts: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(index == 2 ? .title : .title2)
                    .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                    .opacity(showContent ? 0.7 : 0)
                    .scaleEffect(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1 + 0.8),
                        value: showContent
                    )
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Locked Content
    private var lockedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
            
            Text(String(localized: "capsule.stillLocked"))
                .font(.title3)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
            
            Text(capsule.timeRemaining)
                .font(.headline)
                .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
        }
    }
    
    // MARK: - Helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

#Preview {
    CapsuleDetailView(
        capsule: TimeCapsule(
            id: UUID(),
            coupleId: nil,
            createdBy: nil,
            recipientId: nil,
            title: "Sürpriz Mesaj",
            messageContent: "Seni çok seviyorum!",
            mediaUrl: nil,
            unlockDate: Date(),
            isLocked: false,
            notificationSent: true,
            createdAt: Date(),
            hideTitle: false,
            hideCountdown: false,
            hidePreview: false
        ),
        capsuleManager: TimeCapsuleManager(),
        currentUserId: nil
    )
}
