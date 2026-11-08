import Foundation

/// What a step asks of the athlete. Templates emit `rpe` (and `cssOffset` for swims); the session compiler
/// resolves the concrete pace, speed, power or heart rate range from `Step.level` plus the current benchmarks
/// through `ZoneCalculator.resolveTarget`, so zone nudges (annex C rule 3) never rewrite stored sessions.
/// Units: pace in seconds per km, speed in metres per second, power in watts, heart rate in bpm,
/// css offset in seconds per 100 m relative to CSS, rpe on the 1 to 10 scale.
public enum StepTarget: Codable, Hashable, Sendable {
    case pacePerKm(ValueRange)
    case speedRange(ValueRange)
    case powerRange(ValueRange)
    case heartRateRange(ValueRange)
    case cssOffset(ValueRange)
    /// Swim pace in seconds per 100 m (absolute, not an offset from CSS). Keeps swim paces out of the run pace
    /// case so the unit is never guessed.
    case pacePer100m(ValueRange)
    case rpe(ValueRange)
    case none
}

/// One step of a session.
///
/// Repeat groups: steps that share a non nil `repeatGroupID` are stored once, contiguously and in order,
/// and each carries the same `repeatCount`. The group runs `repeatCount` times. Durations and distances in
/// `Session` totals multiply by `repeats`.
public struct Step: Codable, Hashable, Sendable {
    public var sport: Sport
    public var kind: StepKind
    public var durationSeconds: Double
    public var distanceMeters: Double?
    /// Intensity level 1 to 5 (see `IntensityLevel`). The initializer clamps it.
    public var level: Int
    public var target: StepTarget
    public var repeatGroupID: String?
    public var repeatCount: Int?
    /// Display name shown on the watch and the session card (iOS 18, watchOS 11 step names).
    public var name: String
    /// Optional cue or RPE description. Every step should be executable by feel alone (annex A).
    public var note: String?

    public init(
        sport: Sport,
        kind: StepKind,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        level: Int,
        target: StepTarget = .none,
        repeatGroupID: String? = nil,
        repeatCount: Int? = nil,
        name: String,
        note: String? = nil
    ) {
        self.sport = sport
        self.kind = kind
        self.durationSeconds = durationSeconds.isFinite ? max(durationSeconds, 0) : 0
        self.distanceMeters = distanceMeters.map { $0.isFinite ? max($0, 0) : 0 }
        self.level = IntensityLevel.clamped(level)
        self.target = target
        self.repeatGroupID = repeatGroupID
        self.repeatCount = repeatCount
        self.name = name
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case sport, kind, durationSeconds, distanceMeters, level, target, repeatGroupID, repeatCount, name, note
    }

    /// Decoding goes through the clamping initializer, so a stored or shared step can never carry a negative
    /// duration or an out of range level.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sport: try c.decode(Sport.self, forKey: .sport),
            kind: try c.decode(StepKind.self, forKey: .kind),
            durationSeconds: try c.decode(Double.self, forKey: .durationSeconds),
            distanceMeters: try c.decodeIfPresent(Double.self, forKey: .distanceMeters),
            level: try c.decode(Int.self, forKey: .level),
            target: try c.decodeIfPresent(StepTarget.self, forKey: .target) ?? StepTarget.none,
            repeatGroupID: try c.decodeIfPresent(String.self, forKey: .repeatGroupID),
            repeatCount: try c.decodeIfPresent(Int.self, forKey: .repeatCount),
            name: try c.decode(String.self, forKey: .name),
            note: try c.decodeIfPresent(String.self, forKey: .note))
    }

    /// How many times this step runs: the group's repeat count, at least 1.
    public var repeats: Int {
        guard repeatGroupID != nil else { return 1 }
        return max(repeatCount ?? 1, 1)
    }
}

/// Lifecycle of a planned session.
public enum SessionState: String, Codable, Hashable, Sendable, CaseIterable {
    case planned
    case done
    case skipped
}

/// A planned unit of training (spec section 3.2). A workout is what was recorded; a session is what was planned.
public struct Session: Codable, Hashable, Sendable {
    /// Deterministic id, see `SessionID.make`.
    public var id: String
    public var sport: Sport
    public var name: String
    /// One sentence on why the session exists.
    public var purpose: String
    public var steps: [Step]
    public var state: SessionState
    /// Start of the scheduled day in the plan's calendar.
    public var scheduledDate: Date
    /// For a brick: the sport of the second part (the transition run). The first part is `sport`;
    /// steps of the second part carry that sport.
    public var brickSecondSport: Sport?
    /// Counts toward the weekly quality caps (annex B).
    public var isQuality: Bool
    /// A maximal effort test session (annex A retest rotation).
    public var isTest: Bool
    public var benchmarkKind: BenchmarkKind?
    /// Open water session. Open water is never required, so such a session also carries
    /// `poolAlternativeSteps` (spec section 3.2, annex E).
    public var isOpenWater: Bool
    public var poolAlternativeSteps: [Step]

