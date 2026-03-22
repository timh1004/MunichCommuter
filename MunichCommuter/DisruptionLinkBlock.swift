import MunichCommuterKit
import SwiftUI

// MARK: - Link-Art

private enum DisruptionLinkKind: Equatable {
    case pdf
    case image
    case web
}

private enum DisruptionLinkContentResolver {
    static func resolve(url: URL, linkTitle: String?) async -> DisruptionLinkKind {
        let path = url.path.lowercased()
        if path.hasSuffix(".pdf") {
            return .pdf
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 20
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return fallbackPDF(from: linkTitle) ?? .web
            }
            let raw = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            let mime = raw.lowercased().split(separator: ";").first.map(String.init) ?? ""
            if mime.hasPrefix("image/") {
                return .image
            }
            if mime == "application/pdf" || mime == "application/x-pdf" {
                return .pdf
            }
            return .web
        } catch {
            return fallbackPDF(from: linkTitle) ?? .web
        }
    }

    private static func fallbackPDF(from linkTitle: String?) -> DisruptionLinkKind? {
        guard let t = linkTitle, t.range(of: "pdf", options: .caseInsensitive) != nil else { return nil }
        return .pdf
    }
}

// MARK: - UI

/// Bilder inline, PDF wie im Rest der App, Web in Safari-View (iOS) bzw. System-Browser (andere Plattformen).
struct DisruptionLinkBlock: View {
    let link: DisruptionLink

    @State private var kind: DisruptionLinkKind?
    @State private var showSafari = false
    #if !os(iOS)
    @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        Group {
            if let url = link.resolvedURL {
                resolvedBody(url: url)
                    .task(id: url) {
                        kind = await DisruptionLinkContentResolver.resolve(url: url, linkTitle: link.text)
                    }
            }
        }
    }

    @ViewBuilder
    private func resolvedBody(url: URL) -> some View {
        if let kind {
            switch kind {
            case .pdf:
                NavigationLink {
                    PDFViewerView(title: link.displayTitle, url: url)
                } label: {
                    linkRowLabel(systemImage: "doc.fill", tint: .red)
                }
            case .image:
                VStack(alignment: .leading, spacing: 10) {
                    linkRowLabel(systemImage: "photo", tint: .accentColor)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                        case .failure:
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Bild konnte nicht geladen werden", systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                openInBrowserControl(url: url)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            case .web:
                openInBrowserControl(url: url)
            }
        } else {
            HStack {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Anhang wird erkannt…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func openInBrowserControl(url: URL) -> some View {
        #if os(iOS)
        Button {
            showSafari = true
        } label: {
            linkRowLabel(systemImage: "safari", tint: .accentColor)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSafari) {
            InAppSafariView(url: url)
                .ignoresSafeArea()
        }
        #else
        Button {
            openURL(url)
        } label: {
            linkRowLabel(systemImage: "safari", tint: .accentColor)
        }
        .buttonStyle(.plain)
        #endif
    }

    private func linkRowLabel(systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(link.displayTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private extension DisruptionLink {
    var displayTitle: String {
        let t = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t, !t.isEmpty { return t }
        return "Mehr Infos"
    }
}
