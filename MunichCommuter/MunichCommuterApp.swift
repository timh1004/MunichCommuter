//
//  MunichCommuterApp.swift
//  MunichCommuter
//
//  Created by Tim Haug on 21.07.25.
//

import SwiftUI
import MunichCommuterKit

@main
struct MunichCommuterApp: App {
    @State private var widgetDeepLink: WidgetDeepLink?
    @StateObject private var navigationModel = AppNavigationModel()
    @StateObject private var disruptionService = DisruptionService()

    var body: some Scene {
        WindowGroup {
            MainTabView(widgetDeepLink: $widgetDeepLink)
                .environmentObject(navigationModel)
                .environmentObject(disruptionService)
                .onOpenURL { url in
                    // munichcommuter://station/{locationId}?favoriteId={uuid}
                    guard url.scheme == "munichcommuter",
                          url.host == "station" else { return }
                    let locationId = String(url.path.dropFirst()) // drop leading "/"
                    guard !locationId.isEmpty else { return }

                    // Extract optional favoriteId from query parameters
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let favoriteIdString = components?.queryItems?.first(where: { $0.name == "favoriteId" })?.value
                    let favoriteId = favoriteIdString.flatMap { UUID(uuidString: $0) }

                    widgetDeepLink = WidgetDeepLink(locationId: locationId, favoriteId: favoriteId)
                }
        }
        .commands {
            MunichCommuterCommands(navigation: navigationModel)
        }
    }
}

struct WidgetDeepLink: Equatable {
    let id = UUID()
    let locationId: String
    let favoriteId: UUID?
    static func == (lhs: WidgetDeepLink, rhs: WidgetDeepLink) -> Bool { lhs.id == rhs.id }
}
