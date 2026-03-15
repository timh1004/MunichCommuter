import SwiftUI
import MunichCommuterKit

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView {
            // Favoriten Tab
            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Image(systemName: "star.fill")
                Text("Favoriten")
            }

            // Stationen Tab
            NavigationStack {
                StationsView()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Stationen")
            }
        }
        .tint(.blue)
        .onAppear {
            // Start with a single shot to get initial location quickly
            locationManager.requestSingleLocation()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // App is active - views will decide what tracking they need
                // Default to single shot for general app use
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