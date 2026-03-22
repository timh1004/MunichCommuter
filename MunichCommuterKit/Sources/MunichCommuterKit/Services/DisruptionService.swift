import Combine
import Foundation
import os

private let disruptionLogger = Logger(subsystem: "MunichCommuterKit", category: "DisruptionService")

@MainActor
public class DisruptionService: ObservableObject {
    @Published public var messages: [DisruptionMessage] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var lastFetchAt: Date?

    private let messagesURL = "https://www.mvg.de/api/bgw-pt/v3/messages"

    public init() {}

    /// Alle aktiven Meldungen (Störungen + Fahrplanänderungen) — betroffene Linien.
    public var affectedLineNumbers: Set<String> {
        Set(messages.filter(\.isActive).flatMap { $0.lines?.map(\.lineNumber) ?? [] })
    }

    /// Nur **INCIDENT** (akute Störung), für Warnungen in Favoriten & Co.
    public var incidentAffectedLineNumbers: Set<String> {
        Set(messages.filter { $0.isActive && $0.isIncident }.flatMap { $0.lines?.map(\.lineNumber) ?? [] })
    }

    /// Nur **SCHEDULE_CHANGE** (Fahrplanänderung).
    public var scheduleChangeAffectedLineNumbers: Set<String> {
        Set(messages.filter { $0.isActive && $0.isScheduleChange }.flatMap { $0.lines?.map(\.lineNumber) ?? [] })
    }

    /// Ob für die Linie eine **akute Störung** (INCIDENT) aktiv ist.
    public func hasActiveDisruption(for lineNumber: String) -> Bool {
        incidentAffectedLineNumbers.contains(lineNumber)
    }

    /// Aktive **Störungen** (INCIDENT) für diese Linie.
    public func activeDisruptions(for lineNumber: String) -> [DisruptionMessage] {
        messages.filter { message in
            message.isActive && message.isIncident && (message.lines ?? []).contains(where: { $0.lineNumber == lineNumber })
        }
    }

    /// Lädt nur, wenn noch keine Daten da sind oder der letzte Abruf älter als `maxAgeMinutes` ist.
    public func loadMessagesIfStale(maxAgeMinutes: Double = 5) {
        if messages.isEmpty || lastFetchAt?.isOlder(thanMinutes: maxAgeMinutes) == true {
            loadMessages()
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
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.mvg.de/verbindungen/betriebsmeldungen.html", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    disruptionLogger.error("Network error: \(error.localizedDescription, privacy: .public)")
                    self?.errorMessage = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    disruptionLogger.error("Empty response body (nil data)")
                    self?.errorMessage = "Keine Daten erhalten"
                    return
                }

                if let http = response as? HTTPURLResponse {
                    disruptionLogger.debug("messages HTTP \(http.statusCode) bytes=\(data.count)")
                    if http.statusCode != 200 {
                        disruptionLogger.error("Unexpected status \(http.statusCode) bytes=\(data.count)")
                    }
                }

                do {
                    let decoded = try JSONDecoder().decode([DisruptionMessage].self, from: data)
                    disruptionLogger.debug("Decoded \(decoded.count) disruption messages (unfiltered; UI: „Nur aktuelle“)")
                    self?.messages = Self.sortRelevantMessages(decoded)
                    self?.lastFetchAt = Date()
                } catch {
                    let detail = Self.decodingErrorDetail(error)
                    disruptionLogger.error("JSON decode failed: \(detail, privacy: .public)")
                    let preview = String(data: data.prefix(1_200), encoding: .utf8) ?? "<binary>"
                    disruptionLogger.error("Response preview: \(preview, privacy: .public)")
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

    /// Störungen (`INCIDENT`) zuerst, darunter Fahrplanänderungen. Änderungen nach Ende (`validTo`) aufsteigend; Störungen nach Beginn (`validFrom`) absteigend.
    private static func sortRelevantMessages(_ messages: [DisruptionMessage]) -> [DisruptionMessage] {
        messages.sorted { a, b in
            let aSched = isScheduleChange(a)
            let bSched = isScheduleChange(b)
            if aSched != bSched {
                return !aSched && bSched
            }
            if aSched {
                if a.validTo != b.validTo {
                    return a.validTo < b.validTo
                }
                return a.validFrom > b.validFrom
            }
            if a.validFrom != b.validFrom {
                return a.validFrom > b.validFrom
            }
            return a.id < b.id
        }
    }

    private static func isScheduleChange(_ message: DisruptionMessage) -> Bool {
        message.type == "SCHEDULE_CHANGE" || message.type == "SCHEDULE_CHANGES"
    }

    private static func decodingErrorDetail(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else {
            return String(describing: error)
        }
        switch decoding {
        case .keyNotFound(let key, let ctx):
            return "keyNotFound \(key.stringValue) path=\(codingPathString(ctx.codingPath)) — \(ctx.debugDescription)"
        case .typeMismatch(let type, let ctx):
            return "typeMismatch \(type) path=\(codingPathString(ctx.codingPath)) — \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            return "valueNotFound \(type) path=\(codingPathString(ctx.codingPath)) — \(ctx.debugDescription)"
        case .dataCorrupted(let ctx):
            return "dataCorrupted path=\(codingPathString(ctx.codingPath)) — \(ctx.debugDescription)"
        @unknown default:
            return String(describing: decoding)
        }
    }

    private static func codingPathString(_ path: [CodingKey]) -> String {
        path.map(\.stringValue).joined(separator: ".")
    }
}
