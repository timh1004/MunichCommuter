//
//  CompactDepartureRow.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

struct CompactDepartureRow: View {
    let departure: WatchDeparture
    let showPlatform: Bool
    
    init(departure: WatchDeparture, showPlatform: Bool = false) {
        self.departure = departure
        self.showPlatform = showPlatform
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Transport Line Badge
            TransportBadgeWatch(departure: departure)
            
            // Destination (truncated for watch)
            VStack(alignment: .leading, spacing: 0) {
                Text(departure.destination ?? "Unbekanntes Ziel")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if showPlatform, let platform = departure.platform {
                    Text("Gl. \(platform)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 2)
            
            // Time and delay
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 2) {
                    Text(departure.displayTime)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                        .foregroundColor(timeColor)
                    
                    if let delayText = departure.delayText {
                        Text(delayText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                if let minutes = departure.minutesUntilDeparture {
                    Text(minutesText(minutes))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var timeColor: Color {
        guard let minutes = departure.minutesUntilDeparture else {
            return .primary
        }
        
        if minutes <= 2 {
            return .orange
        } else if minutes <= 5 {
            return .yellow
        } else {
            return .primary
        }
    }
    
    private func minutesText(_ minutes: Int) -> String {
        if minutes == 0 {
            return "jetzt"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }
}

struct TransportBadgeWatch: View {
    let departure: WatchDeparture
    
    var body: some View {
        HStack(spacing: 2) {
            // Transport type indicator
            if let transportType = departure.transportType {
                Circle()
                    .fill(transportType.color)
                    .frame(width: 8, height: 8)
            }
            
            // Line number or name
            Text(lineDisplayText)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(departure.transportType?.color ?? .gray)
                .lineLimit(1)
                .frame(minWidth: 20)
        }
    }
    
    private var lineDisplayText: String {
        if let number = departure.lineNumber {
            return number
        } else if let name = departure.lineName {
            return name
        } else {
            return departure.transportType?.shortName ?? "?"
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CompactDepartureRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            CompactDepartureRow(
                departure: WatchDeparture(
                    id: UUID(),
                    lineName: "U6",
                    lineNumber: "U6",
                    destination: "Garching-Forschungszentrum",
                    departureTime: "2024-01-15T14:30:00.000Z",
                    estimatedTime: "2024-01-15T14:32:00.000Z",
                    platform: "1",
                    transportType: .uBahn,
                    delay: 2,
                    isRealtime: true
                )
            )
            
            CompactDepartureRow(
                departure: WatchDeparture(
                    id: UUID(),
                    lineName: "S1",
                    lineNumber: "S1",
                    destination: "Freising",
                    departureTime: "2024-01-15T14:35:00.000Z",
                    estimatedTime: nil,
                    platform: "2",
                    transportType: .sBahn,
                    delay: nil,
                    isRealtime: false
                ),
                showPlatform: true
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif