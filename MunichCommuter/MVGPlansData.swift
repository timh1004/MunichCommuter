import Foundation
import SwiftUI

struct MVGNetworkPlan: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let url: URL
    let icon: String
    let category: PlanCategory
    
    enum PlanCategory: String, CaseIterable {
        case netzplaene = "Netzpläne"
        case linienplaene = "Linien & Tarif"
        case barrierefreiheit = "Barrierefreiheit"
        
        var color: Color {
            switch self {
            case .netzplaene:
                return Color(red: 0/255, green: 101/255, blue: 189/255)
            case .linienplaene:
                return Color(red: 0/255, green: 142/255, blue: 78/255)
            case .barrierefreiheit:
                return Color(red: 0/255, green: 87/255, blue: 106/255)
            }
        }
    }
}

struct MVGStationPlan: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: String
}

struct MVGPlansData {
    
    // MARK: - Network Plans
    
    /// Netzpläne – URLs von https://www.mvg.de/verbindungen/fahrplaene-netzplaene.html (Stand 2026)
    static let networkPlans: [MVGNetworkPlan] = [
        MVGNetworkPlan(
            name: "Netz- & Tarifplan Zone M",
            subtitle: "MVV-Netz Innenstadt – der wichtigste Plan",
            url: URL(string: "https://www.mvg.de/dam/jcr:e9fbaf6f-4ec1-40de-8488-a75787ddbf50/2026_layout_SURTX_M.pdf")!,
            icon: "map.fill",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Netz- und Tarifplan Zone M-12",
            subtitle: "S-Bahn, U-Bahn, Regionalzug",
            url: URL(string: "https://www.mvg.de/dam/jcr:466d44bf-e754-460b-95d0-69364ab9cd93/2026_layout_SUR_M_12.pdf")!,
            icon: "map.circle.fill",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "U-Bahnnetz",
            subtitle: "Alle U-Bahn-Linien",
            url: URL(string: "https://www.mvg.de/dam/jcr:d65f2a96-acb2-49a6-a33f-2b6faf79f6a0/A4-U-Bahnnetz-2025-BAU-IP96-Web.pdf")!,
            icon: "tram.fill",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Tramnetz",
            subtitle: "Alle Tramlinien in München",
            url: URL(string: "https://www.mvg.de/dam/jcr:d01df598-a358-44ad-9c35-3984488c036c/A4-Tramnetz-2026-Web.pdf")!,
            icon: "tram",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Nachtlinien",
            subtitle: "Nacht-U-Bahn, -Tram & -Bus",
            url: URL(string: "https://www.mvg.de/dam/jcr:f284bcc9-3751-4388-9a2e-b6e8917999b1/A4-Nachtnetz-2026-Web.pdf")!,
            icon: "moon.stars.fill",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Netz- und Tarifplan Zone M-5",
            subtitle: "Erweitertes Stadtgebiet",
            url: URL(string: "https://www.mvg.de/dam/jcr:bb478190-c72c-45dc-8bfd-630767abe696/2026_layout_SUR_M_5.pdf")!,
            icon: "map.circle.fill",
            category: .linienplaene
        ),
        MVGNetworkPlan(
            name: "Barrierefreie Haltestellen",
            subtitle: "Aufzüge & stufenfreier Zugang",
            url: URL(string: "https://www.mvg.de/dam/jcr:3b2aed67-ada3-418e-8422-6d088a07e156/barrierefrei.pdf")!,
            icon: "figure.roll",
            category: .barrierefreiheit
        ),
    ]
    
    // MARK: - MVG Meinhalt URL
    
    static func meinhaltURL(for stationName: String) -> URL? {
        let slug = stationSlug(from: stationName)
        guard !slug.isEmpty else { return nil }
        return URL(string: "https://www.mvg.de/meinhalt/\(slug)")
    }
    
