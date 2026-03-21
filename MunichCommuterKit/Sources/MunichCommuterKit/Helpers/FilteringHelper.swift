import Foundation

public class FilteringHelper {

    // MARK: - Destination Filtering
    public static func hasDestinationInRoute(departure: StopEvent, destinations: [String]) -> Bool {
        for dest in destinations {
            let searchTerm = dest.lowercased()

            if let finalDestination = departure.transportation?.destination?.name?.lowercased(),
               finalDestination.contains(searchTerm) {
                return true
            }

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
    public static func hasPlatformMatch(departure: StopEvent, platforms: [String]) -> Bool {
        let departurePlatform = PlatformHelper.effectivePlatform(from: departure.location?.properties)

        guard let departurePlatform = departurePlatform else {
            return false
        }

        for platform in platforms {
            if departurePlatform == platform {
                return true
            }
        }

        return false
    }

    // MARK: - Transport Type Filtering
    public static func matchesTransportType(product: String, transportType: TransportType) -> Bool {
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

    // MARK: - Destination Platform Filtering

    public static func hasDestinationPlatformMatch(departure: StopEvent, destinationPlatforms: [String], destinations: [String]?) -> Bool {
        guard let onwardLocations = departure.onwardLocations else { return false }

        let matchingLocations: [Platform]
        if let destinations = destinations, !destinations.isEmpty {
            matchingLocations = onwardLocations.filter { location in
                guard let name = location.name?.lowercased() else { return false }
                return destinations.contains { name.contains($0.lowercased()) }
            }
        } else {
            if let last = onwardLocations.last {
                matchingLocations = [last]
            } else {
                return false
            }
        }

        for location in matchingLocations {
            if let platform = PlatformHelper.effectivePlatform(from: location.properties) {
                if destinationPlatforms.contains(platform) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Destination Platform Extraction

    public static func availableDestinationPlatforms(departures: [StopEvent], destinations: [String]?) -> [String] {
        var platforms = Set<String>()

        for departure in departures {
            guard let onwardLocations = departure.onwardLocations else { continue }

            let matchingLocations: [Platform]
            if let destinations = destinations, !destinations.isEmpty {
                matchingLocations = onwardLocations.filter { location in
                    guard let name = location.name?.lowercased() else { return false }
                    return destinations.contains { name.contains($0.lowercased()) }
                }
            } else {
                if let last = onwardLocations.last {
                    matchingLocations = [last]
                } else {
                    continue
                }
            }

            for location in matchingLocations {
                if let platform = PlatformHelper.effectivePlatform(from: location.properties) {
                    platforms.insert(platform)
                }
            }
        }

        return PlatformHelper.sortPlatforms(Array(platforms))
    }

    // MARK: - Arrival Time at Destination

    public static func arrivalTimeAtDestination(departure: StopEvent, destinations: [String]?) -> Date? {
        guard let onwardLocations = departure.onwardLocations else { return nil }

        if let destinations = destinations, !destinations.isEmpty {
            for location in onwardLocations {
                guard let name = location.name?.lowercased() else { continue }
                let matches = destinations.contains { name.contains($0.lowercased()) }
                if matches {
                    let timeString = location.arrivalTimeEstimated ?? location.arrivalTimePlanned
                    if let timeString = timeString {
                        return Date.parseISO8601(timeString)
                    }
                }
            }
        }

        if let lastLocation = onwardLocations.last {
            let timeString = lastLocation.arrivalTimeEstimated ?? lastLocation.arrivalTimePlanned
            if let timeString = timeString {
                return Date.parseISO8601(timeString)
            }
        }

        return nil
    }

    // MARK: - Complete Filtering Pipeline
    public static func getFilteredDepartures(departures: [StopEvent],
                                             destinationFilters: [String]?,
                                             platformFilters: [String]?,
                                             transportTypeFilters: [String]?,
                                             destinationPlatformFilters: [String]? = nil) -> [StopEvent] {
        var filtered = departures

        if let destinationFilters = destinationFilters, !destinationFilters.isEmpty {
            filtered = filtered.filter { departure in
                hasDestinationInRoute(departure: departure, destinations: destinationFilters)
            }
        }

        if let platformFilters = platformFilters, !platformFilters.isEmpty {
            filtered = filtered.filter { departure in
                hasPlatformMatch(departure: departure, platforms: platformFilters)
            }
        }

        if let transportTypeFilters = transportTypeFilters, !transportTypeFilters.isEmpty {
            let selectedTypes = Set(transportTypeFilters.compactMap { TransportType(rawValue: $0) })
            filtered = filtered.filter { departure in
                guard let product = departure.transportation?.product?.name else { return false }
                return selectedTypes.contains { transportType in
                    matchesTransportType(product: product, transportType: transportType)
                }
            }
        }

        if let destinationPlatformFilters = destinationPlatformFilters, !destinationPlatformFilters.isEmpty {
            filtered = filtered.filter { departure in
                hasDestinationPlatformMatch(departure: departure, destinationPlatforms: destinationPlatformFilters, destinations: destinationFilters)
            }
        }

        return filtered
    }
}
