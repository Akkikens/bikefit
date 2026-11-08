import Foundation

/// Statistics of one metric of one source (annex C rules 9 to 13: a personal baseline per source).
///
/// HRV and resting heart rate work on the natural log of the nightly values. The baseline is the mean and SD of the
/// 35 nights before the latest 7; the signal is the mean of the latest 7 nights. Values are on the log scale.
public struct MetricBaseline: Hashable, Sendable {
    /// Valid days among the 35 baseline days.
    public var baselineNights: Int
    /// Valid days among the latest 7.
    public var recentNights: Int
    /// Mean of the log values over the baseline. Nil with fewer than `ReadinessConstants.minimumBaselineNights` (10).
    public var mean: Double?
    /// Sample SD (n minus 1) of the log values over the baseline. Nil with too few nights.
    public var standardDeviation: Double?
    /// Mean of the log values over the latest 7 nights. Nil with fewer than 3 valid nights in them.
    public var recentMean: Double?
    /// The least SD the thresholds use for this metric, on the log scale. HRV and resting heart rate have their own
    /// (`ReadinessConstants.minimumHRVLogSD`, `minimumRestingHeartRateLogSD`), set from device error.
    public var floor: Double

    public init(
        baselineNights: Int = 0, recentNights: Int = 0,
        mean: Double? = nil, standardDeviation: Double? = nil, recentMean: Double? = nil,
        floor: Double = ReadinessConstants.minimumHRVLogSD
    ) {
        self.baselineNights = baselineNights
        self.recentNights = recentNights
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.recentMean = recentMean
        self.floor = floor
    }

    /// True when a mean and SD exist.
    public var hasBaseline: Bool { mean != nil && standardDeviation != nil }

    /// The SD used for thresholds: never below `floor`.
    public var effectiveSD: Double? {
        standardDeviation.map { max($0, floor) }
    }

    /// Baseline mean minus `sds` SD on the log scale. Nil without a baseline.
    public func lowerLimit(sds: Double) -> Double? {
        guard let mean, let sd = effectiveSD else { return nil }
        return mean - sds * sd
    }

    /// Baseline mean plus `sds` SD on the log scale. Nil without a baseline.
    public func upperLimit(sds: Double) -> Double? {
        guard let mean, let sd = effectiveSD else { return nil }
        return mean + sds * sd
    }
}

/// Calibration progress of one source (annex C rule 9).
///
/// A night is valid for calibration when any of its HRV (for a source that reports one), resting heart rate or sleep
/// is a plausible value, so a source without HRV (Garmin) can still be calibrated for rule 12.
public struct CalibrationState: Codable, Hashable, Sendable {
    /// Valid nights in the 42 day window (the latest 7 plus the 35 before them), counted from the day the source
    /// last changed when the host reports one.
    public var validNights: Int
    /// Valid nights among the latest 7, counted the same way.
    public var recentValidNights: Int
    /// Valid nights needed, 14.
    public var required: Int
    /// Valid nights among the 35 before the latest 7, over the full history. Ten are needed for a trustworthy mean
    /// and SD (`ReadinessConstants.minimumBaselineNights`).
    public var baselineNights: Int

    public init(
        validNights: Int, recentValidNights: Int, required: Int = ReadinessConstants.calibrationNights,
        baselineNights: Int? = nil
    ) {
        self.validNights = validNights
        self.recentValidNights = recentValidNights
        self.required = required
        self.baselineNights = baselineNights ?? max(validNights - recentValidNights, 0)
    }

    /// Fourteen valid nights are in, and ten of the baseline nights exist.
    public var isCalibrated: Bool {
        validNights >= required && baselineNights >= ReadinessConstants.minimumBaselineNights
    }
    /// At least 3 valid nights in the latest 7.
    public var hasEnoughRecentNights: Bool { recentValidNights >= ReadinessConstants.minimumRecentValidNights }
    /// "Night N" of the learning line. Never above `required`, and one under it while the baseline nights are
    /// still missing, so the line never reads "night 14 of 14" while still learning.
    public var night: Int { isCalibrated ? required : min(validNights, required - 1) }
}

