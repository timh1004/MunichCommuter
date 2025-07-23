import Foundation

extension Date {
    static func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    func minutesFromNow() -> Int {
        let difference = self.timeIntervalSinceNow
        return Int(difference / 60)
    }
}

struct DepartureTimeFormatter {
    static func formatDepartureTime(
        plannedTime: String?,
        estimatedTime: String?,
        includeDelay: Bool = true
    ) -> (timeDisplay: String, delayDisplay: String?) {
        
        // Verwende die geschätzte Zeit für die Anzeige, aber berechne Minuten basierend auf der geplanten Zeit
        let displayTimeString = estimatedTime ?? plannedTime ?? ""
        
        guard let displayDate = Date.parseISO8601(displayTimeString) else {
            return ("--:--", nil)
        }
        
        // Berechne Minuten basierend auf der geplanten Zeit (ohne Verspätung)
        let plannedTimeString = plannedTime ?? estimatedTime ?? ""
        guard let plannedDate = Date.parseISO8601(plannedTimeString) else {
            return ("--:--", nil)
        }
        
        let minutesFromNow = plannedDate.minutesFromNow()
        
        // Berechne Verspätung falls verfügbar
        var delayMinutes: Int? = nil
        if includeDelay,
           let plannedString = plannedTime,
           let estimatedString = estimatedTime,
           let planned = Date.parseISO8601(plannedString),
           let estimated = Date.parseISO8601(estimatedString) {
            
            let difference = estimated.timeIntervalSince(planned)
            let delay = Int(difference / 60)
            // Zeige Verspätung nur wenn sie positiv ist (Zug ist später als geplant)
            if delay > 0 {
                delayMinutes = delay
            }
        }
        
        // Formatiere die Zeitanzeige basierend auf den Regeln
        let timeDisplay: String
        
        if minutesFromNow <= 0 {
            // Abfahrt ist jetzt oder in der Vergangenheit
            timeDisplay = "Jetzt"
        } else if minutesFromNow <= 20 {
            // Abfahrt ist in den nächsten 20 Minuten
            timeDisplay = "\(minutesFromNow) Min"
        } else {
            // Abfahrt ist später - zeige Uhrzeit der geschätzten Zeit
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            timeDisplay = formatter.string(from: displayDate)
        }
        
        // Formatiere Verspätungsanzeige
        let delayDisplay = delayMinutes.map { "+\($0)" }
        
        return (timeDisplay, delayDisplay)
    }
}