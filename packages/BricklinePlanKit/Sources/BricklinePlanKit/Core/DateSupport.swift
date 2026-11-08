import Foundation

/// Small calendar helpers so every module counts days the same way. None of them read the clock.
public extension Calendar {
    /// Whole calendar days from the day of `start` to the day of `end` (negative when `end` is earlier).
    /// Both dates are moved to noon of their own day before counting, so the time of day never matters. That keeps
    /// the count right on a day that starts at 01:00 because daylight saving begins at midnight (for example
    /// Havana, Santiago, Cairo), where counting from the start of the day loses a day.
    func daysBetween(_ start: Date, _ end: Date) -> Int {
        dateComponents([.day], from: noonOfDay(start), to: noonOfDay(end)).day ?? 0
    }

    /// Noon of the calendar day containing `date`. No zone has a daylight saving change at noon, so the result
    /// always exists and sits well inside its day.
    func noonOfDay(_ date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
    }

    /// `date` shifted by whole days. Returns `date` unchanged if the calendar cannot compute the result.
    func addDays(_ days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date) ?? date
    }
}

/// Deterministic session identifiers. Engines never use random UUIDs, so regenerated plans match exactly
/// (annex J "Golden plan fixtures").
public enum SessionID {
    /// Builds an id such as `w03-20261109-run-1`.
    /// - Parameters:
    ///   - weekIndex: zero based plan week.
    ///   - date: scheduled day.
    ///   - sport: primary sport.
    ///   - slot: 1 based counter distinguishing several sessions of one sport on one day.
    public static func make(weekIndex: Int, date: Date, sport: Sport, slot: Int, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "w\(pad(weekIndex, 2))-\(pad(c.year ?? 0, 4))\(pad(c.month ?? 0, 2))\(pad(c.day ?? 0, 2))-\(sport.rawValue)-\(slot)"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(max(value, 0))
        if text.count >= width { return text }
        return String(repeating: "0", count: width - text.count) + text
    }
}
