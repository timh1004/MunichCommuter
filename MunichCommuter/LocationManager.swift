import Foundation
import CoreLocation
import SwiftUI

enum LocationTrackingMode {
    case precise      // Fine-grained updates for live resorting (25m filter, nearestTenMeters)
    case background   // Significant location changes only (500m+ cell tower changes)
    case singleShot   // One-time location request
    case stopped      // No location updates
}

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var location: CLLocation?
    // Persisted last known location to speed up startup and provide fallback (e.g., underground)
    @Published var lastKnownLocation: CLLocation?
    // Published effective location that prefers live location but falls back to last known
    @Published var effectiveLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var currentTrackingMode: LocationTrackingMode = .stopped
    
    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let lastLatKey = "LocationManager.lastKnownLatitude"
    private let lastLonKey = "LocationManager.lastKnownLongitude"
    private let lastTsKey = "LocationManager.lastKnownTimestamp"
    
    override init() {
        super.init()
        setupLocationManager()
        loadPersistedLastKnownLocation()
        updateEffectiveLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // Default settings - will be adjusted based on tracking mode
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // If the system has a cached location, use it immediately
        if let cached = locationManager.location {
            self.lastKnownLocation = cached
            persistLastKnownLocation(cached)
            updateEffectiveLocation()
        }
    }
    
    // Request location permission explicitly (called by user action)
    func requestLocationPermission() {
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            locationError = "Standortzugriff wurde verweigert. Bitte aktivieren Sie ihn in den Einstellungen."
            return
        }
        
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // Get location if permission already granted (no UI prompts)
    func getLocationIfAuthorized() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.requestLocation()
    }
    
    // Legacy method - now just calls getLocationIfAuthorized to avoid permission prompts
    func requestLocation() {
        getLocationIfAuthorized()
    }
    
    // Check if we have location permission
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // Set the location tracking mode
    func setTrackingMode(_ mode: LocationTrackingMode) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            currentTrackingMode = .stopped
            return
        }
        
        // Stop all current tracking
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        currentTrackingMode = mode
        
        switch mode {
        case .precise:
            // Fine-grained updates for live resorting
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 25
            locationManager.activityType = .fitness
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.startUpdatingLocation()
            
        case .background:
            // Significant location changes only (500m+ cell tower changes)
            locationManager.startMonitoringSignificantLocationChanges()
            
        case .singleShot:
            // One-time location request
            locationManager.requestLocation()
            
        case .stopped:
            // All updates stopped
            break
        }
    }
    
    // Convenience methods
    func startPreciseUpdates() {
        setTrackingMode(.precise)
    }
    
    func startBackgroundUpdates() {
        setTrackingMode(.background)
    }
    
    func requestSingleLocation() {
        setTrackingMode(.singleShot)
    }
    
    func stopAllUpdates() {
        setTrackingMode(.stopped)
    }
    
    // Legacy method - now defaults to single shot to avoid prompts
    func startLocationUpdates() {
        setTrackingMode(.singleShot)
    }
    
    func stopLocationUpdates() {
        stopAllUpdates()
    }
    
        func distanceFrom(_ coordinate: [Double]) -> CLLocationDistance? {
        guard let userLocation = effectiveLocation,
              coordinate.count >= 2 else {
            return nil
        }
        
        // MVV API returns [latitude, longitude] format
        let targetLocation = CLLocation(latitude: coordinate[0], longitude: coordinate[1])
        return userLocation.distance(from: targetLocation)
    }
    
    // Helper to get distance from AssignedStop distance field (in meters)
    func distanceFromAssignedStop(_ assignedStopDistance: Int?) -> CLLocationDistance? {
        guard let distance = assignedStopDistance else { return nil }
        return CLLocationDistance(distance)
    }
    
    func formattedDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            let km = distance / 1000
            if km < 10 {
                return String(format: "%.1f km", km)
            } else {
                return "\(Int(km)) km"
            }
        }
    }
    
    // Convenience: compute distance for a Location model using available sources
    func distanceFor(location: Location) -> CLLocationDistance? {
        if let apiDist = location.distance {
            return CLLocationDistance(apiDist)
        }
        return distanceFrom(location.coord ?? [])
    }
    
    func coordStringForAPI() -> String? {
        guard let location = effectiveLocation else { return nil }
        
        // Convert to the WGS84 format expected by MVV API
        // Format: longitude:latitude:WGS84[DD.ddddd]
        // Example: 11.578433335815134:48.12611861375449:WGS84[DD.ddddd]
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        print("🗺️ User Location: \(lat), \(lon)")
        
        return "\(lon):\(lat):WGS84[DD.ddddd]"
    }

    // Await an effective location (live or last-known) with timeout
    func awaitEffectiveLocation(timeout: TimeInterval = 1.5) async -> CLLocation? {
        let start = Date()
        if let loc = effectiveLocation { return loc }
        while Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if let loc = effectiveLocation { return loc }
        }
        return effectiveLocation
    }

    private func updateEffectiveLocation() {
        // Prefer fresh live location; fall back to persisted last known
        if let live = location {
            self.effectiveLocation = live
        } else if let cached = lastKnownLocation {
            self.effectiveLocation = cached
        } else {
            self.effectiveLocation = nil
        }
    }

    private func persistLastKnownLocation(_ location: CLLocation) {
        defaults.set(location.coordinate.latitude, forKey: lastLatKey)
        defaults.set(location.coordinate.longitude, forKey: lastLonKey)
        defaults.set(location.timestamp.timeIntervalSince1970, forKey: lastTsKey)
    }

    private func loadPersistedLastKnownLocation() {
        let lat = defaults.double(forKey: lastLatKey)
        let lon = defaults.double(forKey: lastLonKey)
        let ts = defaults.double(forKey: lastTsKey)
        if ts != 0 {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let timestamp = Date(timeIntervalSince1970: ts)
            self.lastKnownLocation = CLLocation(coordinate: coord, altitude: 0, horizontalAccuracy: 100, verticalAccuracy: -1, timestamp: timestamp)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.lastKnownLocation = location
            self.persistLastKnownLocation(location)
            self.updateEffectiveLocation()
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "Standort konnte nicht ermittelt werden: \(error.localizedDescription)"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                // Start with a single shot to get immediate location, but don't start continuous updates
                // Views will decide what tracking mode they need
                self.setTrackingMode(.singleShot)
                self.updateEffectiveLocation()
            case .denied, .restricted:
                self.locationError = "Standortzugriff wurde verweigert"
                self.currentTrackingMode = .stopped
                self.updateEffectiveLocation()
            case .notDetermined:
                self.currentTrackingMode = .stopped
                break
            @unknown default:
                self.currentTrackingMode = .stopped
                break
            }
        }
    }
}