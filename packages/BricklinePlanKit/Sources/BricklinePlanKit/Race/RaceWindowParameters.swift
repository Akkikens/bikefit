import Foundation

/// Tunable numbers for the race window timeline and the annex H notification cap.
///
/// Implements annex F "Timeline entries" and annex H "Notification rules". Every value is a parameter so the
/// coach reviewer can retune it without touching logic. The bike service, carb load and pack tonight days come
/// straight from annex F; the two travel days are placeholders for the coach reviewer, because the annex says
/// only that travel and pack are keyed to the travel flag.
public struct RaceWindowParameters: Hashable, Sendable {
    /// Bike service reminder, days before race day (annex F: T minus 14). Clamped to the window opening day for
    /// distances whose window opens later than this (Sprint opens at T minus 10).
    public var bikeServiceTMinus: Int
    /// Placeholder: the pack for travel entry, days before race day, only for travel races.
    public var travelPackTMinus: Int
    /// Placeholder: the travel day entry, days before race day, only for travel races.
    public var travelTMinus: Int
    /// Carb load start for the 70.3 (annex F: T minus 2).
    public var carbLoadTMinusLongCourse: Int
    /// Carb load start for shorter races (annex F: race eve, T minus 1).
    public var carbLoadTMinusShortCourse: Int
    /// Pack tonight (annex F: T minus 1).
    public var packTonightTMinus: Int
    /// Annex H: at most one race window notification per day.
    public var maxNotificationsPerDay: Int
    /// Annex H: at most four extra notifications in any week.
    public var maxNotificationsPerWeek: Int

    public init(
        bikeServiceTMinus: Int = 14,
        travelPackTMinus: Int = 5,
        travelTMinus: Int = 3,
        carbLoadTMinusLongCourse: Int = 2,
        carbLoadTMinusShortCourse: Int = 1,
        packTonightTMinus: Int = 1,
        maxNotificationsPerDay: Int = 1,
        maxNotificationsPerWeek: Int = 4
    ) {
        self.bikeServiceTMinus = bikeServiceTMinus
        self.travelPackTMinus = travelPackTMinus
        self.travelTMinus = travelTMinus
        self.carbLoadTMinusLongCourse = carbLoadTMinusLongCourse
        self.carbLoadTMinusShortCourse = carbLoadTMinusShortCourse
        self.packTonightTMinus = packTonightTMinus
        self.maxNotificationsPerDay = maxNotificationsPerDay
        self.maxNotificationsPerWeek = maxNotificationsPerWeek
    }
}

/// Plain language helpers shared by the race window files. Time and number formatting never traps.
enum RaceFormat {
    /// Converts a double to an Int without trapping on NaN, infinity or huge values.
    static func safeInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let limit = 1_000_000_000.0
        return Int(min(max(value.rounded(), -limit), limit))
    }

    /// Minutes after midnight as a 12 hour clock, for example 235 becomes "3:55 AM".
    static func clock(minutesAfterMidnight minutes: Int) -> String {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        let hour24 = clamped / 60
        let minute = clamped % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        return "\(hour12):\(two(minute)) \(suffix)"
    }

    /// Seconds as m:ss, or h:mm:ss from one hour up. Negative and non finite values read as 0:00.
    static func duration(_ seconds: Double) -> String {
        let total = max(safeInt(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h):\(two(m)):\(two(s))" }
        return "\(m):\(two(s))"
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
