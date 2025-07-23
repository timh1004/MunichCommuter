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
        
        let timeString = estimatedTime ?? plannedTime ?? ""
        
        guard let departureDate = Date.parseISO8601(timeString) else {
            return ("--:--", nil)
        }
        
        let minutesFromNow = departureDate.minutesFromNow()
        
        // Berechne Verspätung falls verfügbar
        var delayMinutes: Int? = nil
        if includeDelay,
           let plannedString = plannedTime,
           let estimatedString = estimatedTime,
           let planned = Date.parseISO8601(plannedString),
           let estimated = Date.parseISO8601(estimatedString) {
            
            let difference = estimated.timeIntervalSince(planned)
            let delay = Int(difference / 60)
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
            // Abfahrt ist später - zeige Uhrzeit
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            timeDisplay = formatter.string(from: departureDate)
        }
        
        // Formatiere Verspätungsanzeige
        let delayDisplay = delayMinutes.map { "+\($0) Min" }
        
        return (timeDisplay, delayDisplay)
    }
}