//
//  LocationManager.swift
//  ciftApp
//
//  Us & Time - Location Manager Service
//

import Foundation
import CoreLocation
import Observation
import Supabase

@Observable
final class LocationManager: NSObject {
    // MARK: - Published Properties
    var userLocation: CLLocationCoordinate2D?
    var partnerLocation: CLLocationCoordinate2D?
    var partnerLocationUpdatedAt: Date?
    var partnerName: String?
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Computed Properties
    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var isLocationAvailable: Bool {
        userLocation != nil
    }
    
    var isPartnerLocationAvailable: Bool {
        partnerLocation != nil
    }
    
    var partnerLocationTimeAgo: String? {
        guard let updatedAt = partnerLocationUpdatedAt else { return nil }
        
        let interval = Date().timeIntervalSince(updatedAt)
        
        if interval < 60 {
            return "Az önce"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) dk önce"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) saat önce"
        } else {
            let days = Int(interval / 86400)
            return "\(days) gün önce"
        }
    }
    
    // MARK: - Private
    private let locationManager = CLLocationManager()
    private let supabase = SupabaseManager.shared.client
    private var updateTask: Task<Void, Never>?
    private var lastUpdateTime: Date?
    private let updateInterval: TimeInterval = 60 // 60 seconds debounce for background
    
    // MARK: - Init
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        
        // Start background location monitoring if already authorized
        if authorizationStatus == .authorizedAlways {
            startBackgroundMonitoring()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permission (Always for background access)
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Start tracking user location (foreground)
    func startTracking() {
        guard hasLocationPermission else {
            requestPermission()
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    /// Start background monitoring (significant location changes - battery efficient)
    func startBackgroundMonitoring() {
        guard authorizationStatus == .authorizedAlways else {
            print("🔵 [Location] Background monitoring requires 'Always' authorization")
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        print("🟢 [Location] Started background location monitoring")
    }
    
    /// Stop all tracking
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        updateTask?.cancel()
    }
    
    /// Load partner location from database
    @MainActor
    func loadPartnerLocation() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            // First get my profile to find partner ID
            let myProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard let partnerId = myProfile.partnerId else {
                print("🔵 [Location] No partner found")
                return
            }
            
            // Get partner profile with location
            let partnerProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: partnerId)
                .single()
                .execute()
                .value
            
            partnerName = partnerProfile.username
            
            if let lat = partnerProfile.lastLatitude,
               let lng = partnerProfile.lastLongitude {
                partnerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                partnerLocationUpdatedAt = partnerProfile.lastLocationUpdated
                print("🟢 [Location] Partner location loaded: \(lat), \(lng)")
            } else {
                print("🔵 [Location] Partner has no location data")
            }
            
        } catch {
            print("🔴 [Location] Error loading partner location: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Update my location to database
    @MainActor
    func updateMyLocation(_ coordinate: CLLocationCoordinate2D) async {
        // Debounce - don't update too frequently
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateInterval {
            return
        }
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            struct LocationUpdate: Encodable {
                let last_latitude: Double
                let last_longitude: Double
                let last_location_updated: String
            }
            
            let updateData = LocationUpdate(
                last_latitude: coordinate.latitude,
                last_longitude: coordinate.longitude,
                last_location_updated: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            lastUpdateTime = Date()
            print("🟢 [Location] My location updated: \(coordinate.latitude), \(coordinate.longitude)")
            
        } catch {
            print("🔴 [Location] Error updating location: \(error)")
        }
    }
    
    /// Force refresh partner location
    @MainActor
    func refreshPartnerLocation() async {
        await loadPartnerLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if hasLocationPermission {
            startTracking()
        }
        
        // Start background monitoring if 'Always' is granted
        if authorizationStatus == .authorizedAlways {
            startBackgroundMonitoring()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        userLocation = coordinate
        
        // Update database (debounced)
        Task { @MainActor in
            await updateMyLocation(coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🔴 [Location] Location error: \(error)")
        errorMessage = error.localizedDescription
    }
}
