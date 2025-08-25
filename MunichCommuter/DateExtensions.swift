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

enum TimeDisplayMode: String {
    case relative
    case absolute
}

struct DepartureTimeFormatter {
    static func formatDepartureTime(
        plannedTime: String?,
        estimatedTime: String?,
        includeDelay: Bool = true,
        mode: TimeDisplayMode = .relative
    ) -> (timeDisplay: String, delayDisplay: String?) {
        
        // Verwende die geschätzte Zeit für die Anzeige, aber berechne Minuten basierend auf der geplanten Zeit
        let displayTimeString = estimatedTime ?? plannedTime ?? ""
        
        guard let displayDate = Date.parseISO8601(displayTimeString) else {
            return ("--:--", nil)
        }
        
        // Berechne Minuten basierend auf der geschätzten Zeit (mit Verspätung)
        let timeStringForCalculation = estimatedTime ?? plannedTime ?? ""
        guard let timeDateForCalculation = Date.parseISO8601(timeStringForCalculation) else {
            return ("--:--", nil)
        }
        
        let minutesFromNow = timeDateForCalculation.minutesFromNow()
        
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
        
        // Formatiere die Zeitanzeige basierend auf dem Modus
        // Wenn es mehr als 60 Minuten sind, immer absolute Anzeige
        let effectiveMode: TimeDisplayMode = (minutesFromNow > 60) ? .absolute : mode
        let timeDisplay: String
        switch effectiveMode {
        case .relative:
            if minutesFromNow <= 0 {
                timeDisplay = "Jetzt"
            } else {
                timeDisplay = "\(minutesFromNow) Min"
            }
        case .absolute:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            timeDisplay = formatter.string(from: displayDate)
        }
        
        // Formatiere Verspätungsanzeige
        let delayDisplay = delayMinutes.map { "+\($0)" }
        
        return (timeDisplay, delayDisplay)
    }
    
    // MARK: - Sorting Logic
    
    /// Sortiert Abfahrten chronologisch nach der geschätzten Abfahrtszeit (mit Verspätung)
    static func sortDeparturesByEstimatedTime(_ departures: [StopEvent]) -> [StopEvent] {
        return departures.sorted { departure1, departure2 in
            let time1 = departure1.departureTimeEstimated ?? departure1.departureTimePlanned ?? ""
            let time2 = departure2.departureTimeEstimated ?? departure2.departureTimePlanned ?? ""
            
            guard let date1 = Date.parseISO8601(time1),
                  let date2 = Date.parseISO8601(time2) else {
                return false
            }
            
            return date1 < date2
        }
    }

    // MARK: - Delay Helper
    static func delayMinutes(planned: String?, estimated: String?) -> Int? {
        guard let plannedString = planned,
              let estimatedString = estimated,
              let plannedDate = Date.parseISO8601(plannedString),
              let estimatedDate = Date.parseISO8601(estimatedString) else {
            return nil
        }
        let diff = Int(estimatedDate.timeIntervalSince(plannedDate) / 60)
        return diff > 0 ? diff : nil
    }
}