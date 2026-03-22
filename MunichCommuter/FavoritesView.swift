import SwiftUI
import Foundation
import MunichCommuterKit

struct FavoritesView: View {
    /// Erste Wellengröße: diese Anzahl Favoriten (in aktueller Listenreihenfolge) lädt parallel und wird abgeschlossen, bevor die nächste Welle startet — die oberen Zeilen wirken so schneller „fertig“. `0` = alles in einer parallelen Welle (früheres Verhalten).
    /// Sinnvoll als spätere Nutzereinstellung (z. B. 0 / 4 / 8 / „alle auf einmal“), aktuell fest verdrahtet.
    private static let favoritesDeparturePriorityWaveSize = 8
    
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var disruptionService: DisruptionService
    @Environment(\.scenePhase) private var scenePhase
    @State private var sortOption: FavoritesSortOption = .alphabetical
    @State private var favoriteDepartures: [String: [StopEvent]] = [:] // locationId -> departures
    @State private var loadingFavorites: Set<String> = [] // locationIds being loaded
    @State private var hasInitializedSort = false
    @State private var initializedDeparturesAfterLocation = false
    @State private var lastFavoriteRefreshAt: [String: Date] = [:] // locationId -> last refresh timestamp
    
    private var sortedFavorites: [FilteredFavorite] {
        guard hasInitializedSort else { return [] }
        return FavoritesHelper.sortFavorites(favoritesManager.favorites, by: sortOption, locationManager: locationManager)
    }
    
    /// Stable key when favorites are added, removed, or replaced (same count).
    private var favoriteLocationIdsSignature: String {
        favoritesManager.favorites.map(\.location.id).sorted().joined(separator: "|")
    }
    
    var body: some View {
        VStack {
            if favoritesManager.favorites.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "star")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray.opacity(0.5))
                    
