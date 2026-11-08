import Foundation

/// Why a swim test was not accepted and what to tell the athlete (annex A, swim: a friendly retest flow).
public enum CSSRetestReason: String, Codable, Hashable, Sendable {
    /// The 200 m pace was not faster than the 400 m pace.
    case twoHundredNotFaster
    /// A time was missing, zero, negative or not a number.
    case invalidTimes
    /// The times parse but no swimmer could produce them, which is almost always a typo.
    case implausibleTimes

    /// Calm explanation for the retest screen. No shaming, no blame.
    public var message: String {
        switch self {
        case .twoHundredNotFaster:
            return "Your 200 m pace was not faster than your 400 m pace, so these two times cannot give a clean CSS. "
                + "That usually means the 400 was a little easy or the 200 was held back. "
                + "Rest a day or two, then swim the pair again with a real all out effort on both."
        case .invalidTimes:
            return "One of the times looks empty or unreadable. Enter your 400 m and 200 m times in seconds, "
                + "or as minutes and seconds, and try again."
        case .implausibleTimes:
            return "Those times look a little off, perhaps a typo. Check your 400 m and 200 m times and enter them "
                + "again, or retest if one of them was not a full effort."
        }
    }
}

/// The outcome of the swim test as a value, so the app can branch to the retest flow without handling an error
/// (annex A, swim).
public enum CSSTestDecision: Hashable, Sendable {
    case accepted(BenchmarkValue)
    case retest(CSSRetestReason)
}

/// Where a bike seed came from, so the benchmarks screen can say bike zones were estimated from heart rate
/// and suggest a test (annex A "Seeding without tests").
public enum BikeSeedSource: String, Codable, Hashable, Sendable {
    case power
    case heartRate
    case none
}

/// A bike seed with its source (annex A "Seeding without tests").
public struct BikeSeed: Hashable, Sendable {
    /// Carries `ftpWatts` when the source is power, `lthrBpm` when it is heart rate, and nothing otherwise.
    public var benchmarks: Benchmarks
    public var source: BikeSeedSource

    /// True when the benchmarks screen should say bike zones were estimated from heart rate and suggest a test.
    public var suggestsTest: Bool { source != .power }

    public init(benchmarks: Benchmarks, source: BikeSeedSource) {
        self.benchmarks = benchmarks
        self.source = source
    }
}

/// Implements annex A: test math, zone tables, target resolution and benchmark seeding.
/// All functions are pure and never trap; bad inputs throw `PlanKitError.invalidInput` or return nil.
public struct DefaultZoneCalculator: ZoneCalculator {
    public init() {}

    // MARK: Zone tables

    /// Annex A, swim: easy +8 to +15, steady +4 to +7, threshold minus 3 to plus 3, VO2 minus 8 to minus 4.
    public func swimOffsetRange(_ zone: SwimZone) -> ValueRange {
        switch zone {
        case .easy: return ZoneConstants.swimEasyOffset
        case .steady: return ZoneConstants.swimSteadyOffset
        case .threshold: return ZoneConstants.swimThresholdOffset
        case .vo2: return ZoneConstants.swimVO2Offset
        }
    }

    /// Annex A, swim: CSS plus the zone offset, in seconds per 100 m. A CSS that is not positive and finite is
    /// counts as zero and results are floored at zero.
    public func swimPaceRange(_ zone: SwimZone, css: Double) -> ValueRange {
        let base = Self.positiveOrZero(css)
        let offset = swimOffsetRange(zone)
        return ValueRange(max(0, base + offset.lower), max(0, base + offset.upper))
    }

