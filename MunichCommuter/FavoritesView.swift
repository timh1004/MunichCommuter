import SwiftUI
import Foundation

enum FavoritesSortOption {
    case alphabetical
    case distance
}

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var mvvService = MVVService()
    @State private var sortOption: FavoritesSortOption = .alphabetical
    @State private var favoriteDepartures: [String: [StopEvent]] = [:] // locationId -> departures
    @State private var loadingFavorites: Set<String> = [] // locationIds being loaded
    @State private var hasInitializedSort = false
    
    private var sortedFavorites: [FilteredFavorite] {
        // Don't show favorites until initial sort is determined to avoid jumping
        guard hasInitializedSort else { return [] }
        return FavoritesHelper.sortFavorites(favoritesManager.favorites, by: sortOption, locationManager: locationManager)
    }
    
    var body: some View {
        VStack {
            if favoritesManager.favorites.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "star")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
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
                        Text("🔍 Suchen Sie im 'Stationen' Tab nach Haltestellen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("⭐ Tippen Sie auf das Stern-Symbol um sie zu speichern")
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
                    ForEach(Array(sortedFavorites.enumerated()), id: \.1.id) { index, favorite in
                        NavigationLink(destination: DepartureDetailView(
                            locationId: favorite.location.id,
                            locationName: favorite.location.disassembledName ?? favorite.location.name,
                            initialDestinationFilters: favorite.destinationFilters,
                            initialPlatformFilters: favorite.platformFilters,
                            initialTransportTypes: favorite.transportTypeFilters
                        )) {
                            if index < 3 {
                                // First 3 favorites get enhanced view with departures
                                FavoriteWithDeparturesView(
                                    favorite: favorite,
                                    sortOption: sortOption,
                                    locationManager: locationManager,
                                    departures: favoriteDepartures[favorite.location.id] ?? [],
                                    isLoading: loadingFavorites.contains(favorite.location.id)
                                )
                            } else {
                                // Other favorites get normal view
                                FilteredFavoriteRowView(favorite: favorite, sortOption: sortOption, locationManager: locationManager)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    }
                    .onDelete(perform: deleteFavorites)
                }
                .listStyle(PlainListStyle())
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
                }
            }
        }
        .onAppear {
            setupInitialSortOption()
            // Only get location if we already have permission, don't prompt for it
            locationManager.getLocationIfAuthorized()
            // Load departures for first 3 favorites after a short delay to allow sorting
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                await loadFirst3FavoritesDepartures()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            // Auto-switch to distance sorting when permission is granted for the first time
            if (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) {
                locationManager.getLocationIfAuthorized()
                // Only auto-switch if we don't have favorites yet or if sorting was alphabetical
                if favoritesManager.favorites.isEmpty || sortOption == .alphabetical {
                    sortOption = .distance
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
        // Auto-select based on location permission
        if locationManager.hasLocationPermission && locationManager.location != nil {
            sortOption = .distance
        } else {
            sortOption = .alphabetical
        }
        // Mark as initialized to prevent jumping
        hasInitializedSort = true
    }
    
    @MainActor
    private func loadFirst3FavoritesDepartures() async {
        let first3Favorites = getFirst3FavoritesForDepartures()
        
        for favorite in first3Favorites {
            let locationId = favorite.location.id
            
            // Skip if already loading or already loaded
            if loadingFavorites.contains(locationId) || favoriteDepartures[locationId] != nil {
                continue
            }
            
            loadingFavorites.insert(locationId)
            
            // Load departures for this favorite
            Task {
                await loadDeparturesForFavorite(favorite)
            }
        }
    }
    
    @MainActor
    private func loadDeparturesForFavorite(_ favorite: FilteredFavorite) async {
        let locationId = favorite.location.id
        
        // Create a separate MVVService instance for this request to avoid conflicts
        let tempMVVService = MVVService()
        tempMVVService.loadDepartures(locationId: locationId)
        
        // Wait for departures to load
        while tempMVVService.isDeparturesLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // Apply filters and take first 3
        let filteredDepartures = FilteringHelper.getFilteredDepartures(
            departures: tempMVVService.departures,
            destinationFilters: favorite.destinationFilters,
            platformFilters: favorite.platformFilters,
            transportTypeFilters: favorite.transportTypeFilters
        )
        
        // Sortiere Abfahrten nach der geschätzten Abfahrtszeit (mit Verspätung)
        let sortedDepartures = DepartureTimeFormatter.sortDeparturesByEstimatedTime(filteredDepartures)
        
        favoriteDepartures[locationId] = Array(sortedDepartures.prefix(3))
        loadingFavorites.remove(locationId)
    }
    
    private func getFirst3FavoritesForDepartures() -> [FilteredFavorite] {
        // Use the same sorting logic but ensure we have favorites
        guard !favoritesManager.favorites.isEmpty else { return [] }
        
        let sorted = FavoritesHelper.sortFavorites(favoritesManager.favorites, by: sortOption, locationManager: locationManager)
        return Array(sorted.prefix(3))
    }
    
    @MainActor
    private func refreshFavorites() async {
        // Clear existing departures
        favoriteDepartures.removeAll()
        loadingFavorites.removeAll()
        
        // Get the current first 3 favorites (could have changed due to sorting/location)
        let first3Favorites = getFirst3FavoritesForDepartures()
        
        // Load fresh departures for each of the first 3 favorites
        for favorite in first3Favorites {
            let locationId = favorite.location.id
            loadingFavorites.insert(locationId)
            
            // Load departures for this favorite
            Task {
                await loadDeparturesForFavorite(favorite)
            }
        }
    }
    
    // All filtering logic moved to FilteringHelper
}

struct FilteredFavoriteRowView: View {
    let favorite: FilteredFavorite
    let sortOption: FavoritesSortOption
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        HStack {
            // Star Icon
            Image(systemName: favorite.hasFilters ? "star.circle.fill" : "star.fill")
                .frame(width: 24, height: 24)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Haltestelle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack {
                    if let parent = favorite.location.parent?.name,
                       parent != (favorite.location.disassembledName ?? favorite.location.name) {
                        Text(parent)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if let filterText = favorite.filterDisplayText {
                        if let parent = favorite.location.parent?.name,
                           parent != (favorite.location.disassembledName ?? favorite.location.name) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Text(filterText)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Distance Display (always when we have location permission and location)
            if locationManager.hasLocationPermission && locationManager.location != nil,
               let distance = locationManager.distanceFrom(favorite.location.coord ?? []) {
                Text(locationManager.formattedDistance(distance))
                    .font(.system(size: 14, weight: .medium))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Standard favorite info (same as FilteredFavoriteRowView)
            HStack {
                // Star Icon
                Image(systemName: favorite.hasFilters ? "star.circle.fill" : "star.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Haltestelle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        if let parent = favorite.location.parent?.name,
                           parent != (favorite.location.disassembledName ?? favorite.location.name) {
                            Text(parent)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        if let filterText = favorite.filterDisplayText {
                            if let parent = favorite.location.parent?.name,
                               parent != (favorite.location.disassembledName ?? favorite.location.name) {
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Text(filterText)
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Distance Display (always when we have location permission and location)
                if locationManager.hasLocationPermission && locationManager.location != nil,
                   let distance = locationManager.distanceFrom(favorite.location.coord ?? []) {
                    Text(locationManager.formattedDistance(distance))
                        .font(.system(size: 14, weight: .medium))
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
                .padding(.leading, 40) // Align with text above
            } else if departures.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Keine Abfahrten verfügbar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 40) // Align with text above
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(departures.prefix(3)) { departure in
                        CompactDepartureRowView(departure: departure)
                    }
                }
                .padding(.leading, 40) // Align with text above
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct CompactDepartureRowView: View {
    let departure: StopEvent
    @AppStorage("timeDisplayMode") private var timeDisplayModeRaw: String = TimeDisplayMode.relative.rawValue
    
    private var timeDisplayMode: TimeDisplayMode {
        TimeDisplayMode(rawValue: timeDisplayModeRaw) ?? .relative
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Transport Line Badge (compact)
            TransportBadge(departure: departure, size: .compact)
            
            // Destination (truncated)
            Text(departure.transportation?.destination?.name ?? "Unbekanntes Ziel")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Departure time
            Text(DepartureRowStyling.formattedDepartureTime(for: departure, mode: timeDisplayMode))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .secondary)
        }
    }
    
    // All styling logic moved to DepartureRowStyling helper
}

#Preview {
    NavigationView {
        FavoritesView()
    }
} 