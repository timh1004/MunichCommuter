import Foundation

extension Date {
    public static func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    public func minutesFromNow() -> Int {
        let difference = self.timeIntervalSinceNow
        return Int(difference / 60)
    }

    public func isOlder(thanMinutes minutes: Double, comparedTo referenceDate: Date = Date()) -> Bool {
        return referenceDate.timeIntervalSince(self) > minutes * 60
    }
}

public enum TimeDisplayMode: String, Sendable {
    case relative
    case absolute
}

public struct DepartureTimeFormatter {
    public static func formatDepartureTime(
        plannedTime: String?,
        estimatedTime: String?,
        includeDelay: Bool = true,
        mode: TimeDisplayMode = .relative,
        referenceDate: Date = Date()
    ) -> (timeDisplay: String, delayDisplay: String?) {

        let displayTimeString = estimatedTime ?? plannedTime ?? ""

        guard let displayDate = Date.parseISO8601(displayTimeString) else {
            return ("--:--", nil)
        }

        let timeStringForCalculation = estimatedTime ?? plannedTime ?? ""
        guard let timeDateForCalculation = Date.parseISO8601(timeStringForCalculation) else {
            return ("--:--", nil)
        }

        let minutesFromNow = Int(timeDateForCalculation.timeIntervalSince(referenceDate) / 60)

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

        let effectiveMode: TimeDisplayMode = (minutesFromNow > 60) ? .absolute : mode
        let timeDisplay: String
        switch effectiveMode {
        case .relative:
            if minutesFromNow >= 1 {
                timeDisplay = "\(minutesFromNow) Min"
            } else if minutesFromNow == 0 {
                timeDisplay = "Jetzt"
            } else if minutesFromNow == -1 {
                timeDisplay = "Gerade weg"
            } else {
                timeDisplay = "vor \(-minutesFromNow) Min"
            }
        case .absolute:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            timeDisplay = formatter.string(from: displayDate)
        }

        let delayDisplay = delayMinutes.map { "+\($0)" }

        return (timeDisplay, delayDisplay)
    }

    // MARK: - Sorting Logic

    public static func sortDeparturesByEstimatedTime(_ departures: [StopEvent]) -> [StopEvent] {
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

    public static func sortDeparturesByArrivalTime(_ departures: [StopEvent], destinations: [String]?) -> [StopEvent] {
        return departures.sorted { departure1, departure2 in
            let arrival1 = FilteringHelper.arrivalTimeAtDestination(departure: departure1, destinations: destinations)
            let arrival2 = FilteringHelper.arrivalTimeAtDestination(departure: departure2, destinations: destinations)

            guard let date1 = arrival1 else { return false }
            guard let date2 = arrival2 else { return true }

            return date1 < date2
        }
    }

    // MARK: - Delay Helper
    public static func delayMinutes(planned: String?, estimated: String?) -> Int? {
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
