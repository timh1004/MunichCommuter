import Foundation
import SwiftUI

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [FilteredFavorite] = []
    
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let favoritesKey = "MunichCommuterFavorites"
    
    private init() {
        setupCloudSync()
        loadFavorites()
    }
    
    private func setupCloudSync() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        
        // Start monitoring
        cloudStore.synchronize()
    }
    
    @objc private func cloudStoreDidChange(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.loadFavorites()
        }
    }
    
    // MARK: - New Methods for Multiple Destination Filters
    
    func addFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        let newFavorite = FilteredFavorite(location: location, destinationFilters: destinationFilters, platformFilters: platformFilters, transportTypeFilters: transportTypeFilters)
        favorites.append(newFavorite)
        saveFavorites()
    }
    
    func isFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) -> Bool {
        let normalizedLocationId = location.id.normalizedStationId
        
        // Normalize the filters for comparison
        let normalizedDestinationFilters = destinationFilters?.isEmpty == true ? nil : destinationFilters?.sorted()
        let normalizedPlatformFilters = platformFilters?.isEmpty == true ? nil : platformFilters?.sorted()
        let normalizedTransportFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters?.sorted()
        
        return favorites.contains { 
            $0.location.id.normalizedStationId == normalizedLocationId && 
            $0.destinationFilters?.sorted() == normalizedDestinationFilters &&
            $0.platformFilters?.sorted() == normalizedPlatformFilters &&
            $0.transportTypeFilters?.sorted() == normalizedTransportFilters
        }
    }
    
    func toggleFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        // Check if this specific combination already exists using normalized IDs
        let normalizedLocationId = location.id.normalizedStationId
        let normalizedDestinationFilters = destinationFilters?.isEmpty == true ? nil : destinationFilters?.sorted()
        let normalizedPlatformFilters = platformFilters?.isEmpty == true ? nil : platformFilters?.sorted()
        let normalizedTransportFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters?.sorted()
        
        let existingFavorite = favorites.first { 
            $0.location.id.normalizedStationId == normalizedLocationId && 
            $0.destinationFilters?.sorted() == normalizedDestinationFilters &&
            $0.platformFilters?.sorted() == normalizedPlatformFilters &&
            $0.transportTypeFilters?.sorted() == normalizedTransportFilters
        }
        
        if let existing = existingFavorite {
            removeFavorite(existing)
        } else {
            addFavorite(location, destinationFilters: destinationFilters, platformFilters: platformFilters, transportTypeFilters: transportTypeFilters)
        }
    }

    // MARK: - Legacy Methods for Backwards Compatibility
    
    func addFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        let destinationFilters = destinationFilter.map { [$0] }
        addFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }
    
    func isFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) -> Bool {
        let destinationFilters = destinationFilter.map { [$0] }
        return isFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }
    
    func toggleFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        let destinationFilters = destinationFilter.map { [$0] }
        toggleFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }
    
    // MARK: - Common Methods
    
    func removeFavorite(_ favorite: FilteredFavorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }
    
    func removeFavorite(_ location: Location) {
        // Remove all favorites for this location using normalized IDs
        let normalizedLocationId = location.id.normalizedStationId
        favorites.removeAll { $0.location.id.normalizedStationId == normalizedLocationId }
        saveFavorites()
    }
    
    func isFavorite(_ location: Location) -> Bool {
        let normalizedLocationId = location.id.normalizedStationId
        return favorites.contains { $0.location.id.normalizedStationId == normalizedLocationId }
    }
    
    func getFavorites(for location: Location) -> [FilteredFavorite] {
        let normalizedLocationId = location.id.normalizedStationId
        return favorites.filter { $0.location.id.normalizedStationId == normalizedLocationId }
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            cloudStore.set(data, forKey: favoritesKey)
            cloudStore.synchronize() // Force sync to iCloud
            print("✅ Favorites saved to iCloud")
        } catch {
            print("❌ Failed to save favorites to iCloud: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = cloudStore.data(forKey: favoritesKey) else {
            print("📱 No favorites found in iCloud")
            return
        }
        
        do {
            let loadedFavorites = try JSONDecoder().decode([FilteredFavorite].self, from: data)
            
            // Only update if different to avoid unnecessary UI updates
            let currentIds = Set(favorites.map(\.id))
            let loadedIds = Set(loadedFavorites.map(\.id))
            if currentIds != loadedIds {
                favorites = loadedFavorites
                print("☁️ Favorites loaded from iCloud: \(favorites.count) items")
            }
        } catch {
            print("❌ Failed to load favorites from iCloud: \(error)")
            // Try to migrate old favorites
            if let legacyData = cloudStore.data(forKey: "MunichCommuterFavorites"),
               let legacyFavorites = try? JSONDecoder().decode([Location].self, from: legacyData) {
                favorites = legacyFavorites.map { location in
                    FilteredFavorite(location: location, destinationFilters: nil, platformFilters: nil, transportTypeFilters: nil)
                }
                saveFavorites() // Migrate to new format
                print("📦 Migrated \(legacyFavorites.count) legacy favorites")
            } else {
                favorites = []
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 