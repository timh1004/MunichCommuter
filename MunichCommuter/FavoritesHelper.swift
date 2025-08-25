import Foundation

struct FavoritesHelper {
    static func sortFavorites(_ favorites: [FilteredFavorite],
                              by option: FavoritesSortOption,
                              locationManager: LocationManager) -> [FilteredFavorite] {
        switch option {
        case .alphabetical:
            return favorites.sorted { favorite1, favorite2 in
                let name1 = favorite1.location.disassembledName ?? favorite1.location.name ?? ""
                let name2 = favorite2.location.disassembledName ?? favorite2.location.name ?? ""
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        case .distance:
            guard locationManager.location != nil else {
                return favorites.sorted { favorite1, favorite2 in
                    let name1 = favorite1.location.disassembledName ?? favorite1.location.name ?? ""
                    let name2 = favorite2.location.disassembledName ?? favorite2.location.name ?? ""
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
            }
            return favorites.sorted { favorite1, favorite2 in
                let distance1 = locationManager.distanceFor(location: favorite1.location) ?? Double.infinity
                let distance2 = locationManager.distanceFor(location: favorite2.location) ?? Double.infinity
                return distance1 < distance2
            }
        }
    }
}


