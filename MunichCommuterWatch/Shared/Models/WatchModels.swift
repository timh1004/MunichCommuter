//
//  WatchModels.swift
//  MunichCommuterWatch
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

// MARK: - Watch Location Model
struct WatchLocation: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let disassembledName: String?
    let coord: [Double]?
    let parent: WatchLocationParent?
    let distance: Int?
    
    var displayName: String {
        return disassembledName ?? name ?? "Unbekannte Station"
    }
    
    var parentName: String? {
        return parent?.name
    }
    
    init(id: String, name: String?, disassembledName: String?, coord: [Double]?, parent: WatchLocationParent? = nil, distance: Int? = nil) {
        self.id = id
        self.name = name
        self.disassembledName = disassembledName
        self.coord = coord
        self.parent = parent
        self.distance = distance
    }
    
    // This initializer would be used when converting from the iPhone app's Location model
    // For now, we'll create WatchLocation instances directly in the Watch app
    
    static func == (lhs: WatchLocation, rhs: WatchLocation) -> Bool {
        return lhs.id == rhs.id
    }
}

struct WatchLocationParent: Codable {
    let name: String?
}

// WatchDeparture is now defined in WatchDeparture.swift

// MARK: - Watch Favorite Model
struct WatchFavorite: Codable, Identifiable {
    let id: UUID
    let location: WatchLocation
    let destinationFilters: [String]?
    let platformFilters: [String]?
    let transportTypeFilters: [String]?
    let dateCreated: Date
    
    var displayName: String {
        return location.displayName
    }
    
    var shortDisplayName: String {
        let baseName = location.displayName
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
                filters.append("Gl.\(platforms[0])")
            } else {
                filters.append("\(platforms.count) Gl.")
            }
        }
        
        if let transportTypes = transportTypeFilters, !transportTypes.isEmpty {
            let transportNames = transportTypes.compactMap { WatchTransportType(rawValue: $0)?.shortName }
            if !transportNames.isEmpty {
                filters.append(transportNames.joined(separator: ","))
            }
        }
        
        if !filters.isEmpty {
            return "\(baseName) \(filters.joined(separator: " "))"
        }
        return baseName
    }
    
    var hasFilters: Bool {
        let hasDestinationFilters = destinationFilters?.isEmpty == false
        let hasPlatformFilters = platformFilters?.isEmpty == false
        let hasTransportFilters = transportTypeFilters?.isEmpty == false
        return hasDestinationFilters || hasPlatformFilters || hasTransportFilters
    }
    
    init(location: WatchLocation, destinationFilters: [String]? = nil, platformFilters: [String]? = nil, transportTypeFilters: [String]? = nil) {
        self.id = UUID()
        self.location = location
        self.destinationFilters = destinationFilters?.isEmpty == true ? nil : destinationFilters
        self.platformFilters = platformFilters?.isEmpty == true ? nil : platformFilters
        self.transportTypeFilters = transportTypeFilters?.isEmpty == true ? nil : transportTypeFilters
        self.dateCreated = Date()
    }
    
    // This initializer would be used when converting from the iPhone app's FilteredFavorite model
    // For now, we'll sync favorites via Watch Connectivity
}

// MARK: - Watch Sorting Options
enum WatchSortOption: String, CaseIterable {
    case alphabetical = "alphabetical"
    case distance = "distance"
    
    var displayName: String {
        switch self {
        case .alphabetical: return "A-Z"
        case .distance: return "Entfernung"
        }
    }
    
    var icon: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .distance: return "location.circle"
        }
    }
}