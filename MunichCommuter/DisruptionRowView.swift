import SwiftUI
import MunichCommuterKit

struct DisruptionRowView: View {
    let message: DisruptionMessage

    private var displayLines: [DisruptionLine] { message.displayLines }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(message.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Affected lines
                if !displayLines.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(Array(displayLines.prefix(8)), id: \.self) { line in
                            DisruptionLineBadge(line: line)
                        }
                        if displayLines.count > 8 {
                            Text("+\(displayLines.count - 8)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                }

                // Validity period
                HStack(spacing: 4) {
                    if message.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    Text(validityText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var validityText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")

        let now = Date()
        let from = message.validFromDate
        formatter.dateFormat = "dd.MM., HH:mm"
        let fromStr = formatter.string(from: from)

        guard let endMs = message.validToIfProvided else {
            if message.validFromDate > now {
                return "Ab \(fromStr)"
            }
            return "Ab \(fromStr) · Bis auf Weiteres"
        }

        let to = Date(timeIntervalSince1970: Double(endMs) / 1000)
        let calendar = Calendar.current
        let sameDay = calendar.isDate(from, inSameDayAs: to)

        if sameDay {
            formatter.dateFormat = "dd.MM., HH:mm"
            return "\(formatter.string(from: from)) – \(DateFormatter.shortTime.string(from: to))"
        }
        let toStr = formatter.string(from: to)
        if to > now {
            return "Bis \(toStr)"
        }
        return "\(fromStr) – \(toStr)"
    }
}

// Simple flow layout for line badges that wraps to next line
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f
    }()
}
