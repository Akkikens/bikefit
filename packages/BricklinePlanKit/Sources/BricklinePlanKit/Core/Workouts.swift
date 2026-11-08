import Foundation

/// Where a completed workout came from (annex E "Completion matching").
public enum WorkoutSource: String, Codable, Hashable, Sendable, CaseIterable {
    /// Recorded from a plan scheduled with WorkoutKit (matched by plan UUID).
    case scheduledPlan
    /// Recorded by the Brickline phone player.
    case phonePlayer
    /// Any other HealthKit workout (watch, Garmin through Apple Health, and so on).
    case healthKit
    /// Marked done by hand.
    case manual
}

/// A recorded workout, platform neutral (HealthKit types stay outside this package).
public struct CompletedWorkout: Codable, Hashable, Sendable {
    public var id: String
    public var sport: Sport
    public var start: Date
    public var durationSeconds: Double
    public var distanceMeters: Double?
    /// Average power in watts, bike or outdoor run, when a power source exists.
    public var averagePower: Double?
    /// Power after 30 second smoothing and fourth power weighting, in watts. Used by the power load path when
    /// present, else `averagePower` (annex D "average adjusted intensity").
    public var adjustedPower: Double?
    public var averageHeartRate: Double?
    /// Average power over the work intervals only, from lap or segment data. Annex C rule 3 compares this with the
    /// target of the hard steps, so warm up, recovery and coasting never bias the comparison.
    public var workIntervalAveragePower: Double?
    /// Average run pace over the work intervals only, seconds per km.
    public var workIntervalAveragePacePerKm: Double?
    /// Average swim pace over the work intervals only, seconds per 100 m.
    public var workIntervalAveragePacePer100m: Double?
    /// Seconds spent in each of the five LTHR anchored heart rate zones, index 0 for Z1 (annex A, annex D).
    /// Nil when there is no heart rate data. A value with a count other than 5 is treated as missing.
    public var secondsInHeartRateZones: [Double]?
    /// Reported feel on the 1 to 10 scale, for athletes without heart rate (annex G).
    public var rpe: Int?
    /// Id of the planned session this workout was matched to, if any.
    public var plannedSessionID: String?
    public var source: WorkoutSource

    public init(
        id: String,
        sport: Sport,
        start: Date,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        averagePower: Double? = nil,
        adjustedPower: Double? = nil,
        averageHeartRate: Double? = nil,
        secondsInHeartRateZones: [Double]? = nil,
        rpe: Int? = nil,
        plannedSessionID: String? = nil,
        source: WorkoutSource,
        workIntervalAveragePower: Double? = nil,
        workIntervalAveragePacePerKm: Double? = nil,
        workIntervalAveragePacePer100m: Double? = nil
    ) {
        self.id = id
        self.sport = sport
        self.start = start
        self.durationSeconds = durationSeconds.isFinite ? max(durationSeconds, 0) : 0
        self.distanceMeters = distanceMeters
        self.averagePower = averagePower
        self.adjustedPower = adjustedPower
        self.averageHeartRate = averageHeartRate
        self.workIntervalAveragePower = workIntervalAveragePower
        self.workIntervalAveragePacePerKm = workIntervalAveragePacePerKm
        self.workIntervalAveragePacePer100m = workIntervalAveragePacePer100m
        self.secondsInHeartRateZones = secondsInHeartRateZones
        self.rpe = rpe
        self.plannedSessionID = plannedSessionID
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, sport, start, durationSeconds, distanceMeters, averagePower, adjustedPower, averageHeartRate
        case secondsInHeartRateZones, rpe, plannedSessionID, source
        case workIntervalAveragePower, workIntervalAveragePacePerKm, workIntervalAveragePacePer100m
    }

    /// Decoding goes through the clamping initializer, so a stored workout never has a negative duration.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            sport: try c.decode(Sport.self, forKey: .sport),
            start: try c.decode(Date.self, forKey: .start),
            durationSeconds: try c.decode(Double.self, forKey: .durationSeconds),
            distanceMeters: try c.decodeIfPresent(Double.self, forKey: .distanceMeters),
            averagePower: try c.decodeIfPresent(Double.self, forKey: .averagePower),
            adjustedPower: try c.decodeIfPresent(Double.self, forKey: .adjustedPower),
            averageHeartRate: try c.decodeIfPresent(Double.self, forKey: .averageHeartRate),
            secondsInHeartRateZones: try c.decodeIfPresent([Double].self, forKey: .secondsInHeartRateZones),
            rpe: try c.decodeIfPresent(Int.self, forKey: .rpe),
            plannedSessionID: try c.decodeIfPresent(String.self, forKey: .plannedSessionID),
            source: try c.decode(WorkoutSource.self, forKey: .source),
            workIntervalAveragePower: try c.decodeIfPresent(Double.self, forKey: .workIntervalAveragePower),
            workIntervalAveragePacePerKm: try c.decodeIfPresent(Double.self, forKey: .workIntervalAveragePacePerKm),
            workIntervalAveragePacePer100m: try c.decodeIfPresent(Double.self, forKey: .workIntervalAveragePacePer100m))
    }

    /// Average pace in seconds per km when distance and duration are known and positive.
    public var averagePacePerKm: Double? {
        guard let distance = distanceMeters, distance > 0, durationSeconds > 0 else { return nil }
        return durationSeconds / (distance / 1000)
    }

    /// Average swim pace in seconds per 100 m when distance and duration are known and positive.
    public var averagePacePer100m: Double? {
        guard let distance = distanceMeters, distance > 0, durationSeconds > 0 else { return nil }
        return durationSeconds / (distance / 100)
    }
}

/// One timestamped value of a recorded series (power, heart rate or speed), used for benchmark seeding
/// (annex A "Seeding without tests").
public struct SeriesSample: Codable, Hashable, Sendable {
    /// Seconds since the start of the workout.
    public var offsetSeconds: Double
    /// Watts, bpm or metres per second depending on the series.
    public var value: Double

    public init(offsetSeconds: Double, value: Double) {
        self.offsetSeconds = offsetSeconds
        self.value = value
    }
}
