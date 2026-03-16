import SwiftUI
import WidgetKit
import CoreLocation
import OSLog
import MunichCommuterKit

private let logger = Logger(subsystem: "com.iaha.mvgcommuter", category: "WatchWidget")

// MARK: - WatchWidgetDeparture

struct WatchWidgetDeparture: Identifiable, Sendable {
    let id: UUID
    let lineNumber: String
    let lineColor: Color
    let destination: String
    let departureDate: Date?
}

// MARK: - CommuterEntry

struct CommuterEntry: TimelineEntry {
    let date: Date
    let stationName: String?
    let filterDescription: String?
    let departures: [WatchWidgetDeparture]
    let deepLinkURL: URL?
    let errorMessage: String?

    /// Smart Stack relevance: high when the next departure is within 15 minutes of this entry's date.
    var relevance: TimelineEntryRelevance? {
        guard let depDate = departures.first?.departureDate else { return nil }
        let minutesFromEntry = depDate.timeIntervalSince(date) / 60
        guard minutesFromEntry >= 0, minutesFromEntry <= 15 else { return nil }
        let score = Float((15.0 - minutesFromEntry) / 15.0) * 100
        return TimelineEntryRelevance(score: score, duration: depDate.timeIntervalSince(date))
    }

    static var placeholder: CommuterEntry {
        let now = Date()
        return CommuterEntry(
            date: now,
            stationName: "Marienplatz",
            filterDescription: nil,
            departures: [
                WatchWidgetDeparture(
                    id: UUID(),
                    lineNumber: "U3",
                    lineColor: Color(red: 1.0, green: 0.6, blue: 0.0),
                    destination: "Moosach",
                    departureDate: now.addingTimeInterval(3 * 60)
                ),
                WatchWidgetDeparture(
                    id: UUID(),
                    lineNumber: "U6",
                    lineColor: Color(red: 0.0, green: 0.4, blue: 0.8),
                    destination: "Garching Forschungszentrum",
                    departureDate: now.addingTimeInterval(8 * 60)
                )
            ],
            deepLinkURL: nil,
            errorMessage: nil
        )
    }
}

// MARK: - CommuterTimelineProvider

struct CommuterTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> CommuterEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CommuterEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommuterEntry>) -> Void) {
        Task {
            let now = Date()
            // Refresh after 60 minutes — the timeline covers the same window.
            let refreshDate = now.addingTimeInterval(3600)

            // 1. Favorites from iCloud Key-Value Store
            let favorites = loadFavoritesFromCloudStore()
            guard !favorites.isEmpty else {
                logger.warning("No favorites found in KVS")
                let entry = CommuterEntry(
                    date: now, stationName: nil, filterDescription: nil,
                    departures: [], deepLinkURL: nil,
                    errorMessage: "Keine Favoriten gespeichert."
                )
                completion(Timeline(entries: [entry], policy: .after(refreshDate)))
                return
            }

            // 2. Nearest favorite by current location
            let location = await fetchLocationWithTimeout()
            let coord = location.map { [$0.coordinate.latitude, $0.coordinate.longitude] } ?? []
            logger.info("Coord for nearest lookup: \(coord)")

            guard let fav = nearestFavorite(to: coord, among: favorites) else {
                let entry = CommuterEntry(
                    date: now, stationName: nil, filterDescription: nil,
                    departures: [], deepLinkURL: nil,
                    errorMessage: "Kein Favorit in der Nähe."
                )
                completion(Timeline(entries: [entry], policy: .after(refreshDate)))
                return
            }

            let locationId = fav.location.id.normalizedStationId
            let stationName = fav.location.disassembledName ?? fav.location.name ?? "Haltestelle"
            let deepLinkURL = URL(string: "munichcommuter://station/\(locationId)?favoriteId=\(fav.id.uuidString)")
            logger.info("Nearest favorite: \(stationName, privacy: .public) (\(locationId, privacy: .public))")

            // 3. Fetch departures and build timeline
            do {
                let allDepartures = try await fetchDepartures(locationId: locationId)

                let filtered = FilteringHelper.getFilteredDepartures(
                    departures: allDepartures,
                    destinationFilters: fav.destinationFilters ?? [],
                    platformFilters: fav.platformFilters ?? [],
                    transportTypeFilters: fav.transportTypeFilters ?? []
                )

                // Only keep departures within the 60-minute window
                let upcoming: [WatchWidgetDeparture] = filtered.compactMap { event in
                    let planned = event.departureTimePlanned.flatMap { Date.parseISO8601($0) }
                    let estimated = event.departureTimeEstimated.flatMap { Date.parseISO8601($0) }
                    let depDate = estimated ?? planned
                    guard let d = depDate,
                          d >= now.addingTimeInterval(-60),
                          d <= refreshDate else { return nil }
                    return WatchWidgetDeparture(
                        id: UUID(),
                        lineNumber: event.transportation?.number ?? event.transportation?.name ?? "?",
                        lineColor: DepartureRowStyling.lineColor(for: event),
                        destination: event.transportation?.destination?.name ?? "Unbekannt",
                        departureDate: d
                    )
                }

                // Build entry dates: start at now, then 5 s after each departure fires.
                // This ensures the departure list refreshes exactly when a train leaves.
                var entryDates: [Date] = [now]
                for dep in upcoming.prefix(20) {
                    if let d = dep.departureDate, d > now {
                        let trigger = d.addingTimeInterval(5)
                        if !entryDates.contains(where: { abs($0.timeIntervalSince(trigger)) < 15 }) {
                            entryDates.append(trigger)
                        }
                    }
                }
                entryDates.sort()

                let entries: [CommuterEntry] = entryDates.map { entryDate in
                    let visible = Array(
                        upcoming
                            .filter { ($0.departureDate ?? .distantFuture) >= entryDate }
                            .prefix(3)
                    )
                    return CommuterEntry(
                        date: entryDate,
                        stationName: stationName,
                        filterDescription: fav.filterDisplayText,
                        departures: visible,
                        deepLinkURL: deepLinkURL,
                        errorMessage: nil
                    )
                }

                logger.info("Timeline built: \(entries.count) entries, \(upcoming.count) departures loaded")
                completion(Timeline(entries: entries, policy: .after(refreshDate)))

            } catch {
                logger.error("Failed to fetch departures: \(error.localizedDescription)")
                let entry = CommuterEntry(
                    date: now,
                    stationName: stationName,
                    filterDescription: fav.filterDisplayText,
                    departures: [],
                    deepLinkURL: deepLinkURL,
                    errorMessage: "Fehler beim Laden."
                )
                completion(Timeline(entries: [entry], policy: .after(refreshDate)))
            }
        }
    }
}

