import SwiftUI
import Combine
import CoreLocation
import MunichCommuterKit

struct StationsView: View {
    @Binding var activateSearch: Bool

    @StateObject private var mvvService = MVVService()
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var searchIsPresented = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var isShowingNearbyStations = false

    private var sortedLocations: [Location] {
        if isShowingNearbyStations {
            return mvvService.locations.sorted { location1, location2 in
                let distance1 = getLocationDistance(location1)
                let distance2 = getLocationDistance(location2)
                return distance1 < distance2
            }
        } else {
            return mvvService.locations
        }
    }

    private func getLocationDistance(_ location: Location) -> Double {
        return locationManager.distanceFor(location: location) ?? Double.infinity
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                nearbyStationsButtonSection
                locationErrorSection
                contentSection
            }
        }
        .searchable(text: $searchText, isPresented: $searchIsPresented, prompt: "Haltestelle suchen...")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onChange(of: activateSearch) { _, shouldActivate in
            if shouldActivate {
                searchIsPresented = true
                activateSearch = false
            }
        }
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchText) { _, newValue in
            debounceTask?.cancel()
            guard newValue.count >= 2 else {
                if newValue.isEmpty {
                    mvvService.locations = []
                    isShowingNearbyStations = false
                }
                return
            }
            isShowingNearbyStations = false
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                performSearch()
            }
        }
        .navigationTitle("Stationen")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if locationManager.hasLocationPermission {
                locationManager.startPreciseUpdates()
            }

            // Auto-load nearby stations if we have permission and effective location
            if locationManager.hasLocationPermission && locationManager.effectiveLocation != nil && searchText.isEmpty && mvvService.locations.isEmpty {
                showNearbyStations()
            }
        }
        .onChange(of: locationManager.effectiveLocation) { _, newLocation in
            // If user requested nearby stations but location wasn't available before
            if isShowingNearbyStations && newLocation != nil && mvvService.locations.isEmpty {
                if let coordString = locationManager.coordStringForAPI() {
                    mvvService.searchNearbyStops(coordinate: coordString)
                }
            }

            // Auto-load nearby stations if we just got location and no search is active
            if newLocation != nil && searchText.isEmpty && mvvService.locations.isEmpty && !isShowingNearbyStations {
                showNearbyStations()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            // Auto-load nearby stations when permission is granted
            if (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) && searchText.isEmpty && mvvService.locations.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    locationManager.getLocationIfAuthorized()
                }
            }
        }
    }

    // MARK: - View Sections

    private var nearbyStationsButtonSection: some View {
        Group {
            // Nearby Stations Button
            if !isShowingNearbyStations && searchText.isEmpty {
                Button(action: showNearbyStations) {
                    HStack {
                        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                            Image(systemName: "location.slash")
                                .foregroundColor(.white)
                        } else if mvvService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "location.circle")
                                .foregroundColor(.white)
                        }

                        Text(nearbyButtonText)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(nearbyButtonColor)
                    .cornerRadius(12)
                }
                .disabled(locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var nearbyButtonText: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Standortzugriff verweigert"
        case .notDetermined:
            return "Stationen in der Umgebung anzeigen"
        default:
            return "Stationen in der Umgebung"
        }
    }

    private var nearbyButtonColor: Color {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return .gray
        default:
            return .blue
        }
    }

    private var locationErrorSection: some View {
        Group {
            // Location Error Message
            if let locationError = locationManager.locationError {
                VStack {
                    Label(locationError, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        // Content Area
        if mvvService.isLoading {
            Spacer()
            ProgressView("Suche Haltestellen...")
            Spacer()
        } else if let errorMessage = mvvService.errorMessage {
            Spacer()
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Fehler")
                    .font(.headline)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Erneut versuchen") {
                    mvvService.searchStops(name: searchText)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        } else if mvvService.locations.isEmpty {
            emptyStateSection
        } else {
            resultsListSection
        }
    }

    private var emptyStateSection: some View {
        Group {
            if searchText.isEmpty && !isShowingNearbyStations {
                ScrollView {
                    VStack(spacing: 24) {
                        // Search hint
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray.opacity(0.5))

                            Text("Haltestelle suchen")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text("Geben Sie den Namen einer Haltestelle ein oder nutzen Sie die Umgebungssuche")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 16)

                        // Plans Section
                        PlansCompactSection()
                    }
                }
            } else if isShowingNearbyStations {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "location.circle")
                        .font(.largeTitle)
                        .foregroundColor(.blue)

                    Text("Keine Haltestellen in der Nähe")
                        .font(.headline)

                    Text("Es wurden keine Haltestellen in Ihrer Umgebung gefunden")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("Keine Haltestellen gefunden")
                        .font(.headline)

                    Text("Versuchen Sie eine andere Suche")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    /// Bei Umgebungssuche nur die nächsten 5 Stationen, bei Suche alle.
    private var displayedLocations: [Location] {
        if isShowingNearbyStations {
            return Array(sortedLocations.prefix(5))
        }
        return sortedLocations
    }

    private var resultsListSection: some View {
        let netzplaene = MVGPlansData.networkPlans.filter { $0.category == .netzplaene }
        return List {
            Section {
                ForEach(displayedLocations) { location in
                    NavigationLink(destination: DepartureDetailView(locationId: location.id, locationName: location.disassembledName ?? location.name)) {
                        LocationRowView(location: location, showDistance: isShowingNearbyStations)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
            } header: {
                Text(isShowingNearbyStations ? "Nahegelegene Haltestellen" : "Suchergebnisse")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .textCase(nil)
            }
            Section {
                ForEach(netzplaene) { plan in
                    NavigationLink(destination: PDFViewerView(title: plan.name, url: plan.url)) {
                        PlanCardLabel(plan: plan, showChevron: false)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .listRowSeparator(.visible)
                }
                NavigationLink(destination: PlansOverviewView()) {
                    MorePlansCard(showChevron: false)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            } header: {
                Text("Pläne & Netzpläne")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Search Functions

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isShowingNearbyStations = false
        mvvService.searchStops(name: searchText)
    }

    private func showNearbyStations() {
        // Explicitly request location permission if not granted
        if !locationManager.hasLocationPermission {
            locationManager.requestLocationPermission()
            return
        }

        if locationManager.effectiveLocation == nil {
            locationManager.startPreciseUpdates()
        }

        guard let coordString = locationManager.coordStringForAPI() else {
            // Location is being fetched, the onChange handler will trigger the search
            isShowingNearbyStations = true
            searchText = ""
            return
        }

        isShowingNearbyStations = true
        searchText = ""
        mvvService.searchNearbyStops(coordinate: coordString)
    }
}

struct LocationRowView: View {
    let location: Location
    let showDistance: Bool
    @ObservedObject private var locationManager = LocationManager.shared

    init(location: Location, showDistance: Bool = false) {
        self.location = location
        self.showDistance = showDistance
    }

    var body: some View {
        HStack {
            // Location Type Icon
            Image(systemName: locationIcon)
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(locationDisplayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let parent = location.parent?.name {
                    Text(parent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Distance Display
            if showDistance {
                // Use API distance if available (for nearby stops), otherwise calculate distance
                if let distance = locationManager.distanceFor(location: location) {
                    Text(locationManager.formattedDistance(distance))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var locationDisplayName: String {
        // Use the proper disassembled name from API - no manual string manipulation needed!
        return location.disassembledName ?? location.name ?? "Unbekannte Haltestelle"
    }

    private var locationIcon: String {
        switch location.type {
        case "stop":
            return "tram.circle"
        case "poi":
            return "mappin.circle"
        default:
            return "location.circle"
        }
    }
}

#Preview {
    NavigationStack {
        StationsView(activateSearch: .constant(false))
    }
}
