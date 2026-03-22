import SwiftUI
import WebKit
import MunichCommuterKit

// MARK: - HTML (Betriebsmeldungen enthalten HTML aus der MVG-API)

private struct MVGBetriebsmeldungHTMLView: UIViewRepresentable {
    let htmlBody: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let page = """
        <!DOCTYPE html>
        <html lang="de">
        <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <style>
          body { font: -apple-system-body; color: -apple-system-label; padding: 0 4px; }
          p { margin: 0.6em 0; }
        </style>
        </head>
        <body>\(htmlBody)</body>
        </html>
        """
        webView.loadHTMLString(page, baseURL: URL(string: "https://www.mvg.de"))
    }
}

// MARK: - Linien-Badge (MVG-Meldung)

private struct DisruptionLineBadge: View {
    let line: MVGOperationalMessageLine

    var body: some View {
        let color = DepartureRowStyling.lineColorForMVGDisruptionLine(
            label: line.label,
            transportType: line.transportType
        )
        Text(line.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityLabel("Linie \(line.label)")
    }
}

// MARK: - Detail

private struct OperationalMessageDetailView: View {
    let message: MVGOperationalMessage
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !message.uniqueLines.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(message.uniqueLines, id: \.self) { line in
                                DisruptionLineBadge(line: line)
                            }
                        }
                    }
                }

                if let meta = metadataLine {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let links = message.links, !links.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weitere Infos")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                            if let urlString = link.url, let url = URL(string: urlString) {
                                Button(link.text ?? urlString) {
                                    openURL(url)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }

                MVGBetriebsmeldungHTMLView(htmlBody: message.description)
                    .frame(minHeight: 280)
            }
            .padding()
        }
        .navigationTitle("Meldung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataLine: String? {
        var parts: [String] = []
        if let typeLabel = message.type.flatMap(Self.typeDisplayName) {
            parts.append(typeLabel)
        }
        if let from = formatMillis(message.validFrom), let to = formatMillis(message.validTo) {
            parts.append("Gültig \(from) – \(to)")
        } else if let from = formatMillis(message.validFrom) {
            parts.append("Gültig ab \(from)")
        }
        if parts.isEmpty { return nil }
        return parts.joined(separator: " · ")
    }

    private static func typeDisplayName(_ raw: String) -> String? {
        switch raw {
        case "SCHEDULE_CHANGE":
            return "Fahrplan / Bau / Umleitung"
        default:
            return raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func formatMillis(_ millis: Int64?) -> String? {
        guard let millis else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Hauptansicht (Tab „Störungen“)

struct DisruptionsView: View {
    @StateObject private var service = MVGOperationalMessagesService()
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.scenePhase) private var scenePhase

    private var favoriteStationIds: Set<String> {
        Set(favoritesManager.favorites.map(\.location.id.normalizedStationId))
    }

    private var relevantForFavorites: [MVGOperationalMessage] {
        service.messages.filter { $0.affectsFavoriteStations(favoriteStationIds) }
    }

    private var otherMessages: [MVGOperationalMessage] {
        let relevantIds = Set(relevantForFavorites.map(\.id))
        return service.messages.filter { !relevantIds.contains($0.id) }
    }

    var body: some View {
        Group {
            if service.isLoading && service.messages.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Meldungen werden geladen…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = service.errorMessage, service.messages.isEmpty {
                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Störungen")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await service.loadMessages()
        }
        .task {
            await service.loadMessages()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await service.loadMessages() }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if service.messages.isEmpty {
            ContentUnavailableView(
                "Keine Meldungen",
                systemImage: "checkmark.circle",
                description: Text("Aktuell liegen keine Betriebsmeldungen vor.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !relevantForFavorites.isEmpty {
                    Section("Betrifft Ihre Favoriten") {
                        ForEach(relevantForFavorites) { message in
                            NavigationLink {
                                OperationalMessageDetailView(message: message)
                            } label: {
                                OperationalMessageRowView(message: message)
                            }
                        }
                    }
                }

                if !otherMessages.isEmpty {
                    Section(relevantForFavorites.isEmpty ? "Aktuelle Meldungen" : "Weitere Meldungen") {
                        ForEach(otherMessages) { message in
                            NavigationLink {
                                OperationalMessageDetailView(message: message)
                            } label: {
                                OperationalMessageRowView(message: message)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct OperationalMessageRowView: View {
    let message: MVGOperationalMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !message.uniqueLines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(message.uniqueLines, id: \.self) { line in
                            DisruptionLineBadge(line: line)
                        }
                    }
                }
            }

            if let published = formatPublication(message.publication) {
                Text(published)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatPublication(_ millis: Int64) -> String? {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Veröffentlicht: \(formatter.string(from: date))"
    }
}

#Preview {
    NavigationStack {
        DisruptionsView()
    }
}
