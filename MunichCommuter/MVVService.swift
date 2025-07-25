//
//  MVVService.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import Foundation
import CoreLocation

// MARK: - String Extension for Station ID Normalization
extension String {
    /// Normalizes MVV station IDs to use the base station ID
    /// Examples:
    /// - "de:09162:150:3:3" -> "de:09162:150"
    /// - "de:09162:150" -> "de:09162:150"
    /// - "de:09162:150:1:1" -> "de:09162:150"
    var normalizedStationId: String {
        // Split by colon and take the first 3 parts (base station ID)
        let components = self.components(separatedBy: ":")
        if components.count >= 3 {
            return "\(components[0]):\(components[1]):\(components[2])"
        }
        return self
    }
}

class MVVService: ObservableObject {
    @Published var locations: [Location] = []
    @Published var departures: [StopEvent] = []
    @Published var departureLocations: [DepartureLocation] = []  // ✅ ADD THIS!
    @Published var isLoading = false
    @Published var isDeparturesLoading = false
    @Published var errorMessage: String?
    @Published var departureErrorMessage: String?
    
    private let stopFinderURL = "https://def-efa-mvv02.defas-fgi.de/gullivr_ios/XML_STOPFINDER_REQUEST"
    private let departureMonitorURL = "https://def-efa-mvv02.defas-fgi.de/gullivr_ios/XML_DM_REQUEST"
    
