import SwiftUI
import MunichCommuterKit

struct WatchFavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var favoriteDepartures: [String: [StopEvent]] = [:]
    @State private var loadingFavorites: Set<String> = []
    @State private var hasInitialLoad = false
    @State private var lastRefreshAt: Date?

    private var sortedFavorites: [FilteredFavorite] {
        FavoritesHelper.sortFavorites(
            favoritesManager.favorites,
            by: locationManager.effectiveLocation != nil ? .distance : .alphabetical,
            locationManager: locationManager
        )
    }

    var body: some View {
        Group {
            if favoritesManager.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .navigationTitle("Favoriten")
        .onAppear {
            locationManager.requestSingleLocation()
            if !hasInitialLoad {
                hasInitialLoad = true
                Task {
                    _ = await locationManager.awaitEffectiveLocation(timeout: 1.5)
                    await loadAllDepartures()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let isStale = lastRefreshAt?.isOlder(thanMinutes: 2) ?? true
                if isStale && !favoritesManager.favorites.isEmpty {
                    Task {
                        await loadAllDepartures()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundColor(.gray)

            Text("Keine Favoriten")
                .font(.headline)

            Text("Favoriten auf dem iPhone hinzufügen")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var favoritesList: some View {
        List {
            ForEach(sortedFavorites) { favorite in
                NavigationLink(destination: WatchDepartureListView(
                    locationId: favorite.location.id,
                    locationName: favorite.location.disassembledName ?? favorite.location.name ?? "Station",
                    destinationFilters: favorite.destinationFilters,
                    platformFilters: favorite.platformFilters,
                    transportTypeFilters: favorite.transportTypeFilters
                )) {
                    WatchFavoriteRow(
                        favorite: favorite,
                        departures: favoriteDepartures[favorite.location.id] ?? [],
                        isLoading: loadingFavorites.contains(favorite.location.id),
                        locationManager: locationManager
                    )
                }
            }
        }
        .refreshable {
            await loadAllDepartures()
        }
    }

    @MainActor
    private func loadAllDepartures() async {
        lastRefreshAt = Date()
        for favorite in sortedFavorites {
            let locationId = favorite.location.id
            guard !loadingFavorites.contains(locationId) else { continue }
            loadingFavorites.insert(locationId)
            Task {
                await loadDeparturesForFavorite(favorite)
            }
        }
    }

    @MainActor
    private func loadDeparturesForFavorite(_ favorite: FilteredFavorite) async {
        let locationId = favorite.location.id
        let service = MVVService()
        service.loadDepartures(locationId: locationId)

        while service.isDeparturesLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let filtered = FilteringHelper.getFilteredDepartures(
            departures: service.departures,
            destinationFilters: favorite.destinationFilters,
            platformFilters: favorite.platformFilters,
            transportTypeFilters: favorite.transportTypeFilters
        )
        let sorted = DepartureTimeFormatter.sortDeparturesByEstimatedTime(filtered)
        favoriteDepartures[locationId] = Array(sorted.prefix(3))
        loadingFavorites.remove(locationId)
    }
}

struct WatchFavoriteRow: View {
    let favorite: FilteredFavorite
    let departures: [StopEvent]
    let isLoading: Bool
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(favorite.location.disassembledName ?? favorite.location.name ?? "Station")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                if let distance = locationManager.distanceFor(location: favorite.location) {
                    Text(locationManager.formattedDistance(distance))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let filterText = favorite.filterDisplayText {
                Text(filterText)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if departures.isEmpty {
                Text("Keine Abfahrten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(departures.prefix(3)) { departure in
                    WatchCompactDepartureRow(departure: departure)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
