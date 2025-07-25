//
//  DepartureDetailWatchView.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct DepartureDetailWatchView: View {
    let locationId: String
    let locationName: String
    let favorite: WatchFavorite?
    
    @StateObject private var mvvService = WatchMVVService()
    @StateObject private var favoritesManager = WatchFavoritesManager.shared
    @State private var isRefreshing = false
    @State private var lastRefresh: Date?
    
    private var filteredDepartures: [WatchDeparture] {
        var departures = mvvService.departures
        
        // Apply filters if this is from a favorite
        if let favorite = favorite {
            // Apply destination filters
            if let destinationFilters = favorite.destinationFilters, !destinationFilters.isEmpty {
                departures = departures.filter { departure in
                    guard let destination = departure.destination else { return false }
                    return destinationFilters.contains { filter in
                        destination.localizedCaseInsensitiveContains(filter)
                    }
                }
            }
            
            // Apply platform filters
            if let platformFilters = favorite.platformFilters, !platformFilters.isEmpty {
                departures = departures.filter { departure in
                    guard let platform = departure.platform else { return false }
                    return platformFilters.contains(platform)
                }
            }
            
            // Apply transport type filters
            if let transportFilters = favorite.transportTypeFilters, !transportFilters.isEmpty {
                departures = departures.filter { departure in
                    guard let transportType = departure.transportType else { return false }
                    return transportFilters.contains(transportType.rawValue)
                }
            }
        }
        
        return departures
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if mvvService.isLoading && mvvService.departures.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { _ in
                            DepartureSkeletonWatch()
                        }
                    }
                    .padding()
                } else if let error = mvvService.error {
                    ErrorStateWatch(
                        message: error,
                        action: {
                            Task {
                                await loadDepartures()
                            }
                        }
                    )
                } else if filteredDepartures.isEmpty {
                    EmptyStateWatch(
                        icon: "tram.fill",
                        title: "Keine Abfahrten",
                        subtitle: favorite?.hasFilters == true ? "Keine Abfahrten für die aktiven Filter" : "Keine Abfahrten verfügbar",
                        action: {
                            Task {
                                await loadDepartures()
                            }
                        },
                        actionTitle: "Aktualisieren"
                    )
                } else {
                    List {
                        // Last refresh info
                        if let lastRefresh = lastRefresh {
                            Section {
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Aktualisiert \(formatLastRefresh(lastRefresh))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if isRefreshing {
                                        RefreshIndicatorWatch()
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        }
                        
                        // Departures
                        Section {
                            ForEach(filteredDepartures) { departure in
                                DepartureRowWatchView(departure: departure)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshDepartures()
                    }
                }
            }
            .navigationTitle(locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        if isRefreshing {
                            RefreshIndicatorWatch()
                        }
                        
                        // Favorite toggle button
                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(isFavorite ? .orange : .gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadDepartures()
            }
        }
    }
    
    private var isFavorite: Bool {
        return favoritesManager.isFavorite(locationId: locationId)
    }
    
    private func toggleFavorite() {
        let location = WatchLocation(
            id: locationId,
            name: locationName,
            disassembledName: locationName,
            coord: nil
        )
        
        if isFavorite {
            favoritesManager.removeFavorite(locationId: locationId)
        } else {
            favoritesManager.addFavorite(location)
        }
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }
    
    @MainActor
    private func loadDepartures() async {
        await mvvService.loadDepartures(locationId: locationId, limit: 15)
        lastRefresh = Date()
    }
    
    @MainActor
    private func refreshDepartures() async {
        isRefreshing = true
        
        // Clear cache for fresh data
        mvvService.clearCache()
        
        await mvvService.loadDepartures(locationId: locationId, limit: 15)
        lastRefresh = Date()
        
        isRefreshing = false
    }
    
    private func formatLastRefresh(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Departure Row for Detail View
struct DepartureRowWatchView: View {
    let departure: WatchDeparture
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Transport Badge
                TransportBadgeWatch(departure: departure)
                
                // Destination
                VStack(alignment: .leading, spacing: 1) {
                    Text(departure.destination ?? "Unbekanntes Ziel")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let platform = departure.platform {
                        Text("Gleis \(platform)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Time and delay
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(departure.displayTime)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .fontDesign(.monospaced)
                            .foregroundColor(timeColor)
                        
                        if let delayText = departure.delayText {
                            Text(delayText)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let minutes = departure.minutesUntilDeparture {
                        Text(minutesText(minutes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Realtime indicator
                    if departure.isRealtime {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                            Text("Live")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var timeColor: Color {
        guard let minutes = departure.minutesUntilDeparture else {
            return .primary
        }
        
        if minutes <= 2 {
            return .orange
        } else if minutes <= 5 {
            return .yellow
        } else {
            return .primary
        }
    }
    
    private func minutesText(_ minutes: Int) -> String {
        if minutes == 0 {
            return "jetzt"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Preview
#if DEBUG
struct DepartureDetailWatchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DepartureDetailWatchView(
                locationId: "de:09162:70",
                locationName: "Marienplatz",
                favorite: nil
            )
        }
    }
}
#endif