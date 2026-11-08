import Foundation

/// Every tunable number of the Load model in one place (annex D). Nothing else in the Load module hardcodes a
/// threshold, factor or time constant. The names are Load, Fitness, Fatigue and Form.
public enum LoadConstants {
    /// Heart rate path: Load points earned by one hour in each of the five LTHR anchored zones, Z1 first
    /// (annex D). Provisional values, tuned in QA so that a steady hour at each zone's midpoint intensity lands
    /// close to the power formula. A threshold hour scores 100 for every athlete because the bands are anchored to
    /// that athlete's own LTHR, so no maximum heart rate input is needed.
    ///
    /// Parity with the power path at zone midpoints (0.45, 0.655, 0.83, 0.98 and 1.13 of FTP give 20.3, 42.9,
    /// 68.9, 96.0 and 127.7): the heart rate path reads about 7 percent low at Z2, 6 percent low at Z3, 4 percent
    /// high at Z4 and 6 percent high at Z5. The Methods screen states heart rate Load is within about 7 percent
    /// of the power figure at zone midpoints (`heartRatePowerParityTolerance`), and a test enforces it.
    public static let heartRateZoneFactorsPerHour: [Double] = [20, 40, 65, 100, 135]

    /// Largest relative difference between the heart rate factor and the power path value at a zone midpoint.
    public static let heartRatePowerParityTolerance: Double = 0.07

    /// Upper edges of heart rate zones Z1 to Z4 as fractions of LTHR (annex A table: Z1 under 81 percent,
    /// Z2 81 to 89, Z3 89 to 94, Z4 94 to 102, Z5 above 102). The same table drives prescriptions in Zones/;
    /// it is repeated here only so the Load module has no dependency on another module.
    public static let heartRateZoneUpperBounds: [Double] = [0.81, 0.89, 0.94, 1.02]

    /// Representative intensity of power zones Z1 to Z5 as a fraction of FTP (annex A power table): the middle of
    /// 56 to 75 is 0.655, of 76 to 90 is 0.83, of 91 to 105 is 0.98 and of 106 to 120 is 1.13. Z1 has no lower
    /// edge, so 0.45 stands in for a typical easy spin. Used for planned Load on the power path and for parity
    /// checks between the two paths.
    public static let powerZoneMidpointFractions: [Double] = [0.45, 0.655, 0.83, 0.98, 1.13]

    /// Time constant of Fitness in days (annex D).
    public static let fitnessTimeConstantDays: Double = 42
    /// Time constant of Fatigue in days (annex D).
    public static let fatigueTimeConstantDays: Double = 7

    /// Window of the acute average in days (annex C rule 6).
    public static let acuteWindowDays: Int = 7
    /// Window of the chronic average in days (annex C rule 6).
    public static let chronicWindowDays: Int = 28

    /// Level assumed for a swim that carries no heart rate, no planned level and no feel rating: an easy pool
    /// swim (annex D "Swim load"). Always labelled Estimated.
    public static let defaultSwimLevel: Int = 2

    /// Longest daily series the builder will produce, in days. A guard against absurd date ranges.
    public static let maximumSeriesDays: Int = 3660

    /// Heart rate zone factor for a level 1 to 5 (clamped).
    public static func heartRateFactor(level: Int) -> Double {
        heartRateZoneFactorsPerHour[IntensityLevel.clamped(level) - 1]
    }

    /// Power zone midpoint fraction of FTP for a level 1 to 5 (clamped).
    public static func powerMidpointFraction(level: Int) -> Double {
        powerZoneMidpointFractions[IntensityLevel.clamped(level) - 1]
    }

    /// Level 1 to 5 for a heart rate expressed as a fraction of LTHR, using `heartRateZoneUpperBounds`. A value
    /// exactly on a band edge belongs to the lower zone, the same rule `DefaultZoneCalculator.heartRateZone`
    /// uses, so the Load path and the prescription path never classify one heart rate two ways.
    public static func heartRateLevel(fractionOfLTHR fraction: Double) -> Int {
        for (index, bound) in heartRateZoneUpperBounds.enumerated() where fraction <= bound {
            return index + 1
        }
        return heartRateZoneFactorsPerHour.count
    }

    /// Days of loaded history before Fitness and Form mean something. Fitness is a 42 day average seeded at zero,
    /// so earlier training that was never loaded shows up as a large negative Form until this many days exist.
    public static let fullHistoryDays: Int = 42

    /// Maps a 1 to 10 feel rating to a level 1 to 5 (two rating points per level). Out of range ratings clamp.
    public static func level(forRPE rpe: Int) -> Int {
        IntensityLevel.clamped((min(max(rpe, 1), 10) + 1) / 2)
    }

    /// Smoothing factor of an exponentially weighted average with the given time constant in days:
    /// 1 minus e to the power of minus one over the constant.
    public static func smoothingFactor(timeConstantDays: Double) -> Double {
        guard timeConstantDays > 0 else { return 1 }
        return 1 - exp(-1 / timeConstantDays)
    }
}
