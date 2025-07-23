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
    
    func requestLocation() {
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
              coordinate.count >= 2 else { return nil }
        
        // MVV API returns [latitude, longitude] format
        let targetLocation = CLLocation(latitude: coordinate[0], longitude: coordinate[1])
        return userLocation.distance(from: targetLocation)
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
        
        // Convert to the format expected by MVV API: coord:longitude:latitude:MRCV:description:0
        let longitude = Int(location.coordinate.longitude * 1000000)
        let latitude = Int(location.coordinate.latitude * 1000000)
        
        return "coord:\(longitude):\(latitude):MRCV:Aktuelle Position:0"
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