import Foundation

/// Race record fields the race window needs (annex F).
public struct RaceDetails: Codable, Hashable, Sendable {
    public var distance: RaceDistance
    /// Race day, any time within the day.
    public var raceDate: Date
    /// Start time in minutes after local midnight.
    public var startMinutesAfterMidnight: Int
    public var transitMinutes: Int
    public var setupMinutes: Int
    public var breakfastLeadMinutes: Int
    /// Travel flag; feeds the Pack and Rebuild Check (annex F).
    public var isTravelRace: Bool
    /// True when a Bike record exists, so the service reminder can be shown.
    public var hasBikeRecord: Bool

    public init(
        distance: RaceDistance,
        raceDate: Date,
        startMinutesAfterMidnight: Int,
        transitMinutes: Int = 20,
        setupMinutes: Int = 45,
        breakfastLeadMinutes: Int = 120,
        isTravelRace: Bool = false,
        hasBikeRecord: Bool = false
    ) {
        self.distance = distance
        self.raceDate = raceDate
        self.startMinutesAfterMidnight = startMinutesAfterMidnight
        self.transitMinutes = transitMinutes
        self.setupMinutes = setupMinutes
        self.breakfastLeadMinutes = breakfastLeadMinutes
        self.isTravelRace = isTravelRace
        self.hasBikeRecord = hasBikeRecord
    }
}

/// Kinds of timeline entries (annex F "Timeline entries").
public enum RaceWindowEntryKind: String, Codable, Hashable, Sendable, CaseIterable {
    case bikeService
    case travel
    case pack
    case carbLoad
    case packTonight
    case wakeUp
}

/// One entry of the T minus timeline (annex F). Also the unit that annex H notification budgeting counts.
public struct RaceWindowEntry: Codable, Hashable, Sendable {
    /// Days before race day. 0 is race day.
    public var tMinusDays: Int
    public var kind: RaceWindowEntryKind
    public var text: String
    /// Time of day in minutes after local midnight, when the entry has a computed time (the wake up entry).
    public var minutesAfterMidnight: Int?

    public init(tMinusDays: Int, kind: RaceWindowEntryKind, text: String, minutesAfterMidnight: Int? = nil) {
        self.tMinusDays = tMinusDays
        self.kind = kind
        self.text = text
        self.minutesAfterMidnight = minutesAfterMidnight
    }
}

/// Where a leg's expected duration comes from (annex F: fueling and the debrief key on it).
public enum DurationBasis: String, Codable, Hashable, Sendable, CaseIterable {
    /// Computed from the athlete's own benchmark (CSS, threshold pace).
    case fromBenchmark
    /// Computed from a time or speed the athlete entered.
    case athleteEntered
    /// A generic assumption for the athlete's level. It is not the athlete's plan and is never presented as one.
    case typicalForLevel
}

/// A per leg pacing target. Always a range, never a single split (annex F "Pacing card").
public struct PacingTarget: Codable, Hashable, Sendable {
    public var leg: RaceLeg
    /// Resolved range from the athlete's own zones, or `.rpe` when the needed benchmark is missing.
    public var target: StepTarget
    /// Expected leg duration range in seconds, from the pacing targets. Keys the fueling tier.
    public var expectedDurationSeconds: ValueRange
    /// Short plain description, for example the percent of FTP band used.
    public var summary: String
    /// Where `expectedDurationSeconds` comes from. A `typicalForLevel` duration is a generic assumption.
    public var durationBasis: DurationBasis

    public init(
        leg: RaceLeg,
        target: StepTarget,
        expectedDurationSeconds: ValueRange,
        summary: String,
        durationBasis: DurationBasis = .fromBenchmark
    ) {
        self.leg = leg
        self.target = target
        self.expectedDurationSeconds = expectedDurationSeconds
        self.summary = summary
        self.durationBasis = durationBasis
    }

    private enum CodingKeys: String, CodingKey {
        case leg, target, expectedDurationSeconds, summary, durationBasis
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            leg: try c.decode(RaceLeg.self, forKey: .leg),
            target: try c.decode(StepTarget.self, forKey: .target),
            expectedDurationSeconds: try c.decode(ValueRange.self, forKey: .expectedDurationSeconds),
            summary: try c.decode(String.self, forKey: .summary),
            durationBasis: try c.decodeIfPresent(DurationBasis.self, forKey: .durationBasis) ?? .typicalForLevel)
    }
}

/// The pacing card for a race (annex F).
public struct PacingCard: Codable, Hashable, Sendable {
    public var distance: RaceDistance
    public var targets: [PacingTarget]
    /// The distance scaled caveat that targets can be off on hilly or windy courses (B29).
    public var caveat: String

    public init(distance: RaceDistance, targets: [PacingTarget], caveat: String) {
        self.distance = distance
        self.targets = targets
        self.caveat = caveat
    }
}

/// Fueling tier keyed to expected leg duration (annex F "Fueling card").
public enum FuelingTier: String, Codable, Hashable, Sendable, CaseIterable {
    /// Under about 75 minutes: fluids to thirst only, no carbohydrate target.
    case fluidsOnly
    /// About 1.25 to 2.5 hours: roughly 30 g per hour scaling toward 60.
    case moderate
    /// Over 2.5 hours: 60 to 90 g per hour on the bike, 50 to 70 g per hour on the run.
    case high

    /// Tier for an expected duration in seconds (75 minutes and 150 minutes are the boundaries).
    public static func tier(forDurationSeconds seconds: Double) -> FuelingTier {
        if seconds < 75 * 60 { return .fluidsOnly }
        if seconds <= 150 * 60 { return .moderate }
        return .high
    }
}

/// Fueling advice for one leg (annex F).
public struct FuelingAdvice: Codable, Hashable, Sendable {
    public var leg: RaceLeg
    public var tier: FuelingTier
    /// Carbohydrate grams per hour. Nil for `.fluidsOnly`.
    public var carbsGramsPerHour: ValueRange?
    /// The practice in training line every tier carries.
    public var practiceLine: String
    /// The one sentence that exceeding what the duration needs mainly raises stomach trouble (B29).
    public var stomachLine: String

    public init(
        leg: RaceLeg,
        tier: FuelingTier,
        carbsGramsPerHour: ValueRange?,
        practiceLine: String,
        stomachLine: String
    ) {
        self.leg = leg
        self.tier = tier
        self.carbsGramsPerHour = carbsGramsPerHour
        self.practiceLine = practiceLine
        self.stomachLine = stomachLine
    }
}
