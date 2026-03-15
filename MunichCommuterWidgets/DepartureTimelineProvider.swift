import WidgetKit
import CoreLocation
import OSLog
import MunichCommuterKit

private let logger = Logger(subsystem: "com.iaha.mvgcommuter", category: "Widget")

struct DepartureTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = SelectFavoriteIntent
    typealias Entry = DepartureEntry

    func placeholder(in context: Context) -> DepartureEntry {
        .placeholder(configuration: SelectFavoriteIntent())
    }

    func snapshot(for configuration: SelectFavoriteIntent, in context: Context) async -> DepartureEntry {
        .placeholder(configuration: configuration)
    }

    func timeline(for configuration: SelectFavoriteIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let refreshDate = Date().addingTimeInterval(5 * 60)

        let favorites = loadFavoritesFromCloudStore()
        logger.info("Loaded \(favorites.count) favorites from KVS")
        for f in favorites {
            let hasCoord = f.location.coord != nil
            logger.info("  Favorite: \(f.displayName, privacy: .public) | coord=\(hasCoord)")
        }
        guard !favorites.isEmpty else {
            logger.warning("No favorites found in KVS")
            return Timeline(
                entries: [.error(message: "Keine Favoriten gespeichert.", configuration: configuration)],
                policy: .after(refreshDate)
            )
        }

        // Determine target favorite
        let targetFavorite: FilteredFavorite?
        if configuration.useNearest {
            let authStatus = CLLocationManager().authorizationStatus
            logger.info("Mode: useNearest — auth=\(authStatus.rawValue) — fetching location...")
            let location = await fetchLocationWithTimeout()
            if let loc = location {
                logger.info("Location received: \(loc.coordinate.latitude), \(loc.coordinate.longitude) (accuracy: \(loc.horizontalAccuracy)m)")
            } else {
                logger.warning("Location fetch timed out or failed — falling back to favorites.first")
            }
            let coord = location.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
            targetFavorite = nearestFavorite(to: coord ?? [], among: favorites)
            logger.info("Nearest favorite selected: \(targetFavorite?.displayName ?? "nil", privacy: .public)")
        } else if let favoriteId = configuration.favorite?.id {
            targetFavorite = favorites.first { $0.id == favoriteId }
            logger.info("Mode: manual — selected: \(targetFavorite?.displayName ?? "nil (id not found)", privacy: .public)")
        } else {
            targetFavorite = favorites.first
            logger.info("Mode: manual — no favorite configured, using first")
        }

        guard let favorite = targetFavorite else {
            return Timeline(
                entries: [.error(message: "Station nicht gefunden.", configuration: configuration)],
                policy: .after(refreshDate)
            )
        }

        // Fetch departures
        let locationId = favorite.location.id.normalizedStationId
        let stationName = favorite.location.disassembledName ?? favorite.location.name ?? "Unbekannte Station"
        let deepLinkURL = URL(string: "munichcommuter://station/\(locationId)?favoriteId=\(favorite.id.uuidString)")

        do {
            let allDepartures = try await fetchDepartures(locationId: locationId)

            // Apply favorite's filters
            let filtered = FilteringHelper.getFilteredDepartures(
                departures: allDepartures,
                destinationFilters: favorite.destinationFilters ?? [],
                platformFilters: favorite.platformFilters ?? [],
                transportTypeFilters: favorite.transportTypeFilters ?? []
            )

            // Map once so UUIDs are stable across all timeline entries
            let now = Date()
            let allWidgetDepartures = filtered
                .map { WidgetDeparture.from($0) }
                .filter { ($0.departureDate ?? now) >= now.addingTimeInterval(-60) }

            // Build timeline entries:
            // • One per minute from now → refreshDate so the countdown updates automatically
            // • One 5 s after each departure so the row animates out immediately
            var entryDates: [Date] = []

            var t = now
            while t <= refreshDate {
                entryDates.append(t)
                t = t.addingTimeInterval(60)
            }

            for dep in allWidgetDepartures.prefix(12) {
                if let depDate = dep.departureDate, depDate > now, depDate < refreshDate {
                    let trigger = depDate.addingTimeInterval(5)
                    if !entryDates.contains(where: { abs($0.timeIntervalSince(trigger)) < 15 }) {
                        entryDates.append(trigger)
                    }
                }
            }

            entryDates.sort()

            let entries: [DepartureEntry] = entryDates.map { entryDate in
                let visible = Array(allWidgetDepartures.filter {
                    ($0.departureDate ?? .distantFuture) >= entryDate
                }.prefix(12))
                return DepartureEntry(
                    date: entryDate,
                    fetchedAt: now,
                    stationName: stationName,
                    filterDescription: favorite.filterDisplayText,
                    departures: visible,
                    deepLinkURL: deepLinkURL,
                    errorMessage: nil,

                    configuration: configuration
                )
            }

            return Timeline(entries: entries, policy: .after(refreshDate))

        } catch {
            let entry = DepartureEntry(
                date: .now,
                fetchedAt: .now,
                stationName: stationName,
                filterDescription: favorite.filterDisplayText,
                departures: [],
                deepLinkURL: deepLinkURL,
                errorMessage: "Fehler beim Laden der Abfahrten.",
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(refreshDate))
        }
    }
}

// MARK: - Location helper

private func fetchLocationWithTimeout(timeout: TimeInterval = 5) async -> CLLocation? {
    // 1. Try the system's cached location first (synchronous, instant).
    let manager = CLLocationManager()
    if let cached = manager.location {
        let age = -cached.timestamp.timeIntervalSinceNow
        logger.info("Cached location available (age: \(Int(age))s)")
        if age < 600 { return cached }
    }

    // 2. Use CLLocationUpdate.liveUpdates() — works in widget extensions
    //    unlike the delegate-based requestLocation() which needs Always authorization.
    logger.info("No usable cached location — requesting via CLLocationUpdate.liveUpdates...")
    return await withTaskGroup(of: CLLocation?.self) { group in
        group.addTask {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location {
                        return location
                    }
                }
            } catch {
                logger.warning("CLLocationUpdate failed: \(error.localizedDescription)")
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
