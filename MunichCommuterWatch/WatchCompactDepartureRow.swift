import SwiftUI
import MunichCommuterKit

struct WatchCompactDepartureRow: View {
    let departure: StopEvent
    @State private var now = Date()

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(DepartureRowStyling.lineColor(for: departure))
                .frame(width: 26, height: 16)
                .overlay(
                    Text(departure.transportation?.number ?? "?")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                )

            Text(departure.transportation?.destination?.name ?? "—")
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(DepartureRowStyling.formattedDepartureTime(for: departure, mode: .relative, referenceDate: now))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(DepartureRowStyling.shouldShowOrange(for: departure) ? .orange : .secondary)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            self.now = date
        }
    }
}