    public init(
        id: String,
        sport: Sport,
        name: String,
        purpose: String,
        steps: [Step],
        state: SessionState = .planned,
        scheduledDate: Date,
        brickSecondSport: Sport? = nil,
        isQuality: Bool = false,
        isTest: Bool = false,
        benchmarkKind: BenchmarkKind? = nil,
        isOpenWater: Bool = false,
        poolAlternativeSteps: [Step] = []
    ) {
        self.id = id
        self.sport = sport
        self.name = name
        self.purpose = purpose
        self.steps = steps
        self.state = state
        self.scheduledDate = scheduledDate
        self.brickSecondSport = brickSecondSport
        self.isQuality = isQuality
        self.isTest = isTest
        self.benchmarkKind = benchmarkKind
        self.isOpenWater = isOpenWater
        self.poolAlternativeSteps = poolAlternativeSteps
    }

    /// Planned duration with repeat groups expanded, in seconds.
    public var durationSeconds: Double {
        steps.reduce(0) { $0 + $1.durationSeconds * Double($1.repeats) }
    }

    /// Planned distance with repeat groups expanded, in metres, counting only steps that state a distance.
    public var distanceMeters: Double {
        steps.reduce(0) { $0 + ($1.distanceMeters ?? 0) * Double($1.repeats) }
    }

    public var durationHours: Double { durationSeconds / 3600 }
}

extension Session: Identifiable {}

/// One training week (annex B "Microcycle assembly").
public struct PlannedWeek: Codable, Hashable, Sendable, Identifiable {
    /// Zero based week index within the plan.
    public var index: Int
    /// First day of this week: `Plan.startDate` plus 7 times `index` days.
    public var startDate: Date
    public var phase: Phase
    /// Recovery week, 30 to 40 percent below average volume (annex B).
    public var isRecovery: Bool
    /// Test week on a 4 week block boundary (annex A).
    public var isTest: Bool
    /// Sessions keyed by start of day.
    public var days: [Date: [Session]]
    public var plannedHours: Double
    /// The hours the template designed for this week, set at generation. Annex C rule 5 exempts a peak or taper
    /// week from the cap only while its hours still equal the design, so an athlete edited peak week is policed.
    /// Nil on weeks that carry no design (hand built weeks), which keeps the phase based exemption.
    public var designedHours: Double?
    /// Set by annex C rule 6 ("flag the week") when the load spike caution fired; cleared when the week passes.
    public var cautionFlag: Bool

    public init(
        index: Int,
        startDate: Date,
        phase: Phase,
        isRecovery: Bool = false,
        isTest: Bool = false,
        days: [Date: [Session]] = [:],
        plannedHours: Double = 0,
        designedHours: Double? = nil,
        cautionFlag: Bool = false
    ) {
        self.index = index
        self.startDate = startDate
        self.phase = phase
        self.isRecovery = isRecovery
        self.isTest = isTest
        self.days = days
        self.plannedHours = plannedHours
        self.designedHours = designedHours
        self.cautionFlag = cautionFlag
    }

    private enum CodingKeys: String, CodingKey {
        case index, startDate, phase, isRecovery, isTest, days, plannedHours, designedHours, cautionFlag
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            index: try c.decode(Int.self, forKey: .index),
            startDate: try c.decode(Date.self, forKey: .startDate),
            phase: try c.decode(Phase.self, forKey: .phase),
            isRecovery: try c.decodeIfPresent(Bool.self, forKey: .isRecovery) ?? false,
            isTest: try c.decodeIfPresent(Bool.self, forKey: .isTest) ?? false,
            days: try c.decodeIfPresent([Date: [Session]].self, forKey: .days) ?? [:],
            plannedHours: try c.decodeIfPresent(Double.self, forKey: .plannedHours) ?? 0,
            designedHours: try c.decodeIfPresent(Double.self, forKey: .designedHours),
            cautionFlag: try c.decodeIfPresent(Bool.self, forKey: .cautionFlag) ?? false)
    }

    /// Identity for SwiftUI lists: the zero based week index.
    public var id: Int { index }

    /// All sessions sorted by date, then id.
    public var sessions: [Session] {
        days.values.flatMap { $0 }.sorted {
            if $0.scheduledDate != $1.scheduledDate { return $0.scheduledDate < $1.scheduledDate }
            return $0.id < $1.id
        }
    }
}

