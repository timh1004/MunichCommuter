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
        DispatchQueue.main.async {
            self.loadFavorites()
        }
    }
    
    func addFavorite(_ location: Location, destinationFilter: String? = nil) {
        let newFavorite = FilteredFavorite(location: location, destinationFilter: destinationFilter)
        favorites.append(newFavorite)
        saveFavorites()
    }
    
    func removeFavorite(_ favorite: FilteredFavorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }
    
    func removeFavorite(_ location: Location) {
        // Remove all favorites for this location
        favorites.removeAll { $0.location.id == location.id }
        saveFavorites()
    }
    
    func isFavorite(_ location: Location) -> Bool {
        return favorites.contains { $0.location.id == location.id }
    }
    
    func getFavorites(for location: Location) -> [FilteredFavorite] {
        return favorites.filter { $0.location.id == location.id }
    }
    
    func toggleFavorite(_ location: Location, destinationFilter: String? = nil) {
        // Check if this specific combination already exists
        let existingFavorite = favorites.first { 
            $0.location.id == location.id && $0.destinationFilter == destinationFilter 
        }
        
        if let existing = existingFavorite {
            removeFavorite(existing)
        } else {
            addFavorite(location, destinationFilter: destinationFilter)
        }
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
            if loadedFavorites.map(\.id) != favorites.map(\.id) {
                favorites = loadedFavorites
                print("☁️ Favorites loaded from iCloud: \(favorites.count) items")
            }
        } catch {
            print("❌ Failed to load favorites from iCloud: \(error)")
            // Try to migrate old favorites
            if let legacyData = cloudStore.data(forKey: "MunichCommuterFavorites"),
               let legacyFavorites = try? JSONDecoder().decode([Location].self, from: legacyData) {
                favorites = legacyFavorites.map { FilteredFavorite(location: $0) }
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