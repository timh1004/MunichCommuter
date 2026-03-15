import Foundation
import SwiftUI

@MainActor
public class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()

    @Published public var favorites: [FilteredFavorite] = []

    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let favoritesKey = "MunichCommuterFavorites"

    private init() {
        setupCloudSync()
        loadFavorites()
    }

    private func setupCloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        cloudStore.synchronize()
    }

    @objc private func cloudStoreDidChange(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.loadFavorites()
        }
    }

    // MARK: - Multiple Destination Filters

    public func addFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        // Prevent duplicates
        guard !isFavorite(location, destinationFilters: destinationFilters, platformFilters: platformFilters, transportTypeFilters: transportTypeFilters) else { return }
        let newFavorite = FilteredFavorite(location: location, destinationFilters: destinationFilters, platformFilters: platformFilters, transportTypeFilters: transportTypeFilters)
        favorites.append(newFavorite)
        saveFavorites()
    }

    public func isFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) -> Bool {
        let normalizedLocationId = location.id.normalizedStationId
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

    public func toggleFavorite(_ location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
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

    // MARK: - Legacy Methods

    public func addFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        let destinationFilters = destinationFilter.map { [$0] }
        addFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }

    public func isFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) -> Bool {
        let destinationFilters = destinationFilter.map { [$0] }
        return isFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }

    public func toggleFavorite(_ location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        let destinationFilters = destinationFilter.map { [$0] }
        toggleFavorite(location, destinationFilters: destinationFilters, platformFilters: nil, transportTypeFilters: transportTypeFilters)
    }

    // MARK: - Common Methods

    public func removeFavorite(_ favorite: FilteredFavorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    public func removeFavorite(_ location: Location) {
        let normalizedLocationId = location.id.normalizedStationId
        favorites.removeAll { $0.location.id.normalizedStationId == normalizedLocationId }
        saveFavorites()
    }

    public func isFavorite(_ location: Location) -> Bool {
        let normalizedLocationId = location.id.normalizedStationId
        return favorites.contains { $0.location.id.normalizedStationId == normalizedLocationId }
    }

    public func updateCoordinatesIfNeeded(locationId: String, coord: [Double]) {
        let normalizedId = locationId.normalizedStationId
        var didUpdate = false
        for i in favorites.indices {
            if favorites[i].location.id.normalizedStationId == normalizedId,
               favorites[i].location.coord == nil {
                let old = favorites[i].location
                let updated = Location(
                    id: old.id,
                    type: old.type,
                    name: old.name,
                    disassembledName: old.disassembledName,
                    coord: coord,
                    parent: old.parent,
                    assignedStops: old.assignedStops,
                    properties: old.properties,
                    distance: old.distance,
                    duration: old.duration
                )
                favorites[i] = FilteredFavorite(
                    id: favorites[i].id,
                    location: updated,
                    destinationFilters: favorites[i].destinationFilters,
                    platformFilters: favorites[i].platformFilters,
                    transportTypeFilters: favorites[i].transportTypeFilters,
                    dateCreated: favorites[i].dateCreated
                )
                didUpdate = true
            }
        }
        if didUpdate {
            saveFavorites()
        }
    }

    public func getFavorites(for location: Location) -> [FilteredFavorite] {
        let normalizedLocationId = location.id.normalizedStationId
        return favorites.filter { $0.location.id.normalizedStationId == normalizedLocationId }
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            cloudStore.set(data, forKey: favoritesKey)
            cloudStore.synchronize()
        } catch {
            print("Failed to save favorites to iCloud: \(error)")
        }
    }

    private func loadFavorites() {
        guard let data = cloudStore.data(forKey: favoritesKey) else {
            return
        }

        do {
            let loadedFavorites = try JSONDecoder().decode([FilteredFavorite].self, from: data)
            let currentIds = Set(favorites.map(\.id))
            let loadedIds = Set(loadedFavorites.map(\.id))
            if currentIds != loadedIds {
                favorites = loadedFavorites
            }
        } catch {
            if let legacyData = cloudStore.data(forKey: "MunichCommuterFavorites"),
               let legacyFavorites = try? JSONDecoder().decode([Location].self, from: legacyData) {
                favorites = legacyFavorites.map { location in
                    FilteredFavorite(location: location, destinationFilters: nil, platformFilters: nil, transportTypeFilters: nil)
                }
                saveFavorites()
            } else {
                favorites = []
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