/// A full training plan.
public struct Plan: Codable, Hashable, Sendable {
    /// Schema version of this type, bumped when the stored shape changes.
    public var version: Int
    /// Nil in "no race yet" mode, a rolling 4 week base block (annex B).
    public var raceDistance: RaceDistance?
    public var raceDate: Date?
    /// First day of week 0.
    public var startDate: Date
    public var weeks: [PlannedWeek]
    /// Snapshot of the profile the plan was built from.
    public var athlete: AthleteProfile
    /// Net zone nudge steps applied per sport by annex C rule 3, in units of one step (about 2 percent each).
    /// Positive means zones moved harder (faster, more power). The compiler passes this to the zone resolver.
    public var zoneNudgeSteps: [Sport: Int]
    /// Per sport, the date of the tested benchmark a nudge was measured against. A nudge older than the sport's
    /// latest test is dropped, because the new benchmark already holds the improvement (annex C rule 3).
    public var zoneNudgeBaselineDates: [Sport: Date]
    /// Identifier of the time zone the plan was generated in. Engines read days in this zone whatever the device
    /// zone is now, so travelling never shifts a session to another day. Nil on hand built plans.
    public var timeZoneIdentifier: String?
    /// Things the generator changed from what the athlete asked for, for the plan preview.
    public var warnings: [PlanWarning]

    public static let currentVersion = 1

    public init(
        version: Int = Plan.currentVersion,
        raceDistance: RaceDistance?,
        raceDate: Date?,
        startDate: Date,
        weeks: [PlannedWeek],
        athlete: AthleteProfile,
        zoneNudgeSteps: [Sport: Int] = [:],
        zoneNudgeBaselineDates: [Sport: Date] = [:],
        timeZoneIdentifier: String? = nil,
        warnings: [PlanWarning] = []
    ) {
        self.version = version
        self.raceDistance = raceDistance
        self.raceDate = raceDate
        self.startDate = startDate
        self.weeks = weeks
        self.athlete = athlete
        self.zoneNudgeSteps = zoneNudgeSteps
        self.zoneNudgeBaselineDates = zoneNudgeBaselineDates
        self.timeZoneIdentifier = timeZoneIdentifier
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case version, raceDistance, raceDate, startDate, weeks, athlete, zoneNudgeSteps
        case zoneNudgeBaselineDates, timeZoneIdentifier, warnings
    }

