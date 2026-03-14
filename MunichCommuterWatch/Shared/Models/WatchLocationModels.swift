//
//  WatchLocationModels.swift
//  MunichCommuterWatch
//
//  Created by AI Assistant
//

import Foundation

// MARK: - MVV Location API Response Models for Watch
struct WatchMVVResponse: Codable {
    let locations: [WatchMVVLocation]?
}

struct WatchMVVLocation: Codable {
    let id: String
    let name: String?
    let disassembledName: String?
    let coord: [Double]?
    let parent: WatchMVVLocationParent?
    let distance: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, disassembledName, coord, parent, distance
    }
}

struct WatchMVVLocationParent: Codable {
    let name: String?
}

// Extension to convert from API model to app model
extension WatchLocation {
    init(from mvvLocation: WatchMVVLocation) {
        self.id = mvvLocation.id
        self.name = mvvLocation.name
        self.disassembledName = mvvLocation.disassembledName
        self.coord = mvvLocation.coord
        self.parent = mvvLocation.parent != nil ? WatchLocationParent(name: mvvLocation.parent?.name) : nil
        self.distance = mvvLocation.distance
    }
}