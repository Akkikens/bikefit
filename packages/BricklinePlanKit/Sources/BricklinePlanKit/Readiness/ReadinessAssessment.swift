import Foundation

/// Why readiness is paused (annex C rules 9 and 13). While paused the rules do not change the plan.
public enum ReadinessPauseReason: String, Codable, Hashable, Sendable {
    /// Fewer than 3 valid nights in the latest 7 (rule 9).
    case tooFewRecentNights
    /// No sync for 48 hours (rule 13).
    case noRecentSync
    /// Three overrides in 14 days: notes only (rule 13).
    case notesOnly
    /// The race window is open: the taper lock wins (rules 7 and 13).
    case raceWindow
}

/// The headline state of readiness for the Today card and the Sources screen.
public enum ReadinessStatus: Codable, Hashable, Sendable {
    /// No device data. Check-ins may still be used.
    case noData
    /// Rule 9: "Learning your baseline, night N of 14".
    case calibrating(night: Int, of: Int)
    case paused(ReadinessPauseReason)
    /// The 7 night HRV is inside or above the usual range.
    case onTrack
    /// The 7 night HRV is below baseline minus 0.5 SD.
    case belowUsualRange
}

/// How one component compares with the athlete's usual.
public enum ReadinessLevel: String, Codable, Hashable, Sendable {
    case unavailable
    case usual
    case below
    case above
}

/// The unit of a component's numbers.
public enum ReadinessUnit: String, Codable, Hashable, Sendable {
    case milliseconds
    case beatsPerMinute
    case minutes
    /// A 1 to 5 check-in.
    case score
}

/// One line item of the readiness line.
public struct ReadinessComponent: Codable, Hashable, Sendable {
    public var level: ReadinessLevel
    /// Plain sentence, for example "HRV on track." Empty when `level` is `.unavailable`.
    public var text: String
    /// The number behind the sentence, for a Sources screen that shows "52 ms against your usual 61 ms": the 7 night
    /// HRV, last night's resting heart rate, last night's sleep in minutes or today's check-in. Nil when unavailable.
    public var value: Double?
    /// The athlete's usual for that number (baseline HRV or resting heart rate as a geometric mean, the sleep
    /// median). Nil when there is none.
    public var reference: Double?
    public var unit: ReadinessUnit?

    public init(
        level: ReadinessLevel = .unavailable, text: String = "",
        value: Double? = nil, reference: Double? = nil, unit: ReadinessUnit? = nil
    ) {
        self.level = level
        self.text = text
        self.value = value
        self.reference = reference
        self.unit = unit
    }

    public var isAvailable: Bool { level != .unavailable }
}

/// What the Today card and the Sources screen show about readiness. Built by `ReadinessRules`.
public struct ReadinessAssessment: Codable, Hashable, Sendable {
    public var status: ReadinessStatus
    /// The plain readiness line, for example "HRV on track. Resting heart rate normal. Sleep 7h 10m." or
    /// "Learning your baseline, night 9 of 14."
    public var line: String
    public var hrv: ReadinessComponent
    public var restingHeartRate: ReadinessComponent
    public var sleep: ReadinessComponent
    public var checkIn: ReadinessComponent
    /// The recovery source in use and why. Nil when there is no device source (check-ins only).
    public var source: SourceChoice?
    /// Calibration of that source. Nil when there is no device source.
    public var calibration: CalibrationState?
    /// The rule 12 note for today, when it applies. A note never changes the plan.
    public var sleepNote: String?
    /// True when a plan change is possible today: the gates are open, no guardrail is hit, today's one structural
    /// change is unspent and a hard session is still planned today.
    public var canChangePlanToday: Bool
    /// The gates and guardrails alone: true when readiness has room to change the plan today, whether or not a hard
    /// session is planned. A pending realignment prompt takes the room.
    public var hasRoomForChange: Bool
    /// The day the recovery source changed, when calibration restarted (annex C rule 9). The host stores it in
    /// `ReadinessInputs.sourceChangedOn`, with `source` in `ReadinessInputs.activeSource`.
    public var sourceChangedOn: Date?
    /// Plan changes from rules 10 to 12 in the rolling 7 days (at most 2, rule 13).
    public var planChangesInLast7Days: Int
    /// Distinct days with a Keep planned session tap in the last 14 days (3 means notes only, rule 13).
    public var overridesInLast14Days: Int
    /// True when no device source is in use and only check-ins can drive rule 11.
    public var usesCheckInsOnly: Bool

