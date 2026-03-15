import Foundation
import CoreLocation

private let favoritesKey = "MunichCommuterFavorites"

/// Reads favorites directly from iCloud Key-Value Store.
/// Actor-free, safe to call from WidgetKit TimelineProviders.
public func loadFavoritesFromCloudStore() -> [FilteredFavorite] {
    guard let data = NSUbiquitousKeyValueStore.default.data(forKey: favoritesKey) else {
        return []
    }
    return (try? JSONDecoder().decode([FilteredFavorite].self, from: data)) ?? []
}

/// Returns the favorite closest to the given coordinate.
/// `minimumDeltaMeters`: a second favorite must be at least this much closer
/// to replace the first one — prevents jitter between nearby stations.
public func nearestFavorite(
    to coord: [Double],
    among favorites: [FilteredFavorite],
    minimumDeltaMeters: Double = 300
) -> FilteredFavorite? {
    guard coord.count >= 2 else { return favorites.first }
    let reference = CLLocation(latitude: coord[0], longitude: coord[1])

    var best: FilteredFavorite?
    var bestDistance: CLLocationDistance = .greatestFiniteMagnitude

    for favorite in favorites {
        guard let favCoord = favorite.location.coord, favCoord.count >= 2 else { continue }
        let favLocation = CLLocation(latitude: favCoord[0], longitude: favCoord[1])
        let distance = reference.distance(from: favLocation)
        if distance < bestDistance - minimumDeltaMeters {
            bestDistance = distance
            best = favorite
        }
    }

    return best ?? favorites.first
}
