//
//  DepartureDetailView.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import SwiftUI

struct DepartureDetailView: View {
    let location: Location
    @StateObject private var mvvService = MVVService()
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    // Use the proper disassembled name from API, just like in ContentView
    private var cleanLocationName: String {
        return location.disassembledName ?? location.name ?? "Abfahrten"
    }
    
    var body: some View {
        VStack {
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
            } else if mvvService.departures.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "tram")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Keine Abfahrten")
                        .font(.headline)
                    Text("Aktuell sind keine Abfahrten verfügbar")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                List(mvvService.departures) { departure in
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
        .navigationTitle(cleanLocationName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            mvvService.loadDepartures(for: location)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Favorite Button
                    Button {
                        favoritesManager.toggleFavorite(location)
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(location) ? "star.fill" : "star")
                            .foregroundColor(favoritesManager.isFavorite(location) ? .orange : .primary)
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
                    
                    if let delay = delayMinutes, delay > 0 {
                        Text("+\(delay)")
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
    
    private var delayMinutes: Int? {
        guard let plannedString = departure.departureTimePlanned,
              let estimatedString = departure.departureTimeEstimated,
              let planned = parseDate(plannedString),
              let estimated = parseDate(estimatedString) else {
            return nil
        }
        
        let difference = estimated.timeIntervalSince(planned)
        let minutes = Int(difference / 60)
        return minutes > 0 ? minutes : nil
    }
    
    private var formattedDepartureTime: String {
        let timeString = departure.departureTimeEstimated ?? departure.departureTimePlanned ?? ""
        
        guard let date = parseDate(timeString) else {
            return "--:--"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        return formatter.string(from: date)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}



 