//
//  FavoritesWatchView.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct FavoritesWatchView: View {
    @StateObject private var favoritesManager = WatchFavoritesManager.shared
    @StateObject private var locationManager = WatchLocationManager.shared
    @StateObject private var mvvService = WatchMVVService()
    
    @State private var sortOption: WatchSortOption = .alphabetical
    @State private var favoriteDepartures: [String: [WatchDeparture]] = [:]
    @State private var loadingFavorites: Set<String> = []
    @State private var selectedFavorite: WatchFavorite?
    @State private var showingSortOptions = false
    @State private var isRefreshing = false
    
    private var sortedFavorites: [WatchFavorite] {
        return favoritesManager.sortedFavorites(by: sortOption, locationManager: locationManager)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if favoritesManager.isLoading {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            FavoriteSkeletonWatch()
                        }
                    }
                } else if sortedFavorites.isEmpty {
                    EmptyStateWatch(
                        icon: "star",
                        title: "Keine Favoriten",
                        subtitle: "Favoriten vom iPhone werden automatisch synchronisiert",
                        action: {
                            favoritesManager.requestFavoritesFromPhone()
                        },
                        actionTitle: "Synchronisieren"
                    )
                } else {
                    List {
                        ForEach(Array(sortedFavorites.enumerated()), id: \.1.id) { index, favorite in
                            NavigationLink(destination: DepartureDetailWatchView(
                                locationId: favorite.location.id,
                                locationName: favorite.location.displayName,
                                favorite: favorite
                            )) {
                                if index < 3 {
                                    // First 3 favorites get enhanced view with departures
                                    FavoriteWithDeparturesWatchView(
                                        favorite: favorite,
                                        departures: favoriteDepartures[favorite.location.id] ?? [],
                                        isLoading: loadingFavorites.contains(favorite.location.id),
                                        sortOption: sortOption,
                                        locationManager: locationManager
                                    )
                                } else {
                                    // Other favorites get compact view
                                    FavoriteRowWatchView(
                                        favorite: favorite,
                                        sortOption: sortOption,
                                        locationManager: locationManager
                                    )
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        if isRefreshing {
                            RefreshIndicatorWatch()
                        }
                        
                        if !sortedFavorites.isEmpty {
                            Button {
                                showingSortOptions = true
                            } label: {
                                Image(systemName: sortOption.icon)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Sortierung", isPresented: $showingSortOptions) {
                Button("Alphabetisch") {
                    sortOption = .alphabetical
                }
                
                Button("Nach Entfernung") {
                    if !locationManager.hasLocationPermission {
                        locationManager.requestLocationPermission()
                    } else {
                        sortOption = .distance
                    }
                }
                .disabled(locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted)
                
                Button("Abbrechen", role: .cancel) { }
            }
        }
        .onAppear {
            setupInitialSortOption()
            locationManager.requestLocationUpdate()
            loadFirst3FavoritesDepartures()
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.requestLocationUpdate()
                if sortedFavorites.isEmpty || sortOption == .alphabetical {
                    sortOption = .distance
                }
            }
        }
        .onChange(of: sortOption) { _, _ in
            // Reload departures when sort option changes (different top 3)
            Task {
                await loadFirst3FavoritesDepartures()
            }
        }
    }
    
    private func setupInitialSortOption() {
        if locationManager.hasLocationPermission && locationManager.location != nil {
            sortOption = .distance
        } else {
            sortOption = .alphabetical
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let favorite = sortedFavorites[index]
                favoritesManager.removeFavorite(favorite)
                
                // Clean up departure data
                favoriteDepartures.removeValue(forKey: favorite.location.id)
                loadingFavorites.remove(favorite.location.id)
            }
        }
    }
    
    @MainActor
    private func loadFirst3FavoritesDepartures() async {
        let first3Favorites = Array(sortedFavorites.prefix(3))
        
        for favorite in first3Favorites {
            let locationId = favorite.location.id
            
            // Skip if already loading
            if loadingFavorites.contains(locationId) {
                continue
            }
            
            loadingFavorites.insert(locationId)
            
            Task {
                await loadDeparturesForFavorite(favorite)
            }
        }
    }
    
    @MainActor
    private func loadDeparturesForFavorite(_ favorite: WatchFavorite) async {
        let locationId = favorite.location.id
        
        defer {
            loadingFavorites.remove(locationId)
        }
        
        // Create a new service instance for this request
        let tempMVVService = WatchMVVService()
        await tempMVVService.loadDepartures(locationId: locationId, limit: 5)
        
        // Apply filters if any
        var filteredDepartures = tempMVVService.departures
        
        // Apply destination filters
        if let destinationFilters = favorite.destinationFilters, !destinationFilters.isEmpty {
            filteredDepartures = filteredDepartures.filter { departure in
                guard let destination = departure.destination else { return false }
                return destinationFilters.contains { filter in
                    destination.localizedCaseInsensitiveContains(filter)
                }
            }
        }
        
        // Apply platform filters
        if let platformFilters = favorite.platformFilters, !platformFilters.isEmpty {
            filteredDepartures = filteredDepartures.filter { departure in
                guard let platform = departure.platform else { return false }
                return platformFilters.contains(platform)
            }
        }
        
        // Apply transport type filters
        if let transportFilters = favorite.transportTypeFilters, !transportFilters.isEmpty {
            filteredDepartures = filteredDepartures.filter { departure in
                guard let transportType = departure.transportType else { return false }
                return transportFilters.contains(transportType.rawValue)
            }
        }
        
        favoriteDepartures[locationId] = Array(filteredDepartures.prefix(3))
    }
    
    @MainActor
    private func refreshFavorites() async {
        isRefreshing = true
        
        // Clear existing departures
        favoriteDepartures.removeAll()
        loadingFavorites.removeAll()
        
        // Clear MVV service cache
        mvvService.clearCache()
        
        // Reload departures for first 3 favorites
        await loadFirst3FavoritesDepartures()
        
        // Request fresh data from iPhone
        favoritesManager.requestFavoritesFromPhone()
        
        isRefreshing = false
    }
}

// MARK: - Favorite Row Views
struct FavoriteRowWatchView: View {
    let favorite: WatchFavorite
    let sortOption: WatchSortOption
    @ObservedObject var locationManager: WatchLocationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Star Icon
            Image(systemName: favorite.hasFilters ? "star.circle.fill" : "star.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(favorite.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let parent = favorite.location.parentName,
                   parent != favorite.location.displayName {
                    Text(parent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Distance
            if sortOption == .distance,
               let distance = locationManager.formattedDistanceFromLocation(favorite.location) {
                Text(distance)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FavoriteWithDeparturesWatchView: View {
    let favorite: WatchFavorite
    let departures: [WatchDeparture]
    let isLoading: Bool
    let sortOption: WatchSortOption
    @ObservedObject var locationManager: WatchLocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Standard favorite info
            HStack(spacing: 8) {
                Image(systemName: favorite.hasFilters ? "star.circle.fill" : "star.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(favorite.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let parent = favorite.location.parentName,
                       parent != favorite.location.displayName {
                        Text(parent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if sortOption == .distance,
                   let distance = locationManager.formattedDistanceFromLocation(favorite.location) {
                    Text(distance)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Compact departures
            if isLoading {
                LoadingIndicatorWatch(text: "Lade...", compact: true)
                    .padding(.leading, 24)
            } else if departures.isEmpty {
                ErrorStateWatch(message: "Keine Abfahrten", compact: true)
                    .padding(.leading, 24)
            } else {
                VStack(spacing: 2) {
                    ForEach(departures.prefix(2)) { departure in
                        CompactDepartureRow(departure: departure)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#if DEBUG
struct FavoritesWatchView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesWatchView()
    }
}
#endif