import Foundation

/// What the athlete declared at onboarding (spec section 3.2, annex B "Microcycle assembly").
public struct AthleteProfile: Codable, Hashable, Sendable {
    public var level: Level
    /// Target average weekly training hours.
    public var weeklyHours: Double
    /// Weekdays the athlete can train. Sessions are only placed on these days.
    public var availableWeekdays: Set<Weekday>
    /// Weekdays with pool access. Pool sessions are only placed on these days (annex B).
    public var poolWeekdays: Set<Weekday>
    public var hasWatch: Bool
    public var hasPowerMeter: Bool
    public var hasTrainer: Bool
    /// Offer run walk intervals for run sessions (first timers, spec section 3.2).
    public var prefersRunWalk: Bool

    public init(
        level: Level,
        weeklyHours: Double,
        availableWeekdays: Set<Weekday>,
        poolWeekdays: Set<Weekday>,
        hasWatch: Bool = false,
        hasPowerMeter: Bool = false,
        hasTrainer: Bool = false,
        prefersRunWalk: Bool = false
    ) {
        self.level = level
        self.weeklyHours = weeklyHours
        self.availableWeekdays = availableWeekdays
        self.poolWeekdays = poolWeekdays
        self.hasWatch = hasWatch
        self.hasPowerMeter = hasPowerMeter
        self.hasTrainer = hasTrainer
        self.prefersRunWalk = prefersRunWalk
    }
}
