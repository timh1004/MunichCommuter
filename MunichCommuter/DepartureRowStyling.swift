import SwiftUI
import Foundation

struct DepartureRowStyling {
    
    // MARK: - Main Line Color Logic
    static func lineColor(for departure: StopEvent) -> Color {
        guard let productClass = departure.transportation?.product?.productClass else {
            return Color(red: 0.6, green: 0.6, blue: 0.6) // Grau
        }
        
        switch productClass {
        case 1: return sBahnLineColor(for: departure)                              // S-Bahn: Spezifische Linienfarben
        case 2: return uBahnLineColor(for: departure)                              // U-Bahn: Spezifische Linienfarben
        case 4: return Color(red: 0.8, green: 0.0, blue: 0.0)                     // Tram: MVG Rot
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.8)                     // Bus: MVG Lila
        default: return Color(red: 0.6, green: 0.6, blue: 0.6)                    // Fallback Grau
        }
    }
    
    // MARK: - S-Bahn Specific Colors
    static func sBahnLineColor(for departure: StopEvent) -> Color {
        guard let lineNumber = departure.transportation?.number else {
            return Color(red: 22/255, green: 192/255, blue: 233/255) // Standard S-Bahn (S1)
        }
        
        switch lineNumber {
        case "S1": return Color(red: 22/255, green: 192/255, blue: 233/255)     // Hellblau
        case "S2": return Color(red: 113/255, green: 191/255, blue: 68/255)     // Grün
        case "S3": return Color(red: 123/255, green: 16/255, blue: 125/255)     // Lila
        case "S4": return Color(red: 238/255, green: 28/255, blue: 37/255)      // Rot
        case "S6": return Color(red: 0/255, green: 138/255, blue: 81/255)       // Dunkelgrün
        case "S7": return Color(red: 150/255, green: 56/255, blue: 51/255)      // Dunkelrot
        case "S8": return Color(red: 255/255, green: 203/255, blue: 6/255)      // Gelb
        case "S20": return Color(red: 240/255, green: 90/255, blue: 115/255)    // Pink
        default: return Color(red: 22/255, green: 192/255, blue: 233/255)       // Standard S-Bahn (S1)
        }
    }
    
    // MARK: - U-Bahn Specific Colors
    static func uBahnLineColor(for departure: StopEvent) -> Color {
        guard let lineNumber = departure.transportation?.number else {
            return Color(red: 0.0, green: 0.4, blue: 0.8) // Standard U-Bahn Blau
        }
        
        switch lineNumber {
        case "U1", "1": return Color(red: 0.0, green: 0.7, blue: 0.0)     // Grün
        case "U2", "2": return Color(red: 0.9, green: 0.0, blue: 0.0)     // Rot
        case "U3", "3": return Color(red: 1.0, green: 0.6, blue: 0.0)     // Orange
        case "U4", "4": return Color(red: 0.0, green: 0.8, blue: 0.8)     // Türkis
        case "U5", "5": return Color(red: 0.6, green: 0.4, blue: 0.2)     // Braun
        case "U6", "6": return Color(red: 0.0, green: 0.4, blue: 0.8)     // Blau
        case "U7", "7": return Color(red: 0.0, green: 0.7, blue: 0.0)     // Grün (wie U1)
        case "U8", "8": return Color(red: 0.9, green: 0.0, blue: 0.0)     // Rot (wie U2)
        default: return Color(red: 0.0, green: 0.4, blue: 0.8)           // Standard U-Bahn Blau
        }
    }
    
    // MARK: - Time Display Logic
    static func shouldShowOrange(for departure: StopEvent) -> Bool {
        // Zeige orange nur wenn Abfahrt in 1 Minute oder weniger stattfindet
        let timeString = departure.departureTimePlanned ?? departure.departureTimeEstimated ?? ""
        guard let departureDate = Date.parseISO8601(timeString) else {
            return false
        }
        
        let minutesFromNow = departureDate.minutesFromNow()
        return minutesFromNow <= 1
    }
    
    // MARK: - Transport Type Name
    static func transportTypeName(for departure: StopEvent) -> String {
        return departure.transportation?.product?.name ?? "Zug"
    }
    
    // MARK: - Formatted Departure Time
    static func formattedDepartureTime(for departure: StopEvent) -> String {
        let (timeDisplay, _) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated
        )
        return timeDisplay
    }
    
    // MARK: - Delay Display
    static func delayDisplay(for departure: StopEvent) -> String? {
        let (_, delayDisplay) = DepartureTimeFormatter.formatDepartureTime(
            plannedTime: departure.departureTimePlanned,
            estimatedTime: departure.departureTimeEstimated
        )
        return delayDisplay
    }
    
    // MARK: - Realtime Status
    static func isRealtime(for departure: StopEvent) -> Bool {
        return departure.isRealtimeControlled == true
    }
}

// MARK: - Shared Transport Badge Component
struct TransportBadge: View {
    let departure: StopEvent
    let size: BadgeSize
    
    enum BadgeSize {
        case normal
        case compact
        
        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .normal: return (48, 32)
            case .compact: return (32, 20)
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .normal: return 16
            case .compact: return 10
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .normal: return 8
            case .compact: return 4
            }
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(DepartureRowStyling.lineColor(for: departure))
                .frame(width: size.dimensions.width, height: size.dimensions.height)
            
            Text(departure.transportation?.number ?? "?")
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
} 