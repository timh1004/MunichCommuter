//
//  DepartureModels.swift
//  MunichCommuter
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Departure API Response Models
struct DepartureResponse: Codable {
    let version: String?
    let systemMessages: [SystemMessage]?
    let locations: [DepartureLocation]?
    let stopEvents: [StopEvent]?
}

struct DepartureLocation: Codable {
    let id: String?
    let name: String?
    let type: String?
    let coord: [Double]?
    let properties: LocationProperties?
}

struct StopEvent: Codable, Identifiable {
    // Use a simple computed ID that doesn't access potentially nil properties
    var id: String {
        return UUID().uuidString
    }
    
    let realtimeStatus: [String]?
    let isRealtimeControlled: Bool?
    let location: Platform?
    let departureTimePlanned: String?
    let departureTimeBaseTimetable: String?
    let departureTimeEstimated: String?
    let transportation: Transportation?
    let properties: StopEventProperties?
    let previousLocations: [Platform]?
    let onwardLocations: [Platform]?
    
    enum CodingKeys: String, CodingKey {
        case realtimeStatus, isRealtimeControlled, location
        case departureTimePlanned, departureTimeBaseTimetable, departureTimeEstimated
        case transportation, properties, previousLocations, onwardLocations
    }
}

struct Platform: Codable {
    let id: String?
    let name: String?
    let type: String?
    let coord: [Double]?
    let properties: PlatformProperties?
    let parent: PlatformParent?
    let departureTimePlanned: String?
    let departureTimeEstimated: String?
    let arrivalTimePlanned: String?
    let arrivalTimeEstimated: String?
}

struct PlatformProperties: Codable {
    let stopId: String?
    let area: String?
    let platform: String?
    let platformName: String?
    let plannedPlatformName: String?
    let zone: String?
    let stoppingPointPlanned: String?
    let areaGid: String?
    let areaLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case stopId, area, platform, platformName, plannedPlatformName, zone, stoppingPointPlanned, areaGid
        case areaLevel = "AREA_NIVEAU_DIVA"
    }
}

struct PlatformParent: Codable {
    let id: String?
    let name: String?
    let type: String?
    let properties: LocationProperties?
}

struct Transportation: Codable {
    let id: String?
    let name: String?
    let disassembledName: String?
    let number: String?
    let description: String?
    let product: Product?
    let transportOperator: TransportOperator?
    let destination: Destination?
    let origin: Origin?
    let properties: TransportationProperties?
    
    enum CodingKeys: String, CodingKey {
        case id, name, disassembledName, number, description, product, destination, origin, properties
        case transportOperator = "operator"
    }
}

struct Product: Codable {
    let id: Int?
    let productClass: Int?
    let name: String?
    let iconId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, iconId
        case productClass = "class"
    }
}

struct TransportOperator: Codable {
    let code: String?
    let id: String?
    let name: String?
}

struct Destination: Codable {
    let id: String?
    let name: String?
    let type: String?
}

struct Origin: Codable {
    let id: String?
    let name: String?
    let type: String?
}

struct TransportationProperties: Codable {
    let tripCode: Int?
    let lineDisplay: String?
    let globalId: String?
}

struct StopEventProperties: Codable {
    let AVMSTripID: String?
} 