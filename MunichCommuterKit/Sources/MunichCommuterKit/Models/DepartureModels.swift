import Foundation

// MARK: - Departure API Response Models
public struct DepartureResponse: Codable, Sendable {
    public let version: String?
    public let systemMessages: [SystemMessage]?
    public let locations: [DepartureLocation]?
    public let stopEvents: [StopEvent]?
}

public struct DepartureLocation: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
    public let coord: [Double]?
    public let properties: LocationProperties?
}

public struct StopEvent: Codable, Identifiable, Sendable {
    public var id: String {
        return UUID().uuidString
    }

    public let realtimeStatus: [String]?
    public let isRealtimeControlled: Bool?
    public let location: Platform?
    public let departureTimePlanned: String?
    public let departureTimeBaseTimetable: String?
    public let departureTimeEstimated: String?
    public let transportation: Transportation?
    public let properties: StopEventProperties?
    public let previousLocations: [Platform]?
    public let onwardLocations: [Platform]?

    public enum CodingKeys: String, CodingKey {
        case realtimeStatus, isRealtimeControlled, location
        case departureTimePlanned, departureTimeBaseTimetable, departureTimeEstimated
        case transportation, properties, previousLocations, onwardLocations
    }
}

public struct Platform: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
    public let coord: [Double]?
    public let properties: PlatformProperties?
    public let parent: PlatformParent?
    public let departureTimePlanned: String?
    public let departureTimeEstimated: String?
    public let arrivalTimePlanned: String?
    public let arrivalTimeEstimated: String?
}

public struct PlatformProperties: Codable, Sendable {
    public let stopId: String?
    public let area: String?
    public let platform: String?
    public let platformName: String?
    public let plannedPlatformName: String?
    public let zone: String?
    public let stoppingPointPlanned: String?
    public let areaGid: String?
    public let areaLevel: String?

    public enum CodingKeys: String, CodingKey {
        case stopId, area, platform, platformName, plannedPlatformName, zone, stoppingPointPlanned, areaGid
        case areaLevel = "AREA_NIVEAU_DIVA"
    }
}

public struct PlatformParent: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
    public let properties: LocationProperties?
}

public struct Transportation: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let disassembledName: String?
    public let number: String?
    public let description: String?
    public let product: Product?
    public let transportOperator: TransportOperator?
    public let destination: Destination?
    public let origin: Origin?
    public let properties: TransportationProperties?

    public enum CodingKeys: String, CodingKey {
        case id, name, disassembledName, number, description, product, destination, origin, properties
        case transportOperator = "operator"
    }
}

public struct Product: Codable, Sendable {
    public let id: Int?
    public let productClass: Int?
    public let name: String?
    public let iconId: Int?

    public enum CodingKeys: String, CodingKey {
        case id, name, iconId
        case productClass = "class"
    }
}

public struct TransportOperator: Codable, Sendable {
    public let code: String?
    public let id: String?
    public let name: String?
}

public struct Destination: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
}

public struct Origin: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
}

public struct TransportationProperties: Codable, Sendable {
    public let tripCode: Int?
    public let lineDisplay: String?
    public let globalId: String?
}

public struct StopEventProperties: Codable, Sendable {
    public let AVMSTripID: String?
}
