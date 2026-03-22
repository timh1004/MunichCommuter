import Foundation
import SwiftUI

// MARK: - MVG Disruptions API Response Models (/api/bgw-pt/v3/messages)

public struct DisruptionIncidentWindow: Codable, Sendable, Hashable {
    public let from: Int64
    public let to: Int64?
}

public struct DisruptionMessage: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String                    // e.g. "INCIDENT" or "SCHEDULE_CHANGE"
    public let title: String
    public let description: String
    public let publication: Int64              // unix ms
    public let validFrom: Int64               // unix ms
    /// Gesetztes Enddatum aus der API; `nil` = „offen“ / bis auf Weiteres.
    public let validToIfProvided: Int64?
    public let incidentDurations: [DisruptionIncidentWindow]?
    public let lines: [DisruptionLine]?
    public let links: [DisruptionLink]?
    public let eventTypes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, publication, validFrom, validTo, lines, links, eventTypes
        case incidentDurations
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let publication = try c.decode(Int64.self, forKey: .publication)
        let title = try c.decode(String.self, forKey: .title)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? "\(publication)-\(title)"
        self.type = try c.decode(String.self, forKey: .type)
        self.title = title
        self.description = try c.decode(String.self, forKey: .description)
        self.publication = publication
        self.validFrom = try c.decode(Int64.self, forKey: .validFrom)
        self.validToIfProvided = try c.decodeIfPresent(Int64.self, forKey: .validTo)
        self.incidentDurations = try c.decodeIfPresent([DisruptionIncidentWindow].self, forKey: .incidentDurations)
        self.lines = try c.decodeIfPresent([DisruptionLine].self, forKey: .lines)
        self.links = try c.decodeIfPresent([DisruptionLink].self, forKey: .links)
        self.eventTypes = try c.decodeIfPresent([String].self, forKey: .eventTypes)
    }

    /// Sortierung / Fallback-Anzeige, wenn die API kein `validTo` liefert.
    private static let openEndedValidToFallback: Int64 = 4_102_444_800_000

    /// Effektives Enddatum (API oder Fallback 2100).
    public var validTo: Int64 {
        validToIfProvided ?? Self.openEndedValidToFallback
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(publication, forKey: .publication)
        try c.encode(validFrom, forKey: .validFrom)
        try c.encodeIfPresent(validToIfProvided, forKey: .validTo)
        try c.encodeIfPresent(incidentDurations, forKey: .incidentDurations)
        try c.encodeIfPresent(lines, forKey: .lines)
        try c.encodeIfPresent(links, forKey: .links)
        try c.encodeIfPresent(eventTypes, forKey: .eventTypes)
    }

    public var publicationDate: Date {
        Date(timeIntervalSince1970: Double(publication) / 1000)
    }

    public var validFromDate: Date {
        Date(timeIntervalSince1970: Double(validFrom) / 1000)
    }

    public var validToDate: Date {
        Date(timeIntervalSince1970: Double(validTo) / 1000)
    }

    /// Liegt die Meldung in der gewählten Zeit **inhaltsrelevant** (API-Zeiträume + ggf. Wochentag/Uhrzeit aus dem Text)?
    public var isActive: Bool {
        isRelevantNow(at: Date())
    }

    public func isRelevantNow(at date: Date) -> Bool {
        let nowMs = Int64(date.timeIntervalSince1970 * 1000)
        let incidents = incidentDurations ?? []
        let incMin = incidents.map(\.from).min()
        let effectiveStart = max(validFrom, incMin ?? validFrom)
        guard nowMs >= effectiveStart else { return false }

        if let end = validToIfProvided, nowMs > end {
            return false
        }

        guard !incidents.isEmpty else {
            return isRelevantOpenEndedTail(nowMs: nowMs, at: date)
        }

        // API-Teilfenster ohne Endzeit: ab `from` gültig (innerhalb des Meldungszeitraums).
        for w in incidents where w.to == nil {
            if nowMs >= w.from { return true }
        }

        let bounded = incidents.compactMap { w -> (Int64, Int64)? in
            guard let t = w.to else { return nil }
            return (w.from, t)
        }

        if !bounded.isEmpty {
            if bounded.contains(where: { $0.0 <= nowMs && nowMs <= $0.1 }) {
                return true
            }
            // Nur abgeschlossene Teilintervalle, Meldung selbst aber „bis auf Weiteres“ → weiter relevant (wie MVG).
            if validToIfProvided == nil, nowMs >= validFrom, bounded.allSatisfy({ nowMs > $0.1 }) {
                return true
            }
            return false
        }

        return false
    }

    /// Nach den API-Checks ohne `incidentDurations` bzw. wenn keine Teilfenster zutreffen.
    private func isRelevantOpenEndedTail(nowMs: Int64, at date: Date) -> Bool {
        if validToIfProvided != nil {
            return true
        }
        if DisruptionRecurringScheduleParser.isLikelyRecurringScheduleDescription(description) {
            return DisruptionRecurringScheduleParser.matchesSchedule(description, at: date)
        }
        return true
    }

    public var isIncident: Bool {
        type == "INCIDENT"
    }

    public var isScheduleChange: Bool {
        type == "SCHEDULE_CHANGE" || type == "SCHEDULE_CHANGES"
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
        Set((lines ?? []).compactMap { DisruptionProductType.from(apiTransportType: $0.product) })
    }

    /// Die API liefert oft identische `lines`-Einträge mehrfach; für `ForEach` stabil dedupliziert (Reihenfolge bleibt).
    public var displayLines: [DisruptionLine] {
        guard let lines, !lines.isEmpty else { return [] }
        var seen = Set<DisruptionLine>()
        return lines.filter { seen.insert($0).inserted }
    }
}