// MARK: - Location helper

private func fetchLocationWithTimeout(timeout: TimeInterval = 5) async -> CLLocation? {
    let manager = CLLocationManager()
    if let cached = manager.location {
        let age = -cached.timestamp.timeIntervalSinceNow
        logger.info("Cached location age: \(Int(age))s")
        if age < 600 { return cached }
    }

    logger.info("Requesting live location via CLLocationUpdate.liveUpdates()")
    return await withTaskGroup(of: CLLocation?.self) { group in
        group.addTask {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location }
                }
            } catch {
                logger.warning("CLLocationUpdate failed: \(error.localizedDescription)")
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}

// MARK: - Departure row view

private struct WatchDepartureRowView: View {
    let departure: WatchWidgetDeparture

    var body: some View {
        HStack(spacing: 4) {
            Text(departure.lineNumber)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(departure.lineColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .frame(minWidth: 24)

            Text(departure.destination)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let date = departure.departureDate {
                // Text(date, style: .offset) auto-updates live without needing per-minute entries.
                // Shows "in 3 Min." (German) — compact and always accurate.
                Text(date, style: .offset)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(date.timeIntervalSinceNow < 90 ? Color.orange : Color.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Complication views

private struct RectangularView: View {
    let entry: CommuterEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let error = entry.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let name = entry.stationName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .widgetAccentable()

                if entry.departures.isEmpty {
                    Text("Keine Abfahrten")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.departures.prefix(2)) { dep in
                        WatchDepartureRowView(departure: dep)
                    }
                }
            } else {
                Label("MunichCommuter", systemImage: "tram.fill")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CircularView: View {
    let entry: CommuterEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let dep = entry.departures.first {
                VStack(spacing: 0) {
                    Text(dep.lineNumber)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(dep.lineColor)
                        .widgetAccentable()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let date = dep.departureDate {
                        // .timer shows a compact countdown like "4:32"
                        Text(date, style: .timer)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(2)
            } else {
                Image(systemName: "tram.fill")
                    .font(.title3)
            }
        }
    }
}

private struct InlineView: View {
    let entry: CommuterEntry

    var body: some View {
        if let dep = entry.departures.first,
           let name = entry.stationName,
           let date = dep.departureDate {
            Label {
                Text("\(name) \(dep.lineNumber) ") + Text(date, style: .offset)
            } icon: {
                Image(systemName: "tram.fill")
            }
        } else {
            Label("Abfahrten", systemImage: "tram.fill")
        }
    }
}

private struct CornerView: View {
    let entry: CommuterEntry

    var body: some View {
        if let dep = entry.departures.first, let date = dep.departureDate {
            Image(systemName: "tram.fill")
                .widgetLabel {
                    Text(dep.lineNumber) + Text(" ") + Text(date, style: .offset)
                }
        } else {
            Image(systemName: "tram.fill")
                .widgetLabel("Abfahrten")
        }
    }
}

// MARK: - Entry view

struct CommuterWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CommuterEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularView(entry: entry)
            case .accessoryRectangular:
                RectangularView(entry: entry)
            case .accessoryInline:
                InlineView(entry: entry)
            case .accessoryCorner:
                CornerView(entry: entry)
            @unknown default:
                CircularView(entry: entry)
            }
        }
        .widgetURL(entry.deepLinkURL)
    }
}

// MARK: - Widget

struct MunichCommuterWidget: Widget {
    let kind = "MunichCommuterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommuterTimelineProvider()) { entry in
            CommuterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Abfahrten")
        .description("Zeigt Abfahrten deines nächsten Favoriten.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

@main
struct MunichCommuterWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MunichCommuterWidget()
    }
}
