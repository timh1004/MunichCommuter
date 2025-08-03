//
//  StationSearchWatchView.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct StationSearchWatchView: View {
    @StateObject private var mvvService = WatchMVVService()
    @StateObject private var locationManager = WatchLocationManager.shared
    @StateObject private var favoritesManager = WatchFavoritesManager.shared
    
    @State private var searchText = ""
    @State private var showingNearbyStations = false
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar (simplified for Watch)
                SearchBarWatch(text: $searchText, isSearching: $isSearching)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                
                // Content
                Group {
                    if isSearching {
                        LoadingIndicatorWatch(text: "Suche...")
                    } else if searchText.isEmpty {
                        // Show nearby stations or suggestions
                        NearbyStationsWatchView(
                            mvvService: mvvService,
                            locationManager: locationManager,
                            showingNearbyStations: $showingNearbyStations
                        )
                    } else if mvvService.locations.isEmpty && !mvvService.isLoading {
                        EmptyStateWatch(
                            icon: "magnifyingglass",
                            title: "Keine Stationen gefunden",
                            subtitle: "Versuchen Sie einen anderen Suchbegriff"
                        )
                    } else {
                        // Search results
                        List {
                            ForEach(mvvService.locations) { location in
                                NavigationLink(destination: DepartureDetailWatchView(
                                    locationId: location.id,
                                    locationName: location.displayName,
                                    favorite: nil
                                )) {
                                    StationRowWatchView(
                                        location: location,
                                        locationManager: locationManager,
                                        favoritesManager: favoritesManager
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Stationen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNearbyStations()
                    } label: {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(locationManager.hasLocationPermission ? .blue : .gray)
                    }
                    .disabled(!locationManager.hasLocationPermission)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchStations(query: newValue)
        }
        .onAppear {
            // Auto-show nearby stations if location is available
            if locationManager.hasLocationPermission && locationManager.location != nil && !showingNearbyStations {
                showNearbyStations()
            }
        }
    }
    
    private func searchStations(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            mvvService.clearResults()
            return
        }
        
        isSearching = true
        showingNearbyStations = false
        
        Task {
            await mvvService.searchLocations(query: query, limit: 10)
            DispatchQueue.main.async {
                isSearching = false
            }
        }
    }
    
    private func showNearbyStations() {
        guard locationManager.hasLocationPermission else {
            locationManager.requestLocationPermission()
            return
        }
        
        guard let coordinate = locationManager.coordinateForAPI else {
            locationManager.requestLocationUpdate()
            return
        }
        
        searchText = ""
        mvvService.clearResults()
        showingNearbyStations = true
        
        Task {
            await mvvService.loadNearbyLocations(coordinate: coordinate, limit: 10)
        }
    }
}

// MARK: - Search Bar for Watch
struct SearchBarWatch: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    @State private var showingTextInput = false
    
    var body: some View {
        Button {
            showingTextInput = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(text.isEmpty ? "Station suchen..." : text)
                    .font(.caption)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingTextInput) {
            TextInputWatchView(text: $text, prompt: "Station suchen...")
        }
    }
}

// MARK: - Text Input for Watch
struct TextInputWatchView: View {
    @Binding var text: String
    let prompt: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text(prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                // Use dictation or text input
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                
                Spacer()
                
                Button("Fertig") {
                    dismiss()
                }
                .font(.caption)
                .padding()
            }
            .padding()
            .navigationTitle("Eingabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .font(.caption)
                }
            }
        }
    }
}

// MARK: - Nearby Stations View
struct NearbyStationsWatchView: View {
    @ObservedObject var mvvService: WatchMVVService
    @ObservedObject var locationManager: WatchLocationManager
    @Binding var showingNearbyStations: Bool
    
    var body: some View {
        Group {
            if showingNearbyStations {
                if mvvService.isLoading {
                    LoadingIndicatorWatch(text: "Lade Stationen in der Nähe...")
                } else if mvvService.locations.isEmpty {
                    EmptyStateWatch(
                        icon: "location.slash",
                        title: "Keine Stationen gefunden",
                        subtitle: "Keine Stationen in der Nähe gefunden",
                        action: {
                            locationManager.requestLocationUpdate()
                        },
                        actionTitle: "Standort aktualisieren"
                    )
                } else {
                    List {
                        Section("Stationen in der Nähe") {
                            ForEach(mvvService.locations) { location in
                                NavigationLink(destination: DepartureDetailWatchView(
                                    locationId: location.id,
                                    locationName: location.displayName,
                                    favorite: nil
                                )) {
                                    StationRowWatchView(
                                        location: location,
                                        locationManager: locationManager,
                                        favoritesManager: WatchFavoritesManager.shared
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                // Default suggestions or quick access
                VStack(spacing: 16) {
                    EmptyStateWatch(
                        icon: "magnifyingglass",
                        title: "Stationen suchen",
                        subtitle: "Geben Sie den Namen einer Station ein oder verwenden Sie Ihren Standort"
                    )
                    
                    if locationManager.hasLocationPermission {
                        Button {
                            showingNearbyStations = true
                            if let coordinate = locationManager.coordinateForAPI {
                                Task {
                                    await mvvService.loadNearbyLocations(coordinate: coordinate)
                                }
                            } else {
                                locationManager.requestLocationUpdate()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Stationen in der Nähe")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            locationManager.requestLocationPermission()
                        } label: {
                            HStack {
                                Image(systemName: "location")
                                Text("Standort aktivieren")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

// MARK: - Station Row for Watch
struct StationRowWatchView: View {
    let location: WatchLocation
    @ObservedObject var locationManager: WatchLocationManager
    @ObservedObject var favoritesManager: WatchFavoritesManager
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(location.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let parent = location.parentName,
                   parent != location.displayName {
                    Text(parent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                // Distance
                if let distance = locationManager.formattedDistanceFromLocation(location) {
                    Text(distance)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Favorite indicator
                if favoritesManager.isFavorite(locationId: location.id) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#if DEBUG
struct StationSearchWatchView_Previews: PreviewProvider {
    static var previews: some View {
        StationSearchWatchView()
    }
}
#endif