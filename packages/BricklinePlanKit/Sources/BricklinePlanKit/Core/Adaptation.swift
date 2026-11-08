import Foundation

/// The thirteen rules of annex C, in order. Rules 1 to 8 are the adaptation rules; rules 9 to 13 are the readiness
/// rules (see `ReadinessRules`). Rules 9 and 13 are gates and guardrails that never write a reason line, so they
/// never appear on an `AdaptationEvent` themselves, but they keep their ids so logs and docs can name them.
public enum AdaptationRuleID: Int, Codable, Hashable, Sendable, CaseIterable {
    case skippedMove = 1
    case realignmentPrompt = 2
    case zoneNudge = 3
    case unwellCap = 4
    case rampClamp = 5
    case loadSpike = 6
    case taperLock = 7
    case retest = 8
    /// Rule 9, calibration gate (no reason line).
    case readinessCalibration = 9
    /// Rule 10, defer a hard session.
    case readinessDefer = 10
    /// Rule 11, swap a hard session to easy at about 80 percent duration.
    case readinessEasy = 11
    /// Rule 12, sleep note (a note only, never a plan change).
    case sleepNote = 12
    /// Rule 13, guardrails (no reason line).
    case readinessGuardrails = 13

    /// Default structural classification (annex C: rules never apply more than one structural change per day;
    /// zone nudges and copy only flags are not structural). Rule 2 counts only once the athlete confirms it.
    /// The engine sets `AdaptationEvent.isStructural` per event, which is authoritative.
    public var isNormallyStructural: Bool {
        switch self {
        case .skippedMove, .realignmentPrompt, .unwellCap, .rampClamp, .loadSpike, .retest, .readinessDefer, .readinessEasy:
            return true
        case .zoneNudge, .taperLock, .readinessCalibration, .sleepNote, .readinessGuardrails:
            return false
        }
    }

    /// True for annex C rules 9 to 13, which only ever defer or soften and are advisory.
    public var isReadinessRule: Bool { rawValue >= AdaptationRuleID.readinessCalibration.rawValue }
}

/// What the host needs to offer the one tap "Keep planned session" for an advisory readiness change (annex C
/// rule 13). A readiness event carries the sessions exactly as they were planned before the change, so the host
/// can restore them with `ReadinessRules.keepPlannedSession`.
public struct AdvisoryChange: Codable, Hashable, Sendable {
    /// The sessions as planned before the change, with their original ids, days and steps. Empty for a note only
    /// event (rule 12), which has nothing to restore.
    public var originalSessions: [Session]
    /// The day the athlete tapped Keep planned session on this change. Nil until then. Set by
    /// `AdaptationState.keepPlannedSession`, which makes the tap idempotent and lets the rule 13 override count
    /// come from the log the host already saves.
    public var keptOn: Date?

    public init(originalSessions: [Session] = [], keptOn: Date? = nil) {
        self.originalSessions = originalSessions
        self.keptOn = keptOn
    }

    /// True when the event changed the plan, can be undone and has not been kept yet.
    public var canKeepPlannedSession: Bool { !originalSessions.isEmpty && keptOn == nil }

    /// A copy without the stored sessions, for a change that can no longer be undone. Keeps `keptOn`.
    public func pruned() -> AdvisoryChange { AdvisoryChange(originalSessions: [], keptOn: keptOn) }
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
    /// Set on the advisory readiness events of rules 10 and 11 (annex C rule 13): the data for "Keep planned
    /// session". Nil on every other event, the rule 12 note included, which keeps older stored events decodable.
    public var advisory: AdvisoryChange?

    public init(
        rule: AdaptationRuleID,
        reasonLine: String,
        date: Date,
        isStructural: Bool,
        sessionIDs: [String] = [],
        sport: Sport? = nil,
        advisory: AdvisoryChange? = nil
    ) {
        self.rule = rule
        self.reasonLine = reasonLine
        self.date = date
        self.isStructural = isStructural
        self.sessionIDs = sessionIDs
        self.sport = sport
        self.advisory = advisory
    }

    /// Rule number 1 to 13.
    public var ruleNumber: Int { rule.rawValue }

    /// True when the athlete may overrule the event (the readiness rules are advisory, annex C rule 13). The sleep
    /// note of rule 12 changes nothing, so it carries no advisory data and is not advisory.
    public var isAdvisory: Bool { advisory != nil }

    /// True when a Keep planned session button can work for this event: it changed the plan and has not been
    /// kept. A row keyed on this never shows a dead button.
    public var canKeepPlannedSession: Bool { advisory?.canKeepPlannedSession == true }
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
    /// The readiness picture for the Today card. Nil unless the run was given readiness inputs, so a run without
    /// them is exactly the plain adaptation result.
    public var readinessAssessment: ReadinessAssessment?

    public init(
        plan: Plan,
        events: [AdaptationEvent] = [],
        pendingRealignment: RealignmentPrompt? = nil,
        readinessAssessment: ReadinessAssessment? = nil
    ) {
        self.plan = plan
        self.events = events
        self.pendingRealignment = pendingRealignment
        self.readinessAssessment = readinessAssessment
    }
}