public struct DisruptionLine: Codable, Sendable, Hashable {
    public let sev: Bool?
    /// MVG API field `transportType` (e.g. UBAHN, SBAHN, BUS, TRAM, REGIONAL_BUS).
    public let product: String
    /// MVG API field `label` (e.g. U3, S1, 535).
    public let lineNumber: String
    public let divaId: String?

    enum CodingKeys: String, CodingKey {
        case sev, divaId
        case lineNumber = "label"
        case product = "transportType"
    }
}

public struct DisruptionLink: Codable, Identifiable, Sendable, Hashable {
    public let text: String?
    public let url: String?

    public var id: String { url ?? text ?? "unknown" }

    /// Bereinigte URL (z. B. `http://https//…` aus der API → `https://…`).
    public var resolvedURL: URL? {
        guard let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return Self.normalizeURLString(raw)
    }

    public static func normalizeURLString(_ string: String) -> URL? {
        var s = string
        let lower = s.lowercased()
        if lower.hasPrefix("http://https//") {
            s = "https://" + String(s.dropFirst("http://https//".count))
        } else if lower.hasPrefix("https://https//") {
            s = "https://" + String(s.dropFirst("https://https//".count))
        } else if lower.hasPrefix("http://http//") {
            s = "http://" + String(s.dropFirst("http://http//".count))
        }
        return URL(string: s)
    }
}

// MARK: - Product Type Mapping

public enum DisruptionProductType: String, CaseIterable, Identifiable, Sendable {
    case sbahn = "SBAHN"
    case ubahn = "UBAHN"
    case tram = "TRAM"
    case bus = "BUS"
    /// Fern- und Regionalzüge (RB, RE, IC, …); API `transportType` z. B. `BAHN`.
    case bahn = "BAHN"

    public var id: String { rawValue }

    /// Maps MVG messages `transportType` string to filter categories.
    public static func from(apiTransportType: String) -> DisruptionProductType? {
        switch apiTransportType {
        case "REGIONAL_BUS": return .bus
        case "BAHN": return .bahn
        default: return DisruptionProductType(rawValue: apiTransportType)
        }
    }

    public var displayName: String {
        switch self {
        case .sbahn: return "S-Bahn"
        case .ubahn: return "U-Bahn"
        case .tram: return "Tram"
        case .bus: return "Bus"
        case .bahn: return "Bahn"
        }
    }

    public var icon: String {
        switch self {
        case .sbahn, .ubahn, .tram: return "tram.fill"
        case .bus: return "bus.fill"
        case .bahn: return "train.side.front.car"
        }
    }

    public var color: Color {
        switch self {
        case .sbahn: return Color(red: 0/255, green: 142/255, blue: 78/255)
        case .ubahn: return Color(red: 0/255, green: 78/255, blue: 143/255)
        case .tram: return Color(red: 217/255, green: 26/255, blue: 26/255)
        case .bus: return Color(red: 0/255, green: 87/255, blue: 106/255)
        case .bahn: return Color(red: 50/255, green: 54/255, blue: 127/255)
        }
    }
}

// MARK: - Message Type

public enum DisruptionMessageType: String, CaseIterable, Identifiable, Sendable {
    case incident = "INCIDENT"
    case scheduleChange = "SCHEDULE_CHANGE"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .incident: return "Störungen"
        case .scheduleChange: return "Fahrplanänderungen"
        }
    }

    public var color: Color {
        switch self {
        case .incident: return .red
        case .scheduleChange: return .orange
        }
    }
}
