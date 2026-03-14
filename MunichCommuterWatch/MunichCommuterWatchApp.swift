import SwiftUI
import MunichCommuterKit

@main
struct MunichCommuterWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTabView()
        }
    }
}

struct WatchTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchFavoritesView()
            }
            .tabItem {
                Label("Favoriten", systemImage: "star.fill")
            }

            NavigationStack {
                WatchStationsView()
            }
            .tabItem {
                Label("Suche", systemImage: "magnifyingglass")
            }
        }
    }
}
