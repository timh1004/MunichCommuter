//
//  TripDetailView.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import SwiftUI
import MapKit
import Foundation

struct TripDetailView: View {
    let departure: StopEvent
    let currentStopName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Computed property to get all stops in the route
    private var allStops: [RouteLocation] {
        var stops: [RouteLocation] = []
        
        // Add previous stops
        if let previousStops = departure.previousLocations {
            stops.append(contentsOf: previousStops.map { convertPlatformToRouteLocation($0) })
        }
        
        // Add current stop
        if let currentLocation = departure.location {
            stops.append(convertPlatformToRouteLocation(currentLocation))
        }
        
        // Add onward stops
        if let onwardStops = departure.onwardLocations {
            stops.append(contentsOf: onwardStops.map { convertPlatformToRouteLocation($0) })
        }
        
        return stops
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with Line Info
                TripHeaderView(departure: departure)
                
                // Route Map Section
                if !allStops.isEmpty {
                    RouteMapView(stops: allStops, currentStopName: currentStopName)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                
                // Route Timeline
                LazyVStack(spacing: 0) {
                    // Previous stops
                    if let previousStops = departure.previousLocations {
                        ForEach(Array(previousStops.enumerated()), id: \.offset) { index, stop in
                            RouteStopView(
                                stop: convertPlatformToRouteLocation(stop),
                                isCurrentStop: false,
                                isPast: true,
                                isFirst: index == 0,
                                isLast: false
                            )
                        }
                    }
                    
                    // Current stop
                    RouteStopView(
                        stop: createCurrentStopLocation(),
                        isCurrentStop: true,
                        isPast: false,
                        isFirst: departure.previousLocations?.isEmpty ?? true,
                        isLast: departure.onwardLocations?.isEmpty ?? true
                    )
                    
                    // Future stops
                    if let onwardStops = departure.onwardLocations {
                        ForEach(Array(onwardStops.enumerated()), id: \.offset) { index, stop in
                            RouteStopView(
                                stop: convertPlatformToRouteLocation(stop),
                                isCurrentStop: false,
                                isPast: false,
                                isFirst: false,
                                isLast: index == onwardStops.count - 1
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("\(departure.transportation?.name ?? "Fahrt")")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private func createCurrentStopLocation() -> RouteLocation {
        return RouteLocation(
            id: departure.location?.id,
            name: currentStopName,
            coord: departure.location?.coord,
            parent: departure.location?.parent,
            properties: departure.location?.properties,
            departureTimePlanned: departure.departureTimePlanned,
            departureTimeEstimated: departure.departureTimeEstimated,
            arrivalTimePlanned: departure.departureTimePlanned,
            arrivalTimeEstimated: departure.departureTimeEstimated
        )
    }
    
    private func convertPlatformToRouteLocation(_ platform: Platform) -> RouteLocation {
        return RouteLocation(
            id: platform.id,
            name: platform.name,
            coord: platform.coord,
            parent: platform.parent,
            properties: platform.properties,
            departureTimePlanned: platform.departureTimePlanned,
            departureTimeEstimated: platform.departureTimeEstimated,
            arrivalTimePlanned: platform.arrivalTimePlanned,
            arrivalTimeEstimated: platform.arrivalTimeEstimated
        )
    }
}

struct TripHeaderView: View {
    let departure: StopEvent
    
    var body: some View {
        VStack(spacing: 16) {
            // Line Badge and Route Info
            HStack(spacing: 16) {
                // Line Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lineColor)
                        .frame(width: 60, height: 40)
                    
                    Text(departure.transportation?.number ?? "?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(departure.transportation?.description ?? "Unbekannte Route")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let operatorName = departure.transportation?.transportOperator?.name {
                        Text(operatorName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Departure Time Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Abfahrt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDepartureTime)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(shouldShowOrange ? .orange : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        if departure.isRealtimeControlled == true {
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
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    private var lineColor: Color {
        guard let productClass = departure.transportation?.product?.productClass else {
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
        
        switch productClass {
        case 1: return sBahnLineColor                              // S-Bahn: Spezifische Linienfarben
        case 2: return uBahnLineColor                              // U-Bahn: Spezifische Linienfarben
        case 4: return Color(red: 0.8, green: 0.0, blue: 0.0)     // Tram
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.8)     // Bus
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)
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
            return Color(red: 0.0, green: 0.4, blue: 0.8)
        }
        
        switch lineNumber {
        case "U1", "1": return Color(red: 0.0, green: 0.7, blue: 0.0)
        case "U2", "2": return Color(red: 0.9, green: 0.0, blue: 0.0)
        case "U3", "3": return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "U4", "4": return Color(red: 0.0, green: 0.8, blue: 0.8)
        case "U5", "5": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "U6", "6": return Color(red: 0.0, green: 0.4, blue: 0.8)
        case "U7", "7": return Color(red: 0.0, green: 0.7, blue: 0.0)
        case "U8", "8": return Color(red: 0.9, green: 0.0, blue: 0.0)
        default: return Color(red: 0.0, green: 0.4, blue: 0.8)
        }
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

struct RouteStopView: View {
    let stop: RouteLocation
    let isCurrentStop: Bool
    let isPast: Bool
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Improved Timeline with continuous line
            ZStack(alignment: .leading) {
                // Continuous background line for entire route
                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 4)
                        .offset(x: 8)
                }
                
                // Active line segment
                VStack(spacing: 0) {
                    // Top line segment
                    if !isFirst {
                        Rectangle()
                            .fill(isPast ? .blue : Color.blue.opacity(0.4))
                            .frame(width: 4, height: 30)
                    }
                    
                    // Station indicator
                    ZStack {
                        // Outer ring for current station
                        if isCurrentStop {
                            Circle()
                                .stroke(Color.blue, lineWidth: 3)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(.white))
                        }
                        
                        Circle()
                            .fill(dotColor)
                            .frame(width: isCurrentStop ? 14 : 12, height: isCurrentStop ? 14 : 12)
                        
                        if isCurrentStop {
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    // Bottom line segment
                    if !isLast {
                        Rectangle()
                            .fill(isPast ? .blue : Color.blue.opacity(0.4))
                            .frame(width: 4, height: 30)
                    }
                }
                .offset(x: 8)
            }
            .frame(width: 24)
            
            // Stop Information
            VStack(alignment: .leading, spacing: 6) {
                Text(stop.name ?? "Unbekannte Haltestelle")
                    .font(.system(size: 16, weight: isCurrentStop ? .semibold : .medium))
                    .foregroundColor(isCurrentStop ? .primary : (isPast ? .secondary : .primary))
                
                // Platform/Track Information
                if let platformName = stop.properties?.platformName {
                    Text(platformName)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // Time Information with Real-time Updates
                VStack(alignment: .leading, spacing: 4) {
                    if let arrivalPlanned = stop.arrivalTimePlanned {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Ankunft")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatTime(arrivalPlanned))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            if let arrivalEstimated = stop.arrivalTimeEstimated,
                               arrivalEstimated != arrivalPlanned {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Verspätung")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(formatTime(arrivalEstimated))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    
                    if let departurePlanned = stop.departureTimePlanned {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Abfahrt")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatTime(departurePlanned))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            if let departureEstimated = stop.departureTimeEstimated,
                               departureEstimated != departurePlanned {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Verspätung")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(formatTime(departureEstimated))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                // Zone information if available
                if let zone = stop.properties?.zone {
                    Text("Zone: \(zone)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var dotColor: Color {
        if isCurrentStop {
            return .blue
        } else if isPast {
            return .blue.opacity(0.6)
        } else {
            return .gray.opacity(0.5)
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        guard let date = Date.parseISO8601(timeString) else {
            return "--:--"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        return formatter.string(from: date)
    }
}

// Helper struct for route locations
struct RouteLocation: Identifiable {
    let id = UUID()
    let internalId: String?
    let name: String?
    let coord: [Double]?
    let parent: PlatformParent?
    let properties: PlatformProperties?
    let departureTimePlanned: String?
    let departureTimeEstimated: String?
    let arrivalTimePlanned: String?
    let arrivalTimeEstimated: String?
    
    init(id: String?, name: String?, coord: [Double]?, parent: PlatformParent?, properties: PlatformProperties?, departureTimePlanned: String?, departureTimeEstimated: String?, arrivalTimePlanned: String?, arrivalTimeEstimated: String?) {
        self.internalId = id
        self.name = name
        self.coord = coord
        self.parent = parent
        self.properties = properties
        self.departureTimePlanned = departureTimePlanned
        self.departureTimeEstimated = departureTimeEstimated
        self.arrivalTimePlanned = arrivalTimePlanned
        self.arrivalTimeEstimated = arrivalTimeEstimated
    }
}

// MARK: - Route Map View
struct RouteMapView: View {
    let stops: [RouteLocation]
    let currentStopName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streckenverlauf")
                .font(.headline)
                .padding(.horizontal, 16)
            
            Map(coordinateRegion: $region, annotationItems: validStops) { stop in
                MapAnnotation(coordinate: stop.coordinate) {
                    ZStack {
                        Circle()
                            .fill(stop.name == currentStopName ? .red : .blue)
                            .frame(width: stop.name == currentStopName ? 12 : 8, height: stop.name == currentStopName ? 12 : 8)
                        
                        if stop.name == currentStopName {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .onAppear {
                calculateMapRegion()
            }
        }
    }
    
    private var validStops: [RouteMapStop] {
        return stops.compactMap { stop in
            guard let coord = stop.coord,
                  coord.count >= 2,
                  let name = stop.name else { return nil }
            
            return RouteMapStop(
                id: stop.id,
                name: name,
                coordinate: CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
            )
        }
    }
    
    private func calculateMapRegion() {
        guard !validStops.isEmpty else { return }
        
        let coordinates = validStops.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 48.1351
        let maxLat = coordinates.map { $0.latitude }.max() ?? 48.1351
        let minLon = coordinates.map { $0.longitude }.min() ?? 11.5820
        let maxLon = coordinates.map { $0.longitude }.max() ?? 11.5820
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

struct RouteMapStop: Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
}



 