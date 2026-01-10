//
//  LocationView.swift
//  ciftApp
//
//  Us & Time - Partner Location View
//

import SwiftUI
import MapKit

struct LocationView: View {
    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingBothLocations = true
    
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
            
            if locationManager.hasLocationPermission {
                // Map View
                mapContent
            } else {
                // Permission Request View
                permissionRequestView
            }
        }
        .navigationTitle(String(localized: "location.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await locationManager.refreshPartnerLocation()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                }
            }
        }
        .task {
            locationManager.startTracking()
            await locationManager.loadPartnerLocation()
        }
        .onDisappear {
            locationManager.stopTracking()
        }
    }
    
    // MARK: - Map Content
    private var mapContent: some View {
        VStack(spacing: 0) {
            // Map
            Map(position: $cameraPosition) {
                // My Location
                if let myLocation = locationManager.userLocation {
                    Annotation("Ben", coordinate: myLocation) {
                        myLocationPin
                    }
                }
                
                // Partner Location
                if let partnerLocation = locationManager.partnerLocation {
                    Annotation(locationManager.partnerName ?? "Partner", coordinate: partnerLocation) {
                        partnerLocationPin
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Info Cards
            VStack(spacing: 12) {
                // Partner Info Card
                if locationManager.isPartnerLocationAvailable {
                    partnerInfoCard
                } else {
                    noPartnerLocationCard
                }
                
                // Action Buttons
                actionButtons
            }
            .padding(16)
        }
    }
    
    // MARK: - Location Pins
    private var myLocationPin: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.4, green: 0.7, blue: 0.4))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            
            Image(systemName: "person.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
        }
    }
    
    private var partnerLocationPin: some View {
        Image("locationImage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 50, height: 50)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
    
    // MARK: - Partner Info Card
    private var partnerInfoCard: some View {
        HStack(spacing: 16) {
            // Partner Avatar
            Image("locationImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(locationManager.partnerName ?? "Partner")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                if let timeAgo = locationManager.partnerLocationTimeAgo {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(timeAgo)
                            .font(.caption)
                    }
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                }
            }
            
            Spacer()
            
            // Navigate Button
            if let partnerLocation = locationManager.partnerLocation {
                Button {
                    openInMaps(coordinate: partnerLocation)
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.9))
        )
    }
    
    // MARK: - No Partner Location Card
    private var noPartnerLocationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.55))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "location.noPartner"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                Text(String(localized: "location.notShared"))
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.9))
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Show My Location
            Button {
                if let myLocation = locationManager.userLocation {
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: myLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(String(localized: "location.myLocation"))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.9))
                )
            }
            
            // Show Partner Location
            Button {
                if let partnerLocation = locationManager.partnerLocation {
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: partnerLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text(String(localized: "location.partner"))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.96, green: 0.69, blue: 0.69))
                )
            }
            .disabled(!locationManager.isPartnerLocationAvailable)
            .opacity(locationManager.isPartnerLocationAvailable ? 1 : 0.5)
        }
    }
    
    // MARK: - Permission Request View
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.96, green: 0.69, blue: 0.69).opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(red: 0.96, green: 0.69, blue: 0.69))
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "location.permissionTitle"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.25))
                
                Text(String(localized: "location.permissionDesc"))
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                locationManager.requestPermission()
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(String(localized: "location.grantPermission"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.96, green: 0.69, blue: 0.69))
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = locationManager.partnerName ?? "Partner"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    NavigationStack {
        LocationView()
    }
}
