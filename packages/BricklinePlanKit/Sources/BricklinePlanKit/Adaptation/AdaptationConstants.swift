import Foundation

/// Every tunable threshold of the adaptation engine, in one place (annex C: "Thresholds tunable in one constants
/// file"). Values quote the annex C table; the comment on each says which rule uses it.
public enum AdaptationConstants {
    // MARK: Rule 2, realignment prompt

    /// Look back window for counting misses, in days (annex C rule 2: "3 or more misses in 14 days").
    public static let missWindowDays = 14
    /// Number of misses inside the window that triggers the prompt (annex C rule 2).
    public static let missesToPrompt = 3
    /// A fully elapsed week counts as missed only when it held at least this many sessions and all were missed
    /// (annex C rule 2: "an entire week missed").
    public static let wholeWeekMinimumSessions = 2

    // MARK: Rule 3, zone nudge

    /// Comparable quality sessions needed (annex C rule 3: "the last 3 comparable quality sessions").
    public static let nudgeSessionCount = 3
    /// A session whose deviation from target is larger than this fraction is an outlier and is dropped
    /// (annex C rule 3: "median, outliers dropped").
    public static let nudgeOutlierFraction = 0.20
    /// The median deviation must reach one nudge step, about 2 percent (annex C rule 3).
    public static let nudgeTriggerFraction = ZoneConstants.nudgeFractionPerStep
    /// Only work steps at this level or harder enter the comparison (easy and recovery steps would bias it).
    public static let nudgeMinimumWorkLevel = 3
    /// Minimum days between two nudges of the same sport (annex C rule 3: "max once per 2 weeks").
    public static let nudgeMinimumGapDays = 14
    /// Largest net nudge in either direction, in steps (5 steps is about 10 percent). Below the zone calculator's
    /// own limit, so a stored value is never ignored by the resolver. A retest clears the nudge.
    public static let nudgeMaximumSteps = min(5, ZoneConstants.maximumNudgeSteps)

    // MARK: Rule 4, unwell mode

    /// Easy sessions only for at most this many days (annex C rule 4: "up to 14 days").
    public static let unwellMaximumDays = 14
    /// Length of the gradual return after the easy period (annex C rule 4: "quality returns over 1 week").
    public static let unwellReturnDays = 7
    /// First days of the return week that stay easy only. Quality may come back from this day offset on.
    public static let unwellReturnEasyDays = 3
    /// At most this many quality sessions inside the return week.
    public static let unwellReturnMaximumQuality = 1
    /// Highest intensity level allowed in the return week.
    public static let unwellReturnMaximumLevel = 4
    /// Sessions this many days ahead of today (including today) are adapted on each run. The window rolls
    /// forward each day, so switching the toggle off early never rewrites sessions the athlete will do well.
    public static let unwellHorizonDays = 7
    /// Highest intensity level of an easy session (levels: 1 recovery, 2 easy).
    public static let easyMaximumLevel = 2

    // MARK: Rule 2, re-entry after a gap (compress and shift)

    // Gap based re-entry factors. They are coach review items, tunable here. The gap is the number of days since
    // the last recorded training.

    /// Gap in days up to which the first week back runs at `reentryFactorShortGap` of the reference.
    public static let reentryShortGapDays = 7
    public static let reentryMediumGapDays = 14
    public static let reentryLongGapDays = 28
    /// First week back after a gap of 1 to 7 days.
    public static let reentryFactorShortGap = 0.85
    /// First week back after a gap of 8 to 14 days.
    public static let reentryFactorMediumGap = 0.70
    /// First week back after a gap of 15 to 28 days.
    public static let reentryFactorLongGap = 0.55
    /// First week back after a gap over 28 days: restart from base, quality returns to easy.
    public static let reentryFactorRestart = 0.50
    /// Window of recent actual Load that anchors the re-entry reference, in days.
    public static let reentryActualWindowDays = 28
    /// A session may be shortened down to this fraction of its length while re-entering (the ordinary ramp clamp
    /// keeps `minimumShortenFactor`).
    public static let reentryMinimumShortenFactor = 0.35
    /// Gap in days from which a plan shift inserts one re-entry week before the shifted arc.
    public static let shiftReentryWeekGapDays = 14
    /// A recovery style re-entry week is the nearest recovery week, or the last load week scaled by this.
    public static let reentryWeekFallbackFactor = 0.65

    // MARK: Rule 5, ramp clamp

    /// A load week may not exceed this multiple of the most recent load week (annex C rule 5: 110 percent).
    public static let rampCapFactor = 1.10
    /// Phases that are exempt from the cap (annex C rule 5: "template designed peak and taper weeks exempt").
    public static let rampExemptPhases: Set<Phase> = [.peak, .taper]
    /// A peak or taper week counts as designed (exempt) while its hours stay within this many hours of the design.
    public static let designedHoursTolerance = 0.05
    /// A single session is never shortened below this fraction of its length.
    public static let minimumShortenFactor = 0.6
    /// Step durations are floored to a multiple of this many seconds after shortening (steps under 60 s are
    /// scaled without rounding).
    public static let shortenGranularitySeconds = 30.0
    /// Tolerance on the cap in Load units, so rounding never causes another clamp.
    public static let loadTolerance = 0.5

    // MARK: Rule 6, load spike

    /// Acute over chronic ratio above which the caution rule fires (annex C rule 6).
    public static let spikeRatio = 1.5
    /// The athlete needs at least this many days of recorded history before the ratio means anything.
    public static let spikeMinimumHistoryDays = 28
    /// Length of the inserted easy session, in seconds, when today has no session.
    public static let easyDayDurationSeconds = 1800.0

    // MARK: Rule 7, taper lock

    // The window length comes from `RaceDistance.parameters.windowOpensTMinusDays` (annex F), so there is no
    // constant here: Sprint T minus 10 days, Olympic and 70.3 T minus 21 days.

    // MARK: Rule 8, retest

    /// A test older than this many weeks is stale (annex C rule 8: 8 weeks).
    public static let staleTestWeeks = 8
    /// At most this many test sessions in one week, at least `testSpacingDays` apart (annex A retest rotation:
    /// "never more than two maximal efforts in a recovery week and at least 48 hours between them").
    public static let maximumTestsPerWeek = 2
    public static let testSpacingDays = 2

    // MARK: Reason lines

    /// Rule 6 line (annex C). Phrased without the restricted words so a copy pass cannot clash with the
    /// Safety.strings fence.
    public static let loadSpikeReason = "Your recent load spiked; today went easy. This is a caution rule, not a prediction that anything is wrong"
    /// Rule 7 line (annex C).
    /// The lock runs from the start of the race window (T minus 21 days, T minus 10 for Sprint), so the line says
    /// "window", not "week".
    public static let taperLockReason = "Race window: the plan holds steady on purpose"
    /// Rule 8 line (annex C).
    public static let retestReason = "Time to retest so your zones stay honest"
}
