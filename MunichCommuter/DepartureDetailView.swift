//
//  DepartureDetailView.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import SwiftUI
import Foundation

// MARK: - Transport Type Enumeration
enum TransportType: String, CaseIterable {
    case sBahn = "S-Bahn"
    case uBahn = "U-Bahn"
    case tram = "Tram"
    case stadtBus = "StadtBus"
    case regionalBus = "RegionalBus"
    case regionalBahn = "Regionalbahn"
    case regionalExpress = "Regional-Express"
    case ice = "ICE/IC/EC"
    
    var icon: String {
        switch self {
        case .sBahn: return "tram.fill"
        case .uBahn: return "tram.fill"
        case .tram: return "tram.fill"
        case .stadtBus: return "bus.fill"
        case .regionalBus: return "bus.fill"
        case .regionalBahn: return "train.side.front.car"
        case .regionalExpress: return "train.side.front.car"
        case .ice: return "train.side.front.car"
        }
    }
    
    var color: Color {
        switch self {
        case .sBahn: return Color(red: 0/255, green: 142/255, blue: 78/255)        // MVV S-Bahn #008E4E
        case .uBahn: return Color(red: 0/255, green: 78/255, blue: 143/255)        // MVV U-Bahn #004E8F
        case .tram: return Color(red: 217/255, green: 26/255, blue: 26/255)        // MVV Tram #D91A1A
        case .stadtBus: return Color(red: 0/255, green: 87/255, blue: 106/255)     // MVV Bus #00576A
        case .regionalBus: return Color(red: 0/255, green: 87/255, blue: 106/255)  // MVV Bus #00576A
        case .regionalBahn: return Color(red: 50/255, green: 54/255, blue: 127/255) // MVV Regio #32367F
        case .regionalExpress: return Color(red: 50/255, green: 54/255, blue: 127/255) // MVV Regio #32367F
        case .ice: return Color(red: 50/255, green: 54/255, blue: 127/255)         // MVV Regio #32367F
        }
    }
    
    var shortName: String {
        switch self {
        case .sBahn: return "S-Bahn"
        case .uBahn: return "U-Bahn"
        case .tram: return "Tram"
        case .stadtBus: return "StadtBus"
        case .regionalBus: return "RegBus"
        case .regionalBahn: return "RB"
        case .regionalExpress: return "RE"
        case .ice: return "ICE/IC"
        }
    }
}

struct DepartureDetailView: View {
    let locationId: String
    let locationName: String?
    let initialFilters: [String]?
    let initialPlatformFilters: [String]?
    let initialTransportTypes: [String]?
    
    @StateObject private var mvvService = MVVService()
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    @State private var destinationFilters: [String] = []
    @State private var platformFilters: [String] = []
    @State private var showFilterBar = false
    @State private var showDestinationPicker = false
    @State private var showPlatformPicker = false
    @State private var resolvedLocation: Location?
    @State private var selectedTransportTypes: Set<TransportType> = Set(TransportType.allCases)
    @State private var hasInitialized = false
    
    init(locationId: String, locationName: String? = nil, initialFilter: String? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilters = initialFilter.map { [$0] }
        self.initialPlatformFilters = nil
        self.initialTransportTypes = nil
    }
    
    // New init for multiple filters
    init(locationId: String, locationName: String? = nil, initialFilters: [String]? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilters = initialFilters
        self.initialPlatformFilters = nil
        self.initialTransportTypes = nil
    }
    
    // Convenience initializer for backward compatibility
    init(location: Location, initialFilter: String? = nil) {
        self.locationId = location.id
        self.locationName = location.disassembledName ?? location.name
        self.initialFilters = initialFilter.map { [$0] }
        self.initialPlatformFilters = nil
        self.initialTransportTypes = nil
    }
    
    // Initializer for favorites with transport type filters
    init(locationId: String, locationName: String? = nil, initialFilter: String? = nil, initialTransportTypes: [String]? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilters = initialFilter.map { [$0] }
        self.initialPlatformFilters = nil
        self.initialTransportTypes = initialTransportTypes
    }
    