    /// Decodes a stored plan. A plan saved by a newer version of the app is refused with a readable error
    /// instead of being half understood (annex G).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try c.decode(Int.self, forKey: .version)
        guard stored <= Plan.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: c,
                debugDescription: "This plan was saved by a newer version of the app. Update the app to open it.")
        }
        self.init(
            version: stored,
            raceDistance: try c.decodeIfPresent(RaceDistance.self, forKey: .raceDistance),
            raceDate: try c.decodeIfPresent(Date.self, forKey: .raceDate),
            startDate: try c.decode(Date.self, forKey: .startDate),
            weeks: try c.decode([PlannedWeek].self, forKey: .weeks),
            athlete: try c.decode(AthleteProfile.self, forKey: .athlete),
            zoneNudgeSteps: try c.decodeIfPresent([Sport: Int].self, forKey: .zoneNudgeSteps) ?? [:],
            zoneNudgeBaselineDates: try c.decodeIfPresent([Sport: Date].self, forKey: .zoneNudgeBaselineDates) ?? [:],
            timeZoneIdentifier: try c.decodeIfPresent(String.self, forKey: .timeZoneIdentifier),
            warnings: try c.decodeIfPresent([PlanWarning].self, forKey: .warnings) ?? [])
    }

    /// `calendar` moved into the plan's own time zone, when the plan recorded one. Every engine entry point reads
    /// days through this, so a device time zone change never moves a session (annex G, travel races).
    public func resolvedCalendar(_ calendar: Calendar) -> Calendar {
        guard let id = timeZoneIdentifier, let zone = TimeZone(identifier: id), zone != calendar.timeZone else {
            return calendar
        }
        var adjusted = calendar
        adjusted.timeZone = zone
        return adjusted
    }

    /// Zone nudges that still apply to `benchmarks`: a nudge measured against an older tested benchmark than the
    /// current one is ignored (annex C rule 3). Use this wherever nudges feed a zone calculation.
    public func effectiveZoneNudgeSteps(benchmarks: Benchmarks) -> [Sport: Int] {
        var result = zoneNudgeSteps
        for sport in zoneNudgeSteps.keys where isNudgeStale(sport, benchmarks: benchmarks) {
            result[sport] = nil
        }
        return result
    }

    /// The plan with stale nudges removed and missing baselines recorded. Call after a benchmark test lands.
    public func normalizingNudges(benchmarks: Benchmarks) -> Plan {
        var copy = self
        for sport in zoneNudgeSteps.keys {
            if isNudgeStale(sport, benchmarks: benchmarks) {
                copy.zoneNudgeSteps[sport] = nil
                copy.zoneNudgeBaselineDates[sport] = nil
            } else if copy.zoneNudgeBaselineDates[sport] == nil, let last = benchmarks.lastTestDate(for: sport) {
                copy.zoneNudgeBaselineDates[sport] = last
            }
        }
        for sport in zoneNudgeBaselineDates.keys where copy.zoneNudgeSteps[sport] == nil {
            copy.zoneNudgeBaselineDates[sport] = nil
        }
        return copy
    }

    /// The plan with one sport's zone nudge cleared. The host calls this when the athlete resets a benchmark by
    /// hand.
    public func resettingNudge(for sport: Sport) -> Plan {
        var copy = self
        copy.zoneNudgeSteps[sport] = nil
        copy.zoneNudgeBaselineDates[sport] = nil
        return copy
    }

    private func isNudgeStale(_ sport: Sport, benchmarks: Benchmarks) -> Bool {
        guard let baseline = zoneNudgeBaselineDates[sport], let latest = benchmarks.lastTestDate(for: sport) else {
            return false
        }
        return latest > baseline
    }

    /// Every session of every week sorted by date, then id.
    public var allSessions: [Session] {
        weeks.flatMap { $0.sessions }.sorted {
            if $0.scheduledDate != $1.scheduledDate { return $0.scheduledDate < $1.scheduledDate }
            return $0.id < $1.id
        }
    }

    public func session(withID id: String) -> Session? {
        for week in weeks {
            for list in week.days.values {
                if let found = list.first(where: { $0.id == id }) { return found }
            }
        }
        return nil
    }

    /// Index of the week whose seven day window contains `date`, or nil when outside the plan.
    public func weekIndex(containing date: Date, calendar: Calendar) -> Int? {
        let offset = calendar.daysBetween(startDate, date)
        guard offset >= 0 else { return nil }
        let index = offset / 7
        return index < weeks.count ? index : nil
    }

    /// Edits one session in place. The transform must not change `scheduledDate` (the day key would go stale);
    /// to move a session, rebuild the week's `days`. Returns false when the id is unknown.
    @discardableResult
    public mutating func updateSession(id: String, _ transform: (inout Session) -> Void) -> Bool {
        for weekPosition in weeks.indices {
            let snapshot = weeks[weekPosition].days
            for (day, list) in snapshot {
                if let position = list.firstIndex(where: { $0.id == id }) {
                    var edited = list[position]
                    transform(&edited)
                    weeks[weekPosition].days[day]?[position] = edited
                    return true
                }
            }
        }
        return false
    }
}

/// Something the generator changed from what the athlete asked for. Shown on the plan preview.
public enum PlanWarning: Codable, Hashable, Sendable {
    /// Declared hours were above what the template supports, so the plan assumes `used` hours a week.
    case hoursClampedToMaximum(used: Double)
    /// Declared hours are under the published range for the distance, so the plan may feel tight.
    case hoursBelowPublishedRange(distance: RaceDistance)
    /// Peak weeks run above the declared average (annex B, 20 to 30 percent above).
    case peakExceedsDeclared(peakHours: Double)
    /// A session could not be placed on the declared days and was left out.
    case sessionDropped(weekIndex: Int, name: String)
    /// A recovery week had to lose a session to stay clearly lighter than the load week before it.
    case recoveryWeekTrimmed(weekIndex: Int, name: String)
    /// A hard session became an easy one because the declared days could not keep hard days apart.
    case qualityEased(weekIndex: Int, name: String)

    /// Calm one line for the plan preview. No dashes.
    public var message: String {
        switch self {
        case let .hoursClampedToMaximum(used):
            return "This plan assumes \(Int(used.rounded())) hours a week, the most the template supports."
        case let .hoursBelowPublishedRange(distance):
            return "That is under the usual weekly hours for a \(distance.displayName), so the plan keeps sessions short."
        case let .peakExceedsDeclared(peak):
            return "Your peak weeks reach about \(String(format: "%.1f", peak)) hours, above your weekly average."
        case let .sessionDropped(week, name):
            return "Week \(week + 1) leaves out \(name) because your available days could not fit it."
        case let .recoveryWeekTrimmed(week, name):
            return "Week \(week + 1) drops \(name) so the recovery week stays light."
        case let .qualityEased(week, name):
            return "Week \(week + 1) makes \(name) an easy session because your available days could not keep hard days apart."
        }
    }
}