/// Everything known about one source on one day.
public struct SourceBaseline: Hashable, Sendable {
    public var source: ReadinessSource
    public var hrv: MetricBaseline
    public var restingHeartRate: MetricBaseline
    /// Median of the valid sleep durations among the 35 baseline days, in minutes. Nil with too few nights.
    public var sleepMedianMinutes: Double?
    public var calibration: CalibrationState
    /// One value per valid day, keyed by whole days before today (0 is today). A day with several HRV or resting
    /// heart rate records holds their mean; several sleep records hold their sum.
    public var hrvByDaysAgo: [Int: Double]
    public var restingHeartRateByDaysAgo: [Int: Double]
    public var sleepByDaysAgo: [Int: Double]
    /// Whole days before today of the newest valid night (0 is today). Nil with no valid night. Rule 13 silences
    /// readiness when this reaches 2.
    public var newestNightDaysAgo: Int?

    public init(
        source: ReadinessSource,
        hrv: MetricBaseline, restingHeartRate: MetricBaseline, sleepMedianMinutes: Double?,
        calibration: CalibrationState,
        hrvByDaysAgo: [Int: Double], restingHeartRateByDaysAgo: [Int: Double], sleepByDaysAgo: [Int: Double],
        newestNightDaysAgo: Int? = nil
    ) {
        self.source = source
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepMedianMinutes = sleepMedianMinutes
        self.calibration = calibration
        self.hrvByDaysAgo = hrvByDaysAgo
        self.restingHeartRateByDaysAgo = restingHeartRateByDaysAgo
        self.sleepByDaysAgo = sleepByDaysAgo
        self.newestNightDaysAgo = newestNightDaysAgo
    }

    /// Mean of the latest 7 nights' HRV in milliseconds (the geometric mean, since the mean is taken on the log
    /// scale). Nil with fewer than 3 valid nights.
    public var recentHRVMilliseconds: Double? { hrv.recentMean.map { exp($0) } }
    /// Baseline HRV in milliseconds (geometric mean). Nil without a baseline.
    public var baselineHRVMilliseconds: Double? { hrv.mean.map { exp($0) } }
}

/// Why a source was chosen as the recovery source.
public enum SourceChoiceReason: String, Codable, Hashable, Sendable {
    /// The athlete picked it.
    case chosenByAthlete
    /// It is the only source with nights.
    case onlySource
    /// First in the default order among sources with enough recent nights.
    case defaultOrder
    /// No source has enough recent nights, so the one with the latest data.
    case latestData
    /// The source in use before is kept: it dipped under 3 recent nights but still delivers, so readiness pauses
    /// on it instead of flipping to another source and restarting calibration.
    case keptCurrent
}

/// The recovery source in use and the reason, for the Sources screen.
public struct SourceChoice: Codable, Hashable, Sendable {
    public var source: ReadinessSource
    public var reason: SourceChoiceReason
    /// One plain sentence, for example "Using Oura, the first of your sources with enough recent nights."
    public var explanation: String

    public init(source: ReadinessSource, reason: SourceChoiceReason) {
        self.source = source
        self.reason = reason
        let name = source.displayName
        switch reason {
        case .chosenByAthlete: explanation = "Using \(name), the source you chose."
        case .onlySource: explanation = "Using \(name), your only source with recent nights."
        case .defaultOrder: explanation = "Using \(name), the first of your sources with enough recent nights."
        case .latestData: explanation = "Using \(name), the source with your latest data."
        case .keptCurrent: explanation = "Using \(name), the source you have been using."
        }
    }
}

/// Baselines and calibration for annex C rules 9 to 13. Pure functions of (nights, today, calendar).
///
/// Rules of the road:
/// - Each source is computed alone. A night from another source never enters its mean, SD or counts, so SDNN
///   (Apple Watch) and rMSSD (WHOOP, Oura) are never pooled.
/// - A night is dated by the day the athlete woke up. The latest 7 are the 7 calendar days ending today; the
///   baseline is the 35 days before them. Nights dated after today are ignored.
/// - A night counts as valid for HRV when its source reports an HRV statistic and the value is inside
///   `ReadinessConstants.validHRV`. Resting heart rate and sleep have their own validity. A night is valid for
///   calibration and source choice when any one of the three is valid.
/// - Several HRV or resting heart rate records for one source and day are averaged. Several sleep records for one
///   source and day are fragments of one night and are summed (exact duplicate records count once), and the range
///   check applies to the sum, so a 4 hour and a 2 hour fragment make a valid 6 hour night and a lone nap does not.
///   The order of the input never matters.
/// - The sleep median (rule 12) comes from the chosen source's own 35 baseline days. Sleep duration could be pooled
///   across sources, but one source's missing nights then change another's median, so each source keeps its own.
public enum BaselineCalculator {
    // MARK: Statistics

