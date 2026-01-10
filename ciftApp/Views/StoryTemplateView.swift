//
//  StoryTemplateView.swift
//  ciftApp
//
//  Template for generating Instagram Story images
//

import SwiftUI

struct StoryTemplateView: View {
    let title: String
    let date: Date
    let images: [UIImage] // Pre-loaded images
    let locationName: String?
    let coupleNames: String?
    
    // Instagram Story Resolution (Base reference)
    // We will render at 1080x1920 logical points ideally, or scale to it.
    
    var body: some View {
        ZStack {
            // 1. Background
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.96, blue: 0.96), // Soft Pinkish White
                    Color(red: 0.95, green: 0.90, blue: 0.92),
                    Color(red: 0.90, green: 0.85, blue: 0.85)  // Slightly darker base
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Decorative Background Elements
            GeometryReader { geo in
                Circle()
                    .fill(Color.orange.opacity(0.05))
                    .frame(width: 400, height: 400)
                    .position(x: geo.size.width, y: 100)
                
                Circle()
                    .fill(Color.pink.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .position(x: 0, y: geo.size.height - 200)
            }
            
            VStack(spacing: 0) {
                // MARK: - TOP SECTION
                if images.count >= 1 {
                    let topScale = images.count == 2 ? 0.6 : 0.75
                    PolaroidView(image: images[0], angle: -3)
                        .scaleEffect(topScale)
                        .padding(.top, images.count == 2 ? 5 : 27)
                        .padding(.bottom, images.count == 2 ? -30 : 0) // Negative padding to reduce gap
                }
                
                // MARK: - MIDDLE SECTION (Typography)
                VStack(spacing: images.count == 2 ? 3 : 6) {
                    // Date
                    Text(formattedDate.uppercased())
                        .font(.system(size: images.count == 2 ? 11 : 13, weight: .light, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    
                    // Title
                    Text(title)
                        .font(.system(size: images.count == 2 ? 22 : 30, weight: .semibold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                        .padding(.horizontal, 20)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Location
                    if let loc = locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(loc)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    }
                    
                    // Heart Divider
                    Image(systemName: "heart.fill")
                        .font(images.count == 2 ? .caption : .title3)
                        .foregroundStyle(Color.pink.opacity(0.6))
                        .padding(.vertical, 0)
                    
                    // Couple Names
                    if let names = coupleNames {
                        Text(names)
                            .font(.custom("Snell Roundhand", size: images.count == 2 ? 14 : 20))
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, images.count == 2 ? -20 : 20) // Negative padding to reduce gap
                
                // MARK: - BOTTOM SECTION
                if images.count >= 3 {
                    // Triangle Layout Bottom Split
                    HStack(alignment: .bottom, spacing: 0) {
                        PolaroidView(image: images[1], angle: -6)
                            .scaleEffect(0.5)
                            .rotationEffect(.degrees(-5))
                            .frame(width: 140, height: 160)
                        
                        PolaroidView(image: images[2], angle: 6)
                            .scaleEffect(0.5)
                            .rotationEffect(.degrees(5))
                            .frame(width: 140, height: 160)
                    }
                    .padding(.bottom, 10)
                    
                } else if images.count == 2 {
                    // Bottom photo - bigger size
                    PolaroidView(image: images[1], angle: 4)
                        .scaleEffect(0.6)
                        .padding(.top, -20) // Negative padding to reduce gap
                        .padding(.bottom, 5)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .offset(y: images.count == 2 ? -15 : -40)
        }
        .frame(width: 1080 / 3, height: 1920 / 3) // Preview size
    }
    
    // MARK: - Helpers (Removed old subviews as main body handles layout)
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Components

struct PolaroidView: View {
    let image: UIImage
    let angle: Double
    
    var body: some View {
        ZStack {
            // Photo - Made smaller to ensure it stays INSIDE the frame
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 190, height: 250) // Reduced from 220x280
                .clipped()
                // No corner radius needed if the frame covers the edges properly, 
                // but kept small just in case.
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Frame Overlay ("cerceve" asset)
            Image("cerceve")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 340)
                // The frame sits on top. 
                // If the asset has a transparent hole, the image shows through.
        }
        .rotationEffect(.degrees(angle))
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview (Debugging)

#Preview {
    StoryTemplateView(
        title: "Kapadokya Gezimiz",
        date: Date(),
        images: [UIImage(systemName: "photo")!, UIImage(systemName: "star")!, UIImage(systemName: "heart")!],
        locationName: "Kapadokya, Nevşehir",
        coupleNames: "Ahmet & Ayşe"
    )
}
