import SwiftUI
import MunichCommuterKit

struct WatchCompactDepartureRow: View {
    let departure: StopEvent
    @State private var now = Date()

    var body: some View {
        HStack(spacing: 4) {
            let appearance = DepartureRowStyling.lineBadgeAppearance(for: departure)
            ZStack {
                LineBadgeBackground(appearance: appearance, cornerRadius: 3)
                    .frame(width: 26, height: 16)
                Text(departure.transportation?.number ?? "?")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(appearance.foreground)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

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
