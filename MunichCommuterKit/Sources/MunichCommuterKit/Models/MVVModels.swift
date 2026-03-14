import Foundation

// MARK: - MVV API Response Models
public struct MVVResponse: Codable, Sendable {
    public let version: String?
    public let systemMessages: [SystemMessage]?
    public let locations: [Location]?

    public enum CodingKeys: String, CodingKey {
        case version
        case systemMessages
        case locations
    }
}

public struct SystemMessage: Codable, Sendable {
    public let type: String?
    public let module: String?
    public let code: Int?
    public let text: String?
}

public struct Location: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String?
    public let name: String?
    public let disassembledName: String?
    public let coord: [Double]?
    public let parent: LocationParent?
    public let assignedStops: [AssignedStop]?
    public let properties: LocationProperties?
    public let distance: Int?
    public let duration: Int?

    public enum CodingKeys: String, CodingKey {
        case id, type, name, disassembledName, coord, parent, assignedStops, properties, distance, duration
    }

    public init(id: String, type: String?, name: String?, disassembledName: String?, coord: [Double]?, parent: LocationParent?, assignedStops: [AssignedStop]?, properties: LocationProperties?, distance: Int? = nil, duration: Int? = nil) {
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

public struct LocationParent: Codable, Sendable {
    public let name: String?
    public let type: String?
}

public struct AssignedStop: Codable, Identifiable, Sendable {
    public let id: String
    public let isGlobalId: Bool?
    public let name: String?
    public let type: String?
    public let coord: [Double]?
    public let parent: LocationParent?
    public let distance: Int?
    public let duration: Int?
    public let productClasses: [Int]?
    public let connectingMode: Int?
    public let properties: LocationProperties?
}

public struct LocationProperties: Codable, Sendable {
    public let stopId: String?
    public let area: String?

    public enum CodingKeys: String, CodingKey {
        case stopId
        case area
    }
}
