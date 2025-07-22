import Foundation

struct FilteredFavorite: Codable, Identifiable {
    let id = UUID()
    let location: Location
    let destinationFilter: String?
    let dateCreated: Date
    
    var displayName: String {
        let baseName = location.disassembledName ?? location.name ?? "Unbekannte Station"
        if let filter = destinationFilter, !filter.isEmpty {
            return "\(baseName) → \(filter)"
        }
        return baseName
    }
    
    var filterDisplayText: String? {
        guard let filter = destinationFilter, !filter.isEmpty else { return nil }
        return "Nach \(filter)"
    }
    
    init(location: Location, destinationFilter: String? = nil) {
        self.location = location
        self.destinationFilter = destinationFilter?.isEmpty == true ? nil : destinationFilter
        self.dateCreated = Date()
    }
} 