    /// Annex A, run: easy +45 to +90 s/km, steady +20 to +45, threshold plus or minus 3 percent floored at
    /// plus or minus 10 s, VO2 minus 25 to minus 15.
    public func runPaceRange(_ zone: RunZone, thresholdPace: Double) -> ValueRange {
        let base = Self.positiveOrZero(thresholdPace)
        let low: Double
        let high: Double
        switch zone {
        case .easy:
            low = base + ZoneConstants.runEasyOffset.lower
            high = base + ZoneConstants.runEasyOffset.upper
        case .steady:
            low = base + ZoneConstants.runSteadyOffset.lower
            high = base + ZoneConstants.runSteadyOffset.upper
        case .threshold:
            let tolerance = max(base * ZoneConstants.runThresholdFraction, ZoneConstants.runThresholdFloorSeconds)
            low = base - tolerance
            high = base + tolerance
        case .vo2:
            low = base + ZoneConstants.runVO2Offset.lower
            high = base + ZoneConstants.runVO2Offset.upper
        }
        return ValueRange(max(0, low), max(0, high))
    }

    /// Annex A, bike: percent of FTP bands from `ZoneConstants.bikePowerPercentBand`, Z7 capped at 300 percent.
    public func bikePowerRange(_ zone: BikePowerZone, ftp: Double) -> ValueRange {
        let base = Self.positiveOrZero(ftp)
        let band = ZoneConstants.bikePowerPercentBand(zone)
        return ValueRange(base * band.lower / 100, base * band.upper / 100)
    }

    /// Annex A, bike: the five band table as percent of LTHR, Z1 from 0 and Z5 capped at 120 percent.
    public func heartRateRange(_ zone: HeartRateZone, lthr: Double) -> ValueRange {
        let base = Self.positiveOrZero(lthr)
        let band = ZoneConstants.heartRatePercentBand(zone)
        return ValueRange(base * band.lower / 100, base * band.upper / 100)
    }

    /// The bike power zone a wattage falls in, with no gaps: a sample between the printed band edges
    /// (for example 55.5 percent) belongs to the zone above the edge. Z1 when FTP is not usable.
    public func bikePowerZone(forWatts watts: Double, ftp: Double) -> BikePowerZone {
        guard ftp.isFinite, ftp > 0, watts.isFinite else { return .z1 }
        func above(_ percent: Double) -> Bool { watts > ftp * percent / 100 }
        if above(150) { return .z7 }
        if above(120) { return .z6 }
        if above(105) { return .z5 }
        if above(90) { return .z4 }
        if above(75) { return .z3 }
        if above(55) { return .z2 }
        return .z1
    }

    /// The heart rate zone a rate falls in (annex A five band table). A value on a band edge belongs to the
    /// lower zone. Z1 when LTHR is not usable.
    public func heartRateZone(forBpm bpm: Double, lthr: Double) -> HeartRateZone {
        guard lthr.isFinite, lthr > 0, bpm.isFinite else { return .z1 }
        func above(_ percent: Double) -> Bool { bpm > lthr * percent / 100 }
        if above(102) { return .z5 }
        if above(94) { return .z4 }
        if above(89) { return .z3 }
        if above(81) { return .z2 }
        return .z1
    }

    // MARK: Target resolution

