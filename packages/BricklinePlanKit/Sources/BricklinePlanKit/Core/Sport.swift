import Foundation

/// The three triathlon disciplines.
public enum Sport: String, Codable, Hashable, Sendable, CaseIterable {
    case swim
    case bike
    case run
}

/// One leg of a race with its distance in kilometres (spec section 5, annex F).
public struct RaceLeg: Codable, Hashable, Sendable {
    public var sport: Sport
    public var distanceKm: Double

    public init(sport: Sport, distanceKm: Double) {
        self.sport = sport
        self.distanceKm = distanceKm
    }
}

/// Template parameters per race distance. Implements annex B (table) and annex F (race window opening).
/// All ranges are inclusive and written from literals, so they cannot trap.
public struct DistanceParameters: Hashable, Sendable {
    /// Plan length in weeks (annex B "Plan length").
    public var planWeeks: ClosedRange<Int>
    /// Declared weekly hours the template supports (annex B "Weekly hours").
    public var weeklyHours: ClosedRange<Double>
    /// Sessions per week (annex B "Sessions per week").
    public var sessionsPerWeek: ClosedRange<Int>
    /// Swims per week (annex B "Swims per week").
    public var swimsPerWeek: ClosedRange<Int>
    /// Taper length in weeks (annex B "Taper").
    public var taperWeeks: ClosedRange<Int>
    /// Race window opens this many days before race day (annex F).
    public var windowOpensTMinusDays: Int

    public init(
        planWeeks: ClosedRange<Int>,
        weeklyHours: ClosedRange<Double>,
        sessionsPerWeek: ClosedRange<Int>,
        swimsPerWeek: ClosedRange<Int>,
        taperWeeks: ClosedRange<Int>,
        windowOpensTMinusDays: Int
    ) {
        self.planWeeks = planWeeks
        self.weeklyHours = weeklyHours
        self.sessionsPerWeek = sessionsPerWeek
        self.swimsPerWeek = swimsPerWeek
        self.taperWeeks = taperWeeks
        self.windowOpensTMinusDays = windowOpensTMinusDays
    }
}

/// Supported race distances (spec section 3.2). Full distance 140.6 is a non goal for 1.0.
public enum RaceDistance: String, Codable, Hashable, Sendable, CaseIterable {
    case sprint
    case olympic
    case half

    /// Short label for UI.
    public var displayName: String {
        switch self {
        case .sprint: return "Sprint"
        case .olympic: return "Olympic"
        case .half: return "70.3"
        }
    }

    /// Swim leg length in km.
    public var swimKm: Double {
        switch self {
        case .sprint: return 0.75
        case .olympic: return 1.5
        case .half: return 1.9
        }
    }

    /// Bike leg length in km.
    public var bikeKm: Double {
        switch self {
        case .sprint: return 20
        case .olympic: return 40
        case .half: return 90
        }
    }

    /// Run leg length in km.
    public var runKm: Double {
        switch self {
        case .sprint: return 5
        case .olympic: return 10
        case .half: return 21.1
        }
    }

    /// Ordered legs: swim, bike, run.
    public var legs: [RaceLeg] {
        [
            RaceLeg(sport: .swim, distanceKm: swimKm),
            RaceLeg(sport: .bike, distanceKm: bikeKm),
            RaceLeg(sport: .run, distanceKm: runKm)
        ]
    }

    /// Distance of the leg for a sport.
    public func distanceKm(for sport: Sport) -> Double {
        switch sport {
        case .swim: return swimKm
        case .bike: return bikeKm
        case .run: return runKm
        }
    }

    /// Annex B and annex F numbers for this distance.
    public var parameters: DistanceParameters {
        switch self {
        case .sprint:
            return DistanceParameters(
                planWeeks: 8...12, weeklyHours: 4...7, sessionsPerWeek: 4...6,
                swimsPerWeek: 1...2, taperWeeks: 1...1, windowOpensTMinusDays: 10)
        case .olympic:
            return DistanceParameters(
                planWeeks: 10...16, weeklyHours: 6...10, sessionsPerWeek: 5...7,
                swimsPerWeek: 2...2, taperWeeks: 1...2, windowOpensTMinusDays: 21)
        case .half:
            return DistanceParameters(
                planWeeks: 14...24, weeklyHours: 8...14, sessionsPerWeek: 6...9,
                swimsPerWeek: 2...3, taperWeeks: 2...3, windowOpensTMinusDays: 21)
        }
    }
}

/// Athlete experience level. Level changes session density and quality volume, never the safety rules (annex B).
public enum Level: String, Codable, Hashable, Sendable, CaseIterable {
    case firstTimer
    case intermediate
    case experienced

    /// Total quality sessions allowed per week (annex B "Intensity distribution": 2, 3, 4).
    public var maxQualityPerWeek: Int {
        switch self {
        case .firstTimer: return 2
        case .intermediate: return 3
        case .experienced: return 4
        }
    }

    /// At most this many quality sessions in any one sport per week (annex B).
    public static let maxQualityPerSport = 2
}

/// Training phase (annex B "Phase ratios").
public enum Phase: String, Codable, Hashable, Sendable, CaseIterable {
    case base
    case build
    case peak
    case taper
}

/// Role of a step inside a session.
public enum StepKind: String, Codable, Hashable, Sendable, CaseIterable {
    case warmUp
    case work
    case recovery
    case coolDown
}

/// Day of week. Raw values match Foundation's `Calendar.component(.weekday, ...)` (Sunday is 1).
public enum Weekday: Int, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    /// Weekday of a date in the given calendar. Falls back to Sunday if the calendar returns nonsense.
    public init(date: Date, calendar: Calendar) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
