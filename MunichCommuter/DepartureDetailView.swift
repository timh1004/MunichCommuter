//
//  DepartureDetailView.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import SwiftUI
import Foundation

struct DepartureDetailView: View {
    let location: Location
    let initialFilter: String?
    
    @StateObject private var mvvService = MVVService()
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    @State private var destinationFilter = ""
    @State private var showFilterBar = false
    @State private var showDestinationPicker = false
    
    init(location: Location, initialFilter: String? = nil) {
        self.location = location
        self.initialFilter = initialFilter
    }
    
    // Use the proper disassembled name from API, just like in ContentView
    private var cleanLocationName: String {
        return location.disassembledName ?? location.name ?? "Abfahrten"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Smart Filter Bar
            if showFilterBar {
                VStack(spacing: 8) {
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
                        mvvService.loadDepartures(for: location)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if displayedDepartures.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: showFilterBar && !destinationFilter.isEmpty ? "line.horizontal.3.decrease.circle" : "tram")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(showFilterBar && !destinationFilter.isEmpty ? "Keine gefilterten Abfahrten" : "Keine Abfahrten")
                        .font(.headline)
                    Text(showFilterBar && !destinationFilter.isEmpty ? "Kein Zug/Bus fährt nach '\(destinationFilter)'" : "Aktuell sind keine Abfahrten verfügbar")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List(displayedDepartures) { departure in
                    NavigationLink(destination: TripDetailView(departure: departure, currentStopName: location.name ?? "Unbekannte Haltestelle")) {
                        DepartureRowView(departure: departure)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    mvvService.loadDepartures(for: location)
                }
            }
        }
        .navigationTitle(filterActiveTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            mvvService.loadDepartures(for: location)
            
            // Apply initial filter if provided
            if let filter = initialFilter, !filter.isEmpty {
                destinationFilter = filter
                showFilterBar = true
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
                            favoritesManager.addFavorite(location)
                        }
                        
                        if showFilterBar && !destinationFilter.isEmpty {
                            Button("Als gefilterten Favorit speichern") {
                                favoritesManager.addFavorite(location, destinationFilter: destinationFilter)
                            }
                        }
                        
                        if favoritesManager.isFavorite(location) {
                            Divider()
                            ForEach(favoritesManager.getFavorites(for: location)) { favorite in
                                Button("Entfernen: \(favorite.displayName)") {
                                    favoritesManager.removeFavorite(favorite)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(location) ? "star.fill" : "star")
                            .foregroundColor(favoritesManager.isFavorite(location) ? .orange : .primary)
                    }
                    
                    // Filter Button with Active Indicator
                    Button {
                        showFilterBar.toggle()
                        if !showFilterBar {
                            destinationFilter = ""
                        }
                    } label: {
                        ZStack {
                            Image(systemName: showFilterBar ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                                .foregroundColor(showFilterBar ? .blue : .primary)
                            
                            // Active filter indicator
                            if !destinationFilter.isEmpty {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // Refresh Button
                    Button {
                        mvvService.loadDepartures(for: location)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Filtering Logic
    private var filteredDepartures: [StopEvent] {
        guard !destinationFilter.isEmpty else { return mvvService.departures }
        
        return mvvService.departures.filter { departure in
            hasDestinationInRoute(departure: departure, destination: destinationFilter)
        }
    }
    
    private var displayedDepartures: [StopEvent] {
        return showFilterBar && !destinationFilter.isEmpty ? filteredDepartures : mvvService.departures
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
    private var filterActiveTitle: String {
        if !destinationFilter.isEmpty {
            return "\(cleanLocationName) → \(destinationFilter)"
        }
        return cleanLocationName
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
                    .foregroundColor(isDelayed ? .orange : .primary)
                
                HStack(spacing: 6) {
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
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.orange)
                            )
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
        case 1: return Color(red: 0.0, green: 0.6, blue: 0.0)     // S-Bahn: MVG Grün
        case 2: return uBahnLineColor                              // U-Bahn: Spezifische Linienfarben
        case 4: return Color(red: 0.8, green: 0.0, blue: 0.0)     // Tram: MVG Rot
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.8)     // Bus: MVG Lila
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)    // Fallback Grau
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
        return planned != estimated
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



 