    public init(
        status: ReadinessStatus,
        line: String,
        hrv: ReadinessComponent = ReadinessComponent(),
        restingHeartRate: ReadinessComponent = ReadinessComponent(),
        sleep: ReadinessComponent = ReadinessComponent(),
        checkIn: ReadinessComponent = ReadinessComponent(),
        source: SourceChoice? = nil,
        calibration: CalibrationState? = nil,
        sleepNote: String? = nil,
        canChangePlanToday: Bool = false,
        hasRoomForChange: Bool = false,
        sourceChangedOn: Date? = nil,
        planChangesInLast7Days: Int = 0,
        overridesInLast14Days: Int = 0,
        usesCheckInsOnly: Bool = false
    ) {
        self.status = status
        self.line = line
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleep = sleep
        self.checkIn = checkIn
        self.source = source
        self.calibration = calibration
        self.sleepNote = sleepNote
        self.canChangePlanToday = canChangePlanToday
        self.hasRoomForChange = hasRoomForChange
        self.sourceChangedOn = sourceChangedOn
        self.planChangesInLast7Days = planChangesInLast7Days
        self.overridesInLast14Days = overridesInLast14Days
        self.usesCheckInsOnly = usesCheckInsOnly
    }
}

/// Output of a readiness run.
public struct ReadinessResult: Sendable {
    public var plan: Plan
    /// Newly fired events (rules 10 to 12). Those of rules 10 and 11 carry the data for Keep planned session; the
    /// rule 12 note carries none. Append them to the adaptation history.
    public var events: [AdaptationEvent]
    public var assessment: ReadinessAssessment

    public init(plan: Plan, events: [AdaptationEvent], assessment: ReadinessAssessment) {
        self.plan = plan
        self.events = events
        self.assessment = assessment
    }
}

/// What `ReadinessRules.keepPlannedSession` returns.
public struct KeepPlannedSessionResult: Sendable {
    /// The plan with the original sessions back on their days.
    public var plan: Plan
    /// The day of the tap. `AdaptationState.keepPlannedSession` records it in the log for you. A caller using the
    /// stateless function must keep it itself (`ReadinessInputs.recordingOverride(on:)`).
    public var overrideDay: Date

    public init(plan: Plan, overrideDay: Date) {
        self.plan = plan
        self.overrideDay = overrideDay
    }
}

/// All readiness copy in one place, so the copy scan (annex J) covers it. Sentences follow the annex style: one
/// sentence for the change, then the facts, never a cause, and none of the medical words on the annex J list.
enum ReadinessCopy {
    static let hrvBelowFact = "Your 7 night HRV is below your usual range."
    static let keepOriginal = "Tap to keep the original."
    static let keepOriginals = "Tap to keep the originals."

    /// "7h 10m", "7h", "45m". Whole minutes, rounded to the nearest.
    static func duration(minutes: Double) -> String {
        let total = Int(max(minutes, 0).rounded())
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// Gap in minutes rounded to the nearest `noteRoundingMinutes`, as a duration.
    static func roundedGap(minutes: Double) -> String {
        let step = ReadinessConstants.noteRoundingMinutes
        return duration(minutes: (max(minutes, 0) / step).rounded() * step)
    }

    static func sleepNote(sleepMinutes: Double, medianMinutes: Double) -> String {
        "Short night. Sleep was \(duration(minutes: sleepMinutes)), about \(roundedGap(minutes: medianMinutes - sleepMinutes)) under your usual."
    }

    /// Lower case noun for a session in a sentence: "threshold run", "brick".
    static func descriptor(_ session: Session) -> String {
        if session.brickSecondSport != nil { return "brick" }
        let head = session.name.split(separator: ":").first.map(String.init) ?? session.name
        return head.trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func article(before word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    static func pause(_ reason: ReadinessPauseReason) -> String {
        switch reason {
        case .tooFewRecentNights: return "Readiness is paused until you have 3 nights of data in a week."
        case .noRecentSync: return "Readiness is paused. Your device has not synced in 48 hours."
        case .notesOnly: return "Readiness shows notes only for now. You kept your planned session 3 times lately."
        case .raceWindow: return "Race window: the plan holds steady on purpose."
        }
    }
}