                    Text("Keine Favoriten")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Fügen Sie Stationen zu Ihren Favoriten hinzu, um sie hier zu sehen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 8) {
                        Label("Suchen Sie im 'Stationen' Tab nach Haltestellen", systemImage: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Tippen Sie auf das Stern-Symbol um sie zu speichern", systemImage: "star")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                // Favorites List
                List {
                    ForEach(sortedFavorites) { favorite in
                        NavigationLink(destination: DepartureDetailView(
                            locationId: favorite.location.id,
                            locationName: favorite.location.disassembledName ?? favorite.location.name,
                            initialDestinationFilters: favorite.destinationFilters,
                            initialPlatformFilters: favorite.platformFilters,
                            initialTransportTypes: favorite.transportTypeFilters,
                            initialDestinationPlatformFilters: favorite.destinationPlatformFilters,
                            initialSortByArrivalTime: favorite.sortByArrivalTime
                        )) {
                            FavoriteWithDeparturesView(
                                favorite: favorite,
                                sortOption: sortOption,
                                locationManager: locationManager,
                                departures: favoriteDepartures[favorite.location.id] ?? [],
                                isLoading: loadingFavorites.contains(favorite.location.id),
                                disruptedLineNumbers: disruptionService.affectedLineNumbers
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    }
                    .onDelete(perform: deleteFavorites)
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshFavorites()
                }
            }
        }
        .navigationTitle("Favoriten")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !favoritesManager.favorites.isEmpty {
                    Menu {
                        Button {
                            sortOption = .alphabetical
                        } label: {
                            Label("Alphabetisch sortieren", systemImage: sortOption == .alphabetical ? "checkmark" : "textformat.abc")
                        }
                        
                        Button {
                            if !locationManager.hasLocationPermission {
                                locationManager.requestLocationPermission()
                            } else {
                                sortOption = .distance
                            }
                        } label: {
                            Label("Nach Entfernung sortieren", systemImage: sortOption == .distance ? "checkmark" : "location.circle")
                        }
                        .disabled(locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Sortierung ändern")
                }
            }
        }
        .onAppear {
            setupInitialSortOption()
            // Start precise updates if we're using distance sorting, otherwise single shot
            updateLocationTrackingMode()
            // Gate departures until we have an effective location (live or cached), with a short timeout
            Task { @MainActor in
                _ = await locationManager.awaitEffectiveLocation(timeout: 1.0)
                if !initializedDeparturesAfterLocation {
                    initializedDeparturesAfterLocation = true
                    await loadAllFavoritesDepartures()
                }
            }
        }
        .onChange(of: favoriteLocationIdsSignature) { _, _ in
            Task { @MainActor in
                pruneDeparturesForRemovedFavorites()
                await loadAllFavoritesDepartures(onlyIfMissing: true)
            }
        }
        .onDisappear {
            // Stop precise updates when leaving favorites view
            if locationManager.currentTrackingMode == .precise {
                locationManager.requestSingleLocation()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            // Auto-switch to distance sorting when permission is granted for the first time
            if (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) {
                // Only auto-switch if we don't have favorites yet or if sorting was alphabetical
                if favoritesManager.favorites.isEmpty || sortOption == .alphabetical {
                    sortOption = .distance
                }
                updateLocationTrackingMode()
            }
        }
        .onChange(of: sortOption) { _, _ in
            // Update tracking mode when sort option changes
            updateLocationTrackingMode()
        }
        .onChange(of: locationManager.effectiveLocation) { _, _ in
            // Resort when the user moves significantly and reload departures for visible top items
            if sortOption == .distance {
                // Trigger a state update by toggling hasInitializedSort briefly
                hasInitializedSort.toggle()
                hasInitializedSort.toggle()
                Task { @MainActor in
                    await refreshFavorites()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { @MainActor in
                    let stale = sortedFavorites.filter { favorite in
                        let locationId = favorite.location.id
                        let isStale: Bool
                        if let last = lastFavoriteRefreshAt[locationId] {
                            isStale = last.isOlder(thanMinutes: 5)
                        } else {
                            isStale = favoriteDepartures[locationId] == nil
                        }
                        return isStale && !loadingFavorites.contains(locationId)
                    }
                    await loadDeparturesForFavoritesInWaves(stale)
                }
            }
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let favorite = sortedFavorites[index]
            favoritesManager.removeFavorite(favorite)
        }
    }
    
    private func setupInitialSortOption() {
        // Auto-select based on location permission and any effective location (live or cached)
        if locationManager.hasLocationPermission && locationManager.effectiveLocation != nil {
            sortOption = .distance
        } else {
            sortOption = .alphabetical
        }
        // Mark as initialized to prevent jumping
        hasInitializedSort = true
    }
    
    private func updateLocationTrackingMode() {
        // Use precise updates when distance sorting is active and we have permission
        if sortOption == .distance && locationManager.hasLocationPermission {
            locationManager.startPreciseUpdates()
        } else {
            // Use single shot for alphabetical sorting or when no permission
            locationManager.requestSingleLocation()
        }
    }
    
    @MainActor
    private func pruneDeparturesForRemovedFavorites() {
        let validIds = Set(favoritesManager.favorites.map(\.location.id))
        for id in favoriteDepartures.keys where !validIds.contains(id) {
            favoriteDepartures.removeValue(forKey: id)
            lastFavoriteRefreshAt.removeValue(forKey: id)
        }
        loadingFavorites = loadingFavorites.intersection(validIds)
    }
    
    /// Favoriten, die noch Abfahrten brauchen, in **Listenreihenfolge** (Entfernung oder A–Z je nach Sortierung).
    private func favoritesPendingDepartureLoad(onlyIfMissing: Bool) -> [FilteredFavorite] {
        sortedFavorites.filter { favorite in
            let locationId = favorite.location.id
            if onlyIfMissing, favoriteDepartures[locationId] != nil || loadingFavorites.contains(locationId) {
                return false
            }
            return !loadingFavorites.contains(locationId)
        }
    }
    
    /// Lädt eine Liste von Favoriten parallel (`withTaskGroup`). Die **Reihenfolge der `addTask`-Aufrufe** folgt der Liste; fertig werden die Requests trotzdem unterschiedlich schnell (Netzwerk).
    @MainActor
    private func loadFavoritesInParallel(_ favorites: [FilteredFavorite]) async {
        await withTaskGroup(of: Void.self) { group in
            for favorite in favorites {
                let locationId = favorite.location.id
                guard !loadingFavorites.contains(locationId) else { continue }
                loadingFavorites.insert(locationId)
                group.addTask {
                    await self.loadDeparturesForFavorite(favorite)
                }
            }
        }
    }
    
    /// Wie `WatchFavoritesView.loadAllDepartures`, aber optional in Wellen: erst die ersten N in der Liste, dann der Rest — weniger „alles auf einmal“, schnelleres Auffüllen oben.
    @MainActor
    private func loadDeparturesForFavoritesInWaves(_ favorites: [FilteredFavorite]) async {
        let wave = Self.favoritesDeparturePriorityWaveSize
        if wave <= 0 || favorites.count <= wave {
            await loadFavoritesInParallel(favorites)
            return
        }
        await loadFavoritesInParallel(Array(favorites.prefix(wave)))
        await loadFavoritesInParallel(Array(favorites.dropFirst(wave)))
    }
    
    @MainActor
    private func loadAllFavoritesDepartures(onlyIfMissing: Bool = false) async {
        await loadDeparturesForFavoritesInWaves(favoritesPendingDepartureLoad(onlyIfMissing: onlyIfMissing))
    }
    
    @MainActor
    private func loadDeparturesForFavorite(_ favorite: FilteredFavorite) async {
        let locationId = favorite.location.id
        
        let tempMVVService = MVVService()
        await tempMVVService.loadDeparturesAsync(locationId: locationId)
        
        if let departureLocation = tempMVVService.departureLocations.first(where: { $0.id == locationId }),
           let coord = departureLocation.coord {
            favoritesManager.updateCoordinatesIfNeeded(locationId: locationId, coord: coord)
        }
        
        let filteredDepartures = FilteringHelper.getFilteredDepartures(
            departures: tempMVVService.departures,
            destinationFilters: favorite.destinationFilters,
            platformFilters: favorite.platformFilters,
            transportTypeFilters: favorite.transportTypeFilters,
            destinationPlatformFilters: favorite.destinationPlatformFilters
        )
        
        let sortedDepartures: [StopEvent]
        if favorite.sortByArrivalTime == true {
            sortedDepartures = DepartureTimeFormatter.sortDeparturesByArrivalTime(
                filteredDepartures,
                destinations: favorite.destinationFilters
            )
        } else {
            sortedDepartures = DepartureTimeFormatter.sortDeparturesByEstimatedTime(filteredDepartures)
        }
        
        favoriteDepartures[locationId] = Array(sortedDepartures.prefix(3))
        loadingFavorites.remove(locationId)
        lastFavoriteRefreshAt[locationId] = Date()
    }
    
    @MainActor
    private func refreshFavorites() async {
        favoriteDepartures.removeAll()
        loadingFavorites.removeAll()
        lastFavoriteRefreshAt.removeAll()
        await loadAllFavoritesDepartures()
    }
    
    // All filtering logic moved to FilteringHelper
}

struct FilteredFavoriteRowView: View {
    let favorite: FilteredFavorite
    let sortOption: FavoritesSortOption
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Haltestelle")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack {
                    if let parent = favorite.location.parent?.name,
                       parent != (favorite.location.disassembledName ?? favorite.location.name) {
                        Text(parent)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let filterText = favorite.filterDisplayText {
                        if let parent = favorite.location.parent?.name,
                           parent != (favorite.location.disassembledName ?? favorite.location.name) {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(filterText)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Distance Display (always when we have location permission and effective location)
            if locationManager.hasLocationPermission && locationManager.effectiveLocation != nil,
               let distance = locationManager.distanceFrom(favorite.location.coord ?? []) {
                Text(locationManager.formattedDistance(distance))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct FavoriteWithDeparturesView: View {
    let favorite: FilteredFavorite
    let sortOption: FavoritesSortOption
    @ObservedObject var locationManager: LocationManager
    let departures: [StopEvent]
    let isLoading: Bool
    var disruptedLineNumbers: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Standard favorite info (same as FilteredFavoriteRowView)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Haltestelle")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack {
                        if let parent = favorite.location.parent?.name,
                           parent != (favorite.location.disassembledName ?? favorite.location.name) {
                            Text(parent)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let filterText = favorite.filterDisplayText {
                            if let parent = favorite.location.parent?.name,
                               parent != (favorite.location.disassembledName ?? favorite.location.name) {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(filterText)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                // Distance Display (always when we have location permission and effective location)
                if locationManager.hasLocationPermission && locationManager.effectiveLocation != nil,
                   let distance = locationManager.distanceFrom(favorite.location.coord ?? []) {
                    Text(locationManager.formattedDistance(distance))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Compact departures display
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Lade Abfahrten...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 0)
            } else if departures.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Keine Abfahrten verfügbar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 0)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Disruption warning if any displayed line is affected
                    if departures.prefix(3).contains(where: { dep in
                        if let num = dep.transportation?.number {
                            return disruptedLineNumbers.contains(num)
                        }
                        return false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("Störung")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }

                    ForEach(departures.prefix(3)) { departure in
                        CompactDepartureRowView(departure: departure)
                    }
                }
                .padding(.leading, 0)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct CompactDepartureRowView: View {
    let departure: StopEvent
    @AppStorage("timeDisplayMode") private var timeDisplayModeRaw: String = TimeDisplayMode.relative.rawValue
    @State private var now: Date = Date()
    
    private var timeDisplayMode: TimeDisplayMode {
        TimeDisplayMode(rawValue: timeDisplayModeRaw) ?? .relative
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Transport Line Badge (compact)
            TransportBadge(departure: departure, size: .compact)
            
            // Destination (truncated)
            Text(departure.transportation?.destination?.name ?? "Unbekanntes Ziel")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Departure time
            Text(DepartureRowStyling.formattedDepartureTime(for: departure, mode: timeDisplayMode, referenceDate: now))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .secondary)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { current in
            self.now = current
        }
    }
    
    // All styling logic moved to DepartureRowStyling helper
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(DisruptionService())
    }
} 