    /// Resolves the target a watch or phone player should show (annex A, annex C rule 3 nudges).
    ///
    /// Concrete targets already on the step (pace, speed, power, heart rate) are returned unchanged. Otherwise:
    /// - swim: with a CSS, `.pacePer100m` in seconds per 100 m (from `css` plus the step's `.cssOffset`, or plus the
    ///   level's zone offset), so the compiler can derive a distance with time goal; without, RPE;
    /// - bike: `.powerRange` when the athlete has a power meter and an FTP, else `.heartRateRange` from bike LTHR,
    ///   else RPE;
    /// - run: `.pacePerKm` from threshold pace, else `.heartRateRange` from run LTHR, else RPE. Walk breaks,
    ///   recovery steps and easy warm ups and cool downs stay on feel (see `isFeelOnlyRunStep`), so the watch
    ///   never buzzes for walking.
    /// `nudgeSteps` moves pace and power benchmarks about 2 percent per step toward harder when positive.
    /// Heart rate zones are never nudged. Estimated benchmarks resolve normally.
    public func resolveTarget(
        for step: Step,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        nudgeSteps: Int
    ) -> StepTarget {
        switch step.target {
        case .pacePerKm, .pacePer100m, .speedRange, .powerRange, .heartRateRange:
            return step.target
        case .cssOffset, .rpe, .none:
            break
        }

        let steps = min(max(nudgeSteps, -ZoneConstants.maximumNudgeSteps), ZoneConstants.maximumNudgeSteps)
        let paceFactor = 1 - Double(steps) * ZoneConstants.nudgeFractionPerStep
        let powerFactor = 1 + Double(steps) * ZoneConstants.nudgeFractionPerStep

        switch step.sport {
        case .swim:
            if let css = Self.usable(benchmarks.cssSecondsPer100m) {
                let nudged = css * paceFactor
                let paces: ValueRange
                if case let .cssOffset(offset) = step.target {
                    paces = ValueRange(max(0, nudged + offset.lower), max(0, nudged + offset.upper))
                } else {
                    paces = swimPaceRange(SwimZone(level: step.level), css: nudged)
                }
                if paces.upper > 0 {
                    return .pacePer100m(paces)
                }
            }
        case .bike:
            if athlete.hasPowerMeter, let ftp = Self.usable(benchmarks.ftpWatts) {
                return .powerRange(bikePowerRange(BikePowerZone(level: step.level), ftp: ftp * powerFactor))
            }
            if let lthr = Self.usable(benchmarks.lthrBpm) {
                return .heartRateRange(heartRateRange(HeartRateZone(level: step.level), lthr: lthr))
            }
        case .run:
            if Self.isFeelOnlyRunStep(step, athlete: athlete) {
                break
            }
            if let threshold = Self.usable(benchmarks.thresholdPaceSecondsPerKm) {
                return .pacePerKm(runPaceRange(RunZone(level: step.level), thresholdPace: threshold * paceFactor))
            }
            if let lthr = Self.usable(benchmarks.runLthrBpm) {
                return .heartRateRange(heartRateRange(HeartRateZone(level: step.level), lthr: lthr))
            }
        }

        if case .rpe = step.target { return step.target }
        return .rpe(ZoneConstants.rpeRange(forLevel: step.level))
    }

    /// Run steps that run on feel only: a level 1 warm up, recovery or cool down, and any step the run walk
    /// athlete walks. A pace range on a walk would make the watch buzz for the very athlete the feature serves.
    static func isFeelOnlyRunStep(_ step: Step, athlete: AthleteProfile) -> Bool {
        if step.level <= 1 && (step.kind == .warmUp || step.kind == .recovery || step.kind == .coolDown) {
            return true
        }
        return athlete.prefersRunWalk && step.name.lowercased().contains("walk")
    }

    // MARK: Tests

    /// Annex A, swim: CSS per 100 m = (T400 minus T200) / 2. Rejects when the 200 m pace is not faster than the
    /// 400 m pace, that is when `T400 <= 2 * T200`.
    public func cssFromTest(time400Seconds: Double, time200Seconds: Double, on date: Date) throws -> BenchmarkValue {
        switch evaluateCSSTest(time400Seconds: time400Seconds, time200Seconds: time200Seconds, on: date) {
        case let .accepted(value):
            return value
        case let .retest(reason):
            switch reason {
            case .twoHundredNotFaster: throw PlanKitError.cssTestRejected
            case .invalidTimes: throw PlanKitError.invalidInput("Swim test times must be positive numbers of seconds.")
            case .implausibleTimes: throw PlanKitError.invalidInput("Swim test times look implausible. Check for a typo and retest if needed.")
            }
        }
    }

