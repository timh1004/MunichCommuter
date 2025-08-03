//
//  WatchTransportType.swift
//  MunichCommuterWatch
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Transport Type Enumeration for Watch
enum WatchTransportType: String, CaseIterable, Codable {
    case sBahn = "S-Bahn"
    case uBahn = "U-Bahn"
    case tram = "Tram"
    case stadtBus = "StadtBus"
    case regionalBus = "RegionalBus"
    case regionalBahn = "Regionalbahn"
    case regionalExpress = "Regional-Express"
    case ice = "ICE/IC/EC"
    
    var icon: String {
        switch self {
        case .sBahn: return "tram.fill"
        case .uBahn: return "tram.fill"
        case .tram: return "tram.fill"
        case .stadtBus: return "bus.fill"
        case .regionalBus: return "bus.fill"
        case .regionalBahn: return "train.side.front.car"
        case .regionalExpress: return "train.side.front.car"
        case .ice: return "train.side.front.car"
        }
    }
    
    var color: Color {
        switch self {
        case .sBahn: return Color(red: 0/255, green: 142/255, blue: 78/255)        // MVV S-Bahn #008E4E
        case .uBahn: return Color(red: 0/255, green: 78/255, blue: 143/255)        // MVV U-Bahn #004E8F
        case .tram: return Color(red: 217/255, green: 26/255, blue: 26/255)        // MVV Tram #D91A1A
        case .stadtBus: return Color(red: 0/255, green: 87/255, blue: 106/255)     // MVV Bus #00576A
        case .regionalBus: return Color(red: 0/255, green: 87/255, blue: 106/255)  // MVV Bus #00576A
        case .regionalBahn: return Color(red: 50/255, green: 54/255, blue: 127/255) // MVV Regio #32367F
        case .regionalExpress: return Color(red: 50/255, green: 54/255, blue: 127/255) // MVV Regio #32367F
        case .ice: return Color(red: 50/255, green: 54/255, blue: 127/255)         // MVV Regio #32367F
        }
    }
    
    var shortName: String {
        switch self {
        case .sBahn: return "S"
        case .uBahn: return "U"
        case .tram: return "T"
        case .stadtBus: return "Bus"
        case .regionalBus: return "RB"
        case .regionalBahn: return "R"
        case .regionalExpress: return "RE"
        case .ice: return "ICE"
        }
    }
    
    var displayName: String {
        switch self {
        case .sBahn: return "S-Bahn"
        case .uBahn: return "U-Bahn"
        case .tram: return "Tram"
        case .stadtBus: return "Bus"
        case .regionalBus: return "RegBus"
        case .regionalBahn: return "Regio"
        case .regionalExpress: return "RegExp"
        case .ice: return "ICE"
        }
    }
}