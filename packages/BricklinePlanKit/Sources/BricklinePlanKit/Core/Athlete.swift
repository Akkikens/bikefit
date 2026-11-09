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
    /// A gentle start for someone brand new to training: no hard efforts and no maximal tests anywhere in the plan
    /// (every step is level 3 or lower), two easier opening weeks, and a lighter week after every second load week.
    public var gentleStart: Bool

    public init(
        level: Level,
        weeklyHours: Double,
        availableWeekdays: Set<Weekday>,
        poolWeekdays: Set<Weekday>,
        hasWatch: Bool = false,
        hasPowerMeter: Bool = false,
        hasTrainer: Bool = false,
        prefersRunWalk: Bool = false,
        gentleStart: Bool = false
    ) {
        self.level = level
        self.weeklyHours = weeklyHours
        self.availableWeekdays = availableWeekdays
        self.poolWeekdays = poolWeekdays
        self.hasWatch = hasWatch
        self.hasPowerMeter = hasPowerMeter
        self.hasTrainer = hasTrainer
        self.prefersRunWalk = prefersRunWalk
        self.gentleStart = gentleStart
    }

    private enum CodingKeys: String, CodingKey {
        case level, weeklyHours, availableWeekdays, poolWeekdays, hasWatch, hasPowerMeter, hasTrainer
        case prefersRunWalk, gentleStart
    }

    /// Profiles saved before `gentleStart` existed decode with it off.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            level: try c.decode(Level.self, forKey: .level),
            weeklyHours: try c.decode(Double.self, forKey: .weeklyHours),
            availableWeekdays: try c.decode(Set<Weekday>.self, forKey: .availableWeekdays),
            poolWeekdays: try c.decode(Set<Weekday>.self, forKey: .poolWeekdays),
            hasWatch: try c.decodeIfPresent(Bool.self, forKey: .hasWatch) ?? false,
            hasPowerMeter: try c.decodeIfPresent(Bool.self, forKey: .hasPowerMeter) ?? false,
            hasTrainer: try c.decodeIfPresent(Bool.self, forKey: .hasTrainer) ?? false,
            prefersRunWalk: try c.decodeIfPresent(Bool.self, forKey: .prefersRunWalk) ?? false,
            gentleStart: try c.decodeIfPresent(Bool.self, forKey: .gentleStart) ?? false)
    }
}
