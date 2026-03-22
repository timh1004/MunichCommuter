import SwiftUI

struct MunichCommuterCommands: Commands {
    @ObservedObject var navigation: AppNavigationModel
    @FocusedValue(\.refreshDepartures) private var refreshDepartures
    @FocusedValue(\.toggleDepartureFilters) private var toggleDepartureFilters
    @FocusedValue(\.openDeparturePlans) private var openDeparturePlans

    var body: some Commands {
        CommandMenu("Navigation") {
            Button("Favoriten") {
                navigation.selectedTab = .favoriten
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Stationen") {
                navigation.selectedTab = .stationen
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Haltestelle suchen") {
                navigation.focusStationsSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("Abfahrten") {
            Button("Aktualisieren") {
                refreshDepartures?()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(refreshDepartures == nil)

            Button("Filter") {
                toggleDepartureFilters?()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(toggleDepartureFilters == nil)

            Button("Pläne") {
                openDeparturePlans?()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(openDeparturePlans == nil)
        }
    }
}
