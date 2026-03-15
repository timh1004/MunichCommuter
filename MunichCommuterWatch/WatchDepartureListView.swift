import SwiftUI
import MunichCommuterKit

struct WatchDepartureListView: View {
    let locationId: String
    let locationName: String
    var destinationFilters: [String]? = nil
    var platformFilters: [String]? = nil
    var transportTypeFilters: [String]? = nil

    @StateObject private var mvvService = MVVService()
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()

    private var resolvedLocation: Location {
        let departureLocation = mvvService.departureLocations.first { $0.id == locationId }
        return Location(
            id: locationId,
            type: "stop",
            name: departureLocation?.name ?? locationName,
            disassembledName: locationName,
            coord: departureLocation?.coord,
            parent: nil,
            assignedStops: nil,
            properties: departureLocation?.properties
        )
    }

    private var isFavorite: Bool {
        favoritesManager.isFavorite(
            resolvedLocation,
            destinationFilters: destinationFilters,
            platformFilters: platformFilters,
            transportTypeFilters: transportTypeFilters
        )
    }

    private var filteredDepartures: [StopEvent] {
        FilteringHelper.getFilteredDepartures(
            departures: mvvService.departures,
            destinationFilters: destinationFilters,
            platformFilters: platformFilters,
            transportTypeFilters: transportTypeFilters
        )
    }

    var body: some View {
        List {
            if mvvService.isDeparturesLoading && filteredDepartures.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Lade...")
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            } else if let error = mvvService.departureErrorMessage, filteredDepartures.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                        Button("Neu laden") {
                            mvvService.loadDepartures(locationId: locationId)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .listRowBackground(Color.clear)
            } else if filteredDepartures.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tram")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Keine Abfahrten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredDepartures) { departure in
                    WatchDepartureRow(departure: departure, now: now)
                }
            }
        }
        .navigationTitle(locationName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesManager.toggleFavorite(
                        resolvedLocation,
                        destinationFilters: destinationFilters,
                        platformFilters: platformFilters,
                        transportTypeFilters: transportTypeFilters
                    )
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
            }
        }
        .onAppear {
            mvvService.loadDepartures(locationId: locationId)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            self.now = date
            if let last = mvvService.lastDeparturesFetchAt, last.isOlder(thanMinutes: 1) {
                mvvService.loadDepartures(locationId: locationId)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                self.now = Date()
                mvvService.loadDepartures(locationId: locationId)
            }
        }
    }

}

struct WatchDepartureRow: View {
    let departure: StopEvent
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            TransportBadge(departure: departure, size: .compact)

            VStack(alignment: .leading, spacing: 1) {
                Text(departure.transportation?.destination?.name ?? "—")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if DepartureRowStyling.isRealtime(for: departure) {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("Live")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(DepartureRowStyling.formattedDepartureTime(for: departure, mode: .relative, referenceDate: now))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .primary)

                if let delay = DepartureRowStyling.delayDisplay(for: departure) {
                    Text(delay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
