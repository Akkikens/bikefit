import Foundation

/// The eight rules of annex C, in order.
public enum AdaptationRuleID: Int, Codable, Hashable, Sendable, CaseIterable {
    case skippedMove = 1
    case realignmentPrompt = 2
    case zoneNudge = 3
    case unwellCap = 4
    case rampClamp = 5
    case loadSpike = 6
    case taperLock = 7
    case retest = 8

    /// Default structural classification (annex C: rules never apply more than one structural change per day;
    /// zone nudges and copy only flags are not structural). Rule 2 counts only once the athlete confirms it.
    /// The engine sets `AdaptationEvent.isStructural` per event, which is authoritative.
    public var isNormallyStructural: Bool {
        switch self {
        case .skippedMove, .realignmentPrompt, .unwellCap, .rampClamp, .loadSpike, .retest: return true
        case .zoneNudge, .taperLock: return false
        }
    }
}

/// A fired rule with its reason line, shown on the Today card and kept in the log (annex C).
public struct AdaptationEvent: Codable, Hashable, Sendable {
    public var rule: AdaptationRuleID
    /// The one line explanation, pattern from annex C. Never empty.
    public var reasonLine: String
    public var date: Date
    /// True for a structural change (at most one per day).
    public var isStructural: Bool
    /// Ids of the sessions changed, moved, dropped or inserted.
    public var sessionIDs: [String]
    /// The sport affected, for rule 3 and rule 8.
    public var sport: Sport?

    public init(
        rule: AdaptationRuleID,
        reasonLine: String,
        date: Date,
        isStructural: Bool,
        sessionIDs: [String] = [],
        sport: Sport? = nil
    ) {
        self.rule = rule
        self.reasonLine = reasonLine
        self.date = date
        self.isStructural = isStructural
        self.sessionIDs = sessionIDs
        self.sport = sport
    }

    /// Rule number 1 to 8.
    public var ruleNumber: Int { rule.rawValue }
}

/// The two honest ways forward offered by annex C rule 2.
public enum RealignmentOption: String, Codable, Hashable, Sendable, CaseIterable {
    /// Resume at today with the arc compressed.
    case compress
    /// Shift the whole plan later, only if the race date allows.
    case shiftPlan
}

/// The prompt produced by rule 2. The plan is not changed until the athlete confirms an option.
public struct RealignmentPrompt: Codable, Hashable, Sendable {
    public var reasonLine: String
    public var date: Date
    /// False when the race date leaves no room to shift the plan.
    public var canShiftPlan: Bool

    public init(reasonLine: String, date: Date, canShiftPlan: Bool) {
        self.reasonLine = reasonLine
        self.date = date
        self.canShiftPlan = canShiftPlan
    }
}

/// Things the athlete did that the engine reacts to.
public enum AthleteEvent: Codable, Hashable, Sendable {
    /// The athlete skipped a session on this day (annex C rule 1).
    case sessionSkipped(sessionID: String, on: Date)
    /// Feeling unwell toggle switched on (annex C rule 4).
    case unwellStarted(on: Date)
    /// Feeling unwell toggle switched off.
    case unwellEnded(on: Date)
    /// The athlete confirmed a realignment option (annex C rule 2).
    case realignmentChosen(RealignmentOption, on: Date)
    /// The athlete edited a week's sessions, so rule 5 must re check it.
    case weekEdited(weekIndex: Int, on: Date)
}

/// Everything the adaptation engine needs besides the plan. All fields are plain data so a run is
/// deterministic: the engine never reads the clock.
public struct AdaptationContext: Sendable {
    /// The day being evaluated.
    public var today: Date
    public var events: [AthleteEvent]
    public var completedWorkouts: [CompletedWorkout]
    public var benchmarks: Benchmarks
    /// Previously fired events (for once per 2 weeks nudges and one structural change per day).
    public var history: [AdaptationEvent]
    /// Daily Load totals used by rules 5 and 6.
    public var dailyLoads: [LoadSample]

    public init(
        today: Date,
        events: [AthleteEvent] = [],
        completedWorkouts: [CompletedWorkout] = [],
        benchmarks: Benchmarks = Benchmarks(),
        history: [AdaptationEvent] = [],
        dailyLoads: [LoadSample] = []
    ) {
        self.today = today
        self.events = events
        self.completedWorkouts = completedWorkouts
        self.benchmarks = benchmarks
        self.history = history
        self.dailyLoads = dailyLoads
    }
}

/// Output of an adaptation run.
public struct AdaptationResult: Sendable {
    public var plan: Plan
    /// Newly fired events, in rule order. Each has a non empty reason line (annex J).
    public var events: [AdaptationEvent]
    /// Set when rule 2 fired and awaits the athlete's choice.
    public var pendingRealignment: RealignmentPrompt?

    public init(plan: Plan, events: [AdaptationEvent] = [], pendingRealignment: RealignmentPrompt? = nil) {
        self.plan = plan
        self.events = events
        self.pendingRealignment = pendingRealignment
    }
}
