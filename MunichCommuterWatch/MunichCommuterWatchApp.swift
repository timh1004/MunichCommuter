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
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @State private var deepLinkFavorite: FilteredFavorite?

    var body: some View {
        NavigationStack {
            WatchFavoritesView()
                .navigationDestination(isPresented: Binding(
                    get: { deepLinkFavorite != nil },
                    set: { if !$0 { deepLinkFavorite = nil } }
                )) {
                    if let fav = deepLinkFavorite {
                        WatchDepartureListView(
                            locationId: fav.location.id,
                            locationName: fav.location.disassembledName ?? fav.location.name ?? "Station",
                            destinationFilters: fav.destinationFilters,
                            platformFilters: fav.platformFilters,
                            transportTypeFilters: fav.transportTypeFilters
                        )
                    }
                }
        }
        .onOpenURL { url in
            // munichcommuter://station/{locationId}?favoriteId={uuid}
            guard url.scheme == "munichcommuter", url.host == "station" else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let favoriteIdStr = components?.queryItems?.first(where: { $0.name == "favoriteId" })?.value,
                  let favoriteId = UUID(uuidString: favoriteIdStr) else { return }
            deepLinkFavorite = favoritesManager.favorites.first { $0.id == favoriteId }
        }
    }
}
