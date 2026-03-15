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
        NavigationStack {
            WatchFavoritesView()
        }
    }
}
