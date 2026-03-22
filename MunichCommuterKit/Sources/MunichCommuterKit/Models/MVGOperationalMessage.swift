import Foundation

// MARK: - MVG Betriebsmeldungen (bgw-pt /v3/messages)

public struct MVGOperationalMessage: Codable, Sendable, Identifiable {
    public let title: String
    public let description: String
    public let publication: Int64
    public let publicationDuration: MVGTimeRange?
    public let incidentDurations: [MVGTimeRange]?
    public let validFrom: Int64?
    public let validTo: Int64?
    public let type: String?
    public let provider: String?
    public let links: [MVGOperationalMessageLink]?
    public let lines: [MVGOperationalMessageLine]?
    public let stationGlobalIds: [String]?

    public var id: String {
        "\(publication)_\(validFrom ?? 0)_\(validTo ?? 0)_\(title)"
    }

    /// Deduplizierte Linien-Einträge (die API liefert oft Duplikate).
    public var uniqueLines: [MVGOperationalMessageLine] {
        guard let lines, !lines.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [MVGOperationalMessageLine] = []
        for line in lines {
            let key = "\(line.label)|\(line.transportType ?? "")|\(line.network ?? "")"
            if seen.insert(key).inserted {
                result.append(line)
            }
        }
        return result
    }

    public func affectsFavoriteStations(_ favoriteStationIds: Set<String>) -> Bool {
        guard let stationGlobalIds, !stationGlobalIds.isEmpty else { return false }
        let normalizedFavorites = Set(favoriteStationIds.map(\.normalizedStationId))
        return stationGlobalIds.contains { normalizedFavorites.contains($0.normalizedStationId) }
    }
}

public struct MVGTimeRange: Codable, Sendable, Hashable {
    public let from: Int64?
    public let to: Int64?
}

public struct MVGOperationalMessageLink: Codable, Sendable, Hashable {
    public let text: String?
    public let url: String?
}

public struct MVGOperationalMessageLine: Codable, Sendable, Hashable {
    public let label: String
    public let transportType: String?
    public let network: String?
    public let divaId: String?
    public let sev: Bool?
}
