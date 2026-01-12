//
//  LocationManager.swift
//  ciftApp
//
//  Us & Time - Location Manager Service
//
//  ARCHITECTURE NOTES:
//  ====================
//  This LocationManager follows a battery-efficient, App Store-safe pattern
//  used by apps like Snapchat and Life360 (non-navigation use cases).
//
//  BACKGROUND BEHAVIOR:
//  - Uses ONLY startMonitoringSignificantLocationChanges()
//  - No continuous GPS usage in background
//  - No allowsBackgroundLocationUpdates (not needed for significant location changes)
//  - Event-based updates (cell tower/WiFi changes, ~500m+ movement)
//
//  FOREGROUND BEHAVIOR:
//  - When app opens or map screen appears, temporarily enable high-accuracy GPS
//  - Fetch 1-2 location updates, then immediately stop GPS
//  - This ensures fresh, accurate location when user views the app
//
//  KEY RULE:
//  - NEVER run startUpdatingLocation() and startMonitoringSignificantLocationChanges()
//    at the same time. They are mutually exclusive operations.
//

import Foundation
import CoreLocation
import Observation
import Supabase

// MARK: - Location Tracking Mode
/// Defines the current tracking mode to prevent mixing foreground/background behaviors
private enum LocationTrackingMode {
    case none
    case foregroundHighAccuracy  // GPS active for fresh location on app open
    case backgroundSignificant   // Significant location changes only (battery efficient)
}

@Observable
final class LocationManager: NSObject {
    // MARK: - Singleton
    /// Shared instance - USE THIS instead of creating new instances
    /// This prevents multiple CLLocationManager instances and GPS conflicts
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    var userLocation: CLLocationCoordinate2D?
    var partnerLocation: CLLocationCoordinate2D?
    var partnerLocationUpdatedAt: Date?
    var partnerName: String?
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false
    var errorMessage: String?
    
    /// Indicates whether a high-accuracy location fetch is in progress
    var isFetchingFreshLocation = false
    
    // MARK: - Computed Properties
    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
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
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let supabase = SupabaseManager.shared.client
    
    /// Current tracking mode - ensures we never mix foreground/background behaviors
    private var currentTrackingMode: LocationTrackingMode = .none
    
    /// Timer to auto-stop GPS after timeout (fail-safe for foreground fetch)
    private var gpsTimeoutTimer: Timer?
    
    /// Maximum time GPS can run during foreground fetch (10 seconds)
    private let gpsTimeoutInterval: TimeInterval = 10.0
    
    /// Number of location updates received during high-accuracy fetch
    private var highAccuracyUpdatesReceived: Int = 0
    
    /// Maximum updates to receive before stopping GPS (1-2 updates)
    private let maxHighAccuracyUpdates: Int = 2
    
    /// Last time location was sent to backend (debounce for background updates)
    private var lastBackendUpdateTime: Date?
    
    /// Minimum interval between backend updates (prevents spamming)
    private let minBackendUpdateInterval: TimeInterval = 60.0
    
    /// Completion handler for foreground fetch
    private var foregroundFetchCompletion: ((CLLocationCoordinate2D?) -> Void)?
    
    // MARK: - Init
    override init() {
        super.init()
        locationManager.delegate = self
        
        // IMPORTANT: Use lower accuracy by default
        // High accuracy is ONLY enabled during explicit foreground fetch
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // CRITICAL: Do NOT enable allowsBackgroundLocationUpdates
        // Significant location changes work WITHOUT this flag
        // This is what causes the persistent location indicator!
        // locationManager.allowsBackgroundLocationUpdates = false  // This is the default
        
        // Allow the system to pause updates to save battery (default behavior)
        locationManager.pausesLocationUpdatesAutomatically = true
        
        authorizationStatus = locationManager.authorizationStatus
        
        // If already authorized for "Always", start background monitoring
        // NOTE: We do NOT start startUpdatingLocation() here!
        if authorizationStatus == .authorizedAlways {
            startBackgroundMonitoring()
        }
        
        print("🔵 [Location] LocationManager initialized - Battery efficient mode")
    }
    
    deinit {
        stopAllTracking()
    }
    
    // MARK: - Public Methods
    
