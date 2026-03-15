import Foundation

private let departureMonitorURL = "https://def-efa-mvv02.defas-fgi.de/gullivr_ios/XML_DM_REQUEST"

/// Fetches departures directly from the MVV API.
/// Actor-free, safe to call from WidgetKit TimelineProviders.
public func fetchDepartures(locationId: String) async throws -> [StopEvent] {
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
        throw URLError(.badURL)
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(DepartureResponse.self, from: data)
    let stopEvents = response.stopEvents ?? []
    return DepartureTimeFormatter.sortDeparturesByEstimatedTime(stopEvents)
}
