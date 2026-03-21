import SwiftUI
import MunichCommuterKit

enum AppTab: Hashable {
    case favoriten
    case stationen
}

/// Navigation value for deep-linking into a station detail with optional favorite filters.
struct StationDeepLink: Hashable {
    let locationId: String
    let locationName: String?
    let destinationFilters: [String]?
    let platformFilters: [String]?
    let transportTypeFilters: [String]?
    let destinationPlatformFilters: [String]?
    let sortByArrivalTime: Bool?
}

struct MainTabView: View {
    @Binding var widgetDeepLink: WidgetDeepLink?
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = AppTab.favoriten
    @State private var stationsSearchIsActive = false
    @State private var favoritesPath = NavigationPath()

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .stationen && selectedTab == .stationen {
                    // Re-tap on Stationen tab → activate search
                    stationsSearchIsActive = true
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Favoriten", systemImage: "star.fill", value: .favoriten) {
                NavigationStack(path: $favoritesPath) {
                    FavoritesView()
                        .navigationDestination(for: StationDeepLink.self) { link in
                            DepartureDetailView(
                                locationId: link.locationId,
                                locationName: link.locationName,
                                initialDestinationFilters: link.destinationFilters,
                                initialPlatformFilters: link.platformFilters,
                                initialTransportTypes: link.transportTypeFilters,
                                initialDestinationPlatformFilters: link.destinationPlatformFilters,
                                initialSortByArrivalTime: link.sortByArrivalTime
                            )
                        }
                }
            }

            Tab("Stationen", systemImage: "magnifyingglass", value: .stationen) {
                NavigationStack {
                    StationsView(activateSearch: $stationsSearchIsActive)
                }
            }
        }
        .onAppear {
            // Start with a single shot to get initial location quickly
            locationManager.requestSingleLocation()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // App is active - views will decide what tracking they need
                if locationManager.currentTrackingMode == .background {
                    locationManager.requestSingleLocation()
                }
            case .background, .inactive:
                // App going to background - switch to low-power significant changes
                if locationManager.currentTrackingMode == .precise {
                    locationManager.startBackgroundUpdates()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: widgetDeepLink) { _, deepLink in
            guard let deepLink else { return }
            // Switch to Favoriten tab and pop to root first
            selectedTab = .favoriten
            favoritesPath = NavigationPath()
            widgetDeepLink = nil

            // Look up matching favorite to pass its filters.
            // Prefer exact match by favoriteId, fall back to locationId.
            let matchingFavorite: FilteredFavorite? = {
                if let fid = deepLink.favoriteId {
                    return favoritesManager.favorites.first { $0.id == fid }
                }
                let normalizedId = deepLink.locationId.normalizedStationId
                return favoritesManager.favorites.first {
                    $0.location.id.normalizedStationId == normalizedId
                }
            }()

            let link = StationDeepLink(
                locationId: deepLink.locationId,
                locationName: matchingFavorite?.displayName,
                destinationFilters: matchingFavorite?.destinationFilters,
                platformFilters: matchingFavorite?.platformFilters,
                transportTypeFilters: matchingFavorite?.transportTypeFilters,
                destinationPlatformFilters: matchingFavorite?.destinationPlatformFilters,
                sortByArrivalTime: matchingFavorite?.sortByArrivalTime
            )

            // Delay the push so SwiftUI can process the pop-to-root first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                favoritesPath.append(link)
            }
        }
    }
}

#Preview {
    MainTabView(widgetDeepLink: .constant(nil))
}
