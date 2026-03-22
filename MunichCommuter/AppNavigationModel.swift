import SwiftUI

enum AppTab: Hashable {
    case favoriten
    case stationen
}

@MainActor
final class AppNavigationModel: ObservableObject {
    @Published var selectedTab: AppTab = .favoriten
    @Published var activateStationsSearch = false

    func focusStationsSearch() {
        selectedTab = .stationen
        activateStationsSearch = true
    }
}
