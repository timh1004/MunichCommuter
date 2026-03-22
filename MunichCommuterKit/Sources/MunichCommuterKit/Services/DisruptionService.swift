import Foundation
import Combine

@MainActor
public class DisruptionService: ObservableObject {
    @Published public var messages: [DisruptionMessage] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var lastFetchAt: Date?

    private let messagesURL = "https://www.mvg.de/api/bgw-pt/v3/messages"

    public init() {}

    /// Set of line numbers with active disruptions, for quick lookup.
    public var affectedLineNumbers: Set<String> {
        Set(messages.filter(\.isActive).flatMap { $0.lines?.map(\.lineNumber) ?? [] })
    }

    /// Check if a specific line number has an active disruption.
    public func hasActiveDisruption(for lineNumber: String) -> Bool {
        affectedLineNumbers.contains(lineNumber)
    }

    /// Active disruptions affecting a given line number.
    public func activeDisruptions(for lineNumber: String) -> [DisruptionMessage] {
        messages.filter { message in
            message.isActive && (message.lines ?? []).contains(where: { $0.lineNumber == lineNumber })
        }
    }

    public func loadMessages() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: messagesURL) else {
            self.errorMessage = "Ungültige URL"
            self.isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode([DisruptionMessage].self, from: data)
                    // Sort: active first (by validFrom desc), then inactive
                    self?.messages = decoded.sorted { a, b in
                        if a.isActive != b.isActive { return a.isActive }
                        return a.validFrom > b.validFrom
                    }
                    self?.lastFetchAt = Date()
                } catch {
                    self?.errorMessage = "Fehler beim Verarbeiten: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    /// Async wrapper using Combine, following MVVService pattern.
    public func loadMessagesAsync() async {
        loadMessages()
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = $isLoading
                .dropFirst()
                .filter { !$0 }
                .first()
                .sink { _ in
                    cancellable?.cancel()
                    continuation.resume()
                }
        }
    }
}
