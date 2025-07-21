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
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, disassembledName, coord, parent, assignedStops, properties
    }
}

struct LocationParent: Codable {
    let name: String?
    let type: String?
}

struct AssignedStop: Codable {
    let name: String?
    let type: String?
}

struct LocationProperties: Codable {
    let stopId: String?
    let area: String?
    
    enum CodingKeys: String, CodingKey {
        case stopId
        case area
    }
} 