import SwiftUI
import Foundation

public struct DepartureRowStyling {

    // MARK: - Main Line Color Logic
    public static func lineColor(for departure: StopEvent) -> Color {
        guard let productClass = departure.transportation?.product?.productClass else {
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        }

        switch productClass {
        case 1: return sBahnLineColor(for: departure)
        case 2: return uBahnLineColor(for: departure)
        case 4: return Color(red: 0.8, green: 0.0, blue: 0.0)
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.8)
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    // MARK: - S-Bahn Specific Colors
    public static func sBahnLineColor(for departure: StopEvent) -> Color {
        guard let lineNumber = departure.transportation?.number else {
            return Color(red: 22/255, green: 192/255, blue: 233/255)
        }

        switch lineNumber {
        case "S1": return Color(red: 22/255, green: 192/255, blue: 233/255)
        case "S2": return Color(red: 113/255, green: 191/255, blue: 68/255)
        case "S3": return Color(red: 123/255, green: 16/255, blue: 125/255)
        case "S4": return Color(red: 238/255, green: 28/255, blue: 37/255)
        case "S6": return Color(red: 0/255, green: 138/255, blue: 81/255)
        case "S7": return Color(red: 150/255, green: 56/255, blue: 51/255)
        case "S8": return Color(red: 255/255, green: 203/255, blue: 6/255)
        case "S20": return Color(red: 240/255, green: 90/255, blue: 115/255)
        default: return Color(red: 22/255, green: 192/255, blue: 233/255)
        }
    }

    // MARK: - U-Bahn Specific Colors
    public static func uBahnLineColor(for departure: StopEvent) -> Color {
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

    // MARK: - Time Display Logic
    public static func shouldShowOrange(for departure: StopEvent) -> Bool {
        let timeString = departure.departureTimePlanned ?? departure.departureTimeEstimated ?? ""
        guard let departureDate = Date.parseISO8601(timeString) else {
            return false
        }
        let minutesFromNow = departureDate.minutesFromNow()
        return minutesFromNow <= 1
    }

    // MARK: - Transport Type Name
    public static func transportTypeName(for departure: StopEvent) -> String {
        return departure.transportation?.product?.name ?? "Zug"
    }

    // MARK: - Formatted Departure Time
    public static func formattedDepartureTime(for departure: StopEvent, mode: TimeDisplayMode = .relative, referenceDate: Date = Date()) -> String {
        let (timeDisplay, _) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated,
            includeDelay: true,
            mode: mode,
            referenceDate: referenceDate
        )
        return timeDisplay
    }

    // MARK: - Delay Display
    public static func delayDisplay(for departure: StopEvent) -> String? {
        let (_, delayDisplay) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated,
            includeDelay: true,
            mode: .relative
        )
        return delayDisplay
    }

    // MARK: - Realtime Status
    public static func isRealtime(for departure: StopEvent) -> Bool {
        return departure.isRealtimeControlled == true
    }

    // MARK: - Line Color by String (for Disruptions)

    /// Returns the MVG line color for a given line number and product type string.
    /// Used by DisruptionLineBadge where we don't have a StopEvent.
    public static func lineColorForNumber(_ lineNumber: String, product: String) -> Color {
        switch product {
        case "SBAHN":
            return sBahnColorForNumber(lineNumber)
        case "UBAHN":
            return uBahnColorForNumber(lineNumber)
        case "TRAM":
            return Color(red: 0.8, green: 0.0, blue: 0.0)
        case "BUS":
            return Color(red: 0/255, green: 87/255, blue: 106/255)
        default:
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }

    private static func sBahnColorForNumber(_ lineNumber: String) -> Color {
        switch lineNumber {
        case "S1": return Color(red: 22/255, green: 192/255, blue: 233/255)
        case "S2": return Color(red: 113/255, green: 191/255, blue: 68/255)
        case "S3": return Color(red: 123/255, green: 16/255, blue: 125/255)
        case "S4": return Color(red: 238/255, green: 28/255, blue: 37/255)
        case "S6": return Color(red: 0/255, green: 138/255, blue: 81/255)
        case "S7": return Color(red: 150/255, green: 56/255, blue: 51/255)
        case "S8": return Color(red: 255/255, green: 203/255, blue: 6/255)
        case "S20": return Color(red: 240/255, green: 90/255, blue: 115/255)
        default: return Color(red: 22/255, green: 192/255, blue: 233/255)
        }
    }

    private static func uBahnColorForNumber(_ lineNumber: String) -> Color {
        switch lineNumber {
        case "U1": return Color(red: 0.0, green: 0.7, blue: 0.0)
        case "U2": return Color(red: 0.9, green: 0.0, blue: 0.0)
        case "U3": return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "U4": return Color(red: 0.0, green: 0.8, blue: 0.8)
        case "U5": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "U6": return Color(red: 0.0, green: 0.4, blue: 0.8)
        case "U7": return Color(red: 0.0, green: 0.7, blue: 0.0)
        case "U8": return Color(red: 0.9, green: 0.0, blue: 0.0)
        default: return Color(red: 0.0, green: 0.4, blue: 0.8)
        }
    }
}

// MARK: - Shared Transport Badge Component
public struct TransportBadge: View {
    public let departure: StopEvent
    public let size: BadgeSize

    public enum BadgeSize {
        case normal
        case compact

        public var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .normal: return (48, 32)
            case .compact: return (32, 20)
            }
        }

        public var fontSize: CGFloat {
            switch self {
            case .normal: return 16
            case .compact: return 10
            }
        }

        public var cornerRadius: CGFloat {
            switch self {
            case .normal: return 8
            case .compact: return 4
            }
        }
    }

    public init(departure: StopEvent, size: BadgeSize) {
        self.departure = departure
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(DepartureRowStyling.lineColor(for: departure))
                .frame(width: size.dimensions.width, height: size.dimensions.height)

            Text(departure.transportation?.number ?? "?")
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .accessibilityLabel("\(DepartureRowStyling.transportTypeName(for: departure)) \(departure.transportation?.number ?? "")")
    }
}

// MARK: - Reusable Realtime Badge
public struct RealtimeBadge: View {
    public let isRealtime: Bool

    public init(isRealtime: Bool) {
        self.isRealtime = isRealtime
    }

    public var body: some View {
        Group {
            if isRealtime {
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .accessibilityLabel("Echtzeitdaten verfügbar")
            }
        }
    }
}

// MARK: - Disruption Line Badge Component
public struct DisruptionLineBadge: View {
    public let line: DisruptionLine

    public init(line: DisruptionLine) {
        self.line = line
    }

    public var body: some View {
        Text(line.lineNumber)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DepartureRowStyling.lineColorForNumber(line.lineNumber, product: line.product))
            )
            .accessibilityLabel("\(line.product) \(line.lineNumber)")
    }
}
