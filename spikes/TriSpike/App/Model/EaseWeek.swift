import Foundation
import BricklinePlanKit

/// "This feels too hard": the athlete eases the rest of the week with one tap. Sessions still to do become easy and
/// about a quarter shorter. Finished sessions and later weeks are left alone. No judgement, and it can be undone.
enum EaseStore {
    private static let key = "trispike.easedweeks.v1"

    static func load() -> Set<String> {
        guard let list = UserDefaults.standard.stringArray(forKey: key) else { return [] }
        return Set(list)
    }

    static func save(_ weeks: Set<String>) {
        UserDefaults.standard.set(weeks.sorted(), forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    /// A stable key for a week: the calendar day its first day falls on, such as "2026-11-09".
    static func weekKey(_ weekStart: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: weekStart)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

enum EaseWeek {
    /// The line printed on every eased session.
    static let reason = "You said this week felt too hard, so this session is easier and shorter. That is a good call, not a step back."
    /// The rule behind that line, for the expandable text.
    static let rule = "You chose to ease this week. TriSpike makes the sessions you have not done yet easy and about a quarter shorter. Next week goes back to the plan. You can undo this on Today."

    /// Whether a session should be eased: still to do, and on or after today. Every one is shortened, hard or not,
    /// because a week that feels too hard is often about the total, not one session.
    static func shouldEase(_ s: BricklinePlanKit.Session, today: Date, hasCompletion: Bool, calendar: Calendar) -> Bool {
        guard s.state == .planned, !hasCompletion else { return false }
        guard s.scheduledDate >= calendar.startOfDay(for: today) else { return false }
        return true
    }

    /// The gentler session, from the engine so the steps and targets agree with every other easy session.
    static func eased(_ s: BricklinePlanKit.Session, kit: PlanKit) -> BricklinePlanKit.Session {
        kit.easedSession(s)
    }

    /// Plain sentence that tells the athlete what the button does, shown before they confirm.
    static let confirmMessage = "Feeling this is too hard is useful information, and it happens to everyone. The sessions you have not done yet this week become easy and about a quarter shorter. Next week stays as planned. You can undo this."
}
