import Foundation

/// Every tunable threshold of the readiness rules in one place (annex C rules 9 to 13). All values are design
/// choices to tune in the field; no rule is validated in triathletes.
public enum ReadinessConstants {
    // MARK: Baseline (annex C rules 9 to 13 summary)

    /// Nights in the signal: the latest 7.
    public static let recentWindowDays = 7
    /// Nights in the baseline: the 35 before the latest 7.
    public static let baselineWindowDays = 35
    /// A week needs at least this many valid nights to count (annex C: "minimum 3 valid nights a week").
    public static let minimumRecentValidNights = 3
    /// Fewest baseline nights (outside the latest 7) from which a mean and SD are computed, and that the
    /// calibration gate also needs. The SD of fewer nights is too noisy to hang a threshold on.
    public static let minimumBaselineNights = 10
    /// Floor on the SD of the log HRV values. Wearable HRV carries about 6 to 8 percent error from night to night,
    /// so a flat or lucky baseline must not make half an SD smaller than that.
    public static let minimumHRVLogSD = 0.05
    /// Floor on the SD of the log resting heart rate values. Device error is about 2 to 3 percent.
    public static let minimumRestingHeartRateLogSD = 0.03

    // MARK: Rule 9, calibration gate

    /// Valid nights before any readiness rule may fire (annex C rule 9: 14).
    public static let calibrationNights = 14

    // MARK: Validity of single values

    /// HRV values outside this range (milliseconds) are sensor artefacts and are ignored.
    public static let validHRV: ClosedRange<Double> = 5...400
    /// Resting heart rate range in bpm.
    public static let validRestingHeartRate: ClosedRange<Double> = 25...140
    /// A record of sleep shorter or longer than this (minutes) is a partial or merged record and is ignored.
    public static let validSleepMinutes: ClosedRange<Double> = 120...1080

    // MARK: Rules 10 and 11

    /// Rule 10: the 7 night mean must sit below baseline minus this many SD.
    public static let deferralSDMultiple = 0.5
    /// Rule 11: each of two mornings must sit below baseline minus this many SD.
    public static let easySDMultiple = 1.0
    /// Rule 11: resting heart rate this many SD above baseline is the second signal.
    public static let restingHeartRateSDMultiple = 1.0
    /// Rule 11: consecutive mornings needed.
    public static let consecutiveMornings = 2
    /// Check-in scores run 1 to 5.
    public static let checkInRange: ClosedRange<Int> = 1...5
    /// Rule 11: a check-in at or below this is low.
    public static let lowCheckIn = 2
    /// Rule 11: the easy session keeps about this fraction of the planned duration.
    public static let easyDurationFactor = 0.8

    // MARK: Rule 12, sleep note

    /// Sleep at or under this many minutes (6 hours) can raise the note.
    public static let shortSleepMinutes = 360.0
    /// ... when it is also at least this many minutes (1 hour) under the athlete's median.
    public static let sleepUnderMedianMinutes = 60.0
    /// Baseline nights with valid sleep needed before a median is trusted.
    public static let minimumSleepNightsForMedian = 5
    /// The "about" in the note rounds the gap to this many minutes.
    public static let noteRoundingMinutes = 10.0

    // MARK: Rule 13, guardrails

    /// At most this many plan changes inside the rolling window, across rules 10 to 12.
    public static let maximumPlanChanges = 2
    public static let planChangeWindowDays = 7
    /// This many overrides inside the window drops readiness to notes only.
    public static let overrideLimit = 3
    public static let overrideWindowDays = 14
    /// No sync for this many hours silences readiness.
    public static let silenceAfterHours = 48.0
    /// The chosen source's newest valid night this many whole days old also silences readiness, whatever the host
    /// reports as the sync date (a pull attempt is not a delivery).
    public static let silenceAfterNightDays = 2
    /// Rule 10: a session already deferred inside this many days is made easy instead of moving again.
    public static let redeferWindowDays = 7

    // MARK: Copy

    /// Label of the one tap undo on every advisory change.
    public static let keepPlannedSessionTitle = "Keep planned session"
}

extension Date {
    /// False for a date that is not a number, which no calendar can place on a day. Inputs with such dates are
    /// ignored instead of reaching the calendar.
    var isUsable: Bool { timeIntervalSinceReferenceDate.isFinite }
}
