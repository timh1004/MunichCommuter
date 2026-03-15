import WidgetKit
import SwiftUI

struct MunichCommuterDepartureWidget: Widget {
    let kind = "MunichCommuterDepartureWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectFavoriteIntent.self,
            provider: DepartureTimelineProvider()
        ) { entry in
            DepartureWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Abfahrten")
        .description("Zeigt die nächsten Abfahrten deiner Lieblingshaltestelle.")
        .supportedFamilies([
            .accessoryRectangular,
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}
