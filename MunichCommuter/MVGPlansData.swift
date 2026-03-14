import Foundation

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
    
    static let networkPlans: [MVGNetworkPlan] = [
        MVGNetworkPlan(
            name: "Schnellbahnnetz",
            subtitle: "S-Bahn, U-Bahn, Regionalzug",
            url: URL(string: "https://www.mvg.de/dam/mvg/plaene/netz-und-tarifplaene/netz-tarifplan.pdf")!,
            icon: "map.fill",
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
            url: URL(string: "https://www.mvg.de/dam/jcr:4920a44b-e600-44bf-bc79-1a06d305fe45/A4-Tramnetz-2026-Web.pdf")!,
            icon: "tram",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Nachtlinien",
            subtitle: "Nacht-U-Bahn, -Tram & -Bus",
            url: URL(string: "https://www.mvg.de/dam/jcr:fe99cd93-ef1c-483c-a715-f421da96382b/nachtliniennetz.pdf")!,
            icon: "moon.stars.fill",
            category: .netzplaene
        ),
        MVGNetworkPlan(
            name: "Netz- & Tarifplan Zone M",
            subtitle: "Innenstadtbereich",
            url: URL(string: "https://www.mvg.de/dam/jcr:e9fbaf6f-4ec1-40de-8488-a75787ddbf50/2025_layout_SURTX_M_SCR.pdf")!,
            icon: "circle.dashed",
            category: .linienplaene
        ),
        MVGNetworkPlan(
            name: "Netz- & Tarifplan Region",
            subtitle: "Gesamtes MVV-Gebiet",
            url: URL(string: "https://www.mvg.de/dam/jcr:3861445b-9af4-4cfd-9b13-1b44d5f2d7f6/netz-tarifplan-region.pdf")!,
            icon: "map.circle.fill",
            category: .linienplaene
        ),
        MVGNetworkPlan(
            name: "Barrierefreie Haltestellen",
            subtitle: "Aufzüge & stufenfreier Zugang",
            url: URL(string: "https://www.mvg.de/dam/mvg/plaene/netz-und-tarifplaene/barrierefrei_MVV.pdf")!,
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
            ("Ä", "ae"), ("Ö", "oe"), ("Ü", "ue"),
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
    
    // MARK: - Aushangfahrplan (Station Timetable PDFs)
    
    static func aushangfahrplanURL(for stationCode: String) -> URL? {
        guard !stationCode.isEmpty else { return nil }
        return URL(string: "https://www.mvg.de/aushangfahrplan/P8_H_\(stationCode)_0.pdf")
    }
    
    /// Maps U-Bahn station names (disassembledName from the API) to their two-letter codes
    /// used in the MVG Aushangfahrplan URL scheme.
    static let uBahnStationCodes: [String: String] = [
        // U1
        "Olympia-Einkaufszentrum": "OZ",
        "Georg-Brauchle-Ring": "GB",
        "Westfriedhof": "WF",
        "Gern": "GN",
        "Rotkreuzplatz": "RK",
        "Maillingerstraße": "ML",
        "Stiglmaierplatz": "SG",
        "Hauptbahnhof": "HB",
        "Sendlinger Tor": "SE",
        "Fraunhoferstraße": "FR",
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
        "Giesing": "GI",
        "Karl-Preis-Platz": "KA",
        "Innsbrucker Ring": "IG",
        "Josephsburg": "JO",
        "Kreillerstraße": "KD",
        "Trudering": "TK",
        "Moosfeld": "MO",
        "Messestadt West": "MS",
        "Messestadt Ost": "ME",
        
        // U3
        "Moosach": "MA",
        "Olympiazentrum": "OP",
        "Oberwiesenfeld": "OW",
        "Petuelring": "PS",
        "Bonner Platz": "BP",
        "Münchner Freiheit": "MU",
        "Giselastraße": "GS",
        "Universität": "UV",
        "Odeonsplatz": "OU",
        "Marienplatz": "MP",
        "Goetheplatz": "GK",
        "Poccistraße": "PP",
        "Implerstraße": "IP",
        "Brudermühlstraße": "BL",
        "Thalkirchen": "TS",
        "Obersendling": "OR",
        "Aidenbachstraße": "AB",
        "Basler Straße": "BA",
        "Fürstenried West": "FG",
        
        // U4
        "Arabellapark": "AT",
        "Böhmerwaldplatz": "BO",
        "Richard-Strauss-Straße": "RB",
        "Prinzregentenplatz": "PZ",
        "Max-Weber-Platz": "MW",
        "Lehel": "LH",
        "Schwanthalerhöhe": "SW",
        "Westendstraße": "WH",
        "Heimeranplatz": "HM",
        "Laimer Platz": "LK",
        
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
        "Harras": "HP",
        "Partnachplatz": "PW",
        "Westpark": "WP",
        "Holzapfelkreuth": "HC",
        "Haderner Stern": "HS",
        "Großhadern": "GR",
        "Klinikum Großhadern": "KG",
    ]
    
    /// Look up the station code for a given station name, trying various matching strategies.
    static func stationCode(for stationName: String?) -> String? {
        guard let name = stationName else { return nil }
        
        if let code = uBahnStationCodes[name] {
            return code
        }
        
        for (key, code) in uBahnStationCodes {
            if name.localizedCaseInsensitiveContains(key) || key.localizedCaseInsensitiveContains(name) {
                return code
            }
        }
        
        return nil
    }
    
    /// Returns available station plans for a given station name.
    static func stationPlans(for stationName: String?) -> [MVGStationPlan] {
        var plans: [MVGStationPlan] = []
        
        if let code = stationCode(for: stationName),
           let url = aushangfahrplanURL(for: code) {
            plans.append(MVGStationPlan(
                name: "Aushangfahrplan (PDF)",
                url: url,
                icon: "doc.text.fill"
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
