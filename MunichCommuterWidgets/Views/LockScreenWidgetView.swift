import SwiftUI

struct LockScreenWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.stationName)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(.secondary)

            if let error = entry.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if entry.departures.isEmpty {
                Text("Keine Abfahrten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.departures.prefix(2)) { departure in
                    WidgetDepartureRowView(departure: departure, entryDate: entry.date, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
