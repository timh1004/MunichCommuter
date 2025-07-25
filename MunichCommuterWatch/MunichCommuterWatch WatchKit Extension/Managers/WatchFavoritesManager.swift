//
//  WatchFavoritesManager.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import Foundation
import WatchConnectivity

@MainActor
class WatchFavoritesManager: NSObject, ObservableObject {
    static let shared = WatchFavoritesManager()
    
    @Published var favorites: [WatchFavorite] = []
    @Published var isLoading = false
    @Published var syncError: String?
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "WatchFavorites"
    private let groupContainer = "group.com.yourcompany.munichcommuter"
    
    private var watchSession: WCSession? {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }
    
    override init() {
        super.init()
        setupWatchConnectivity()
        loadFavorites()
    }
    
    // MARK: - Watch Connectivity Setup
    private func setupWatchConnectivity() {
        guard let session = watchSession else { return }
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Favorites Management
    func addFavorite(_ location: WatchLocation, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        let newFavorite = WatchFavorite(
            location: location,
            destinationFilters: destinationFilters,
            platformFilters: platformFilters,
            transportTypeFilters: transportTypeFilters
        )
        
        favorites.append(newFavorite)
        saveFavorites()
        sendFavoriteToPhone(newFavorite, action: "add")
    }
    
    func removeFavorite(_ favorite: WatchFavorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
        sendFavoriteToPhone(favorite, action: "remove")
    }
    
    func removeFavorite(locationId: String) {
        let removedFavorites = favorites.filter { $0.location.id == locationId }
        favorites.removeAll { $0.location.id == locationId }
        saveFavorites()
        
        // Notify phone about each removed favorite
        for favorite in removedFavorites {
            sendFavoriteToPhone(favorite, action: "remove")
        }
    }
    
    func isFavorite(_ location: WatchLocation, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) -> Bool {
        return favorites.contains { favorite in
            favorite.location.id == location.id &&
            favorite.destinationFilters?.sorted() == destinationFilters?.sorted() &&
            favorite.platformFilters?.sorted() == platformFilters?.sorted() &&
            favorite.transportTypeFilters?.sorted() == transportTypeFilters?.sorted()
        }
    }
    
    func isFavorite(locationId: String) -> Bool {
        return favorites.contains { $0.location.id == locationId }
    }
    
    func getFavorites(for locationId: String) -> [WatchFavorite] {
        return favorites.filter { $0.location.id == locationId }
    }
    
    func toggleFavorite(_ location: WatchLocation, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        if let existingFavorite = favorites.first(where: { favorite in
            favorite.location.id == location.id &&
            favorite.destinationFilters?.sorted() == destinationFilters?.sorted() &&
            favorite.platformFilters?.sorted() == platformFilters?.sorted() &&
            favorite.transportTypeFilters?.sorted() == transportTypeFilters?.sorted()
        }) {
            removeFavorite(existingFavorite)
        } else {
            addFavorite(location, destinationFilters: destinationFilters, platformFilters: platformFilters, transportTypeFilters: transportTypeFilters)
        }
    }
    
    // MARK: - Sorting
    func sortedFavorites(by option: WatchSortOption, locationManager: WatchLocationManager) -> [WatchFavorite] {
        switch option {
        case .alphabetical:
            return favorites.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .distance:
            guard locationManager.hasLocationPermission, locationManager.location != nil else {
                // Fallback to alphabetical if no location
                return favorites.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            }
            
            return favorites.sorted { favorite1, favorite2 in
                let distance1 = locationManager.distanceFromLocation(favorite1.location) ?? Double.infinity
                let distance2 = locationManager.distanceFromLocation(favorite2.location) ?? Double.infinity
                return distance1 < distance2
            }
        }
    }
    
    // MARK: - Persistence
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            userDefaults.set(data, forKey: favoritesKey)
            
            // Also try to save to group container for iPhone sync
            if let groupDefaults = UserDefaults(suiteName: groupContainer) {
                groupDefaults.set(data, forKey: "WatchFavorites")
                groupDefaults.synchronize()
            }
            
            print("✅ Watch favorites saved: \(favorites.count) items")
        } catch {
            print("❌ Failed to save watch favorites: \(error)")
            syncError = "Favoriten konnten nicht gespeichert werden"
        }
    }
    
    private func loadFavorites() {
        isLoading = true
        
        // Try to load from group container first (iPhone sync)
        var data: Data?
        
        if let groupDefaults = UserDefaults(suiteName: groupContainer),
           let groupData = groupDefaults.data(forKey: "WatchFavorites") {
            data = groupData
        } else {
            // Fallback to local storage
            data = userDefaults.data(forKey: favoritesKey)
        }
        
        guard let data = data else {
            print("📱 No watch favorites found")
            isLoading = false
            return
        }
        
        do {
            let loadedFavorites = try JSONDecoder().decode([WatchFavorite].self, from: data)
            self.favorites = loadedFavorites
            print("☁️ Watch favorites loaded: \(favorites.count) items")
        } catch {
            print("❌ Failed to load watch favorites: \(error)")
            syncError = "Favoriten konnten nicht geladen werden"
            self.favorites = []
        }
        
        isLoading = false
    }
    
    // MARK: - iPhone Sync
    private func sendFavoriteToPhone(_ favorite: WatchFavorite, action: String) {
        guard let session = watchSession, session.isPaired && session.isReachable else {
            print("📱 iPhone not reachable for sync")
            return
        }
        
        do {
            let favoriteData = try JSONEncoder().encode(favorite)
            let message = [
                "type": "favorite_sync",
                "action": action,
                "favorite": favoriteData
            ] as [String: Any]
            
            session.sendMessage(message, replyHandler: { reply in
                print("✅ Favorite sync successful: \(reply)")
            }, errorHandler: { error in
                print("❌ Favorite sync failed: \(error)")
            })
        } catch {
            print("❌ Failed to encode favorite for sync: \(error)")
        }
    }
    
    func requestFavoritesFromPhone() {
        guard let session = watchSession, session.isPaired else { return }
        
        let message = ["type": "request_favorites"]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            if let favoritesData = reply["favorites"] as? Data {
                self?.receiveFavoritesFromPhone(favoritesData)
            }
        }, errorHandler: { error in
            print("❌ Failed to request favorites from phone: \(error)")
        })
    }
    
    private func receiveFavoritesFromPhone(_ data: Data) {
        do {
            let phoneFavorites = try JSONDecoder().decode([WatchFavorite].self, from: data)
            
            // Merge with local favorites (phone favorites take precedence)
            var mergedFavorites = phoneFavorites
            
            // Add any local-only favorites
            for localFavorite in favorites {
                if !phoneFavorites.contains(where: { $0.id == localFavorite.id }) {
                    mergedFavorites.append(localFavorite)
                }
            }
            
            self.favorites = mergedFavorites
            saveFavorites()
            
            print("📱 Received \(phoneFavorites.count) favorites from iPhone")
        } catch {
            print("❌ Failed to decode favorites from iPhone: \(error)")
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        favorites.removeAll()
        userDefaults.removeObject(forKey: favoritesKey)
        
        if let groupDefaults = UserDefaults(suiteName: groupContainer) {
            groupDefaults.removeObject(forKey: "WatchFavorites")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchFavoritesManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ Watch connectivity activation failed: \(error)")
            DispatchQueue.main.async {
                self.syncError = "iPhone-Verbindung fehlgeschlagen"
            }
        } else {
            print("✅ Watch connectivity activated: \(activationState.rawValue)")
            // Request favorites from iPhone when connection is established
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.requestFavoritesFromPhone()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                switch type {
                case "favorites_update":
                    if let favoritesData = message["favorites"] as? Data {
                        self.receiveFavoritesFromPhone(favoritesData)
                    }
                    replyHandler(["status": "received"])
                    
                default:
                    replyHandler(["status": "unknown_type"])
                }
            }
        }
    }
}