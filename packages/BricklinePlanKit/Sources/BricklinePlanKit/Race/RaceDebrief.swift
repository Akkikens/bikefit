import Foundation

// Core has no debrief types, so they live here (annex F "Debrief"). They are plain value types so the app
// can map a HealthKit multisport workout onto `RaceActuals` outside this package.

/// Actual leg and transition durations from the finished race, in seconds. Nil means not recorded.
public struct RaceActuals: Codable, Hashable, Sendable {
    public var swimSeconds: Double?
    public var transition1Seconds: Double?
    public var bikeSeconds: Double?
    public var transition2Seconds: Double?
    public var runSeconds: Double?

    public init(
        swimSeconds: Double? = nil,
        transition1Seconds: Double? = nil,
        bikeSeconds: Double? = nil,
        transition2Seconds: Double? = nil,
        runSeconds: Double? = nil
    ) {
        self.swimSeconds = swimSeconds
        self.transition1Seconds = transition1Seconds
        self.bikeSeconds = bikeSeconds
        self.transition2Seconds = transition2Seconds
        self.runSeconds = runSeconds
    }

    func legSeconds(_ sport: Sport) -> Double? {
        switch sport {
        case .swim: return swimSeconds
        case .bike: return bikeSeconds
        case .run: return runSeconds
        }
    }
}

/// How an actual leg time compares with the planned range.
public enum LegDeviation: String, Codable, Hashable, Sendable, CaseIterable {
    case faster
    case within
    case slower
    case notRecorded
    /// The planned time is only a typical value for the athlete's level, so there is no plan to compare with.
    /// The actual time is shown without a faster or slower verdict.
    case noPlan
}

/// Planned versus actual for one leg.
public struct LegDebrief: Codable, Hashable, Sendable {
    public var leg: RaceLeg
    public var plannedSeconds: ValueRange
    public var actualSeconds: Double?
    public var deviation: LegDeviation
    /// Seconds outside the planned range: negative when faster than its lower bound, positive when slower than
    /// its upper bound, zero when inside or not recorded.
    public var deltaSeconds: Double
    public var line: String

    public init(leg: RaceLeg, plannedSeconds: ValueRange, actualSeconds: Double?, deviation: LegDeviation, deltaSeconds: Double, line: String) {
        self.leg = leg
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.deviation = deviation
        self.deltaSeconds = deltaSeconds
        self.line = line
    }
}

/// An actual transition time. Transitions have no planned value, so they are reported on their own.
public struct TransitionDebrief: Codable, Hashable, Sendable {
    public var name: String
    public var seconds: Double?
    public var line: String

    public init(name: String, seconds: Double?, line: String) {
        self.name = name
        self.seconds = seconds
        self.line = line
    }
}

/// The debrief comparison (annex F "Debrief"). The two prompts and the next race picker are shown by the app.
public struct RaceDebrief: Codable, Hashable, Sendable {
    public var distance: RaceDistance
    public var legs: [LegDebrief]
    public var transitions: [TransitionDebrief]
    /// Sum of the planned leg ranges, transitions excluded.
    public var plannedLegsTotalSeconds: ValueRange
    /// Sum of the recorded legs, or nil when any leg was not recorded.
    public var actualLegsTotalSeconds: Double?
    /// Everything recorded: legs plus transitions.
    public var totalRecordedSeconds: Double
    public var summaryLine: String
    public var prompts: [String]

    public init(
        distance: RaceDistance,
        legs: [LegDebrief],
        transitions: [TransitionDebrief],
        plannedLegsTotalSeconds: ValueRange,
        actualLegsTotalSeconds: Double?,
        totalRecordedSeconds: Double,
        summaryLine: String,
        prompts: [String]
    ) {
        self.distance = distance
        self.legs = legs
        self.transitions = transitions
        self.plannedLegsTotalSeconds = plannedLegsTotalSeconds
        self.actualLegsTotalSeconds = actualLegsTotalSeconds
        self.totalRecordedSeconds = totalRecordedSeconds
        self.summaryLine = summaryLine
        self.prompts = prompts
    }
}