    // New initializer for favorites with multiple destination filters
    init(locationId: String, locationName: String? = nil, initialFilters: [String]? = nil, initialTransportTypes: [String]? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilters = initialFilters
        self.initialPlatformFilters = nil
        self.initialTransportTypes = initialTransportTypes
    }
    
    // New initializer for favorites with all filter types
    init(locationId: String, locationName: String? = nil, initialDestinationFilters: [String]? = nil, initialPlatformFilters: [String]? = nil, initialTransportTypes: [String]? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilters = initialDestinationFilters
        self.initialPlatformFilters = initialPlatformFilters
        self.initialTransportTypes = initialTransportTypes
    }
    
    // Create a fallback location for immediate favorite functionality
    private var fallbackLocation: Location {
        return Location(
            id: locationId,
            type: "stop",
            name: locationName,
            disassembledName: locationName,
            coord: nil,
            parent: nil,
            assignedStops: nil,
            properties: nil
        )
    }
    
    // Get the best available location (resolved or fallback)
    private var bestAvailableLocation: Location {
        return resolvedLocation ?? fallbackLocation
    }
    
    // Use the resolved location name from API or fallback to provided name
    private var cleanLocationName: String {
        return resolvedLocation?.disassembledName ?? 
               resolvedLocation?.name ?? 
               locationName ?? 
               "Abfahrten"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Smart Filter Bar
            if showFilterBar {
                VStack(spacing: 8) {
                    // Transport Type Filter Tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TransportType.allCases, id: \.self) { transportType in
                                TransportTypeFilterButton(
                                    transportType: transportType,
                                    isSelected: selectedTransportTypes.contains(transportType),
                                    isAllSelected: selectedTransportTypes.count == TransportType.allCases.count,
                                    action: {
                                        handleTransportTypeSelection(transportType)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                    
                    // Destination Filter
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "line.horizontal.3.decrease.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                            
                            Text("Zielhaltestellen (\(destinationFilters.count))")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                showDestinationPicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Hinzufügen")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if !destinationFilters.isEmpty {
                                Button(action: {
                                    destinationFilters.removeAll()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                        Text("Alle löschen")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Selected destinations display
                        if !destinationFilters.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(destinationFilters, id: \.self) { destination in
                                        HStack(spacing: 4) {
                                            Text(destination)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Button(action: {
                                                destinationFilters.removeAll { $0 == destination }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Platform Filter
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "train.side.front.car")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            
                            Text("Gleise (\(platformFilters.count))")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                showPlatformPicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Hinzufügen")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if !platformFilters.isEmpty {
                                Button(action: {
                                    platformFilters.removeAll()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                        Text("Alle löschen")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Selected platforms display
                        if !platformFilters.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(platformFilters, id: \.self) { platform in
                                        HStack(spacing: 4) {
                                            Text("Gl. \(platform)")
                                                .font(.caption)
                                                .lineLimit(1)
                                            Button(action: {
                                                platformFilters.removeAll { $0 == platform }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Close Button
                    HStack {
                        Spacer()
                        Button("Filter schließen") {
                            showFilterBar = false
                            destinationFilters.removeAll()
                            platformFilters.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    if hasActiveFilters && filteredDepartures.isEmpty && !mvvService.departures.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(getFilterMessage())
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .bottom
                )
            }
            
            // Main Content
            if mvvService.isDeparturesLoading {
                Spacer()
                ProgressView("Lade Abfahrten...")
                Spacer()
            } else if let errorMessage = mvvService.departureErrorMessage {
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
                        mvvService.loadDepartures(locationId: locationId)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if displayedDepartures.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: hasActiveFilters ? "line.horizontal.3.decrease.circle" : "tram")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(hasActiveFilters ? "Keine gefilterten Abfahrten" : "Keine Abfahrten")
                        .font(.headline)
                    Text(hasActiveFilters ? getFilterMessage() : "Aktuell sind keine Abfahrten verfügbar")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List(displayedDepartures) { departure in
                    NavigationLink(destination: TripDetailView(departure: departure, currentStopName: cleanLocationName)) {
                        DepartureRowView(departure: departure)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    mvvService.loadDepartures(locationId: locationId)
                }
            }
        }
        .navigationTitle(filterActiveTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Only initialize once to prevent multiple calls
            guard !hasInitialized else { return }
            hasInitialized = true
            
            // Reset other state to prevent conflicts between different instances
            showFilterBar = false
            showDestinationPicker = false
            
            // Handle initial transport types
            if let transportTypes = initialTransportTypes, !transportTypes.isEmpty {
                let validTypes = Set(transportTypes.compactMap { TransportType(rawValue: $0) })
                if !validTypes.isEmpty {
                    selectedTransportTypes = validTypes
                } else {
                    selectedTransportTypes = Set(TransportType.allCases)
                }
            }
            
            mvvService.loadDepartures(locationId: locationId)
            
            // Apply initial filters if provided
            var hasInitialFilters = false
            
            if let filters = initialFilters, !filters.isEmpty {
                destinationFilters = filters
                hasInitialFilters = true
            }
            
            if let platforms = initialPlatformFilters, !platforms.isEmpty {
                platformFilters = platforms
                hasInitialFilters = true
            }
            
            // Check if transport types are filtered
            if selectedTransportTypes.count < TransportType.allCases.count {
                hasInitialFilters = true
            }
            
            // Note: Filter bar stays closed even with active filters from favorites
            // User can manually open it if needed
        }
        .onDisappear {
            // Clean up when view disappears to prevent state pollution
        }
        .onReceive(mvvService.$departureLocations) { departureLocations in
            // Extract location information from API response
            if let firstLocation = departureLocations.first {
                // Use the original locationId to maintain consistency
                resolvedLocation = Location(
                    id: firstLocation.id ?? locationId,
                    type: firstLocation.type,
                    name: firstLocation.name,
                    disassembledName: locationName, // Use original locationName for disassembledName
                    coord: firstLocation.coord,
                    parent: nil,  // DepartureLocation doesn't have parent
                    assignedStops: nil,
                    properties: firstLocation.properties
                )
                
                // Update existing favorites with coordinates
                updateExistingFavoritesWithCoordinates()
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPickerView(
                destinations: availableDestinations,
                selectedDestinations: $destinationFilters,
                isPresented: $showDestinationPicker
            )
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerView(
                platforms: availablePlatforms,
                selectedPlatforms: $platformFilters,
                isPresented: $showPlatformPicker
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Favorite Button with Filter Support
                    Menu {
                        Button("Als Favorit speichern") {
                            // Only use resolvedLocation with coordinates, fallback to bestAvailableLocation
                            let locationToSave = (resolvedLocation?.coord != nil) ? resolvedLocation! : bestAvailableLocation
                            favoritesManager.addFavorite(locationToSave, destinationFilters: nil, platformFilters: nil, transportTypeFilters: nil)
                        }
                        
                        if hasActiveFilters {
                            Button("Als gefilterten Favorit speichern") {
                                // Only save transport filters if not all types are selected
                                let transportFilters: [String]?
                                if selectedTransportTypes.count < TransportType.allCases.count {
                                    transportFilters = Array(selectedTransportTypes).map { $0.rawValue }
                                } else {
                                    transportFilters = nil
                                }
                                
                                // Only save filters if not empty
                                let destinationFiltersToSave = destinationFilters.isEmpty ? nil : destinationFilters
                                let platformFiltersToSave = platformFilters.isEmpty ? nil : platformFilters
                                
                                // Only use resolvedLocation with coordinates, fallback to bestAvailableLocation
                                let locationToSave = (resolvedLocation?.coord != nil) ? resolvedLocation! : bestAvailableLocation
                                favoritesManager.addFavorite(
                                    locationToSave, 
                                    destinationFilters: destinationFiltersToSave,
                                    platformFilters: platformFiltersToSave,
                                    transportTypeFilters: transportFilters
                                )
                            }
                        }
                        
                        if favoritesManager.isFavorite(resolvedLocation ?? bestAvailableLocation) {
                            Divider()
                            ForEach(favoritesManager.getFavorites(for: resolvedLocation ?? bestAvailableLocation)) { favorite in
                                Button("Entfernen: \(favorite.displayName)") {
                                    favoritesManager.removeFavorite(favorite)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: isCurrentFavorite ? "star.fill" : "star")
                            .foregroundColor(isCurrentFavorite ? .orange : .primary)
                    }
                    
                    // Filter Button with Active Indicator
                    Button {
                        showFilterBar.toggle()
                        if !showFilterBar {
                            // Only reset filters if no initial filters were provided
                            // This preserves filters from favorites
                            if initialFilters == nil || initialFilters?.isEmpty == true {
                                destinationFilters.removeAll()
                                platformFilters.removeAll()
                            }
                            // Don't reset transport types as they might come from a favorite
                        }
                    } label: {
                        ZStack {
                            Image(systemName: showFilterBar ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                                .foregroundColor(showFilterBar ? .blue : .primary)
                            
                            // Active filter indicator
                            if hasActiveFilters {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // Refresh Button
                    Button {
                        mvvService.loadDepartures(locationId: locationId)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Filtering Logic
    private var filteredDepartures: [StopEvent] {
        var filtered = mvvService.departures
        
        // Filter by transport type
        if selectedTransportTypes.count < TransportType.allCases.count {
            let beforeCount = filtered.count
            filtered = filtered.filter { departure in
                guard let product = departure.transportation?.product?.name else { return false }
                return selectedTransportTypes.contains { transportType in
                    matchesTransportType(product: product, transportType: transportType)
                }
            }
            let afterCount = filtered.count
            print("🚇 Transport filter: \(beforeCount) → \(afterCount) departures")
        }
        
        // Filter by destination
        if !destinationFilters.isEmpty {
            let beforeCount = filtered.count
            filtered = filtered.filter { departure in
                hasDestinationInRoute(departure: departure, destination: destinationFilters)
            }
            let afterCount = filtered.count
            print("🎯 Destination filter: \(beforeCount) → \(afterCount) departures")
        }
        
        // Filter by platform
        if !platformFilters.isEmpty {
            let beforeCount = filtered.count
            filtered = filtered.filter { departure in
                hasPlatformMatch(departure: departure, platforms: platformFilters)
            }
            let afterCount = filtered.count
            print("🚉 Platform filter: \(beforeCount) → \(afterCount) departures")
        }
        
        return filtered
    }
    
    private var displayedDepartures: [StopEvent] {
        // Show filtered departures if there are active filters (regardless of filter bar state)
        // This ensures filters from favorites work even when filter bar is closed
        if hasActiveFilters {
            return filteredDepartures
        } else {
            return mvvService.departures
        }
    }
    
    private func matchesTransportType(product: String, transportType: TransportType) -> Bool {
        return FilteringHelper.matchesTransportType(product: product, transportType: transportType)
    }
    
    private func getFilterMessage() -> String {
        var messages: [String] = []
        
        if !destinationFilters.isEmpty {
            messages.append("Kein Verkehrsmittel fährt zu den ausgewählten Zielen")
        }
        
        if !platformFilters.isEmpty {
            messages.append("Keine Verbindungen von den ausgewählten Gleisen")
        }
        
        if selectedTransportTypes.count < TransportType.allCases.count {
            let selectedTypes = selectedTransportTypes.map { $0.shortName }.joined(separator: ", ")
            messages.append("Keine \(selectedTypes) verfügbar")
        }
        
        if messages.isEmpty {
            messages.append("Keine Verbindungen mit den aktiven Filtern")
        }
        
        return messages.joined(separator: " und ")
    }
    
    private func handleTransportTypeSelection(_ transportType: TransportType) {
        let allTypesSelected = selectedTransportTypes.count == TransportType.allCases.count
        let isCurrentlySelected = selectedTransportTypes.contains(transportType)
        
        if allTypesSelected && isCurrentlySelected {
            // Wenn alle ausgewählt sind und ich auf ein ausgewähltes tippe: Nur dieses aktivieren
            selectedTransportTypes = [transportType]
        } else if isCurrentlySelected {
            // Wenn das Verkehrsmittel bereits ausgewählt ist: Deaktivieren
            selectedTransportTypes.remove(transportType)
            
            // Verhindern, dass alle deaktiviert werden - mindestens eines muss ausgewählt bleiben
            if selectedTransportTypes.isEmpty {
                selectedTransportTypes = [transportType]
            }
        } else {
            // Wenn das Verkehrsmittel nicht ausgewählt ist: Aktivieren
            selectedTransportTypes.insert(transportType)
        }
    }
    
    private func hasDestinationInRoute(departure: StopEvent, destination: [String]) -> Bool {
        return FilteringHelper.hasDestinationInRoute(departure: departure, destinations: destination)
    }
    
    private func hasPlatformMatch(departure: StopEvent, platforms: [String]) -> Bool {
        return FilteringHelper.hasPlatformMatch(departure: departure, platforms: platforms)
    }
    
    // MARK: - Computed Properties
    private var hasActiveFilters: Bool {
        let hasDestinationFilter = !destinationFilters.isEmpty
        let hasPlatformFilter = !platformFilters.isEmpty
        let hasTransportFilter = selectedTransportTypes.count < TransportType.allCases.count
        return hasDestinationFilter || hasPlatformFilter || hasTransportFilter
    }
    
    private var isCurrentFavorite: Bool {
        // Use resolvedLocation if available, otherwise bestAvailableLocation
        let locationToCheck = resolvedLocation ?? bestAvailableLocation
        
        if hasActiveFilters {
            // Check if current filter combination is favorited
            let destinationFiltersToCheck = destinationFilters.isEmpty ? nil : destinationFilters
            let platformFiltersToCheck = platformFilters.isEmpty ? nil : platformFilters
            let transportFiltersToCheck = selectedTransportTypes.count < TransportType.allCases.count ? 
                Array(selectedTransportTypes).map { $0.rawValue } : nil
            
            return favoritesManager.isFavorite(
                locationToCheck,
                destinationFilters: destinationFiltersToCheck,
                platformFilters: platformFiltersToCheck,
                transportTypeFilters: transportFiltersToCheck
            )
        } else {
            // Check if location is favorited without filters
            return favoritesManager.isFavorite(locationToCheck)
        }
    }
    
    private var filterActiveTitle: String {
        if destinationFilters.isEmpty {
            return cleanLocationName
        } else {
            return "\(cleanLocationName) → \(destinationFilters.joined(separator: ", "))"
        }
    }
    
    // MARK: - State Management
    private func resetState() {
        // Reset state variables but preserve filter settings
        destinationFilters.removeAll()
        platformFilters.removeAll()
        showFilterBar = false
        showDestinationPicker = false
        showPlatformPicker = false
        // Don't reset resolvedLocation - we use bestAvailableLocation for immediate functionality
        // Don't reset selectedTransportTypes - they are set by the initializer
        
        
    }
    
    // MARK: - Update Existing Favorites
    private func updateExistingFavoritesWithCoordinates() {
        guard let resolved = resolvedLocation,
              let coords = resolved.coord,
              coords.count >= 2 else {
            return
        }
        
        let allFavoritesForLocation = favoritesManager.getFavorites(for: fallbackLocation)
        
        // Find favorites for this location that don't have coordinates
        let favoritesToUpdate = allFavoritesForLocation.filter { favorite in
            favorite.location.coord == nil || favorite.location.coord?.isEmpty == true
        }
        
        if !favoritesToUpdate.isEmpty {
            for favorite in favoritesToUpdate {
                // Create updated location with coordinates
                let updatedLocation = Location(
                    id: favorite.location.id,
                    type: resolved.type,
                    name: favorite.location.name ?? resolved.name,
                    disassembledName: favorite.location.disassembledName ?? resolved.disassembledName,
                    coord: coords,
                    parent: resolved.parent,
                    assignedStops: resolved.assignedStops,
                    properties: resolved.properties
                )
                
                // Remove old and add updated
                favoritesManager.removeFavorite(favorite)
                favoritesManager.addFavorite(
                    updatedLocation,
                    destinationFilters: favorite.destinationFilters,
                    platformFilters: favorite.platformFilters,
                    transportTypeFilters: favorite.transportTypeFilters
                )
            }
        }
    }
    
    // MARK: - Available Destinations and Platforms
    private var availableDestinations: [String] {
        var destinations = Set<String>()
        
        for departure in mvvService.departures {
            // Add final destination
            if let finalDestination = departure.transportation?.destination?.name {
                destinations.insert(finalDestination)
            }
            
            // Add all stops along the route
            if let onwardLocations = departure.onwardLocations {
                for platform in onwardLocations {
                    if let name = platform.name {
                        destinations.insert(name)
                    }
                }
            }
        }
        
        return Array(destinations).sorted()
    }
    
    private var availablePlatforms: [String] {
        var platforms = Set<String>()
        
        for departure in mvvService.departures {
            if let platform = PlatformHelper.effectivePlatform(from: departure.location?.properties) {
                platforms.insert(platform)
            }
        }
        
        return PlatformHelper.sortPlatforms(Array(platforms))
    }
}

// MARK: - Transport Type Filter Button
struct TransportTypeFilterButton: View {
    let transportType: TransportType
    let isSelected: Bool
    let isAllSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: transportType.icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(transportType.shortName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(buttonBackgroundColor)
            )
            .foregroundColor(buttonTextColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(buttonBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var buttonBackgroundColor: Color {
        if isSelected {
            return transportType.color
        } else if isAllSelected {
            return Color(.systemGray6) // Leicht hervorgehoben wenn alle ausgewählt
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var buttonTextColor: Color {
        if isSelected {
            return .white
        } else if isAllSelected {
            return .primary // Normale Textfarbe wenn alle ausgewählt
        } else {
            return .primary
        }
    }
    
    private var buttonBorderColor: Color {
        if isSelected {
            return transportType.color
        } else if isAllSelected {
            return Color(.systemGray3) // Leicht hervorgehobener Rahmen
        } else {
            return Color(.systemGray4)
        }
    }
}

struct DepartureRowView: View {
    let departure: StopEvent
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Transport Line - MVG Style Badge (Linksbündig)
            VStack(spacing: 4) {
                TransportBadge(departure: departure, size: .normal)
                
                Text(DepartureRowStyling.transportTypeName(for: departure))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 64, alignment: .center)
            }
            .frame(width: 64, alignment: .leading) // Slightly wider + explicit alignment
            
            // Destination and Platform (Nimmt maximalen verfügbaren Platz ein)
            VStack(alignment: .leading, spacing: 3) {
                Text(departure.transportation?.destination?.name ?? "Unbekanntes Ziel")
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading) // Explicit maxWidth
                
                HStack(spacing: 8) {
                    if let platformName = departure.location?.properties?.platformName {
                        Text("Gleis \(platformName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let plannedPlatformName = departure.location?.properties?.plannedPlatformName {
                        Text("Gleis \(plannedPlatformName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let platform = departure.location?.properties?.platform {
                        Text("Gleis \(platform)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = departure.transportation?.description {
                        Text("• \(description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Explicit maxWidth
            }
            .frame(maxWidth: .infinity) // Maximaler verfügbarer Platz
            
            // Departure Time (Rechtsbündig)
            VStack(alignment: .trailing, spacing: 3) {
                Text(DepartureRowStyling.formattedDepartureTime(for: departure))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .primary)
                
                HStack(spacing: 4) {
                    RealtimeBadge(isRealtime: DepartureRowStyling.isRealtime(for: departure))
                    
                    if let delayText = DepartureRowStyling.delayDisplay(for: departure) {
                        Text(delayText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: 70, alignment: .trailing) // Kompakter für besseres Layout
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // All styling logic moved to DepartureRowStyling helper
}

#Preview {
    NavigationView {
        DepartureDetailView(
            locationId: "de:09162:10",
            locationName: "Pasing",
            initialFilter: nil
        )
    }
}

#Preview("With Filter") {
    NavigationView {
        DepartureDetailView(
            locationId: "de:09162:10",
            locationName: "Pasing",
            initialFilter: "Marienplatz"
        )
    }
}



 
