import Foundation

/// Pace and speed conversions for watch alerts (annex A "threshold speed", annex E "pace inverted to speed").
/// WorkoutKit speed range alerts use metres per second. A pace range has its faster pace as the lower number,
/// so the matching speed range has the lower speed at the slower pace. Every function returns nil instead of
/// dividing by zero.
public enum PaceConversion {
    /// Metres per second for a pace in seconds per km. Nil for a pace that is not positive and finite.
    public static func speedMetersPerSecond(fromPacePerKm pace: Double) -> Double? {
        guard pace.isFinite, pace > 0 else { return nil }
        return 1000 / pace
    }

    /// Metres per second for a swim pace in seconds per 100 m. Nil for a pace that is not positive and finite.
    public static func speedMetersPerSecond(fromPacePer100m pace: Double) -> Double? {
        guard pace.isFinite, pace > 0 else { return nil }
        return 100 / pace
    }

    /// Seconds per km for a speed in metres per second. Nil for a speed that is not positive and finite.
    public static func pacePerKm(fromSpeed speed: Double) -> Double? {
        guard speed.isFinite, speed > 0 else { return nil }
        return 1000 / speed
    }

    /// Seconds per 100 m for a speed in metres per second. Nil for a speed that is not positive and finite.
    public static func pacePer100m(fromSpeed speed: Double) -> Double? {
        guard speed.isFinite, speed > 0 else { return nil }
        return 100 / speed
    }

    /// Speed range in metres per second for a pace range in seconds per km (annex E run alerts).
    public static func speedRange(fromPaceRangePerKm range: ValueRange) -> ValueRange? {
        guard let slow = speedMetersPerSecond(fromPacePerKm: range.upper),
              let fast = speedMetersPerSecond(fromPacePerKm: range.lower) else { return nil }
        return ValueRange(slow, fast)
    }

    /// Speed range in metres per second for a swim pace range in seconds per 100 m.
    public static func speedRange(fromPaceRangePer100m range: ValueRange) -> ValueRange? {
        guard let slow = speedMetersPerSecond(fromPacePer100m: range.upper),
              let fast = speedMetersPerSecond(fromPacePer100m: range.lower) else { return nil }
        return ValueRange(slow, fast)
    }

    /// Run threshold speed in metres per second from the 30 minute test: distance divided by 1800 s
    /// (annex A, run). Nil for a distance that is not positive and finite.
    public static func thresholdSpeedMetersPerSecond(testDistanceKilometres km: Double) -> Double? {
        guard km.isFinite, km > 0 else { return nil }
        return km * 1000 / ZoneConstants.runTestDurationSeconds
    }

    /// Run threshold pace in seconds per km from the 30 minute test: 1800 s divided by the kilometres covered
    /// (annex A, run). Nil for a distance that is not positive and finite.
    public static func thresholdPacePerKm(testDistanceKilometres km: Double) -> Double? {
        guard km.isFinite, km > 0 else { return nil }
        return ZoneConstants.runTestDurationSeconds / km
    }
}
