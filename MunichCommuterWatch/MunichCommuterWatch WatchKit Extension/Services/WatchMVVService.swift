//
//  WatchMVVService.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import Foundation
import Combine

@MainActor
class WatchMVVService: ObservableObject {
    @Published var departures: [WatchDeparture] = []
    @Published var locations: [WatchLocation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "https://www.mvg.de/api/fib/v2"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Cache for departures (5 minutes)
    private var departureCache: [String: (departures: [WatchDeparture], timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Departures
    func loadDepartures(locationId: String, limit: Int = 10) async {
        // Check cache first
        if let cached = departureCache[locationId],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            self.departures = Array(cached.departures.prefix(limit))
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let url = URL(string: "\(baseURL)/departure/\(locationId)?limit=\(limit)")!
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("de", forHTTPHeaderField: "Accept-Language")
            
            let (data, _) = try await session.data(for: request)
            
            // Parse response using the watch models
            let response = try JSONDecoder().decode(WatchDepartureResponse.self, from: data)
            
            let watchDepartures = response.stopEvents?.compactMap { stopEvent in
                WatchDeparture(from: stopEvent)
            } ?? []
            
            // Cache the results
            departureCache[locationId] = (departures: watchDepartures, timestamp: Date())
            
            self.departures = Array(watchDepartures.prefix(limit))
            
        } catch {
            self.error = "Abfahrten konnten nicht geladen werden: \(error.localizedDescription)"
            print("❌ Departure loading error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Location Search
    func searchLocations(query: String, limit: Int = 10) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.locations = []
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let url = URL(string: "\(baseURL)/location?query=\(encodedQuery)&limit=\(limit)")!
            
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("de", forHTTPHeaderField: "Accept-Language")
            
            let (data, _) = try await session.data(for: request)
            
            // Parse response using the watch models
            let response = try JSONDecoder().decode(WatchMVVResponse.self, from: data)
            
            let watchLocations = response.locations?.compactMap { location in
                WatchLocation(from: location)
            } ?? []
            
            self.locations = watchLocations
            
        } catch {
            self.error = "Stationen konnten nicht gefunden werden: \(error.localizedDescription)"
            print("❌ Location search error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Nearby Locations
    func loadNearbyLocations(coordinate: [Double], limit: Int = 10) async {
        guard coordinate.count >= 2 else { return }
        
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Format: longitude:latitude:WGS84[DD.ddddd]
            let coordString = "\(coordinate[1]):\(coordinate[0]):WGS84[DD.ddddd]"
            let encodedCoord = coordString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            let url = URL(string: "\(baseURL)/location?coord=\(encodedCoord)&limit=\(limit)")!
            
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("de", forHTTPHeaderField: "Accept-Language")
            
            let (data, _) = try await session.data(for: request)
            
            // Parse response using the watch models
            let response = try JSONDecoder().decode(WatchMVVResponse.self, from: data)
            
            let watchLocations = response.locations?.compactMap { location in
                WatchLocation(from: location)
            } ?? []
            
            self.locations = watchLocations
            
        } catch {
            self.error = "Stationen in der Nähe konnten nicht gefunden werden: \(error.localizedDescription)"
            print("❌ Nearby locations error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func clearCache() {
        departureCache.removeAll()
    }
    
    func clearResults() {
        departures = []
        locations = []
        error = nil
    }
    
    private func handleHTTPError(_ response: HTTPURLResponse) -> Error? {
        guard 200...299 ~= response.statusCode else {
            return NSError(domain: "MVVService", code: response.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP Error \(response.statusCode)"
            ])
        }
        return nil
    }
}