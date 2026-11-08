import Foundation

/// A closed numeric range that cannot trap: the initializer orders its bounds, so `lower <= upper` always.
/// Units depend on the context (seconds per km, seconds per 100 m, watts, bpm, metres per second, RPE).
/// For pace values the lower number is the faster pace.
public struct ValueRange: Codable, Hashable, Sendable {
    public var lower: Double
    public var upper: Double

    public init(_ a: Double, _ b: Double) {
        self.lower = min(a, b)
        self.upper = max(a, b)
    }

    private enum CodingKeys: String, CodingKey {
        case lower, upper
    }

    /// Decoding goes through the ordering initializer, so a stored or shared range is never reversed. Non finite
    /// numbers are refused.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let a = try c.decode(Double.self, forKey: .lower)
        let b = try c.decode(Double.self, forKey: .upper)
        guard a.isFinite, b.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .lower, in: c, debugDescription: "A value range needs finite numbers.")
        }
        self.init(a, b)
    }

    public var midpoint: Double { (lower + upper) / 2 }
    public var width: Double { upper - lower }

    public func contains(_ value: Double) -> Bool {
        value >= lower && value <= upper
    }
}

/// Intensity level used by `Step.level`, 1 to 5. One neutral ladder shared by all sports:
/// 1 recovery, 2 easy, 3 steady, 4 threshold, 5 VO2 and above.
/// Mapping used by every module:
/// - heart rate zones Z1 to Z5 are levels 1 to 5 (annex A);
/// - bike power zones Z1 to Z5 are levels 1 to 5 (Z6 and Z7 are reachable only through `BikePowerZone` directly);
/// - swim and run zones: levels 1 and 2 are Easy, 3 Steady, 4 Threshold, 5 VO2 (annex A).
public enum IntensityLevel {
    public static let range: ClosedRange<Int> = 1...5

    /// Clamps any integer into 1 to 5 without trapping.
    public static func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// App defined swim zones as offsets from CSS (annex A, swim).
public enum SwimZone: String, Codable, Hashable, Sendable, CaseIterable {
    case easy
    case steady
    case threshold
    case vo2

    /// Maps `Step.level` (see `IntensityLevel`).
    public init(level: Int) {
        switch IntensityLevel.clamped(level) {
        case 1, 2: self = .easy
        case 3: self = .steady
        case 4: self = .threshold
        default: self = .vo2
        }
    }
}

/// App defined run zones relative to threshold pace (annex A, run).
public enum RunZone: String, Codable, Hashable, Sendable, CaseIterable {
    case easy
    case steady
    case threshold
    case vo2

    /// Maps `Step.level` (see `IntensityLevel`).
    public init(level: Int) {
        switch IntensityLevel.clamped(level) {
        case 1, 2: self = .easy
        case 3: self = .steady
        case 4: self = .threshold
        default: self = .vo2
        }
    }
}

/// Bike power zones as percent of FTP (annex A, bike): Z1 under 55, Z2 56 to 75, Z3 76 to 90, Z4 91 to 105,
/// Z5 106 to 120, Z6 121 to 150, Z7 above 150. Bands are contiguous so no sample falls outside every zone.
public enum BikePowerZone: Int, Codable, Hashable, Sendable, CaseIterable {
    case z1 = 1
    case z2
    case z3
    case z4
    case z5
    case z6
    case z7

    /// Maps `Step.level` 1 to 5 to Z1 to Z5.
    public init(level: Int) {
        self = BikePowerZone(rawValue: IntensityLevel.clamped(level)) ?? .z1
    }
}

/// Five heart rate zones anchored to LTHR (annex A): Z1 under 81 percent, Z2 81 to 89, Z3 89 to 94,
/// Z4 94 to 102, Z5 above 102. Used for prescriptions and for the load model.
public enum HeartRateZone: Int, Codable, Hashable, Sendable, CaseIterable {
    case z1 = 1
    case z2
    case z3
    case z4
    case z5

    /// Maps `Step.level` 1 to 5 to Z1 to Z5.
    public init(level: Int) {
        self = HeartRateZone(rawValue: IntensityLevel.clamped(level)) ?? .z1
    }

    /// Zero based index into a 5 element array such as `CompletedWorkout.secondsInHeartRateZones`.
    public var index: Int { rawValue - 1 }
}
