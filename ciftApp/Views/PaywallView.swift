//
//  PaywallView.swift
//  ciftApp
//
//  Us & Time - Premium Paywall
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    
    @State private var selectedPlan: PlanType = .yearly
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var onComplete: (() -> Void)?
    var showCloseButton: Bool = true
    
    enum PlanType {
        case monthly, yearly
    }
    
    // MARK: - Colors
    private let pinkAccent = Color(red: 0.96, green: 0.69, blue: 0.69)
    private let darkPink = Color(red: 0.90, green: 0.50, blue: 0.55)
    private let textPrimary = Color(red: 0.25, green: 0.20, blue: 0.22)
    private let textSecondary = Color(red: 0.55, green: 0.50, blue: 0.52)
    
    var body: some View {
        ZStack {
            // Blurred pink background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.85, blue: 0.87),
                    Color(red: 0.98, green: 0.90, blue: 0.91),
                    Color(red: 0.96, green: 0.88, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MASCOT with close button overlay
                    ZStack(alignment: .topTrailing) {
                        // MASCOT - Full width with gradient fade
                        Image("ani")
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: 320)
                            .clipped()
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: 0.65),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Close Button
                        if showCloseButton {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .shadow(radius: 4)
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 50)
                        }
                    }
                    
                    // Title & Subtitle
                    VStack(spacing: 8) {
                        Text(String(localized: "paywall.title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                        
                        Text(String(localized: "paywall.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, -20)
                    
                    // Features
                    HStack(spacing: 32) {
                        featureItem(icon: "photo.on.rectangle", text: String(localized: "paywall.photos"))
                        featureItem(icon: "envelope", text: String(localized: "paywall.capsules"))
                        featureItem(icon: "checklist", text: String(localized: "paywall.todos"))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    // One person pays banner
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(darkPink)
                        Text(String(localized: "paywall.onePersonPays"))
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.8))
                    )
                    .padding(.bottom, 12)
                    
                    // Plan Cards
                    VStack(spacing: 10) {
                        // Yearly
                        planCard(
                            type: .yearly,
                            title: String(localized: "paywall.yearly"),
                            trialText: String(localized: "paywall.trialThenYearly"),
                            price: subscriptionManager.yearlyProduct?.displayPrice ?? "$39.99",
                            showBadge: true,
                            isSelected: selectedPlan == .yearly
                        )
                        
                        // Monthly
                        planCard(
                            type: .monthly,
                            title: String(localized: "paywall.monthly"),
                            trialText: String(localized: "paywall.trialThenMonthly"),
                            price: subscriptionManager.monthlyProduct?.displayPrice ?? "$4.99",
                            showBadge: false,
                            isSelected: selectedPlan == .monthly
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // CTA Button
                    Button {
                        Task {
                            await startPurchase()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(String(localized: "paywall.startTrial"))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [darkPink, pinkAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Terms
                    VStack(spacing: 4) {
                        Text(String(localized: "paywall.terms"))
                            .font(.caption2)
                            .foregroundStyle(textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button(String(localized: "paywall.restore")) {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(darkPink)
                        .underline()
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .alert(String(localized: "common.error"), isPresented: $showError) {
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Feature Item
    private func featureItem(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(pinkAccent)
            Text(text)
                .font(.caption)
                .foregroundStyle(textSecondary)
        }
    }
    
    // MARK: - Plan Card
    private func planCard(
        type: PlanType,
        title: String,
        trialText: String,
        price: String,
        showBadge: Bool,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPlan = type
            }
        } label: {
            HStack {
                // Radio
                Circle()
                    .stroke(isSelected ? darkPink : Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .fill(isSelected ? darkPink : .clear)
                            .frame(width: 12, height: 12)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(textPrimary)
                        
                        if showBadge {
                            Text(String(localized: "paywall.bestValue"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, Color(red: 1.0, green: 0.4, blue: 0.4)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    
                    Text(trialText)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
                
                Spacer()
                
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(darkPink)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? darkPink : .clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Start Purchase
    private func startPurchase() async {
        isProcessing = true
        errorMessage = ""
        defer { isProcessing = false }
        
        let product = selectedPlan == .yearly 
            ? subscriptionManager.yearlyProduct 
            : subscriptionManager.monthlyProduct
        
        guard let productToPurchase = product else {
            errorMessage = String(localized: "paywall.loadError")
            showError = true
            return
        }
        
        let success = await subscriptionManager.purchase(productToPurchase)
        
        if success {
            onComplete?()
            dismiss()
        }
        // If failed or cancelled, purchase() handles it silently or prints error.
        // We stay on paywall to let user try again.
    }
}

#Preview {
    PaywallView()
}