    /// Request location permission (Always for background access)
    func requestPermission() {
        // Request "Always" permission for background significant location changes
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Request "When In Use" permission only
    func requestWhenInUsePermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Foreground Location Fetch (High Accuracy, Time-Limited)
    
    /// Fetch a fresh, high-accuracy location when the app or map opens.
    /// This temporarily enables GPS, gets 1-2 updates, then stops immediately.
    ///
    /// USAGE: Call this when:
    /// - App becomes active
    /// - User opens the map/location screen
    /// - User pulls to refresh
    ///
    /// GPS will automatically stop after receiving updates or timeout.
    func fetchFreshLocation(completion: ((CLLocationCoordinate2D?) -> Void)? = nil) {
        guard hasLocationPermission else {
            print("🔴 [Location] Cannot fetch - no permission")
            completion?(nil)
            return
        }
        
        // If already fetching, ignore duplicate calls
        guard !isFetchingFreshLocation else {
            print("🔵 [Location] Already fetching fresh location, ignoring duplicate call")
            return
        }
        
        print("🟡 [Location] Starting high-accuracy GPS fetch...")
        
        // STEP 1: Stop any existing tracking to prevent conflicts
        stopAllLocationUpdates()
        
        // STEP 2: Configure for high accuracy foreground fetch
        currentTrackingMode = .foregroundHighAccuracy
        isFetchingFreshLocation = true
        highAccuracyUpdatesReceived = 0
        foregroundFetchCompletion = completion
        
        // STEP 3: Set high accuracy for GPS
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // STEP 4: Start GPS updates (will be stopped automatically after receiving updates)
        locationManager.startUpdatingLocation()
        
        // STEP 5: Set a fail-safe timeout to stop GPS even if updates don't arrive
        startGPSTimeoutTimer()
        
        print("🟢 [Location] GPS activated for foreground fetch (timeout: \(gpsTimeoutInterval)s)")
    }
    
    /// Async version of fetchFreshLocation for cleaner SwiftUI integration
    @MainActor
    func fetchFreshLocationAsync() async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            fetchFreshLocation { coordinate in
                continuation.resume(returning: coordinate)
            }
        }
    }
    
    // MARK: - Background Monitoring (Significant Location Changes)
    
    /// Start battery-efficient background monitoring using significant location changes.
    /// This uses cell tower/WiFi changes and does NOT keep GPS active.
    ///
    /// WHEN TO CALL:
    /// - After user grants "Always" authorization
    /// - When app enters background
    ///
    /// BATTERY IMPACT: Very low. Only triggers on ~500m+ movement.
    func startBackgroundMonitoring() {
        guard hasAlwaysPermission else {
            print("🔵 [Location] Background monitoring requires 'Always' authorization")
            return
        }
        
        // Stop foreground tracking if active to prevent conflicts
        if currentTrackingMode == .foregroundHighAccuracy {
            stopForegroundFetch()
        }
        
        // Only start if not already monitoring
        guard currentTrackingMode != .backgroundSignificant else {
            print("🔵 [Location] Already monitoring significant changes")
            return
        }
        
        currentTrackingMode = .backgroundSignificant
        
        // Use lower accuracy for background (save battery)
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Start significant location change monitoring
        // This does NOT require allowsBackgroundLocationUpdates!
        // It works automatically with "Always" permission
        locationManager.startMonitoringSignificantLocationChanges()
        
        print("🟢 [Location] Started significant location monitoring (battery efficient)")
    }
    
    /// Stop background monitoring
    func stopBackgroundMonitoring() {
        guard currentTrackingMode == .backgroundSignificant else { return }
        
        locationManager.stopMonitoringSignificantLocationChanges()
        currentTrackingMode = .none
        
        print("🔵 [Location] Stopped significant location monitoring")
    }
    
    // MARK: - Stop Methods
    
    /// Stop foreground GPS fetch (called after receiving updates or on timeout)
    private func stopForegroundFetch() {
        guard currentTrackingMode == .foregroundHighAccuracy else { return }
        
        // Invalidate the timeout timer
        gpsTimeoutTimer?.invalidate()
        gpsTimeoutTimer = nil
        
        // Stop GPS updates
        locationManager.stopUpdatingLocation()
        
        // Reset accuracy to default
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Reset state
        currentTrackingMode = .none
        isFetchingFreshLocation = false
        highAccuracyUpdatesReceived = 0
        foregroundFetchCompletion = nil
        
        print("🔵 [Location] GPS stopped - foreground fetch complete")
        
        // Resume background monitoring if we have "Always" permission
        if hasAlwaysPermission {
            startBackgroundMonitoring()
        }
    }
    
    /// Stop all location updates (both foreground and background)
    private func stopAllLocationUpdates() {
        gpsTimeoutTimer?.invalidate()
        gpsTimeoutTimer = nil
        
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        currentTrackingMode = .none
        isFetchingFreshLocation = false
        highAccuracyUpdatesReceived = 0
        foregroundFetchCompletion = nil
    }
    
    /// Public method to stop all tracking
    func stopAllTracking() {
        stopAllLocationUpdates()
        print("🔵 [Location] All location tracking stopped")
    }
    
    /// Stop only foreground GPS tracking, keep background monitoring active
    /// Use this when leaving a view that requested high-accuracy location
    func stopForegroundTrackingOnly() {
        if currentTrackingMode == .foregroundHighAccuracy {
            stopForegroundFetch()
            print("🔵 [Location] Foreground GPS stopped, background monitoring continues")
        }
    }
    
    // MARK: - GPS Timeout Timer
    
    /// Start a fail-safe timer to stop GPS if updates don't arrive
    private func startGPSTimeoutTimer() {
        gpsTimeoutTimer?.invalidate()
        
        gpsTimeoutTimer = Timer.scheduledTimer(withTimeInterval: gpsTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            print("⚠️ [Location] GPS timeout reached - stopping GPS")
            
            // Call completion with last known location if available
            let lastLocation = self.userLocation
            self.foregroundFetchCompletion?(lastLocation)
            
            self.stopForegroundFetch()
        }
    }
    
    // MARK: - Database Methods (Supabase)
    
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
    /// Includes debouncing to prevent excessive backend calls
    @MainActor
    func updateMyLocation(_ coordinate: CLLocationCoordinate2D, force: Bool = false) async {
        // Debounce - don't update too frequently (unless forced)
        if !force, let lastUpdate = lastBackendUpdateTime,
           Date().timeIntervalSince(lastUpdate) < minBackendUpdateInterval {
            print("🔵 [Location] Skipping backend update (debounced)")
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
            
            lastBackendUpdateTime = Date()
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
    
    // MARK: - App Lifecycle Helpers
    
    /// Call when app becomes active (enters foreground)
    /// This fetches a fresh location for display
    func onAppBecameActive() {
        print("🔵 [Location] App became active - fetching fresh location")
        fetchFreshLocation()
    }
    
    /// Call when app enters background
    /// This ensures only significant location monitoring is active
    func onAppEnteredBackground() {
        print("🔵 [Location] App entered background - switching to significant monitoring")
        
        // Stop any foreground GPS tracking
        if currentTrackingMode == .foregroundHighAccuracy {
            stopForegroundFetch()
        }
        
        // Ensure background monitoring is active
        if hasAlwaysPermission && currentTrackingMode != .backgroundSignificant {
            startBackgroundMonitoring()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus
        
        print("🔵 [Location] Authorization changed: \(oldStatus.rawValue) → \(authorizationStatus.rawValue)")
        
        // IMPORTANT: Do NOT automatically start GPS tracking on authorization change!
        // This was one of the main issues in the original implementation.
        
        switch authorizationStatus {
        case .authorizedAlways:
            // Start battery-efficient background monitoring
            // Do NOT call startUpdatingLocation() here!
            startBackgroundMonitoring()
            
        case .authorizedWhenInUse:
            // User has "When In Use" permission
            // They can still use fetchFreshLocation() when app is open
            print("🔵 [Location] 'When In Use' granted - GPS available on-demand only")
            
        case .denied, .restricted:
            print("🔴 [Location] Permission denied or restricted")
            stopAllTracking()
            
        case .notDetermined:
            print("🔵 [Location] Permission not determined yet")
            
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        userLocation = coordinate
        
        // Handle based on current tracking mode
        switch currentTrackingMode {
        case .foregroundHighAccuracy:
            // We're doing a high-accuracy foreground fetch
            highAccuracyUpdatesReceived += 1
            
            print("🟢 [Location] High-accuracy update #\(highAccuracyUpdatesReceived): \(coordinate.latitude), \(coordinate.longitude)")
            
            // Force update to backend when fetching fresh location (user is actively viewing)
            Task { @MainActor in
                await updateMyLocation(coordinate, force: true)
            }
            
            // Check if we have enough updates to stop GPS
            if highAccuracyUpdatesReceived >= maxHighAccuracyUpdates {
                print("🟢 [Location] Received \(maxHighAccuracyUpdates) updates - stopping GPS")
                
                // Call completion handler with the location
                foregroundFetchCompletion?(coordinate)
                
                // Stop GPS and resume background monitoring
                stopForegroundFetch()
            }
            
        case .backgroundSignificant:
            // This is a significant location change event (cell tower/WiFi change)
            print("🔵 [Location] Significant location change: \(coordinate.latitude), \(coordinate.longitude)")
            
            // Update backend (debounced)
            Task { @MainActor in
                await updateMyLocation(coordinate)
            }
            
        case .none:
            // Unexpected - we shouldn't receive updates in this state
            print("⚠️ [Location] Received update in 'none' mode - this shouldn't happen")
            userLocation = coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🔴 [Location] Location error: \(error)")
        errorMessage = error.localizedDescription
        
        // If we're doing a foreground fetch and it fails, stop it
        if currentTrackingMode == .foregroundHighAccuracy {
            foregroundFetchCompletion?(nil)
            stopForegroundFetch()
        }
    }
}
