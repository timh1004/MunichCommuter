import SwiftUI
import Combine
import CoreLocation

struct StationsView: View {
    @StateObject private var mvvService = MVVService()
    @StateObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var debounceTimer: Timer?
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
        if let apiDist = location.distance {
            return Double(apiDist)
        } else {
            return locationManager.distanceFrom(location.coord ?? []) ?? Double.infinity
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarSection
            nearbyStationsButtonSection
            locationErrorSection
            contentSection
        }
        .navigationTitle(isShowingNearbyStations ? "Nahegelegene Stationen" : "Stationen")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Only get location if we already have permission, don't prompt for it
            locationManager.getLocationIfAuthorized()
            
            // Auto-load nearby stations if we have permission and location
            if locationManager.hasLocationPermission && locationManager.location != nil && searchText.isEmpty && mvvService.locations.isEmpty {
                showNearbyStations()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
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
    
    private var searchBarSection: some View {
        // Enhanced Search Bar with Auto-search and Clear Button
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Haltestelle suchen...", text: $searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { _, newValue in
                        startDebounceTimer(for: newValue)
                    }
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isShowingNearbyStations = false
                        mvvService.locations = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
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
                    Text("📍 \(locationError)")
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
        VStack(spacing: 16) {
            Spacer()
            if searchText.isEmpty && !isShowingNearbyStations {
                // Initial state - no search performed yet
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("Haltestelle suchen")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("Geben Sie den Namen einer Haltestelle ein")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("oder nutzen Sie den Button unten für Stationen in der Umgebung")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if isShowingNearbyStations {
                // Showing nearby stations but no results
                Image(systemName: "location.circle")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("Keine Haltestellen in der Nähe")
                    .font(.headline)
                
                Text("Es wurden keine Haltestellen in Ihrer Umgebung gefunden")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                // Search performed but no results found
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                
                Text("Keine Haltestellen gefunden")
                    .font(.headline)
                
                Text("Versuchen Sie eine andere Suche")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var resultsListSection: some View {
        // Results List
        List(sortedLocations) { location in
            NavigationLink(destination: DepartureDetailView(locationId: location.id, locationName: location.disassembledName ?? location.name, initialFilters: nil, initialTransportTypes: nil)) {
                LocationRowView(location: location, showDistance: isShowingNearbyStations)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Search Functions
    private func startDebounceTimer(for searchText: String) {
        // Cancel existing timer
        debounceTimer?.invalidate()
        
        // Don't search for very short queries
        guard searchText.count >= 2 else {
            mvvService.locations = []
            isShowingNearbyStations = false
            return
        }
        
        // Start new timer with 0.5 second delay
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            performSearch()
        }
    }
    
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
        
        // If we have permission but no location yet, try to get it
        if locationManager.location == nil {
            locationManager.getLocationIfAuthorized()
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
    @StateObject private var locationManager = LocationManager.shared
    
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let parent = location.parent?.name {
                    Text(parent)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Distance Display
            if showDistance {
                // Use API distance if available (for nearby stops), otherwise calculate distance
                if let apiDistance = location.distance {
                    let distance = CLLocationDistance(apiDistance)
                    Text(locationManager.formattedDistance(distance))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else if let calculatedDistance = locationManager.distanceFrom(location.coord ?? []) {
                    Text(locationManager.formattedDistance(calculatedDistance))
                        .font(.system(size: 14, weight: .medium))
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
    NavigationView {
        StationsView()
    }
} 