extension DefaultRaceWindow {
    /// Annex F "Debrief": per leg planned versus actual, transitions included, with calm wording and the two
    /// prompts. A leg time that is missing, not finite or not positive reads as not recorded.
    public func debrief(card: PacingCard, actuals: RaceActuals) -> RaceDebrief {
        var legRows: [LegDebrief] = []
        var plannedLower = 0.0
        var plannedUpper = 0.0
        var recordedLegs = 0.0
        var allLegsRecorded = true
        var anyTypical = false

        for target in card.targets {
            let planned = target.expectedDurationSeconds
            plannedLower += planned.lower
            plannedUpper += planned.upper
            let name = Self.legName(target.leg.sport)
            let plannedText = "\(RaceFormat.duration(planned.lower)) to \(RaceFormat.duration(planned.upper))"

            guard let actual = Self.validSeconds(actuals.legSeconds(target.leg.sport)) else {
                allLegsRecorded = false
                legRows.append(LegDebrief(
                    leg: target.leg, plannedSeconds: planned, actualSeconds: nil, deviation: .notRecorded, deltaSeconds: 0,
                    line: "\(name): no time recorded. Planned \(plannedText)."))
                continue
            }
            recordedLegs += actual

            if target.durationBasis == .typicalForLevel {
                anyTypical = true
                legRows.append(LegDebrief(
                    leg: target.leg, plannedSeconds: planned, actualSeconds: actual, deviation: .noPlan, deltaSeconds: 0,
                    line: "\(name): \(RaceFormat.duration(actual)). A typical time for your level is \(plannedText), so there was no plan of your own to compare with."))
            } else if actual < planned.lower {
                let delta = actual - planned.lower
                legRows.append(LegDebrief(
                    leg: target.leg, plannedSeconds: planned, actualSeconds: actual, deviation: .faster, deltaSeconds: delta,
                    line: "\(name): \(RaceFormat.duration(actual)), \(RaceFormat.duration(-delta)) faster than your planned \(plannedText)."))
            } else if actual > planned.upper {
                let delta = actual - planned.upper
                legRows.append(LegDebrief(
                    leg: target.leg, plannedSeconds: planned, actualSeconds: actual, deviation: .slower, deltaSeconds: delta,
                    line: "\(name): \(RaceFormat.duration(actual)), \(RaceFormat.duration(delta)) slower than your planned \(plannedText)."))
            } else {
                legRows.append(LegDebrief(
                    leg: target.leg, plannedSeconds: planned, actualSeconds: actual, deviation: .within, deltaSeconds: 0,
                    line: "\(name): \(RaceFormat.duration(actual)), inside your planned \(plannedText)."))
            }
        }

        let t1 = Self.validSeconds(actuals.transition1Seconds)
        let t2 = Self.validSeconds(actuals.transition2Seconds)
        let transitions = [
            Self.transitionRow(name: "First transition", seconds: t1),
            Self.transitionRow(name: "Second transition", seconds: t2)
        ]
        let recordedTotal = recordedLegs + (t1 ?? 0) + (t2 ?? 0)
        let plannedTotal = ValueRange(plannedLower, plannedUpper)
        let actualLegsTotal: Double? = allLegsRecorded && !legRows.isEmpty ? recordedLegs : nil

        let summary: String
        if let actualLegsTotal {
            let against = anyTypical ? "against typical times for your level of" : "against a plan of"
            summary = "Total \(RaceFormat.duration(recordedTotal)) with transitions. Your legs added up to \(RaceFormat.duration(actualLegsTotal)) \(against) \(RaceFormat.duration(plannedTotal.lower)) to \(RaceFormat.duration(plannedTotal.upper))."
        } else if recordedTotal > 0 {
            summary = "Recorded \(RaceFormat.duration(recordedTotal)) so far. Some legs have no time, so the totals are partial."
        } else {
            summary = "No times were recorded for this race."
        }

        return RaceDebrief(
            distance: card.distance,
            legs: legRows,
            transitions: transitions,
            plannedLegsTotalSeconds: plannedTotal,
            actualLegsTotalSeconds: actualLegsTotal,
            totalRecordedSeconds: recordedTotal,
            summaryLine: summary,
            prompts: RaceWindowCopy.debriefPrompts)
    }

    private static func validSeconds(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    private static func legName(_ sport: Sport) -> String {
        switch sport {
        case .swim: return "Swim"
        case .bike: return "Bike"
        case .run: return "Run"
        }
    }

    private static func transitionRow(name: String, seconds: Double?) -> TransitionDebrief {
        guard let seconds else {
            return TransitionDebrief(name: name, seconds: nil, line: "\(name): no time recorded.")
        }
        return TransitionDebrief(name: name, seconds: seconds, line: "\(name): \(RaceFormat.duration(seconds)).")
    }
}
