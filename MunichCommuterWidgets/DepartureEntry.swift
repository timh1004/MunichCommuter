import SwiftUI
import WidgetKit
import MunichCommuterKit

// MARK: - WidgetDeparture

struct WidgetDeparture: Identifiable, Sendable {
    let id: UUID
    let lineNumber: String
    let lineBadgeAppearance: LineBadgeAppearance
    let destination: String
    let plannedDate: Date?
    let estimatedDate: Date?
    let platform: String?
    let isRealtime: Bool

    /// The best available departure date for countdown display.
    var departureDate: Date? { estimatedDate ?? plannedDate }

    /// True if departure is more than 1 minute in the past.
    var hasDeparted: Bool {
        guard let date = departureDate else { return false }
        return date.timeIntervalSinceNow < -60
    }

    static func from(_ stopEvent: StopEvent) -> WidgetDeparture {
        let plannedDate = stopEvent.departureTimePlanned.flatMap { Date.parseISO8601($0) }
        let estimatedDate = stopEvent.departureTimeEstimated.flatMap { Date.parseISO8601($0) }
        let platform = PlatformHelper.effectivePlatform(from: stopEvent.location?.properties)

        return WidgetDeparture(
            id: UUID(),
            lineNumber: stopEvent.transportation?.number ?? stopEvent.transportation?.name ?? "?",
            lineBadgeAppearance: DepartureRowStyling.lineBadgeAppearance(for: stopEvent),
            destination: stopEvent.transportation?.destination?.name ?? "Unbekannt",
            plannedDate: plannedDate,
            estimatedDate: estimatedDate,
            platform: platform,
            isRealtime: DepartureRowStyling.isRealtime(for: stopEvent)
        )
    }
}

// MARK: - DepartureEntry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let fetchedAt: Date
    let stationName: String
    let filterDescription: String?
    let departures: [WidgetDeparture]
    let deepLinkURL: URL?
    let errorMessage: String?
    let configuration: SelectFavoriteIntent

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 600
    }

    static func placeholder(configuration: SelectFavoriteIntent) -> DepartureEntry {
        let now = Date()
        let placeholderDepartures = [
            WidgetDeparture(
                id: UUID(),
                lineNumber: "S1",
                lineBadgeAppearance: DepartureRowStyling.lineBadgeAppearance(lineNumber: "S1", apiProduct: "SBAHN"),
                destination: "Ostbahnhof",
                plannedDate: now.addingTimeInterval(3 * 60),
                estimatedDate: now.addingTimeInterval(3 * 60),
                platform: "1",
                isRealtime: true
            ),
            WidgetDeparture(
                id: UUID(),
                lineNumber: "U3",
                lineBadgeAppearance: DepartureRowStyling.lineBadgeAppearance(lineNumber: "U3", apiProduct: "UBAHN"),
                destination: "Moosach",
                plannedDate: now.addingTimeInterval(7 * 60),
                estimatedDate: now.addingTimeInterval(8 * 60),
                platform: "2",
                isRealtime: true
            ),
            WidgetDeparture(
                id: UUID(),
                lineNumber: "18",
                lineBadgeAppearance: DepartureRowStyling.lineBadgeAppearance(lineNumber: "18", apiProduct: "BUS"),
                destination: "Gondrellplatz",
                plannedDate: now.addingTimeInterval(12 * 60),
                estimatedDate: now.addingTimeInterval(12 * 60),
                platform: nil,
                isRealtime: false
            ),
            WidgetDeparture(
                id: UUID(),
                lineNumber: "S8",
                lineBadgeAppearance: DepartureRowStyling.lineBadgeAppearance(lineNumber: "S8", apiProduct: "SBAHN"),
                destination: "Flughafen München",
                plannedDate: now.addingTimeInterval(18 * 60),
                estimatedDate: now.addingTimeInterval(20 * 60),
                platform: "3",
                isRealtime: true
            )
        ]
        return DepartureEntry(
            date: now,
            fetchedAt: now,
            stationName: "Marienplatz",
            filterDescription: nil,
            departures: placeholderDepartures,
            deepLinkURL: nil,
            errorMessage: nil,

            configuration: configuration
        )
    }

    static func error(message: String, configuration: SelectFavoriteIntent) -> DepartureEntry {
        DepartureEntry(
            date: .now,
            fetchedAt: .now,
            stationName: "Keine Station",
            filterDescription: nil,
            departures: [],
            deepLinkURL: nil,
            errorMessage: message,

            configuration: configuration
        )
    }
}