    /// Annex A, swim: the same math as `cssFromTest`, returned as a value so the retest flow needs no error handling.
    public func evaluateCSSTest(time400Seconds: Double, time200Seconds: Double, on date: Date) -> CSSTestDecision {
        guard time400Seconds.isFinite, time200Seconds.isFinite, time400Seconds > 0, time200Seconds > 0 else {
            return .retest(.invalidTimes)
        }
        // Pace per 100 m is t200 / 2 for the short swim and t400 / 4 for the long one.
        guard time200Seconds * 2 < time400Seconds else {
            return .retest(.twoHundredNotFaster)
        }
        // A typo (400 m in 100 s) must not drive every swim prescription, so impossible times ask for a retest.
        guard ZoneConstants.swim400TimeBounds.contains(time400Seconds),
              ZoneConstants.swim200TimeBounds.contains(time200Seconds) else {
            return .retest(.implausibleTimes)
        }
        let css = (time400Seconds - time200Seconds) / 2
        guard ZoneConstants.cssBounds.contains(css) else { return .retest(.implausibleTimes) }
        return .accepted(BenchmarkValue(value: css, isEstimated: false, date: date))
    }

    /// Annex A, bike: FTP = 0.95 times the best 20 minute average power.
    public func ftpFromTest(best20MinutePower: Double, on date: Date) throws -> BenchmarkValue {
        guard best20MinutePower.isFinite, best20MinutePower > 0 else {
            throw PlanKitError.invalidInput("Best 20 minute power must be a positive number of watts.")
        }
        let ftp = best20MinutePower * ZoneConstants.ftpFractionOfTwentyMinutePower
        guard ZoneConstants.ftpBounds.contains(ftp) else {
            throw PlanKitError.invalidInput("That power looks implausible. Check for a typo and retest if needed.")
        }
        return BenchmarkValue(value: ftp, isEstimated: false, date: date)
    }

    /// Annex A, bike: LTHR is the average heart rate of the final 20 minutes of the 30 minute solo time trial.
    public func bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: Double, on date: Date) throws -> BenchmarkValue {
        guard Self.isPlausibleHeartRate(finalTwentyMinuteAverageHeartRate) else {
            throw PlanKitError.invalidInput("Average heart rate must be between 40 and 240 beats per minute.")
        }
        return BenchmarkValue(value: finalTwentyMinuteAverageHeartRate, isEstimated: false, date: date)
    }

    /// Annex A, run: threshold pace per km = 1800 s divided by the kilometres covered in the 30 minute test.
    /// LTHR, when given, is the average heart rate of the final 20 minutes. Only the run fields are set.
    public func runThresholdFromTest(
        distanceKilometres: Double,
        finalTwentyMinuteAverageHeartRate: Double?,
        on date: Date
    ) throws -> Benchmarks {
        guard let pace = PaceConversion.thresholdPacePerKm(testDistanceKilometres: distanceKilometres),
              ZoneConstants.thresholdPaceBounds.contains(pace) else {
            throw PlanKitError.invalidInput("Distance covered in 30 minutes must be a realistic positive number of kilometres.")
        }
        var result = Benchmarks(thresholdPaceSecondsPerKm: BenchmarkValue(value: pace, isEstimated: false, date: date))
        if let heartRate = finalTwentyMinuteAverageHeartRate {
            guard Self.isPlausibleHeartRate(heartRate) else {
                throw PlanKitError.invalidInput("Average heart rate must be between 40 and 240 beats per minute.")
            }
            result.runLthrBpm = BenchmarkValue(value: heartRate, isEstimated: false, date: date)
        }
        return result
    }

    // MARK: Helpers

    /// Faster than 2:00 per km sustained for 30 minutes is not a real test result.
    static let fastestPlausibleRunPace: Double = ZoneConstants.thresholdPaceBounds.lowerBound

    static func isPlausibleHeartRate(_ value: Double) -> Bool {
        value.isFinite && value >= 40 && value <= 240
    }

    static func positiveOrZero(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }

    /// The benchmark value when it is positive and finite, else nil.
    static func usable(_ benchmark: BenchmarkValue?) -> Double? {
        guard let value = benchmark?.value, value.isFinite, value > 0 else { return nil }
        return value
    }
}