    func searchStops(name: String = "edua") {
        isLoading = true
        errorMessage = nil
        
        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: name),
            URLQueryItem(name: "type_sf", value: "any")
        ]
        
        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.errorMessage = "Ungültige URL"
                self.isLoading = false
            }
            return
        }
        
        print("🌐 Stop Finder API URL: \(url.absoluteString)")
        print("   Search term: '\(name)'")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }
                
                do {
                    let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                    self?.locations = mvvResponse.locations ?? []
                } catch {
                    self?.errorMessage = "Fehler beim Verarbeiten der Daten: \(error.localizedDescription)"
                    print("JSON Decoding Error: \(error)")
                    
                    // Debug: Print raw response
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw JSON Response: \(jsonString)")
                    }
                }
            }
        }.resume()
    }
    
    func searchNearbyStops(coordinate: String) {
        isLoading = true
        errorMessage = nil
        
        // Step 1: Convert GPS coordinates to MVV coordinate system
        convertCoordinateToMVV(coordinate: coordinate) { [weak self] mvvCoordinate in
            guard let mvvCoordinate = mvvCoordinate else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Koordinaten konnten nicht konvertiert werden"
                    self?.isLoading = false
                }
                return
            }
            
            // Step 2: Search for nearby stops using MVV coordinates
            self?.searchStopsNearMVVCoordinate(mvvCoordinate: mvvCoordinate)
        }
    }
    
    private func convertCoordinateToMVV(coordinate: String, completion: @escaping (String?) -> Void) {
        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "convertCoord2LocationServer", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: coordinate),
            URLQueryItem(name: "type_sf", value: "coord"),
            URLQueryItem(name: "doNotSearchForStops_sf", value: "1")
        ]
        
        guard let url = components?.url else {
            completion(nil)
            return
        }
        
        print("🗺️ Step 1 - Convert GPS to MVV coordinates")
        print("🌐 Coordinate Conversion URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Coordinate conversion error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data received for coordinate conversion")
                completion(nil)
                return
            }
            
            do {
                let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                if let location = mvvResponse.locations?.first {
                    print("✅ Converted to MVV coordinate: \(location.id)")
                    completion(location.id)
                } else {
                    print("❌ No location returned from coordinate conversion")
                    completion(nil)
                }
            } catch {
                print("❌ Failed to decode coordinate conversion response: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func searchStopsNearMVVCoordinate(mvvCoordinate: String) {
        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "convertCoord2LocationServer", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "useProxFootSearch", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: mvvCoordinate),
            URLQueryItem(name: "type_sf", value: "any")
        ]
        
        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.errorMessage = "Ungültige URL für Haltestellensuche"
                self.isLoading = false
            }
            return
        }
        
        print("🗺️ Step 2 - Search for nearby stops")
        print("🌐 Nearby Stops URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }
                
                do {
                    let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                    let rawLocations = mvvResponse.locations ?? []
                    
                    // Extract assigned stops and convert them to Location objects
                    var nearbyStops: [Location] = []
                    
                    for location in rawLocations {
                        if let assignedStops = location.assignedStops {
                            for stop in assignedStops {
                                // Convert AssignedStop to Location for consistent handling
                                let stopLocation = Location(
                                    id: stop.id,
                                    type: stop.type,
                                    name: stop.name,
                                    disassembledName: stop.name, // Use name as disassembledName for stops
                                    coord: stop.coord,
                                    parent: stop.parent,
                                    assignedStops: nil,
                                    properties: stop.properties,
                                    distance: stop.distance,
                                    duration: stop.duration
                                )
                                nearbyStops.append(stopLocation)
                            }
                        }
                    }
                    
                    print("✅ Extracted \(nearbyStops.count) nearby stops from \(rawLocations.count) locations")
                    
                    // Debug: Print the first few stops
                    for (index, stop) in nearbyStops.prefix(3).enumerated() {
                        let distanceText = stop.distance != nil ? "\(stop.distance!)m" : "unknown"
                        print("   Stop \(index + 1): \(stop.name ?? "unknown") (\(distanceText))")
                    }
                    
                    self?.locations = nearbyStops
                } catch {
                    self?.errorMessage = "Fehler beim Verarbeiten der Daten: \(error.localizedDescription)"
                    print("❌ JSON Decoding Error: \(error)")
                    
                    // Debug: Print raw response
                    if let jsonString = String(data: data, encoding: .utf8) {
    
                    }
                }
            }
        }.resume()
    }
    
    func loadDepartures(for location: Location) {
        guard let locationId = extractLocationId(from: location) else {
            print("❌ Departure API: Keine gültige Location ID gefunden für: \(location.name ?? "unknown")")
            print("   Properties: \(String(describing: location.properties))")
            DispatchQueue.main.async {
                self.departureErrorMessage = "Ungültige Haltestellen-ID"
            }
            return
        }
        loadDepartures(locationId: locationId)
    }
    
    func loadDepartures(locationId: String) {
        
        print("🚀 Departure API: Location ID extracted: \(locationId)")
        
        isDeparturesLoading = true
        departureErrorMessage = nil
        
        var components = URLComponents(string: departureMonitorURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "imparedOptionsActive", value: "1"),
            URLQueryItem(name: "itOptionsActive", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "ptOptionsActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "useRealtime", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macromobile_gullivr", value: "true"),
            URLQueryItem(name: "AllowEarlyDepartures", value: "true"),
            URLQueryItem(name: "name_dm", value: locationId),
            URLQueryItem(name: "type_dm", value: "any"),
            URLQueryItem(name: "depSearchType", value: "departurebyline"),
            URLQueryItem(name: "depType", value: "stopEvents"),
            URLQueryItem(name: "canChangeMOT", value: "0"),
            URLQueryItem(name: "includeCompleteStopSeq", value: "1"),
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "maxTimeLoop", value: "1"),
            URLQueryItem(name: "useAllStops", value: "1"),
            URLQueryItem(name: "mode", value: "direct")
        ]
        
        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.departureErrorMessage = "Ungültige URL für Abfahrten"
                self.isDeparturesLoading = false
            }
            return
        }
        
        print("🌐 Departure API URL: \(url.absoluteString)")
        print("   Location ID: '\(locationId)'")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isDeparturesLoading = false
                
                if let error = error {
                    self.departureErrorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.departureErrorMessage = "Keine Abfahrtsdaten erhalten"
                    return
                }
                
                do {
                    let departureResponse = try JSONDecoder().decode(DepartureResponse.self, from: data)
                    let stopEvents = departureResponse.stopEvents ?? []
                    
                    print("✅ Departure API: Successfully decoded response")
                    print("   Stop Events Count: \(stopEvents.count)")
                    print("   Locations Count: \(departureResponse.locations?.count ?? 0)")
                    
                    if let locations = departureResponse.locations {
                        for (index, loc) in locations.enumerated() {
                            print("   Location \(index): \(loc.name ?? "unknown") (ID: \(loc.id ?? "none"))")
                        }
                    }
                    
                    if stopEvents.isEmpty {
                        print("⚠️ No stop events found in API response")
                    } else {
                        for (index, event) in stopEvents.prefix(3).enumerated() {
                            print("   Event \(index): \(event.transportation?.name ?? "unknown") → \(event.transportation?.destination?.name ?? "unknown") at \(event.departureTimePlanned ?? "unknown")")
                        }
                    }
                    
                    self.departures = stopEvents
                    self.departureLocations = departureResponse.locations ?? []
                } catch {
                    self.departureErrorMessage = "Fehler beim Verarbeiten der Abfahrtsdaten: \(error.localizedDescription)"
                    print("❌ Departure JSON Decoding Error: \(error)")
                    
                    // Debug: Print raw response
                    if let jsonString = String(data: data, encoding: .utf8) {
    
                    }
                }
            }
        }.resume()
    }
    
    private func extractLocationId(from location: Location) -> String? {

        
        // Normalize the location ID to use the base station ID
        let normalizedId = location.id.normalizedStationId

        
        return normalizedId.isEmpty ? nil : normalizedId
    }
} 