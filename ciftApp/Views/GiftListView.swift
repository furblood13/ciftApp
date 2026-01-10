
//
//  GiftListView.swift
//  ciftApp
//
//  Us & Time - Gift Ideas List
//

import SwiftUI

struct GiftListView: View {
    let userId: String
    @State private var giftManager = GiftManager()
    @State private var newGiftText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
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
                // Input Area
                HStack(spacing: 12) {
                    TextField(String(localized: "gift.add"), text: $newGiftText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addGift()
                        }
                    
                    Button {
                        addGift()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.96, green: 0.69, blue: 0.69))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                }
                .padding()
                
                if giftManager.gifts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "gift")
                            .font(.system(size: 60))
                            .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69).opacity(0.5))
                        Text(String(localized: "gift.empty.title") + "\n" + String(localized: "gift.empty.subtitle"))
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45).opacity(0.7))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(giftManager.gifts) { gift in
                            HStack {
                                Button {
                                    withAnimation {
                                        giftManager.toggleGift(gift)
                                    }
                                } label: {
                                    Image(systemName: gift.isPurchased ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(
                                            gift.isPurchased 
                                            ? Color(red: 0.6, green: 0.8, blue: 0.6) 
                                            : Color(red: 0.8, green: 0.7, blue: 0.75)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                Text(gift.title)
                                    .strikethrough(gift.isPurchased)
                                    .foregroundStyle(
                                        gift.isPurchased 
                                        ? .gray 
                                        : Color(red: 0.3, green: 0.2, blue: 0.25)
                                    )
                                
                                Spacer()
                            }
                            .listRowBackground(Color.white.opacity(0.6))
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            giftManager.deleteGift(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(String(localized: "gift.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            giftManager.loadGifts(for: userId)
        }
    }
    
    private func addGift() {
        guard !newGiftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation {
            giftManager.addGift(newGiftText)
            newGiftText = ""
            isInputFocused = false // Dismiss keyboard after adding
        }
    }
}

#Preview {
    NavigationStack {
        GiftListView(userId: "test_user")
    }
}
