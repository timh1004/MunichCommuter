import SwiftUI
import MunichCommuterKit

enum AppTab: Hashable {
    case favoriten
    case stationen
}

struct MainTabView: View {
    @ObservedObject private var locationManager = LocationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = AppTab.favoriten
    @State private var stationsSearchIsActive = false

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
                NavigationStack {
                    FavoritesView()
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
    }
}

#Preview {
    MainTabView()
}
