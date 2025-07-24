import Foundation

struct FilteredFavorite: Codable, Identifiable {
    let id: UUID
    let location: Location
    let destinationFilters: [String]? // Changed from String? to [String]?
    let platformFilters: [String]? // Array of platform/gleis strings
    let transportTypeFilters: [String]? // Array of TransportType.rawValue
    let dateCreated: Date
    
    var displayName: String {
        let baseName = location.disassembledName ?? location.name ?? "Unbekannte Station"
        var filters: [String] = []
        
        if let destinations = destinationFilters, !destinations.isEmpty {
            if destinations.count == 1 {
                filters.append("→ \(destinations[0])")
            } else {
                filters.append("→ \(destinations.count) Ziele")
            }
        }
        
        if let platforms = platformFilters, !platforms.isEmpty {
            if platforms.count == 1 {
                filters.append("🚉 Gl.\(platforms[0])")
            } else {
                filters.append("🚉 \(platforms.count) Gleise")
            }
        }
        
        if let transportTypes = transportTypeFilters, !transportTypes.isEmpty {
            let transportNames = transportTypes.compactMap { TransportType(rawValue: $0)?.shortName }
            if !transportNames.isEmpty {
                filters.append("🚇 \(transportNames.joined(separator: ", "))")
            }
        }
        
        if !filters.isEmpty {
            return "\(baseName) \(filters.joined(separator: " "))"
        }
        return baseName
    }
    
    var shortDisplayName: String {
        let baseName = location.disassembledName ?? location.name ?? "Unbekannte Station"
        var filters: [String] = []
        
        if let destinations = destinationFilters, !destinations.isEmpty {
            if destinations.count == 1 {
                filters.append("→ \(destinations[0])")
            } else {
                filters.append("→ \(destinations.count)")
            }
        }
        
        if let platforms = platformFilters, !platforms.isEmpty {
            if platforms.count == 1 {
                filters.append("🚉 \(platforms[0])")
            } else {
                filters.append("🚉 \(platforms.count)")
            }
        }
        
        if let transportTypes = transportTypeFilters, !transportTypes.isEmpty {
            let transportNames = transportTypes.compactMap { TransportType(rawValue: $0)?.shortName }
            if !transportNames.isEmpty {
                filters.append("🚇 \(transportNames.joined(separator: ", "))")
            }
        }
        
        if !filters.isEmpty {
            return "\(baseName) \(filters.joined(separator: " "))"
        }
        return baseName
    }
    
    var filterDisplayText: String? {
        var filters: [String] = []
        
        if let destinations = destinationFilters, !destinations.isEmpty {
            if destinations.count == 1 {
                filters.append("Nach \(destinations[0])")
            } else {
                filters.append("Nach \(destinations.joined(separator: ", "))")
            }
        }
        
        if let platforms = platformFilters, !platforms.isEmpty {
            if platforms.count == 1 {
                filters.append("Gleis \(platforms[0])")
            } else {
                filters.append("Gleise \(platforms.joined(separator: ", "))")
            }
        }
        
        if let transportTypes = transportTypeFilters, !transportTypes.isEmpty {
            let transportNames = transportTypes.map { TransportType(rawValue: $0)?.shortName ?? $0 }
            filters.append("Nur \(transportNames.joined(separator: ", "))")
        }
        
        return filters.isEmpty ? nil : filters.joined(separator: " • ")
    }
    
    var hasFilters: Bool {
        let hasDestinationFilters = destinationFilters?.isEmpty == false && destinationFilters?.count ?? 0 > 0
        let hasPlatformFilters = platformFilters?.isEmpty == false && platformFilters?.count ?? 0 > 0
        let hasTransportFilters = transportTypeFilters?.isEmpty == false && transportTypeFilters?.count ?? 0 > 0
        return hasDestinationFilters || hasPlatformFilters || hasTransportFilters
    }
    
    init(location: Location, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        self.id = UUID()
        self.location = location
        self.destinationFilters = destinationFilters?.isEmpty == true ? nil : destinationFilters
        self.platformFilters = platformFilters?.isEmpty == true ? nil : platformFilters
        self.transportTypeFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters
        self.dateCreated = Date()
    }
    
    // Legacy initializer for backwards compatibility during migration
    init(location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        self.id = UUID()
        self.location = location
        self.destinationFilters = destinationFilter.map { [$0] }
        self.platformFilters = nil
        self.transportTypeFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters
        self.dateCreated = Date()
    }
} 