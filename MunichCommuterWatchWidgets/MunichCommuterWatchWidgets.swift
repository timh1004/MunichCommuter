import SwiftUI
import WidgetKit

struct CommuterEntry: TimelineEntry {
    let date: Date
}

struct CommuterTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CommuterEntry {
        CommuterEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CommuterEntry) -> Void) {
        completion(CommuterEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommuterEntry>) -> Void) {
        let entry = CommuterEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct CircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "tram.fill")
                .font(.title3)
                .foregroundColor(.primary)
        }
    }
}

struct RectangularView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.title3)
            VStack(alignment: .leading) {
                Text("Abfahrten")
                    .font(.headline)
                    .widgetAccentable()
                Text("Tippen zum Öffnen")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InlineView: View {
    var body: some View {
        Label("Abfahrten", systemImage: "tram.fill")
    }
}

struct CornerView: View {
    var body: some View {
        Image(systemName: "tram.fill")
            .widgetLabel("Abfahrten")
    }
}

struct CommuterWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CommuterEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView()
        case .accessoryRectangular:
            RectangularView()
        case .accessoryInline:
            InlineView()
        case .accessoryCorner:
            CornerView()
        @unknown default:
            CircularView()
        }
    }
}

struct MunichCommuterWidget: Widget {
    let kind = "MunichCommuterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommuterTimelineProvider()) { entry in
            CommuterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Abfahrten")
        .description("Öffne die MunichCommuter App")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

@main
struct MunichCommuterWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MunichCommuterWidget()
    }
}
