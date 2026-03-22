import SwiftUI
import MunichCommuterKit

struct DisruptionDetailView: View {
    let message: DisruptionMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Type badge
                HStack {
                    Image(systemName: message.isIncident ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                        .foregroundColor(message.isIncident ? .red : .orange)
                    Text(message.isIncident ? "Störung" : "Fahrplanänderung")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(message.isIncident ? .red : .orange)

                    Spacer()

                    if message.isActive {
                        Text("Aktiv")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.green))
                    }
                }

                // Title
                Text(message.title)
                    .font(.title3)
                    .fontWeight(.bold)

                // Affected lines
                if let lines = message.lines, !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Betroffene Linien")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        FlowLayoutDetail(spacing: 6) {
                            ForEach(lines, id: \.self) { line in
                                HStack(spacing: 4) {
                                    DisruptionLineBadge(line: line)
                                    if line.sev == true {
                                        Image(systemName: "arrow.triangle.swap")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                // Validity period
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zeitraum")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        Label(formatDate(message.validFromDate), systemImage: "clock")
                        Text("–")
                        Text(formatDate(message.validToDate))
                    }
                    .font(.subheadline)
                }

                Divider()

                // Description
                Text(message.cleanDescription)
                    .font(.body)
                    .lineSpacing(4)

                // Links
                if let links = message.links, !links.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weitere Informationen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        ForEach(links) { link in
                            if let urlString = link.url, let url = URL(string: urlString) {
                                Link(destination: url) {
                                    HStack {
                                        Image(systemName: "link")
                                        Text(link.text ?? "Mehr Info")
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }

                // Publication date
                Text("Veröffentlicht: \(formatDate(message.publicationDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

// Duplicate-free flow layout for detail view
private struct FlowLayoutDetail: Layout {
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
