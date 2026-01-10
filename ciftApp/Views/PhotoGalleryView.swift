//
//  PhotoGalleryView.swift
//  ciftApp
//
//  Us & Time - Photo Gallery
//

import SwiftUI

struct PhotoGalleryView: View {
    @Bindable var timelineManager: TimelineManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: TimelineEvent?
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if photosWithImages.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .background(
                Color(red: 0.98, green: 0.96, blue: 0.96)
                    .ignoresSafeArea()
            )
            .navigationTitle(String(localized: "gallery.title"))
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
            .fullScreenCover(item: $selectedPhoto) { event in
                PhotoViewerView(event: event, allPhotos: photosWithImages, selectedPhoto: $selectedPhoto)
            }
        }
    }
    
    // MARK: - Photo Grid
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photosWithImages) { event in
                    PhotoThumbnail(event: event) {
                        selectedPhoto = event
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.8))
            
            Text(String(localized: "gallery.empty.title"))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.35))
            
            Text(String(localized: "gallery.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Photos With Images
    private var photosWithImages: [TimelineEvent] {
        timelineManager.events.filter { $0.hasPhoto }
    }
}

// MARK: - Photo Thumbnail
struct PhotoThumbnail: View {
    let event: TimelineEvent
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let urlString = event.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(1, contentMode: .fill)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
            )
    }
}

// MARK: - Photo Viewer
struct PhotoViewerView: View {
    let event: TimelineEvent
    let allPhotos: [TimelineEvent]
    @Binding var selectedPhoto: TimelineEvent?
    @State private var currentIndex: Int = 0
    @State private var showInfo = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(allPhotos.enumerated()), id: \.element.id) { index, photo in
                    PhotoPage(event: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .onAppear {
                currentIndex = allPhotos.firstIndex(where: { $0.id == event.id }) ?? 0
            }
            
            // Overlay Controls
            VStack {
                // Top bar
                HStack {
                    Button {
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button {
                        showInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                .background(
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                )
                
                Spacer()
                
                // Bottom info
                if showInfo, currentIndex < allPhotos.count {
                    let currentPhoto = allPhotos[currentIndex]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentPhoto.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(currentPhoto.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if let description = currentPhoto.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.easeInOut, value: showInfo)
    }
}

// MARK: - Photo Page
struct PhotoPage: View {
    let event: TimelineEvent
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        if let urlString = event.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = 1.0
                                    }
                                }
                        )
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    PhotoGalleryView(timelineManager: TimelineManager())
}
