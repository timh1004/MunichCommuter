import Foundation

class FilteringHelper {
    
    // MARK: - Destination Filtering
    static func hasDestinationInRoute(departure: StopEvent, destinations: [String]) -> Bool {
        // Check if any of the destination filters match this departure
        for dest in destinations {
            let searchTerm = dest.lowercased()
            
            // Check if destination matches the final destination
            if let finalDestination = departure.transportation?.destination?.name?.lowercased(),
               finalDestination.contains(searchTerm) {
                return true
            }
            
            // Check if destination is in onward locations (stops along the route)
            if let onwardLocations = departure.onwardLocations {
                let hasMatch = onwardLocations.contains { platform in
                    guard let name = platform.name?.lowercased() else { return false }
                    return name.contains(searchTerm)
                }
                if hasMatch {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Platform Filtering
    static func hasPlatformMatch(departure: StopEvent, platforms: [String]) -> Bool {
        // Check if any of the platform filters match this departure
        // Try platformName first, then plannedPlatformName, then fall back to platform
        let departurePlatform = departure.location?.properties?.platformName 
                             ?? departure.location?.properties?.plannedPlatformName 
                             ?? departure.location?.properties?.platform
        
        guard let departurePlatform = departurePlatform else {
            return false // No platform info available
        }
        
        for platform in platforms {
            if departurePlatform == platform {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Transport Type Filtering
    static func matchesTransportType(product: String, transportType: TransportType) -> Bool {
        guard !product.isEmpty else { return false }
        
        let productLower = product.lowercased()
        
        switch transportType {
        case .sBahn:
            return productLower.contains("s-bahn") || productLower.contains("sbahn")
        case .uBahn:
            return productLower.contains("u-bahn") || productLower.contains("ubahn")
        case .tram:
            return productLower.contains("tram") || productLower.contains("straßenbahn")
        case .stadtBus:
            return productLower.contains("stadtbus") || (productLower.contains("bus") && !productLower.contains("regional"))
        case .regionalBus:
            return productLower.contains("regionalbus") || productLower.contains("regbus")
        case .regionalBahn:
            return productLower.contains("regionalbahn") || productLower.contains("rb")
        case .regionalExpress:
            return productLower.contains("regional-express") || productLower.contains("re")
        case .ice:
            return productLower.contains("ice") || productLower.contains("ic") || productLower.contains("ec")
        }
    }
    
    // MARK: - Complete Filtering Pipeline
    static func getFilteredDepartures(departures: [StopEvent], 
                                    destinationFilters: [String]?, 
                                    platformFilters: [String]?, 
                                    transportTypeFilters: [String]?) -> [StopEvent] {
        var filtered = departures
        
        // Apply destination filters if any
        if let destinationFilters = destinationFilters, !destinationFilters.isEmpty {
            filtered = filtered.filter { departure in
                hasDestinationInRoute(departure: departure, destinations: destinationFilters)
            }
        }
        
        // Apply platform filters if any
        if let platformFilters = platformFilters, !platformFilters.isEmpty {
            filtered = filtered.filter { departure in
                hasPlatformMatch(departure: departure, platforms: platformFilters)
            }
        }
        
        // Apply transport type filters if any
        if let transportTypeFilters = transportTypeFilters, !transportTypeFilters.isEmpty {
            let selectedTypes = Set(transportTypeFilters.compactMap { TransportType(rawValue: $0) })
            filtered = filtered.filter { departure in
                guard let product = departure.transportation?.product?.name else { return false }
                return selectedTypes.contains { transportType in
                    matchesTransportType(product: product, transportType: transportType)
                }
            }
        }
        
        return filtered
    }
} 