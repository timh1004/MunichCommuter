import Foundation
import SwiftUI

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [Location] = []
    
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
    
    func addFavorite(_ location: Location) {
        // Check if already exists
        if !favorites.contains(where: { $0.id == location.id }) {
            favorites.append(location)
            saveFavorites()
        }
    }
    
    func removeFavorite(_ location: Location) {
        favorites.removeAll { $0.id == location.id }
        saveFavorites()
    }
    
    func isFavorite(_ location: Location) -> Bool {
        return favorites.contains { $0.id == location.id }
    }
    
    func toggleFavorite(_ location: Location) {
        if isFavorite(location) {
            removeFavorite(location)
        } else {
            addFavorite(location)
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
            let loadedFavorites = try JSONDecoder().decode([Location].self, from: data)
            
            // Only update if different to avoid unnecessary UI updates
            if loadedFavorites.map(\.id) != favorites.map(\.id) {
                favorites = loadedFavorites
                print("☁️ Favorites loaded from iCloud: \(favorites.count) items")
            }
        } catch {
            print("❌ Failed to load favorites from iCloud: \(error)")
            favorites = []
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 