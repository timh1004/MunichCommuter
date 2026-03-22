//
//  WatchDeparture.swift
//  MunichCommuterWatch
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

// MARK: - Simplified MVV API Response Models for Watch
struct WatchStopEvent: Codable, Identifiable {
    let id = UUID()
    let departureTimePlanned: String?
    let departureTimeEstimated: String?
    let isRealtimeControlled: Bool?
    let location: WatchPlatform?
    let transportation: WatchTransportation?
    
    enum CodingKeys: String, CodingKey {
        case departureTimePlanned, departureTimeEstimated, isRealtimeControlled, location, transportation
    }
}

struct WatchPlatform: Codable {
    let properties: WatchPlatformProperties?
}

struct WatchPlatformProperties: Codable {
    let platform: String?
}

struct WatchTransportation: Codable {
    let name: String?
    let number: String?
    let destination: WatchDestination?
    let product: WatchProduct?
    
    enum CodingKeys: String, CodingKey {
        case name, number, destination, product
    }
}

struct WatchProduct: Codable {
    let productClass: Int?
    
    enum CodingKeys: String, CodingKey {
        case productClass = "class"
    }
}

struct WatchDestination: Codable {
    let name: String?
}

struct WatchDepartureResponse: Codable {
    let stopEvents: [WatchStopEvent]?
}

// MARK: - Watch Departure Model
struct WatchDeparture: Codable, Identifiable {
    let id = UUID()
    let lineName: String?
    let lineNumber: String?
    let destination: String?
    let departureTime: String?
    let estimatedTime: String?
    let platform: String?
    let transportType: WatchTransportType?
    let delay: Int? // in minutes
    let isRealtime: Bool
    
    var displayTime: String {
        if let estimated = estimatedTime {
            return formatTime(estimated)
        } else if let planned = departureTime {
            return formatTime(planned)
        }
        return "--"
    }
    
    var delayText: String? {
        guard let delay = delay, delay > 0 else { return nil }
        return "+\(delay)"
    }
    
    var minutesUntilDeparture: Int? {
        let timeString = estimatedTime ?? departureTime
        guard let timeString = timeString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let departureDate = formatter.date(from: timeString) else { return nil }
        
        let minutes = Int(departureDate.timeIntervalSinceNow / 60)
        return max(0, minutes)
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = formatter.date(from: timeString) else {
            return timeString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        return outputFormatter.string(from: date)
    }
    
    // Create from WatchStopEvent
    init(from stopEvent: WatchStopEvent) {
        self.lineName = stopEvent.transportation?.name
        self.lineNumber = stopEvent.transportation?.number
        self.destination = stopEvent.transportation?.destination?.name
        self.departureTime = stopEvent.departureTimePlanned
        self.estimatedTime = stopEvent.departureTimeEstimated
        self.platform = stopEvent.location?.properties?.platform
        self.isRealtime = stopEvent.isRealtimeControlled ?? false
        
        // Determine transport type based on product class
        if let productClass = stopEvent.transportation?.product?.productClass {
            self.transportType = WatchDeparture.mapProductClassToTransportType(productClass)
        } else {
            self.transportType = nil
        }
        
        // Calculate delay
        if let planned = stopEvent.departureTimePlanned,
           let estimated = stopEvent.departureTimeEstimated {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            if let plannedDate = formatter.date(from: planned),
               let estimatedDate = formatter.date(from: estimated) {
                self.delay = Int((estimatedDate.timeIntervalSince(plannedDate)) / 60)
            } else {
                self.delay = nil
            }
        } else {
            self.delay = nil
        }
    }
    
    // Manual initializer for testing/previews
    init(
        lineName: String?,
        lineNumber: String?,
        destination: String?,
        departureTime: String?,
        estimatedTime: String?,
        platform: String?,
        transportType: WatchTransportType?,
        delay: Int?,
        isRealtime: Bool
    ) {
        self.lineName = lineName
        self.lineNumber = lineNumber
        self.destination = destination
        self.departureTime = departureTime
        self.estimatedTime = estimatedTime
        self.platform = platform
        self.transportType = transportType
        self.delay = delay
        self.isRealtime = isRealtime
    }
    
    private static func mapProductClassToTransportType(_ productClass: Int) -> WatchTransportType? {
        switch productClass {
        case 1: return .ice
        case 2: return .regionalExpress
        case 4: return .regionalBahn
        case 8: return .sBahn
        case 16: return .uBahn
        case 32: return .tram
        case 64: return .stadtBus
        case 128: return .regionalBus
        default: return nil
        }
    }
}