import Foundation

/// Erkennt in MVG-HTML typische „Wochentag + ca. HH:MM – HH:MM“-Zeiträume (z. B. Verstärkerzüge).
enum DisruptionRecurringScheduleParser {
    private static let weekdays: [(name: String, value: Int)] = [
        ("sonntag", 1), ("montag", 2), ("dienstag", 3), ("mittwoch", 4),
        ("donnerstag", 5), ("freitag", 6), ("samstag", 7),
    ]

    /// Nur wenn ein solches Muster plausibel ist, werten wir die Freitext-Zeiten aus (sonst gilt die Meldung als ganztägig gültig).
    static func isLikelyRecurringScheduleDescription(_ html: String) -> Bool {
        let t = Self.stripTags(html).lowercased()
        // „Verstärker“ allein (z. B. nur in der Überschrift) hat oft keine „ca. HH:MM“-Zeilen → nicht als Wochenplan behandeln.
        if t.contains("verstärker"), t.contains("ca.") || t.contains("folgende zeiträume") { return true }
        if t.contains("folgende zeiträume"), t.contains("ca.") { return true }
        return false
    }

    /// `true`, wenn `date` (Europe/Berlin) in mindestens einem erkannten Wochentag-Zeitfenster liegt.
    /// Keine parsbaren Blöcke trotz Stichwort (z. B. nur „Verstärker“ im Titel) → **true**, damit die Meldung nicht komplett verschwindet (analog MVG).
    static func matchesSchedule(_ html: String, at date: Date) -> Bool {
        let blocks = Self.parseBlocks(from: html)
        if blocks.isEmpty { return true }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let weekday = cal.component(.weekday, from: date)
        let minutes = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)

        return blocks.contains { block in
            block.weekdays.contains(weekday) && minutes >= block.startMinutes && minutes <= block.endMinutes
        }
    }

    private struct Block {
        let weekdays: Set<Int>
        let startMinutes: Int
        let endMinutes: Int
    }

    private static func parseBlocks(from html: String) -> [Block] {
        let lines = stripTags(html)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "\u{00a0}" }

        var result: [Block] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if let days = weekdaySet(from: line) {
                if i + 1 < lines.count, let range = timeRangeMinutes(from: lines[i + 1]) {
                    result.append(Block(weekdays: days, startMinutes: range.0, endMinutes: range.1))
                    i += 2
                    continue
                }
            }
            i += 1
        }
        return result
    }

    private static func weekdaySet(from line: String) -> Set<Int>? {
        let lower = line.lowercased()
        guard !lower.contains("uhr") else { return nil }

        if lower.contains(" bis ") {
            let parts = lower.components(separatedBy: " bis ")
            guard parts.count >= 2,
                  let start = weekdayNumber(in: parts[0]),
                  let end = weekdayNumber(in: parts[1]) else { return nil }
            if start <= end {
                return Set(start...end)
            }
            return Set(start...7).union(Set(1...end))
        }

        if let only = weekdayNumber(in: lower), line.count < 48 {
            return [only]
        }
        return nil
    }

    private static func weekdayNumber(in string: String) -> Int? {
        let lower = string.lowercased()
        for (name, value) in weekdays.reversed() {
            if lower.contains(name) { return value }
        }
        return nil
    }

    private static func timeRangeMinutes(from line: String) -> (Int, Int)? {
        guard let regex = try? NSRegularExpression(
            pattern: #"ca\.\s*(\d{1,2}):(\d{2})\s*[\u2013\-]\s*(\d{1,2}):(\d{2})"#,
            options: []
        ) else { return nil }
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = regex.firstMatch(in: line, options: [], range: full),
              m.numberOfRanges == 5,
              let r1 = Range(m.range(at: 1), in: line),
              let r2 = Range(m.range(at: 2), in: line),
              let r3 = Range(m.range(at: 3), in: line),
              let r4 = Range(m.range(at: 4), in: line),
              let h1 = Int(line[r1]),
              let mi1 = Int(line[r2]),
              let h2 = Int(line[r3]),
              let mi2 = Int(line[r4]) else { return nil }
        let a = h1 * 60 + mi1
        let b = h2 * 60 + mi2
        return a <= b ? (a, b) : (b, a)
    }

    private static func stripTags(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        return text
    }
}
