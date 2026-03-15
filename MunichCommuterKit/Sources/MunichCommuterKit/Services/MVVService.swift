import Foundation
import Combine
import CoreLocation

@MainActor
public class MVVService: ObservableObject {
    @Published public var locations: [Location] = []
    @Published public var departures: [StopEvent] = []
    @Published public var departureLocations: [DepartureLocation] = []
    @Published public var isLoading = false
    @Published public var isDeparturesLoading = false
    @Published public var errorMessage: String?
    @Published public var departureErrorMessage: String?
    @Published public var lastDeparturesFetchAt: Date?

    private let stopFinderURL = "https://def-efa-mvv02.defas-fgi.de/gullivr_ios/XML_STOPFINDER_REQUEST"
    private let departureMonitorURL = "https://def-efa-mvv02.defas-fgi.de/gullivr_ios/XML_DM_REQUEST"

    public init() {}

    public func searchStops(name: String = "edua") {
        isLoading = true
        errorMessage = nil

        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: name),
            URLQueryItem(name: "type_sf", value: "any")
        ]

        guard let url = components?.url else {
            self.errorMessage = "Ungültige URL"
            self.isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }

                do {
                    let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                    self?.locations = mvvResponse.locations ?? []
                } catch {
                    self?.errorMessage = "Fehler beim Verarbeiten der Daten: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    public func searchNearbyStops(coordinate: String) {
        isLoading = true
        errorMessage = nil

        convertCoordinateToMVV(coordinate: coordinate) { [weak self] mvvCoordinate in
            DispatchQueue.main.async {
                guard let mvvCoordinate = mvvCoordinate else {
                    self?.errorMessage = "Koordinaten konnten nicht konvertiert werden"
                    self?.isLoading = false
                    return
                }
                self?.searchStopsNearMVVCoordinate(mvvCoordinate: mvvCoordinate)
            }
        }
    }

    private nonisolated func convertCoordinateToMVV(coordinate: String, completion: @escaping @Sendable (String?) -> Void) {
        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "convertCoord2LocationServer", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: coordinate),
            URLQueryItem(name: "type_sf", value: "coord"),
            URLQueryItem(name: "doNotSearchForStops_sf", value: "1")
        ]

        guard let url = components?.url else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                if let location = mvvResponse.locations?.first {
                    completion(location.id)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func searchStopsNearMVVCoordinate(mvvCoordinate: String) {
        var components = URLComponents(string: stopFinderURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "convertCoord2LocationServer", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "useProxFootSearch", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macro_sf", value: "gullivr"),
            URLQueryItem(name: "name_sf", value: mvvCoordinate),
            URLQueryItem(name: "type_sf", value: "any")
        ]

        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.errorMessage = "Ungültige URL für Haltestellensuche"
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }

                do {
                    let mvvResponse = try JSONDecoder().decode(MVVResponse.self, from: data)
                    let rawLocations = mvvResponse.locations ?? []

                    var nearbyStops: [Location] = []

                    for location in rawLocations {
                        if let assignedStops = location.assignedStops {
                            for stop in assignedStops {
                                let stopLocation = Location(
                                    id: stop.id,
                                    type: stop.type,
                                    name: stop.name,
                                    disassembledName: stop.name,
                                    coord: stop.coord,
                                    parent: stop.parent,
                                    assignedStops: nil,
                                    properties: stop.properties,
                                    distance: stop.distance,
                                    duration: stop.duration
                                )
                                nearbyStops.append(stopLocation)
                            }
                        }
                    }

                    self?.locations = nearbyStops
                } catch {
                    self?.errorMessage = "Fehler beim Verarbeiten der Daten: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    public func loadDepartures(for location: Location) {
        guard let locationId = extractLocationId(from: location) else {
            self.departureErrorMessage = "Ungültige Haltestellen-ID"
            return
        }
        loadDepartures(locationId: locationId)
    }

    public func loadDepartures(locationId: String) {
        isDeparturesLoading = true
        departureErrorMessage = nil

        var components = URLComponents(string: departureMonitorURL)
        components?.queryItems = [
            URLQueryItem(name: "excludedMeans", value: "checkbox"),
            URLQueryItem(name: "coordListOutputFormat", value: "STRING"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.ddddd]"),
            URLQueryItem(name: "imparedOptionsActive", value: "1"),
            URLQueryItem(name: "itOptionsActive", value: "1"),
            URLQueryItem(name: "locationServerActive", value: "1"),
            URLQueryItem(name: "ptOptionsActive", value: "1"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "useRealtime", value: "1"),
            URLQueryItem(name: "serverInfo", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "version", value: "10.6.20.22"),
            URLQueryItem(name: "macromobile_gullivr", value: "true"),
            URLQueryItem(name: "AllowEarlyDepartures", value: "true"),
            URLQueryItem(name: "name_dm", value: locationId),
            URLQueryItem(name: "type_dm", value: "any"),
            URLQueryItem(name: "depSearchType", value: "departurebyline"),
            URLQueryItem(name: "depType", value: "stopEvents"),
            URLQueryItem(name: "canChangeMOT", value: "0"),
            URLQueryItem(name: "includeCompleteStopSeq", value: "1"),
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "maxTimeLoop", value: "1"),
            URLQueryItem(name: "useAllStops", value: "1"),
            URLQueryItem(name: "mode", value: "direct")
        ]

        guard let url = components?.url else {
            self.departureErrorMessage = "Ungültige URL für Abfahrten"
            self.isDeparturesLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.isDeparturesLoading = false

                if let error = error {
                    self.departureErrorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self.departureErrorMessage = "Keine Abfahrtsdaten erhalten"
                    return
                }

                do {
                    let departureResponse = try JSONDecoder().decode(DepartureResponse.self, from: data)
                    let stopEvents = departureResponse.stopEvents ?? []

                    let sortedStopEvents = DepartureTimeFormatter.sortDeparturesByEstimatedTime(stopEvents)

                    self.departures = sortedStopEvents
                    self.departureLocations = departureResponse.locations ?? []
                    self.lastDeparturesFetchAt = Date()
                } catch {
                    self.departureErrorMessage = "Fehler beim Verarbeiten der Abfahrtsdaten: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    /// Loads departures and waits for the result using Combine instead of polling.
    public func loadDeparturesAsync(locationId: String) async {
        loadDepartures(locationId: locationId)
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = $isDeparturesLoading
                .dropFirst()
                .filter { !$0 }
                .first()
                .sink { _ in
                    cancellable?.cancel()
                    continuation.resume()
                }
        }
    }

    private func extractLocationId(from location: Location) -> String? {
        let normalizedId = location.id.normalizedStationId
        return normalizedId.isEmpty ? nil : normalizedId
    }
}
