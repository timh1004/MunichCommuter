import SwiftUI

struct WidgetDepartureRowView: View {
    let departure: WidgetDeparture
    let entryDate: Date
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Line badge
            Text(departure.lineNumber)
                .font(compact ? .system(size: 11, weight: .bold) : .system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, compact ? 5 : 6)
                .padding(.vertical, compact ? 3 : 4)
                .background(departure.lineColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minWidth: compact ? 28 : 32)

            // Destination
            Text(departure.destination)
                .font(compact ? .caption2 : .caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Departure time (minutes countdown)
            if let date = departure.departureDate {
                let minutes = Int(date.timeIntervalSince(entryDate) / 60)
                Text(minutes <= 0 ? "Jetzt" : "\(minutes) Min.")
                    .font(.system(compact ? .caption2 : .caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(minutes <= 1 ? .orange : .primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.4), value: minutes)
            } else {
                Text("–")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}
