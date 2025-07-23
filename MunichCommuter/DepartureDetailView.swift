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
    let initialFilter: String?
    let initialTransportTypes: [String]?
    
    @StateObject private var mvvService = MVVService()
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    @State private var destinationFilter = ""
    @State private var showFilterBar = false
    @State private var showDestinationPicker = false
    @State private var resolvedLocation: Location?
    @State private var selectedTransportTypes: Set<TransportType> = Set(TransportType.allCases)
    @State private var hasInitialized = false
    
    init(locationId: String, locationName: String? = nil, initialFilter: String? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilter = initialFilter
        self.initialTransportTypes = nil
    }
    
    // Convenience initializer for backward compatibility
    init(location: Location, initialFilter: String? = nil) {
        self.locationId = location.id
        self.locationName = location.disassembledName ?? location.name
        self.initialFilter = initialFilter
        self.initialTransportTypes = nil
    }
    
    // Initializer for favorites with transport type filters
    init(locationId: String, locationName: String? = nil, initialFilter: String? = nil, initialTransportTypes: [String]? = nil) {
        self.locationId = locationId
        self.locationName = locationName
        self.initialFilter = initialFilter
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
                    HStack {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        HStack {
                            TextField("Nach Zielort filtern...", text: $destinationFilter)
                            
                            Button(action: {
                                showDestinationPicker = true
                            }) {
                                Image(systemName: "list.bullet.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !destinationFilter.isEmpty {
                            Button(action: {
                                destinationFilter = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button("Schließen") {
                            showFilterBar = false
                            destinationFilter = ""
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    
                    if !destinationFilter.isEmpty && filteredDepartures.isEmpty && !mvvService.departures.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Keine Verbindungen nach '\(destinationFilter)' gefunden")
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
            
            // Only reset destination filter if no initial filter is provided
            if initialFilter?.isEmpty != false {
                destinationFilter = ""
            }
            
            mvvService.loadDepartures(locationId: locationId)
            
            // Apply initial filters if provided
            var hasInitialFilters = false
            
            if let filter = initialFilter, !filter.isEmpty {
                destinationFilter = filter
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
            print("👋 DepartureDetailView disappeared for location: \(locationId)")
        }
        .onReceive(mvvService.$departures) { _ in
            // Extract location information from API response
            if let firstLocation = mvvService.departures.first?.location {
                // Convert PlatformParent to LocationParent
                let locationParent: LocationParent?
                if let platformParent = firstLocation.parent {
                    locationParent = LocationParent(
                        name: platformParent.name,
                        type: platformParent.type
                    )
                } else {
                    locationParent = nil
                }
                
                // Convert PlatformProperties to LocationProperties
                let locationProperties: LocationProperties?
                if let platformProperties = firstLocation.properties {
                    locationProperties = LocationProperties(
                        stopId: platformProperties.stopId,
                        area: platformProperties.area
                    )
                } else {
                    locationProperties = nil
                }
                
                // Use the original locationId to maintain consistency
                resolvedLocation = Location(
                    id: locationId,
                    type: firstLocation.type,
                    name: firstLocation.name,
                    disassembledName: firstLocation.name,
                    coord: firstLocation.coord,
                    parent: locationParent,
                    assignedStops: nil,
                    properties: locationProperties
                )
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPickerView(
                destinations: availableDestinations,
                selectedDestination: $destinationFilter,
                isPresented: $showDestinationPicker
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Favorite Button with Filter Support
                    Menu {
                        Button("Als Favorit speichern") {
                            favoritesManager.addFavorite(bestAvailableLocation)
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
                                
                                // Only save destination filter if not empty
                                let destinationFilterToSave = destinationFilter.isEmpty ? nil : destinationFilter
                                
                                favoritesManager.addFavorite(
                                    bestAvailableLocation, 
                                    destinationFilter: destinationFilterToSave,
                                    transportTypeFilters: transportFilters
                                )
                            }
                        }
                        
                        if favoritesManager.isFavorite(bestAvailableLocation) {
                            Divider()
                            ForEach(favoritesManager.getFavorites(for: bestAvailableLocation)) { favorite in
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
                            if initialFilter == nil || initialFilter?.isEmpty == true {
                                destinationFilter = ""
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
        if !destinationFilter.isEmpty {
            let beforeCount = filtered.count
            filtered = filtered.filter { departure in
                hasDestinationInRoute(departure: departure, destination: destinationFilter)
            }
            let afterCount = filtered.count
            print("🎯 Destination filter: \(beforeCount) → \(afterCount) departures")
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
        guard !product.isEmpty else { return false }
        
        let productLower = product.lowercased()
        
        switch transportType {
        case .sBahn:
            return productLower.contains("s-bahn") || productLower.contains("sbahn")
        case .uBahn:
            return productLower.contains("u-bahn") || productLower.contains("ubahn")
        case .tram:
            return productLower.contains("tram") || productLower.contains("straßenbahn")
        case .stadtBus:
            return productLower.contains("stadtbus") || (productLower.contains("bus") && !productLower.contains("regional"))
        case .regionalBus:
            return productLower.contains("regionalbus") || productLower.contains("regbus")
        case .regionalBahn:
            return productLower.contains("regionalbahn") || productLower.contains("rb")
        case .regionalExpress:
            return productLower.contains("regional-express") || productLower.contains("re")
        case .ice:
            return productLower.contains("ice") || productLower.contains("ic") || productLower.contains("ec")
        }
    }
    
    private func getFilterMessage() -> String {
        var messages: [String] = []
        
        if !destinationFilter.isEmpty {
            messages.append("Kein Verkehrsmittel fährt nach '\(destinationFilter)'")
        }
        
        if selectedTransportTypes.count < TransportType.allCases.count {
            let selectedTypes = selectedTransportTypes.map { $0.shortName }.joined(separator: ", ")
            messages.append("Keine \(selectedTypes) verfügbar")
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
    
    private func hasDestinationInRoute(departure: StopEvent, destination: String) -> Bool {
        let searchTerm = destination.lowercased()
        
        // Check if destination matches the final destination
        if let finalDestination = departure.transportation?.destination?.name?.lowercased(),
           finalDestination.contains(searchTerm) {
            return true
        }
        
        // Check if destination is in onward locations (stops along the route)
        if let onwardLocations = departure.onwardLocations {
            return onwardLocations.contains { platform in
                guard let name = platform.name?.lowercased() else { return false }
                return name.contains(searchTerm)
            }
        }
        
        return false
    }
    
    // MARK: - Computed Properties
    private var hasActiveFilters: Bool {
        let hasDestinationFilter = !destinationFilter.isEmpty
        let hasTransportFilter = selectedTransportTypes.count < TransportType.allCases.count
        return hasDestinationFilter || hasTransportFilter
    }
    
    private var isCurrentFavorite: Bool {
        if hasActiveFilters {
            // Check if current filter combination is favorited
            let destinationFilterToCheck = destinationFilter.isEmpty ? nil : destinationFilter
            let transportFiltersToCheck = selectedTransportTypes.count < TransportType.allCases.count ? 
                Array(selectedTransportTypes).map { $0.rawValue } : nil
            
            return favoritesManager.isFavorite(
                bestAvailableLocation,
                destinationFilter: destinationFilterToCheck,
                transportTypeFilters: transportFiltersToCheck
            )
        } else {
            // Check if location is favorited without filters
            return favoritesManager.isFavorite(bestAvailableLocation)
        }
    }
    
    private var filterActiveTitle: String {
        if !destinationFilter.isEmpty {
            return "\(cleanLocationName) → \(destinationFilter)"
        }
        return cleanLocationName
    }
    
    // MARK: - State Management
    private func resetState() {
        // Reset state variables but preserve filter settings
        destinationFilter = ""
        showFilterBar = false
        showDestinationPicker = false
        // Don't reset resolvedLocation - we use bestAvailableLocation for immediate functionality
        // Don't reset selectedTransportTypes - they are set by the initializer
        
        print("🔄 State reset for location: \(locationId)")
    }
    
    // MARK: - Available Destinations
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
        HStack(alignment: .center, spacing: 12) {
            // Transport Line - MVG Style Badge
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lineColor)
                        .frame(width: 48, height: 32)
                    
                    Text(departure.transportation?.number ?? "?")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                
                Text(transportTypeName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 56) // Fixed width for alignment
            
            // Destination and Platform
            VStack(alignment: .leading, spacing: 3) {
                Text(departure.transportation?.destination?.name ?? "Unbekanntes Ziel")
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    if let platform = departure.location?.properties?.platform {
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
            }
            
            Spacer()
            
            // Departure Time
            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedDepartureTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(shouldShowOrange ? .orange : .primary)
                
                HStack(spacing: 4) {
                    if isRealtime {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if let delayText = delayDisplay {
                        Text(delayText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: 80) // Fixed width for alignment
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var lineColor: Color {
        guard let productClass = departure.transportation?.product?.productClass else {
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Grau
        }
        
        switch productClass {
        case 1: return sBahnLineColor                              // S-Bahn: Spezifische Linienfarben
        case 2: return uBahnLineColor                              // U-Bahn: Spezifische Linienfarben
        case 4: return Color(red: 0.8, green: 0.0, blue: 0.0)     // Tram: MVG Rot
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.8)     // Bus: MVG Lila
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)    // Fallback Grau
        }
    }
    
    private var sBahnLineColor: Color {
        guard let lineNumber = departure.transportation?.number else {
            return Color(red: 22/255, green: 192/255, blue: 233/255) // Standard S-Bahn (S1)
        }
        
        switch lineNumber {
        case "S1": return Color(red: 22/255, green: 192/255, blue: 233/255)     // Hellblau
        case "S2": return Color(red: 113/255, green: 191/255, blue: 68/255)     // Grün
        case "S3": return Color(red: 123/255, green: 16/255, blue: 125/255)     // Lila
        case "S4": return Color(red: 238/255, green: 28/255, blue: 37/255)      // Rot
        case "S6": return Color(red: 0/255, green: 138/255, blue: 81/255)       // Dunkelgrün
        case "S7": return Color(red: 150/255, green: 56/255, blue: 51/255)      // Dunkelrot
        case "S8": return Color(red: 255/255, green: 203/255, blue: 6/255)      // Gelb
        case "S20": return Color(red: 240/255, green: 90/255, blue: 115/255)    // Pink
        default: return Color(red: 22/255, green: 192/255, blue: 233/255)       // Standard S-Bahn (S1)
        }
    }
    
    private var uBahnLineColor: Color {
        guard let lineNumber = departure.transportation?.number else {
            return Color(red: 0.0, green: 0.4, blue: 0.8) // Standard U-Bahn Blau
        }
        
        switch lineNumber {
        case "U1", "1": return Color(red: 0.0, green: 0.7, blue: 0.0)     // Grün
        case "U2", "2": return Color(red: 0.9, green: 0.0, blue: 0.0)     // Rot
        case "U3", "3": return Color(red: 1.0, green: 0.6, blue: 0.0)     // Orange
        case "U4", "4": return Color(red: 0.0, green: 0.8, blue: 0.8)     // Türkis
        case "U5", "5": return Color(red: 0.6, green: 0.4, blue: 0.2)     // Braun
        case "U6", "6": return Color(red: 0.0, green: 0.4, blue: 0.8)     // Blau
        case "U7", "7": return Color(red: 0.0, green: 0.7, blue: 0.0)     // Grün (wie U1)
        case "U8", "8": return Color(red: 0.9, green: 0.0, blue: 0.0)     // Rot (wie U2)
        default: return Color(red: 0.0, green: 0.4, blue: 0.8)           // Standard U-Bahn Blau
        }
    }
    
    private var transportTypeName: String {
        departure.transportation?.product?.name ?? "Zug"
    }
    
    private var isRealtime: Bool {
        departure.isRealtimeControlled == true
    }
    
    private var isDelayed: Bool {
        guard let planned = departure.departureTimePlanned,
              let estimated = departure.departureTimeEstimated else {
            return false
        }
        // Zeige orange nur bei positiver Verspätung (Zug ist später als geplant)
        guard let plannedDate = Date.parseISO8601(planned),
              let estimatedDate = Date.parseISO8601(estimated) else {
            return false
        }
        return estimatedDate > plannedDate
    }
    
    private var shouldShowOrange: Bool {
        // Zeige orange nur wenn Abfahrt in 1 Minute oder weniger stattfindet
        // Verwende die geplante Zeit für die Berechnung, nicht die geschätzte Zeit
        let timeString = departure.departureTimePlanned ?? departure.departureTimeEstimated ?? ""
        guard let departureDate = Date.parseISO8601(timeString) else {
            return false
        }
        
        let minutesFromNow = departureDate.minutesFromNow()
        return minutesFromNow <= 1
    }
    
    private var formattedTimes: (timeDisplay: String, delayDisplay: String?) {
        return DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated
        )
    }
    
    private var formattedDepartureTime: String {
        return formattedTimes.timeDisplay
    }
    
    private var delayDisplay: String? {
        return formattedTimes.delayDisplay
    }
    
    // Legacy computed property for backwards compatibility
    private var delayMinutes: Int? {
        guard let plannedString = departure.departureTimePlanned,
              let estimatedString = departure.departureTimeEstimated,
              let planned = Date.parseISO8601(plannedString),
              let estimated = Date.parseISO8601(estimatedString) else {
            return nil
        }
        
        let difference = estimated.timeIntervalSince(planned)
        let minutes = Int(difference / 60)
        return minutes > 0 ? minutes : nil
    }
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



 