    static func stationSlug(from name: String) -> String {
        var slug = name.lowercased()
        
        let replacements: [(String, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"),
        ]
        for (from, to) in replacements {
            slug = slug.replacingOccurrences(of: from, with: to)
        }
        
        slug = slug.replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "'", with: "")
        
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        slug = slug.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "-" }
            .joined()
        
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        return slug
    }
    
    // MARK: - Umgebungsplan & Aushang-API (offizielle URLs)
    
    /// Fallback-URL für Umgebungsplan, wenn Aushang-API nicht genutzt wird (P8_H = CONTEXT_MAP).
    static func umgebungsplanFallbackURL(for stationCode: String) -> URL? {
        guard !stationCode.isEmpty else { return nil }
        return URL(string: "https://www.mvg.de/aushangfahrplan/P8_H_\(stationCode)_0.pdf")
    }
    
    /// Eintrag aus der Aushang-API: https://www.mvg.de/.rest/aushang/stations?id={abbreviation}
    struct AushangEntry: Codable, Identifiable {
        let uri: String
        let scheduleKind: String  // CONTEXT_MAP, STATION_OVERVIEW_MAP, SUBWAY, TRAM, BUS, NIGHT_LINE
        let scheduleName: String
        let direction: String?
        
        var id: String { uri }
        var url: URL? { URL(string: uri) }
        
        /// Anzeigename je nach scheduleKind
        var displayTitle: String {
            switch scheduleKind {
            case "CONTEXT_MAP": return "Umgebungsplan"
            case "STATION_OVERVIEW_MAP": return "Haltestellen-Übersicht Bus/Tram"
            default: return scheduleName
            }
        }
        
        var displaySubtitle: String? {
            if scheduleKind == "CONTEXT_MAP" || scheduleKind == "STATION_OVERVIEW_MAP" { return nil }
            return direction
        }
        
        var icon: String {
            switch scheduleKind {
            case "CONTEXT_MAP": return "map.fill"
            case "STATION_OVERVIEW_MAP": return "list.bullet.rectangle.fill"
            case "SUBWAY": return "tram.fill"
            case "TRAM": return "tram.fill"
            case "BUS": return "bus.fill"
            case "NIGHT_LINE": return "moon.stars.fill"
            default: return "doc.text.fill"
            }
        }
    }
    
    /// Lädt alle Pläne (Umgebungsplan, Linienfahrpläne etc.) für eine Station per Abkürzung.
    static func fetchAushangPlans(abbreviation: String) async -> [AushangEntry] {
        guard !abbreviation.isEmpty,
              let url = URL(string: "https://www.mvg.de/.rest/aushang/stations?id=\(abbreviation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? abbreviation)") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("https://www.mvg.de/meinhalt", forHTTPHeaderField: "referer")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode([AushangEntry].self, from: data)
            return decoded
        } catch {
            return []
        }
    }
    
    // MARK: - ZDM Station API (Abkürzung für Aushang-API)
    
    /// Response from MVG ZDM station API: https://www.mvg.de/.rest/zdm/stations/{locationId}
    private struct ZDMStationResponse: Codable {
        let abbreviation: String?
    }
    
    /// Fetches the station abbreviation (e.g. "SE" for Sendlinger Tor) from MVG’s ZDM API.
    /// Use with fetchAushangPlans(abbreviation:) to get Umgebungsplan and line schedules.
    static func fetchStationAbbreviation(locationId: String) async -> String? {
        let path = locationId.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: ":"))) ?? locationId
        guard let url = URL(string: "https://www.mvg.de/.rest/zdm/stations/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("https://www.mvg.de/meinhalt", forHTTPHeaderField: "referer")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(ZDMStationResponse.self, from: data)
            return decoded.abbreviation
        } catch {
            return nil
        }
    }
    
    /// Maps U-Bahn station names (disassembledName from the API) to their two-letter codes
    /// used in the MVG Aushangfahrplan URL scheme: https://www.mvg.de/aushangfahrplan/P8_H_[CODE]_0.pdf
    /// There is no official API for these codes; they are derived from MVG’s published PDF URLs
    /// and may need updating if MVG changes filenames. Verified examples: RO=Rotkreuzplatz, HU=Hauptbahnhof, SE=Sendlinger Tor.
    static let uBahnStationCodes: [String: String] = [
        // U1 (codes verified against mvg.de/aushangfahrplan P8_H_*_0.pdf)
        "Olympia-Einkaufszentrum": "OE",
        "Georg-Brauchle-Ring": "GB",
        "Westfriedhof": "WF",
        "Gern": "GE",
        "Rotkreuzplatz": "RO",
        "Rot-Kreuz-Platz": "RO",
        "Maillingerstraße": "ML",
        "Stiglmaierplatz": "SM",
        "Hauptbahnhof": "HU",
        "Sendlinger Tor": "SE",
        "Fraunhoferstraße": "FR",
        "Fraunhofer Straße": "FR",
        "Kolumbusplatz": "KO",
        "Silberhornstraße": "SH",
        "Wettersteinplatz": "WS",
        "Candidplatz": "CP",
        "Mangfallplatz": "MF",
        
        // U2
        "Feldmoching": "FM",
        "Hasenbergl": "HG",
        "Dülferstraße": "DF",
        "Harthof": "HK",
        "Am Hart": "HA",
        "Frankfurter Ring": "FK",
        "Milbertshofen": "MB",
        "Scheidplatz": "SC",
        "Hohenzollernplatz": "HZ",
        "Josephsplatz": "JP",
        "Theresienstraße": "TH",
        "Königsplatz": "KP",
        "Untersbergstraße": "UP",
        "Giesing": "GG",
        "Karl-Preis-Platz": "KA",
        "Innsbrucker Ring": "IG",  // P8_H may not exist; IG 404
        "Josephsburg": "JO",
        "Kreillerstraße": "KD",
        "Trudering": "TK",
        "Moosfeld": "MO",
        "Messestadt West": "MS",
        "Messestadt Ost": "ME",
        
        // U3
        "Moosach": "MA",
        "Olympiazentrum": "OZ",
        "Oberwiesenfeld": "ON",
        "Petuelring": "PS",  // 404
        "Bonner Platz": "BP",
        "Münchner Freiheit": "MU",
        "Giselastraße": "GI",
        "Universität": "UN",
        "Odeonsplatz": "OU",
        "Marienplatz": "MP",
        "Goetheplatz": "GK",
        "Poccistraße": "PC",
        "Implerstraße": "IP",
        "Brudermühlstraße": "BL",
        "Thalkirchen": "TS",  // 404
        "Obersendling": "OS",
        "Aidenbachstraße": "AB",
        "Basler Straße": "BA",
        "Fürstenried West": "FW",
        
        // U4
        "Arabellapark": "AR",
        "Böhmerwaldplatz": "BO",
        "Richard-Strauss-Straße": "RS",
        "Prinzregentenplatz": "PZ",
        "Max-Weber-Platz": "MW",
        "Lehel": "LH",
        "Schwanthalerhöhe": "SW",  // 404
        "Westendstraße": "WH",  // 404
        "Heimeranplatz": "HP",
        "Laimer Platz": "LK",  // 404
        
        // U5
        "Neuperlach Süd": "NP",
        "Therese-Giehse-Allee": "TG",
        "Perlach": "PE",
        "Michaelibad": "MI",
        "Quiddestraße": "QU",
        "Am Keferloher See": "KL",
        "Ostbahnhof": "OB",
        "Leuchtenbergring": "LR",
        "Pasing": "PA",
        
        // U6
        "Garching-Forschungszentrum": "GF",
        "Garching": "GH",
        "Garching-Hochbrück": "GC",
        "Fröttmaning": "FT",
        "Kieferngarten": "KW",
        "Freimann": "FN",
        "Studentenstadt": "ST",
        "Alte Heide": "AH",
        "Nordfriedhof": "NO",
        "Dietlindenstraße": "DL",
        // Harras: kein P8_H gefunden (HP = Heimeranplatz) – nur MVG.de-Link
        "Partnachplatz": "PW",
        "Westpark": "WP",
        "Holzapfelkreuth": "HC",
        "Haderner Stern": "HD",
        "Großhadern": "GR",
        "Klinikum Großhadern": "KG",
    ]
    
    /// Normalizes a station name for matching (removes hyphens/spaces, lowercased).
    /// Ensures "Rot-Kreuz-Platz", "Rot Kreuz Platz" and "Rotkreuzplatz" all match.
    private static func normalizedForMatching(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
    
    /// Look up the station code for a given station name.
    /// Tries exact match first, then normalized match (hyphens/spaces ignored), then longest substring match.
    static func stationCode(for stationName: String?) -> String? {
        guard let name = stationName else { return nil }
        
        if let code = uBahnStationCodes[name] {
            return code
        }
        
        let normalizedName = normalizedForMatching(name)
        for (key, code) in uBahnStationCodes where normalizedForMatching(key) == normalizedName {
            return code
        }
        
        var bestMatch: (key: String, code: String)?
        for (key, code) in uBahnStationCodes {
            let normKey = normalizedForMatching(key)
            let matches = normalizedName.contains(normKey) || normKey.contains(normalizedName)
            guard matches else { continue }
            
            if let current = bestMatch {
                if key.count > current.key.count {
                    bestMatch = (key, code)
                } else if key.count == current.key.count && key < current.key {
                    bestMatch = (key, code)
                }
            } else {
                bestMatch = (key, code)
            }
        }
        
        return bestMatch?.code
    }
    
    /// Returns available station plans for a given station name.
    static func stationPlans(for stationName: String?) -> [MVGStationPlan] {
        var plans: [MVGStationPlan] = []
        
        if let code = stationCode(for: stationName),
           let url = umgebungsplanFallbackURL(for: code) {
            plans.append(MVGStationPlan(
                name: "Umgebungsplan",
                url: url,
                icon: "map.fill"
            ))
        }
        
        if let name = stationName,
           let url = meinhaltURL(for: name) {
            plans.append(MVGStationPlan(
                name: "Station auf MVG.de",
                url: url,
                icon: "safari.fill"
            ))
        }
        
        return plans
    }
    
    // MARK: - Fahrpläne & Netzpläne page
    
    static let fahrplaeneNetzplaeneURL = URL(string: "https://www.mvg.de/verbindungen/fahrplaene-netzplaene.html")!
}
