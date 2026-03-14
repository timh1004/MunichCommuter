import SwiftUI
import MunichCommuterKit

struct WatchStationsView: View {
    @StateObject private var mvvService = MVVService()
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var isShowingNearby = false
    @State private var debounceTask: Task<Void, Never>?

    private var sortedLocations: [Location] {
        if isShowingNearby {
            return mvvService.locations.sorted { l1, l2 in
                let d1 = locationManager.distanceFor(location: l1) ?? .infinity
                let d2 = locationManager.distanceFor(location: l2) ?? .infinity
                return d1 < d2
            }
        }
        return mvvService.locations
    }

    private var displayedLocations: [Location] {
        if isShowingNearby {
            return Array(sortedLocations.prefix(8))
        }
        return sortedLocations
    }

    var body: some View {
        List {
            if !isShowingNearby && searchText.isEmpty {
                Section {
                    Button(action: showNearby) {
                        Label("In der Nähe", systemImage: "location.fill")
                    }
                }
            }

            if mvvService.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Suche...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if let error = mvvService.errorMessage {
                Section {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else if !displayedLocations.isEmpty {
                Section(header: Text(isShowingNearby ? "In der Nähe" : "Ergebnisse")) {
                    ForEach(displayedLocations) { location in
                        NavigationLink(destination: WatchDepartureListView(
                            locationId: location.id,
                            locationName: location.disassembledName ?? location.name ?? "Station"
                        )) {
                            WatchLocationRow(
                                location: location,
                                showDistance: isShowingNearby,
                                locationManager: locationManager
                            )
                        }
                    }
                }
            } else if !searchText.isEmpty {
                Section {
                    Text("Keine Ergebnisse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Haltestelle")
        .onChange(of: searchText) { _, newValue in
            debounceTask?.cancel()
            guard newValue.count >= 2 else {
                mvvService.locations = []
                isShowingNearby = false
                return
            }
            isShowingNearby = false
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                mvvService.searchStops(name: newValue)
            }
        }
        .navigationTitle("Suche")
        .onAppear {
            locationManager.requestSingleLocation()
            if locationManager.hasLocationPermission && mvvService.locations.isEmpty && searchText.isEmpty {
                showNearby()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                locationManager.requestSingleLocation()
                if isShowingNearby {
                    showNearby()
                }
            }
        }
    }

    private func showNearby() {
        if !locationManager.hasLocationPermission {
            locationManager.requestLocationPermission()
            return
        }
        guard let coordString = locationManager.coordStringForAPI() else {
            isShowingNearby = true
            return
        }
        isShowingNearby = true
        searchText = ""
        mvvService.searchNearbyStops(coordinate: coordString)
    }
}

struct WatchLocationRow: View {
    let location: Location
    let showDistance: Bool
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(location.disassembledName ?? location.name ?? "Station")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)

            HStack {
                if let parent = location.parent?.name {
                    Text(parent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if showDistance, let distance = locationManager.distanceFor(location: location) {
                    Spacer()
                    Text(locationManager.formattedDistance(distance))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
