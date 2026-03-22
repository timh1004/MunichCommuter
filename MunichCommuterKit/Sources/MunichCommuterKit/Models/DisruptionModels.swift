import Foundation
import SwiftUI

// MARK: - MVG Disruptions API Response Models (/api/bgw-pt/v3/messages)

public struct DisruptionMessage: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String                    // "INCIDENT" or "SCHEDULE_CHANGES"
    public let title: String
    public let description: String
    public let publication: Int64              // unix ms
    public let validFrom: Int64               // unix ms
    public let validTo: Int64                 // unix ms
    public let lines: [DisruptionLine]?
    public let links: [DisruptionLink]?
    public let eventTypes: [String]?

    public var publicationDate: Date {
        Date(timeIntervalSince1970: Double(publication) / 1000)
    }

    public var validFromDate: Date {
        Date(timeIntervalSince1970: Double(validFrom) / 1000)
    }

    public var validToDate: Date {
        Date(timeIntervalSince1970: Double(validTo) / 1000)
    }

    public var isActive: Bool {
        let now = Date()
        return validFromDate <= now && now <= validToDate
    }

    public var isIncident: Bool {
        type == "INCIDENT"
    }

    /// Strip HTML tags from description for plain-text display.
    public var cleanDescription: String {
        var text = description
        // Replace <br>, <br/>, <br /> with newline
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        // Strip remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var affectedProducts: Set<DisruptionProductType> {
        Set((lines ?? []).compactMap { DisruptionProductType(rawValue: $0.product) })
    }
}

public struct DisruptionLine: Codable, Sendable, Hashable {
    public let sev: Bool?
    public let product: String                // "UBAHN", "SBAHN", "BUS", "TRAM"
    public let lineNumber: String             // "U3", "S1", etc.
    public let divaId: String?
}

public struct DisruptionLink: Codable, Identifiable, Sendable, Hashable {
    public let text: String?
    public let url: String?

    public var id: String { url ?? text ?? "unknown" }
}

// MARK: - Product Type Mapping

public enum DisruptionProductType: String, CaseIterable, Identifiable, Sendable {
    case sbahn = "SBAHN"
    case ubahn = "UBAHN"
    case tram = "TRAM"
    case bus = "BUS"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sbahn: return "S-Bahn"
        case .ubahn: return "U-Bahn"
        case .tram: return "Tram"
        case .bus: return "Bus"
        }
    }

    public var icon: String {
        switch self {
        case .sbahn, .ubahn, .tram: return "tram.fill"
        case .bus: return "bus.fill"
        }
    }

    public var color: Color {
        switch self {
        case .sbahn: return Color(red: 0/255, green: 142/255, blue: 78/255)
        case .ubahn: return Color(red: 0/255, green: 78/255, blue: 143/255)
        case .tram: return Color(red: 217/255, green: 26/255, blue: 26/255)
        case .bus: return Color(red: 0/255, green: 87/255, blue: 106/255)
        }
    }
}

// MARK: - Message Type

public enum DisruptionMessageType: String, CaseIterable, Identifiable, Sendable {
    case incident = "INCIDENT"
    case scheduleChanges = "SCHEDULE_CHANGES"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .incident: return "Störungen"
        case .scheduleChanges: return "Fahrplanänderungen"
        }
    }

    public var color: Color {
        switch self {
        case .incident: return .red
        case .scheduleChanges: return .orange
        }
    }
}
