import AppIntents
import SwiftUI
import WidgetKit

struct DepartureWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DepartureEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                LockScreenWidgetView(entry: entry)
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemLarge:
                MediumLargeWidgetView(entry: entry, maxRows: 7)
            default:
                MediumLargeWidgetView(entry: entry, maxRows: 4)
            }
        }
        .widgetURL(entry.deepLinkURL)
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(entry.stationName)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)

            if let filter = entry.filterDescription {
                Text(filter)
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            if let error = entry.errorMessage {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if let departure = entry.departures.first {
                Spacer(minLength: 4)

                // Line badge + destination
                HStack(spacing: 6) {
                    Text(departure.lineNumber)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(departure.lineColor)
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    Text(departure.destination)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .bottom),
                    removal: .push(from: .top)
                ))

                Spacer(minLength: 2)

                // Hero countdown
                if let date = departure.departureDate {
                    let minutes = Int(date.timeIntervalSince(entry.date) / 60)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Spacer()
                        if minutes <= 0 {
                            Text("Jetzt")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        } else {
                            Text("\(minutes)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(minutes <= 1 ? .orange : .primary)
                                .contentTransition(.numericText(countsDown: true))
                                .animation(.easeInOut(duration: 0.4), value: minutes)
                            Text("Min.")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            } else {
                Spacer()
                Text("Keine Abfahrten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Minimal refresh button (icon only)
            HStack {
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(entry.isStale ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.35), value: entry.departures.first?.id)
    }
}

// MARK: - Medium / Large

struct MediumLargeWidgetView: View {
    let entry: DepartureEntry
    let maxRows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.stationName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if let filter = entry.filterDescription {
                        Text(filter)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            Divider()

            // Departures or error state
            if let error = entry.errorMessage {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if entry.departures.isEmpty {
                Spacer()
                Text("Keine Abfahrten verfügbar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                VStack(spacing: 5) {
                    ForEach(entry.departures.prefix(maxRows)) { departure in
                        WidgetDepartureRowView(departure: departure, entryDate: entry.date)
                            .transition(.asymmetric(
                                insertion: .push(from: .bottom),
                                removal: .push(from: .top)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: entry.departures.map(\.id))
                Spacer(minLength: 0)
            }

            RefreshTimestampView(fetchedAt: entry.fetchedAt, isStale: entry.isStale)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Refresh Timestamp

struct RefreshTimestampView: View {
    let fetchedAt: Date
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            Button(intent: RefreshWidgetIntent()) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(fetchedAt, style: .time)
                        .font(.system(.caption2, design: .monospaced))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.5), value: fetchedAt)
                }
                .foregroundColor(isStale ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
