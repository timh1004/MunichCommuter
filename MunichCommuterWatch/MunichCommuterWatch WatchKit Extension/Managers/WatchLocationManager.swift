//
//  WatchLocationManager.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
class WatchLocationManager: NSObject, ObservableObject {
    static let shared = WatchLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: String?
    @Published var isLocationUpdating = false
    
    private let locationManager = CLLocationManager()
    private var lastLocationUpdate: Date?
    private let locationUpdateInterval: TimeInterval = 30 // 30 seconds minimum between updates
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // Less precise for battery saving
        locationManager.distanceFilter = 50 // Update every 50 meters
    }
    
    // MARK: - Permission Handling
    func requestLocationPermission() {
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            error = "Standortzugriff verweigert. Aktivieren Sie ihn in den Einstellungen."
            return
        }
        
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if hasLocationPermission {
            requestLocationUpdate()
        }
    }
    
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // MARK: - Location Updates
    func requestLocationUpdate() {
        guard hasLocationPermission else {
            requestLocationPermission()
            return
        }
        
        // Throttle location updates to save battery
        if let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < locationUpdateInterval {
            return
        }
        
        guard !isLocationUpdating else { return }
        
        isLocationUpdating = true
        error = nil
        
        locationManager.requestLocation()
    }
    
    func startLocationUpdates() {
        guard hasLocationPermission else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationUpdating = false
    }
    
    // MARK: - Distance Calculations
    func distanceFrom(_ coordinate: [Double]) -> CLLocationDistance? {
        guard let userLocation = location,
              coordinate.count >= 2 else {
            return nil
        }
        
        // MVV API returns [latitude, longitude] format
        let targetLocation = CLLocation(latitude: coordinate[0], longitude: coordinate[1])
        return userLocation.distance(from: targetLocation)
    }
    
    func distanceFromLocation(_ location: WatchLocation) -> CLLocationDistance? {
        guard let coord = location.coord else { return nil }
        return distanceFrom(coord)
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
    
    func formattedDistanceFromLocation(_ location: WatchLocation) -> String? {
        guard let distance = distanceFromLocation(location) else { return nil }
        return formattedDistance(distance)
    }
    
    // Convert to MVV API coordinate format
    func coordStringForAPI() -> String? {
        guard let location = location else { return nil }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Format: longitude:latitude:WGS84[DD.ddddd]
        return "\(lon):\(lat):WGS84[DD.ddddd]"
    }
    
    var coordinateForAPI: [Double]? {
        guard let location = location else { return nil }
        return [location.coordinate.latitude, location.coordinate.longitude]
    }
    
    // MARK: - Battery Optimization
    func optimizeForBattery() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
    }
    
    func optimizeForAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 50
    }
}

// MARK: - CLLocationManagerDelegate
extension WatchLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = newLocation
            self.error = nil
            self.isLocationUpdating = false
            self.lastLocationUpdate = Date()
        }
        
        // Stop updating if we got a single location request
        if !manager.significantLocationChangeMonitoringAvailable {
            manager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.error = "Standort konnte nicht ermittelt werden: \(error.localizedDescription)"
            self.isLocationUpdating = false
        }
        
        print("❌ Location error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.error = nil
                self.requestLocationUpdate()
            case .denied, .restricted:
                self.error = "Standortzugriff wurde verweigert"
                self.isLocationUpdating = false
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}