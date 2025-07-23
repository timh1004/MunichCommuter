//
//  MVVModels.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import Foundation

// MARK: - MVV API Response Models
struct MVVResponse: Codable {
    let version: String?
    let systemMessages: [SystemMessage]?
    let locations: [Location]?
    
    enum CodingKeys: String, CodingKey {
        case version
        case systemMessages
        case locations
    }
}

struct SystemMessage: Codable {
    let type: String?
    let module: String?
    let code: Int?
    let text: String?
}

struct Location: Codable, Identifiable {
    let id: String
    let type: String?
    let name: String?
    let disassembledName: String?
    let coord: [Double]?
    let parent: LocationParent?
    let assignedStops: [AssignedStop]?
    let properties: LocationProperties?
    
    // For nearby stops from API - distance in meters
    let distance: Int?
    let duration: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, disassembledName, coord, parent, assignedStops, properties, distance, duration
    }
    
    // Custom initializer for converting AssignedStop to Location
    init(id: String, type: String?, name: String?, disassembledName: String?, coord: [Double]?, parent: LocationParent?, assignedStops: [AssignedStop]?, properties: LocationProperties?, distance: Int? = nil, duration: Int? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.disassembledName = disassembledName
        self.coord = coord
        self.parent = parent
        self.assignedStops = assignedStops
        self.properties = properties
        self.distance = distance
        self.duration = duration
    }
}

struct LocationParent: Codable {
    let name: String?
    let type: String?
}

struct AssignedStop: Codable, Identifiable {
    let id: String
    let isGlobalId: Bool?
    let name: String?
    let type: String?
    let coord: [Double]?
    let parent: LocationParent?
    let distance: Int?
    let duration: Int?
    let productClasses: [Int]?
    let connectingMode: Int?
    let properties: LocationProperties?
}

struct LocationProperties: Codable {
    let stopId: String?
    let area: String?
    
    enum CodingKeys: String, CodingKey {
        case stopId
        case area
    }
} 