import Foundation

/// Every number of annex A in one place, so the zone calculator, the tests and the Methods screen read the same
/// table. Offsets are the app's own (annex A states they are app defined pending coach review).
public enum ZoneConstants {
    // MARK: Test formulas (annex A)

    /// FTP is this fraction of the best 20 minute average power (annex A, bike).
    public static let ftpFractionOfTwentyMinutePower: Double = 0.95

    /// Run threshold pace is this many seconds divided by the kilometres covered (annex A, run).
    public static let runTestDurationSeconds: Double = 1800

    /// Length of the final stretch of the 30 minute tests whose average heart rate is the LTHR (annex A).
    public static let lthrWindowSeconds: Double = 1200

    /// Length of the best power window behind a seeded FTP (annex A "Seeding without tests").
    public static let ftpSeedWindowSeconds: Double = 1200

    /// Shortest sustained segment a heart rate or speed seed accepts: 20 minutes (annex A, seeding).
    public static let seedMinimumWindowSeconds: Double = 1200

    /// Longest sustained segment a heart rate or speed seed searches: 30 minutes (annex A, seeding).
    public static let seedMaximumWindowSeconds: Double = 1800

    /// A hole in a series longer than this many seconds ends a continuous segment, so a paused recording
    /// is never bridged into one sustained effort.
    public static let seriesMaximumGapSeconds: Double = 60

    // MARK: Plausibility bounds

    // One set for test entry, race pacing and plan durations, so the modules never disagree about what a real
    // result looks like. A value outside a bound is almost always a typo, so test entry asks for a retest and
    // race pacing treats it as missing.

    /// Critical swim speed in seconds per 100 m.
    public static let cssBounds: ClosedRange<Double> = 40...300
    /// The all out 400 m time in seconds.
    public static let swim400TimeBounds: ClosedRange<Double> = 180...1200
    /// The all out 200 m time in seconds.
    public static let swim200TimeBounds: ClosedRange<Double> = 80...700
    /// Functional threshold power in watts.
    public static let ftpBounds: ClosedRange<Double> = 20...700
    /// Lactate threshold heart rate in beats per minute.
    public static let lthrBounds: ClosedRange<Double> = 80...230
    /// Run threshold pace in seconds per km.
    public static let thresholdPaceBounds: ClosedRange<Double> = 120...1200

    /// A run seeded from a window shorter than the 30 minute test runs a little faster than a test pace. The
    /// seeded pace is slowed by this fraction at the shortest window (20 minutes), scaling to zero at 30
    /// (annex A "Seeding without tests": the value stays labelled Estimated).
    public static let seedShortWindowPaceAdjustment: Double = 0.04

    // MARK: Swim offsets in seconds per 100 m (annex A, swim)

    public static let swimEasyOffset = ValueRange(8, 15)
    public static let swimSteadyOffset = ValueRange(4, 7)
    public static let swimThresholdOffset = ValueRange(-3, 3)
    public static let swimVO2Offset = ValueRange(-8, -4)

    // MARK: Run offsets in seconds per km (annex A, run)

    public static let runEasyOffset = ValueRange(45, 90)
    public static let runSteadyOffset = ValueRange(20, 45)
    public static let runVO2Offset = ValueRange(-25, -15)
    /// Threshold band is plus or minus this fraction of threshold pace.
    public static let runThresholdFraction: Double = 0.03
    /// The threshold band is never narrower than plus or minus this many seconds per km.
    public static let runThresholdFloorSeconds: Double = 10

    // MARK: Bike power bands in percent of FTP (annex A, bike)

    /// Z1 under 55, Z2 56 to 75, Z3 76 to 90, Z4 91 to 105, Z5 106 to 120, Z6 121 to 150, Z7 above 150.
    /// Z7 is capped at `bikePowerCapPercent` so the range stays finite.
    public static func bikePowerPercentBand(_ zone: BikePowerZone) -> ValueRange {
        switch zone {
        case .z1: return ValueRange(0, 55)
        case .z2: return ValueRange(56, 75)
        case .z3: return ValueRange(76, 90)
        case .z4: return ValueRange(91, 105)
        case .z5: return ValueRange(106, 120)
        case .z6: return ValueRange(121, 150)
        case .z7: return ValueRange(151, bikePowerCapPercent)
        }
    }

    /// Upper bound of the open ended Z7 band, in percent of FTP.
    public static let bikePowerCapPercent: Double = 300

    // MARK: Heart rate bands in percent of LTHR (annex A, bike)

    /// Z1 under 81, Z2 81 to 89, Z3 89 to 94, Z4 94 to 102, Z5 above 102. The bands touch, so every
    /// heart rate belongs to a zone. Z5 is capped at `heartRateCapPercent`.
    public static func heartRatePercentBand(_ zone: HeartRateZone) -> ValueRange {
        switch zone {
        case .z1: return ValueRange(0, 81)
        case .z2: return ValueRange(81, 89)
        case .z3: return ValueRange(89, 94)
        case .z4: return ValueRange(94, 102)
        case .z5: return ValueRange(102, heartRateCapPercent)
        }
    }

    /// Upper bound of the open ended Z5 band, in percent of LTHR.
    public static let heartRateCapPercent: Double = 120

    // MARK: Nudges (annex C rule 3)

    /// One zone nudge step moves the benchmark by about this fraction.
    public static let nudgeFractionPerStep: Double = 0.02

    /// Nudge steps beyond this magnitude are ignored so a bad stored value cannot flip a pace.
    public static let maximumNudgeSteps: Int = 10

    // MARK: Feel scale

    /// Default feel range for a step level when no benchmark exists (annex A: every step is executable by feel).
    public static func rpeRange(forLevel level: Int) -> ValueRange {
        switch IntensityLevel.clamped(level) {
        case 1: return ValueRange(1, 2)
        case 2: return ValueRange(3, 4)
        case 3: return ValueRange(5, 6)
        case 4: return ValueRange(7, 8)
        default: return ValueRange(9, 10)
        }
    }
}
