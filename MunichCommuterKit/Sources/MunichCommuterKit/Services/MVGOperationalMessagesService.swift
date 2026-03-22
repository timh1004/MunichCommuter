import Foundation

/// Lädt Betriebsmeldungen von mvg.de (wie auf der Seite „Betriebsmeldungen“).
@MainActor
public final class MVGOperationalMessagesService: ObservableObject {
    @Published public private(set) var messages: [MVGOperationalMessage] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private static let messagesURL = URL(string: "https://www.mvg.de/api/bgw-pt/v3/messages")!
    private static let refererURL = URL(string: "https://www.mvg.de/verbindungen/betriebsmeldungen.html")!

    public init() {}

    public func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: Self.messagesURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.refererURL.absoluteString, forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Serverfehler (HTTP \(http.statusCode))"
                return
            }
            let decoded = try JSONDecoder().decode([MVGOperationalMessage].self, from: data)
            messages = decoded.sorted { $0.publication > $1.publication }
        } catch {
            errorMessage = "Meldungen konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }
}
