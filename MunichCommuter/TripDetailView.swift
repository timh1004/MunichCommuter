//
//  TripDetailView.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import SwiftUI
import MapKit
import Foundation

private struct StopCenterPreference: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

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
    
    private let currentStopId = "current"
    
    private var currentStopIndex: Int {
        departure.previousLocations?.count ?? 0
    }
    
    @State private var highlightedStopIndex: Int = 0
    @State private var scrollToIndex: Int?
    @State private var suppressHighlightUpdate = false
    @State private var scrollViewHeight: CGFloat = 300
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                TripHeaderView(departure: departure)
                
                if !allStops.isEmpty {
                    RouteMapView(
                        stops: allStops,
                        currentStopName: currentStopName,
                        currentStopIndex: currentStopIndex,
                        highlightedStopIndex: highlightedStopIndex,
                        onStopTapped: { index in
                            scrollToIndex = index
                        }
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let previousStops = departure.previousLocations {
                            ForEach(Array(previousStops.enumerated()), id: \.offset) { index, stop in
                                RouteStopView(
                                    stop: convertPlatformToRouteLocation(stop),
                                    isCurrentStop: false,
                                    isPast: true,
                                    isFirst: index == 0,
                                    isLast: false
                                )
                                .id("stop-\(index)")
                                .background(stopPositionReporter(globalIndex: index))
                            }
                        }
                        
                        RouteStopView(
                            stop: createCurrentStopLocation(),
                            isCurrentStop: true,
                            isPast: false,
                            isFirst: departure.previousLocations?.isEmpty ?? true,
                            isLast: departure.onwardLocations?.isEmpty ?? true
                        )
                        .id("stop-\(currentStopIndex)")
                        .background(stopPositionReporter(globalIndex: currentStopIndex))
                        
                        if let onwardStops = departure.onwardLocations {
                            ForEach(Array(onwardStops.enumerated()), id: \.offset) { index, stop in
                                let globalIndex = currentStopIndex + 1 + index
                                let isLast = index == onwardStops.count - 1
                                RouteStopView(
                                    stop: convertPlatformToRouteLocation(stop),
                                    isCurrentStop: false,
                                    isPast: false,
                                    isFirst: false,
                                    isLast: isLast
                                )
                                .id("stop-\(globalIndex)")
                                .background(stopPositionReporter(globalIndex: globalIndex))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "stopList")
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { scrollViewHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, h in scrollViewHeight = h }
                    }
                )
                .onPreferenceChange(StopCenterPreference.self) { positions in
                    guard !suppressHighlightUpdate, !positions.isEmpty else { return }
                    let center = scrollViewHeight / 2
                    if let closest = positions.min(by: { abs($0.value - center) < abs($1.value - center) }) {
                        if closest.key != highlightedStopIndex {
                            highlightedStopIndex = closest.key
                        }
                    }
                }
                .onAppear {
                    highlightedStopIndex = currentStopIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("stop-\(currentStopIndex)", anchor: .center)
                        }
                    }
                }
                .onChange(of: scrollToIndex) { _, newValue in
                    guard let idx = newValue else { return }
                    suppressHighlightUpdate = true
                    highlightedStopIndex = idx
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo("stop-\(idx)", anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        suppressHighlightUpdate = false
                        scrollToIndex = nil
                    }
                }
            }
        }
        .navigationTitle("\(departure.transportation?.name ?? "Fahrt")")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private func stopPositionReporter(globalIndex: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: StopCenterPreference.self,
                value: [globalIndex: geo.frame(in: .named("stopList")).midY]
            )
        }
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
    @AppStorage("timeDisplayMode") private var timeDisplayModeRaw: String = TimeDisplayMode.relative.rawValue
    @State private var now: Date = Date()
    
    private var timeDisplayMode: TimeDisplayMode {
        TimeDisplayMode(rawValue: timeDisplayModeRaw) ?? .relative
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(lineColor)
                    .frame(width: 48, height: 32)
                
                Text(departure.transportation?.number ?? "?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(departure.transportation?.description ?? "Unbekannte Route")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let operatorName = departure.transportation?.transportOperator?.name {
                    Text(operatorName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(formattedDepartureTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .primary)
                    .onTapGesture {
                        timeDisplayModeRaw = (timeDisplayMode == .relative ? TimeDisplayMode.absolute.rawValue : TimeDisplayMode.relative.rawValue)
                    }
                
                VStack(spacing: 2) {
                    RealtimeBadge(isRealtime: departure.isRealtimeControlled == true)
                    if let delayText = delayDisplay {
                        Text(delayText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
    
    // removed local shouldShowOrange; use DepartureRowStyling.shouldShowOrange(for:)
    
    private var formattedTimes: (timeDisplay: String, delayDisplay: String?) {
        return DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated,
            includeDelay: true,
            mode: timeDisplayMode,
            referenceDate: now
        )
    }
    
    private var formattedDepartureTime: String {
        return formattedTimes.timeDisplay
    }
    
    private var delayDisplay: String? {
        return formattedTimes.delayDisplay
    }
    
    // Delay via shared helper
    private var delayMinutes: Int? {
        return DepartureTimeFormatter.delayMinutes(planned: departure.departureTimePlanned,
                                                   estimated: departure.departureTimeEstimated)
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
            // Nur Punkt, keine Linie (bessere Lesbarkeit)
            ZStack {
                if isCurrentStop {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2.5)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white))
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: isCurrentStop ? 12 : 10, height: isCurrentStop ? 12 : 10)
                if isCurrentStop {
                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 24, height: 24)
            
            // Stop Information
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, isCurrentStop ? 10 : 8)
        .padding(.horizontal, isCurrentStop ? 8 : 0)
        .background(isCurrentStop ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(isCurrentStop ? 10 : 0)
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

// MARK: - Route Map View (mit Polyline, Karte fixiert)
struct RouteMapView: View {
    let stops: [RouteLocation]
    let currentStopName: String
    var currentStopIndex: Int = 0
    var highlightedStopIndex: Int = 0
    var onStopTapped: ((Int) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streckenverlauf")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            RouteMapUIKitView(
                stops: validStops,
                currentStopName: currentStopName,
                currentStopIndexInValid: currentStopIndexInValidStops,
                highlightedIndex: highlightedIndexInValid,
                onStopTapped: { validIndex in
                    if validIndex < validStops.count {
                        let tappedName = validStops[validIndex].name
                        if let globalIdx = globalIndexForName(tappedName) {
                            onStopTapped?(globalIdx)
                        }
                    }
                }
            )
        }
    }
    
    private var currentStopIndexInValidStops: Int {
        validStops.firstIndex(where: { $0.name == currentStopName }) ?? 0
    }
    
    private var highlightedIndexInValid: Int {
        var validIdx = 0
        var globalIdx = 0
        for stop in stops {
            let isValid = stop.coord != nil && (stop.coord?.count ?? 0) >= 2 && stop.name != nil
            if globalIdx == highlightedStopIndex {
                return isValid ? validIdx : max(validIdx - 1, 0)
            }
            if isValid { validIdx += 1 }
            globalIdx += 1
        }
        return max(validStops.count - 1, 0)
    }
    
    private func globalIndexForName(_ name: String) -> Int? {
        var globalIdx = 0
        for stop in stops {
            if stop.name == name { return globalIdx }
            globalIdx += 1
        }
        return nil
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
}

// Custom Annotation um Index für Highlight zu speichern
final class StopAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let index: Int
    init(coordinate: CLLocationCoordinate2D, title: String?, index: Int) {
        self.coordinate = coordinate
        self.title = title
        self.index = index
    }
}

// UIKit Map: kleine Punkte, Scroll-Highlight, Tap-zu-Liste
struct RouteMapUIKitView: UIViewRepresentable {
    let stops: [RouteMapStop]
    let currentStopName: String
    var currentStopIndexInValid: Int = 0
    var highlightedIndex: Int = 0
    var onStopTapped: ((Int) -> Void)?
    
    private static let dotSize: CGFloat = 10
    private static let highlightDotSize: CGFloat = 16
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        return map
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.highlightedIndex = highlightedIndex
        context.coordinator.currentStopIndex = currentStopIndexInValid
        context.coordinator.onStopTapped = onStopTapped
        
        let needsRebuild = map.annotations.count != stops.count
        
        if needsRebuild {
            map.removeAnnotations(map.annotations)
            map.removeOverlays(map.overlays)
            
            guard !stops.isEmpty else { return }
            
            let coords = stops.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(polyline)
            
            for (index, stop) in stops.enumerated() {
                let ann = StopAnnotation(coordinate: stop.coordinate, title: stop.name, index: index)
                map.addAnnotation(ann)
            }
            
            let rect = MKMapRect(coordinates: coords)
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30), animated: false)
        } else {
            for annotation in map.annotations {
                guard let stopAnn = annotation as? StopAnnotation,
                      let view = map.view(for: stopAnn) else { continue }
                updateDotAppearance(view: view, index: stopAnn.index)
            }
        }
    }
    
    private func updateDotAppearance(view: MKAnnotationView, index: Int) {
        let isHighlighted = index == highlightedIndex
        let isCurrent = index == currentStopIndexInValid
        let isPast = index < currentStopIndexInValid
        
        let size = isHighlighted ? Self.highlightDotSize : Self.dotSize
        let color: UIColor
        if isHighlighted {
            color = .systemOrange
        } else if isCurrent {
            color = .systemRed
        } else if isPast {
            color = .systemGray
        } else {
            color = .systemBlue
        }
        
        view.frame.size = CGSize(width: size, height: size)
        view.image = Self.dotImage(color: color, size: size)
        view.centerOffset = CGPoint(x: 0, y: 0)
        view.displayPriority = .required
        view.layer.zPosition = isHighlighted ? 100 : (isCurrent ? 50 : 0)
    }
    
    static func dotImage(color: UIColor, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(1.5)
            ctx.cgContext.strokeEllipse(in: CGRect(x: 0.75, y: 0.75, width: size - 1.5, height: size - 1.5))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(currentStopIndex: currentStopIndexInValid, highlightedIndex: highlightedIndex, onStopTapped: onStopTapped)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var currentStopIndex: Int
        var highlightedIndex: Int
        var onStopTapped: ((Int) -> Void)?
        
        init(currentStopIndex: Int, highlightedIndex: Int, onStopTapped: ((Int) -> Void)?) {
            self.currentStopIndex = currentStopIndex
            self.highlightedIndex = highlightedIndex
            self.onStopTapped = onStopTapped
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: poly)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            return renderer
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? StopAnnotation else { return nil }
            let reuseId = "DotStop"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            view.annotation = annotation
            view.canShowCallout = false
            
            let isHighlighted = ann.index == highlightedIndex
            let isCurrent = ann.index == currentStopIndex
            let isPast = ann.index < currentStopIndex
            
            let size = isHighlighted ? RouteMapUIKitView.highlightDotSize : RouteMapUIKitView.dotSize
            let color: UIColor
            if isHighlighted {
                color = .systemOrange
            } else if isCurrent {
                color = .systemRed
            } else if isPast {
                color = .systemGray
            } else {
                color = .systemBlue
            }
            
            view.image = RouteMapUIKitView.dotImage(color: color, size: size)
            view.frame.size = CGSize(width: size, height: size)
            view.centerOffset = .zero
            view.displayPriority = .required
            view.layer.zPosition = isHighlighted ? 100 : (isCurrent ? 50 : 0)
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let ann = annotation as? StopAnnotation else { return }
            onStopTapped?(ann.index)
            mapView.deselectAnnotation(annotation, animated: false)
        }
    }
}

extension MKMapRect {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = .world
            return
        }
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for c in coordinates {
            let pt = MKMapPoint(c)
            minX = min(minX, pt.x); maxX = max(maxX, pt.x)
            minY = min(minY, pt.y); maxY = max(maxY, pt.y)
        }
        self = MKMapRect(x: minX, y: minY, width: max(maxX - minX, 0.001), height: max(maxY - minY, 0.001))
    }
}

struct RouteMapStop: Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
}



 