    /// Mean and sample SD (n minus 1) of the natural log of `values`. Values that are not finite or not above zero
    /// are skipped. Nil when fewer than two usable values remain.
    public static func logMeanAndSD(of values: [Double]) -> (mean: Double, standardDeviation: Double)? {
        let logs = values.filter { $0.isFinite && $0 > 0 }.map { log($0) }.sorted()
        guard logs.count >= 2 else { return nil }
        let mean = logs.reduce(0, +) / Double(logs.count)
        let squares = logs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (mean, (squares / Double(logs.count - 1)).squareRoot())
    }

    /// Median of the finite values, or nil when there are none.
    public static func median(of values: [Double]) -> Double? {
        let sorted = values.filter { $0.isFinite }.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    // MARK: Baseline

    /// The baseline, counts and calibration of one source on `today`. With `since`, only nights dated on or after
    /// that day count toward the 14 valid nights (annex C rule 9: a source change restarts calibration); the mean,
    /// SD and median still use every night of the source.
    public static func baseline(
        for source: ReadinessSource, nights: [ReadinessNight], today: Date, calendar: Calendar, since: Date? = nil
    ) -> SourceBaseline {
        let todayStart = calendar.startOfDay(for: today)
        let hrv = source.hrvKind == nil
            ? [:] : daily(.hrv, source: source, nights: nights, todayStart: todayStart, calendar: calendar)
        let rhr = daily(.restingHeartRate, source: source, nights: nights, todayStart: todayStart, calendar: calendar)
        let sleep = daily(.sleep, source: source, nights: nights, todayStart: todayStart, calendar: calendar)

        let recentRange = 0..<ReadinessConstants.recentWindowDays
        let baselineRange = ReadinessConstants.recentWindowDays..<(ReadinessConstants.recentWindowDays + ReadinessConstants.baselineWindowDays)

        let sleepBase = baselineRange.compactMap { sleep[$0] }
        let sleepMedian = sleepBase.count >= ReadinessConstants.minimumSleepNightsForMedian ? median(of: sleepBase) : nil

        let valid = Set(hrv.keys).union(rhr.keys).union(sleep.keys)
        var counted = valid
        if let since {
            let limit = max(calendar.daysBetween(calendar.startOfDay(for: since), todayStart), 0)
            counted = valid.filter { $0 <= limit }
        }
        let calibration = CalibrationState(
            validNights: counted.count,
            recentValidNights: counted.filter { recentRange.contains($0) }.count,
            baselineNights: valid.filter { baselineRange.contains($0) }.count)
        return SourceBaseline(
            source: source,
            hrv: metric(hrv, recent: recentRange, baseline: baselineRange, floor: ReadinessConstants.minimumHRVLogSD),
            restingHeartRate: metric(
                rhr, recent: recentRange, baseline: baselineRange, floor: ReadinessConstants.minimumRestingHeartRateLogSD),
            sleepMedianMinutes: sleepMedian,
            calibration: calibration,
            hrvByDaysAgo: hrv, restingHeartRateByDaysAgo: rhr, sleepByDaysAgo: sleep,
            newestNightDaysAgo: valid.min())
    }

    /// Valid nights of one source inside the 42 day window: nights with any valid HRV, resting heart rate or sleep.
    public static func validNightCount(
        for source: ReadinessSource, nights: [ReadinessNight], today: Date, calendar: Calendar
    ) -> Int {
        validDays(for: source, nights: nights, todayStart: calendar.startOfDay(for: today), calendar: calendar).count
    }

    // MARK: Source choice

    /// Picks the recovery source (annex C rule 9 and the integrations direction): the athlete's choice when set,
    /// else the first source in `ReadinessSource.defaultOrder` with at least 3 valid nights in the latest 7, else
    /// the source with the latest valid night. Nil means no device source, so check-ins only. A preference for
    /// `.manual` also means check-ins only.
    ///
    /// With `current` (the source used on the previous run), a source that dipped under 3 recent nights but still
    /// has one or two is kept, so a ring on the charger does not flip the baseline day to day. A source higher in
    /// the order that has 3 recent nights still wins.
    public static func chooseSource(
        nights: [ReadinessNight], preferred: ReadinessSource?, current: ReadinessSource? = nil,
        today: Date, calendar: Calendar
    ) -> SourceChoice? {
        if let preferred {
            return preferred.isDevice ? SourceChoice(source: preferred, reason: .chosenByAthlete) : nil
        }
        let todayStart = calendar.startOfDay(for: today)
        var entries: [(source: ReadinessSource, recent: Int, latest: Int)] = []
        for source in ReadinessSource.defaultOrder {
            let days = validDays(for: source, nights: nights, todayStart: todayStart, calendar: calendar)
            guard let latest = days.min() else { continue }
            let recent = days.filter { $0 < ReadinessConstants.recentWindowDays }.count
            entries.append((source, recent, latest))
        }
        guard !entries.isEmpty else { return nil }
        if entries.count == 1 { return SourceChoice(source: entries[0].source, reason: .onlySource) }
        let first = entries.first(where: { $0.recent >= ReadinessConstants.minimumRecentValidNights })
        if let current, let kept = entries.first(where: { $0.source == current }),
           kept.recent >= 1, kept.recent < ReadinessConstants.minimumRecentValidNights, first == nil || first?.source != current {
            return SourceChoice(source: kept.source, reason: .keptCurrent)
        }
        if let first { return SourceChoice(source: first.source, reason: .defaultOrder) }
        // Entries are already in default order, so a stable minimum keeps the order on ties.
        var best = entries[0]
        for entry in entries.dropFirst() where entry.latest < best.latest { best = entry }
        return SourceChoice(source: best.source, reason: .latestData)
    }

    // MARK: Internals

    enum Metric {
        case hrv, restingHeartRate, sleep

        var range: ClosedRange<Double> {
            switch self {
            case .hrv: return ReadinessConstants.validHRV
            case .restingHeartRate: return ReadinessConstants.validRestingHeartRate
            case .sleep: return ReadinessConstants.validSleepMinutes
            }
        }

        func value(of night: ReadinessNight) -> Double? {
            switch self {
            case .hrv: return night.hrvMilliseconds
            case .restingHeartRate: return night.restingHeartRate
            case .sleep: return night.sleepMinutes
            }
        }
    }

    /// Days before today (0 through 41) on which one source has a valid HRV, resting heart rate or sleep value.
    static func validDays(
        for source: ReadinessSource, nights: [ReadinessNight], todayStart: Date, calendar: Calendar
    ) -> Set<Int> {
        var days = Set<Int>()
        if source.hrvKind != nil {
            days.formUnion(daily(.hrv, source: source, nights: nights, todayStart: todayStart, calendar: calendar).keys)
        }
        days.formUnion(daily(.restingHeartRate, source: source, nights: nights, todayStart: todayStart, calendar: calendar).keys)
        days.formUnion(daily(.sleep, source: source, nights: nights, todayStart: todayStart, calendar: calendar).keys)
        return days
    }

    /// One value per day for one source and metric, keyed by days before today, 0 through 41. HRV and resting
    /// heart rate average the day's records. Sleep sums them (fragments of one night) and range checks the sum.
    static func daily(
        _ metric: Metric, source: ReadinessSource, nights: [ReadinessNight], todayStart: Date, calendar: Calendar
    ) -> [Int: Double] {
        let limit = ReadinessConstants.recentWindowDays + ReadinessConstants.baselineWindowDays
        var buckets: [Int: [Double]] = [:]
        let records = metric == .sleep ? Array(Set(nights.filter { $0.source == source })) : nights.filter { $0.source == source }
        for night in records {
            guard night.date.isUsable, let value = metric.value(of: night), value.isFinite else { continue }
            if metric == .sleep ? value < 0 : !metric.range.contains(value) { continue }
            let offset = calendar.daysBetween(calendar.startOfDay(for: night.date), todayStart)
            guard offset >= 0, offset < limit else { continue }
            buckets[offset, default: []].append(value)
        }
        var result: [Int: Double] = [:]
        for (offset, values) in buckets {
            let sorted = values.sorted()
            let total = sorted.reduce(0, +)
            if metric == .sleep {
                if metric.range.contains(total) { result[offset] = total }
            } else {
                result[offset] = total / Double(sorted.count)
            }
        }
        return result
    }

    private static func metric(
        _ days: [Int: Double], recent: Range<Int>, baseline: Range<Int>, floor: Double
    ) -> MetricBaseline {
        let recentValues = recent.compactMap { days[$0] }
        let baselineValues = baseline.compactMap { days[$0] }
        var result = MetricBaseline(
            baselineNights: baselineValues.count, recentNights: recentValues.count, floor: floor)
        if baselineValues.count >= ReadinessConstants.minimumBaselineNights,
           let stats = logMeanAndSD(of: baselineValues) {
            result.mean = stats.mean
            result.standardDeviation = stats.standardDeviation
        }
        if recentValues.count >= ReadinessConstants.minimumRecentValidNights {
            let logs = recentValues.map { log($0) }.sorted()
            result.recentMean = logs.reduce(0, +) / Double(logs.count)
        }
        return result
    }
}
