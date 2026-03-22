import SwiftUI

private struct RefreshDeparturesKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ToggleDepartureFiltersKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct OpenDeparturePlansKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var refreshDepartures: (() -> Void)? {
        get { self[RefreshDeparturesKey.self] }
        set { self[RefreshDeparturesKey.self] = newValue }
    }

    var toggleDepartureFilters: (() -> Void)? {
        get { self[ToggleDepartureFiltersKey.self] }
        set { self[ToggleDepartureFiltersKey.self] = newValue }
    }

    var openDeparturePlans: (() -> Void)? {
        get { self[OpenDeparturePlansKey.self] }
        set { self[OpenDeparturePlansKey.self] = newValue }
    }
}
