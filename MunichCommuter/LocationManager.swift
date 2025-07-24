import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
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
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocation()
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
        func distanceFrom(_ coordinate: [Double]) -> CLLocationDistance? {
        guard let userLocation = location,
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
    
    func coordStringForAPI() -> String? {
        guard let location = location else { return nil }
        
        // Convert to the WGS84 format expected by MVV API
        // Format: longitude:latitude:WGS84[DD.ddddd]
        // Example: 11.578433335815134:48.12611861375449:WGS84[DD.ddddd]
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        print("🗺️ User Location: \(lat), \(lon)")
        
        return "\(lon):\(lat):WGS84[DD.ddddd]"
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
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
                self.locationManager.requestLocation()
            case .denied, .restricted:
                self.locationError = "Standortzugriff wurde verweigert"
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}