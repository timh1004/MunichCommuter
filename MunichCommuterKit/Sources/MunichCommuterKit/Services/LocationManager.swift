import Foundation
import CoreLocation
import SwiftUI

public enum LocationTrackingMode: Sendable {
    case precise
    case background
    case singleShot
    case stopped
}

@MainActor
public class LocationManager: NSObject, ObservableObject {
    public static let shared = LocationManager()

    @Published public var location: CLLocation?
    @Published public var lastKnownLocation: CLLocation?
    @Published public var effectiveLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var locationError: String?
    @Published public var currentTrackingMode: LocationTrackingMode = .stopped

    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let lastLatKey = "LocationManager.lastKnownLatitude"
    private let lastLonKey = "LocationManager.lastKnownLongitude"
    private let lastTsKey = "LocationManager.lastKnownTimestamp"

    override public init() {
        super.init()
        setupLocationManager()
        loadPersistedLastKnownLocation()
        updateEffectiveLocation()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        #if !os(watchOS)
        // Nahverkehr: zuverlässigere Updates beim Gehen (Fitness + Pause führten oft zu „eingefrorenem“ Standort).
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        #endif

        if let cached = locationManager.location {
            self.lastKnownLocation = cached
            persistLastKnownLocation(cached)
            updateEffectiveLocation()
        }
    }

    public func requestLocationPermission() {
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            locationError = "Standortzugriff wurde verweigert. Bitte aktivieren Sie ihn in den Einstellungen."
            return
        }

        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            locationManager.requestLocation()
        }
    }

    public func getLocationIfAuthorized() {
        guard isAuthorized else { return }
        locationManager.requestLocation()
    }

    public func requestLocation() {
        getLocationIfAuthorized()
    }

    public var hasLocationPermission: Bool {
        return isAuthorized
    }

    private var isAuthorized: Bool {
        #if os(macOS)
        return authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
        #else
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #endif
    }

    public func setTrackingMode(_ mode: LocationTrackingMode) {
        guard isAuthorized else {
            currentTrackingMode = .stopped
            return
        }

        locationManager.stopUpdatingLocation()
        #if !os(watchOS)
        locationManager.stopMonitoringSignificantLocationChanges()
        #endif

        currentTrackingMode = mode

        switch mode {
        case .precise:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 25
            #if !os(watchOS)
            locationManager.activityType = .otherNavigation
            locationManager.pausesLocationUpdatesAutomatically = false
            #endif
            locationManager.startUpdatingLocation()
        case .background:
            #if !os(watchOS)
            locationManager.startMonitoringSignificantLocationChanges()
            #else
            locationManager.requestLocation()
            #endif
        case .singleShot:
            locationManager.requestLocation()
        case .stopped:
            break
        }
    }

    public func startPreciseUpdates() {
        setTrackingMode(.precise)
    }

    public func startBackgroundUpdates() {
        setTrackingMode(.background)
    }

    public func requestSingleLocation() {
        setTrackingMode(.singleShot)
    }

    public func stopAllUpdates() {
        setTrackingMode(.stopped)
    }

    public func startLocationUpdates() {
        setTrackingMode(.singleShot)
    }

    public func stopLocationUpdates() {
        stopAllUpdates()
    }

    public func distanceFrom(_ coordinate: [Double]) -> CLLocationDistance? {
        guard let userLocation = effectiveLocation,
              coordinate.count >= 2 else {
            return nil
        }
        let targetLocation = CLLocation(latitude: coordinate[0], longitude: coordinate[1])
        return userLocation.distance(from: targetLocation)
    }

    public func distanceFromAssignedStop(_ assignedStopDistance: Int?) -> CLLocationDistance? {
        guard let distance = assignedStopDistance else { return nil }
        return CLLocationDistance(distance)
    }

    public func formattedDistance(_ distance: CLLocationDistance) -> String {
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

    /// Entfernung zur Haltestelle: mit bekanntem Gerätestandort immer **live** aus GPS+Koordinate,
    /// damit sich Werte beim Gehen aktualisieren (API-`distance` stammt vom Suchzeitpunkt).
    public func distanceFor(location: Location) -> CLLocationDistance? {
        if effectiveLocation != nil, let coord = location.coord, coord.count >= 2 {
            return distanceFrom(coord)
        }
        if let apiDist = location.distance {
            return CLLocationDistance(apiDist)
        }
        return distanceFrom(location.coord ?? [])
    }

    public func coordStringForAPI() -> String? {
        guard let location = effectiveLocation else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return "\(lon):\(lat):WGS84[DD.ddddd]"
    }

    public func awaitEffectiveLocation(timeout: TimeInterval = 1.5) async -> CLLocation? {
        let start = Date()
        if let loc = effectiveLocation { return loc }
        while Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let loc = effectiveLocation { return loc }
        }
        return effectiveLocation
    }

    private func updateEffectiveLocation() {
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
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.location = location
            self.lastKnownLocation = location
            self.persistLastKnownLocation(location)
            self.updateEffectiveLocation()
            self.locationError = nil
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "Standort konnte nicht ermittelt werden: \(error.localizedDescription)"
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status

            #if os(macOS)
            let authorized = (status == .authorizedAlways || status == .authorized)
            #else
            let authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            #endif

            if authorized {
                self.locationError = nil
                self.startPreciseUpdates()
                self.updateEffectiveLocation()
            } else if status == .denied || status == .restricted {
                self.locationError = "Standortzugriff wurde verweigert"
                self.currentTrackingMode = .stopped
                self.updateEffectiveLocation()
            } else {
                self.currentTrackingMode = .stopped
            }
        }
    }
}
