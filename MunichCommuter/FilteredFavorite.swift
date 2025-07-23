import Foundation

struct FilteredFavorite: Codable, Identifiable {
    let id: UUID
    let location: Location
    let destinationFilter: String?
    let transportTypeFilters: [String]? // Array of TransportType.rawValue
    let dateCreated: Date
    
    var displayName: String {
        let baseName = location.disassembledName ?? location.name ?? "Unbekannte Station"
        var filters: [String] = []
        
        if let destination = destinationFilter, !destination.isEmpty {
            filters.append("→ \(destination)")
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
        
        if let destination = destinationFilter, !destination.isEmpty {
            filters.append("→ \(destination)")
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
        
        if let destination = destinationFilter, !destination.isEmpty {
            filters.append("Nach \(destination)")
        }
        
        if let transportTypes = transportTypeFilters, !transportTypes.isEmpty {
            let transportNames = transportTypes.map { TransportType(rawValue: $0)?.shortName ?? $0 }
            filters.append("Nur \(transportNames.joined(separator: ", "))")
        }
        
        return filters.isEmpty ? nil : filters.joined(separator: " • ")
    }
    
    var hasFilters: Bool {
        let hasDestinationFilter = destinationFilter?.isEmpty == false
        let hasTransportFilters = transportTypeFilters?.isEmpty == false && transportTypeFilters?.count ?? 0 > 0
        return hasDestinationFilter || hasTransportFilters
    }
    
    init(location: Location, destinationFilter: String? = nil, transportTypeFilters: [String]? = nil) {
        self.id = UUID()
        self.location = location
        self.destinationFilter = destinationFilter?.isEmpty == true ? nil : destinationFilter
        self.transportTypeFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters
        self.dateCreated = Date()
    }
} 