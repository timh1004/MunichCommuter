import SwiftUI

public enum TransportType: String, CaseIterable, Sendable {
    case sBahn = "S-Bahn"
    case uBahn = "U-Bahn"
    case tram = "Tram"
    case stadtBus = "StadtBus"
    case regionalBus = "RegionalBus"
    case regionalBahn = "Regionalbahn"
    case regionalExpress = "Regional-Express"
    case ice = "ICE/IC/EC"

    public var icon: String {
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

    public var color: Color {
        switch self {
        case .sBahn: return Color(red: 0/255, green: 142/255, blue: 78/255)
        case .uBahn: return Color(red: 0/255, green: 78/255, blue: 143/255)
        case .tram: return Color(red: 217/255, green: 26/255, blue: 26/255)
        case .stadtBus: return Color(red: 0/255, green: 87/255, blue: 106/255)
        case .regionalBus: return Color(red: 0/255, green: 87/255, blue: 106/255)
        case .regionalBahn: return Color(red: 50/255, green: 54/255, blue: 127/255)
        case .regionalExpress: return Color(red: 50/255, green: 54/255, blue: 127/255)
        case .ice: return Color(red: 50/255, green: 54/255, blue: 127/255)
        }
    }

    public var shortName: String {
        switch self {
        case .sBahn: return "S-Bahn"
        case .uBahn: return "U-Bahn"
        case .tram: return "Tram"
        case .stadtBus: return "StadtBus"
        case .regionalBus: return "RegBus"
        case .regionalBahn: return "RB"
        case .regionalExpress: return "RE"
        case .ice: return "ICE/IC"
        }
    }
}
