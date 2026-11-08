import Foundation

// Platform neutral intermediate representation of a watch workout (annex E). The WorkoutKit bridge in
// Compile/ converts these values to WorkoutKit types inside `#if canImport(WorkoutKit)`. Tests run on this
// representation alone, so nothing here imports WorkoutKit.

/// Where an activity takes place.
public enum CompiledLocation: String, Codable, Hashable, Sendable {
    case pool
    case indoor
    case outdoor
    case unspecified
}

/// Sport plus location, the unit WorkoutKit supports checks key on (annex E "Alerts", B12).
public struct CompiledActivity: Codable, Hashable, Sendable {
    public var sport: Sport
    public var location: CompiledLocation

    public init(sport: Sport, location: CompiledLocation) {
        self.sport = sport
        self.location = location
    }
}

/// Step goal (annex E "Goals"). Energy goals are not supported in custom workouts.
public enum CompiledGoal: Codable, Hashable, Sendable {
    case open
    case time(seconds: Double)
    case distance(meters: Double)
    /// Pool swim goal, which carries the CSS pace target (annex E, iOS 18 and watchOS 11).
    case distanceWithTime(meters: Double, seconds: Double)
}

/// Alert descriptor. Always an explicit range, never a zone alert (annex E "Alerts").
public enum CompiledAlert: Codable, Hashable, Sendable {
    case none
    /// Metres per second. Run pace is inverted to speed.
    case speedRange(ValueRange)
    /// Watts.
    case powerRange(ValueRange)
    /// Beats per minute.
    case heartRateRange(ValueRange)
}

/// One step of a compiled workout.
public struct CompiledStep: Codable, Hashable, Sendable {
    /// Work or recovery for interval steps; warm up and cool down steps are held separately.
    public var kind: StepKind
    public var displayName: String
    public var goal: CompiledGoal
    public var alert: CompiledAlert
    /// RPE description so the step is executable by feel (annex A).
    public var rpeText: String?
    /// Set when a requested goal or alert was dropped because the device does not support it
    /// (annex E "Alerts": the step then ships with goal only).
    public var limitation: String?

    public init(
        kind: StepKind,
        displayName: String,
        goal: CompiledGoal,
        alert: CompiledAlert = .none,
        rpeText: String? = nil,
        limitation: String? = nil
    ) {
        self.kind = kind
        self.displayName = displayName
        self.goal = goal
        self.alert = alert
        self.rpeText = rpeText
        self.limitation = limitation
    }
}

/// An interval block: its steps repeat `iterations` times.
public struct CompiledBlock: Codable, Hashable, Sendable {
    public var iterations: Int
    public var steps: [CompiledStep]

    public init(iterations: Int, steps: [CompiledStep]) {
        self.iterations = max(iterations, 1)
        self.steps = steps
    }
}

/// Warm up, interval blocks, cool down (annex E "Each planned session compiles to a CustomWorkout").
public struct CompiledCustomWorkout: Codable, Hashable, Sendable {
    public var activity: CompiledActivity
    public var displayName: String
    public var warmUp: CompiledStep?
    public var blocks: [CompiledBlock]
    public var coolDown: CompiledStep?

    public init(
        activity: CompiledActivity,
        displayName: String,
        warmUp: CompiledStep? = nil,
        blocks: [CompiledBlock] = [],
        coolDown: CompiledStep? = nil
    ) {
        self.activity = activity
        self.displayName = displayName
        self.warmUp = warmUp
        self.blocks = blocks
        self.coolDown = coolDown
    }
}

/// One goal for the whole workout, used by the older watch tier for pool swims (annex E tier 2).
public struct CompiledSingleGoalWorkout: Codable, Hashable, Sendable {
    public var activity: CompiledActivity
    public var displayName: String
    public var goal: CompiledGoal

    public init(activity: CompiledActivity, displayName: String, goal: CompiledGoal) {
        self.activity = activity
        self.displayName = displayName
        self.goal = goal
    }
}

/// One leg of a multisport workout with an open goal (annex E "Race day").
public struct CompiledLeg: Codable, Hashable, Sendable {
    public var activity: CompiledActivity
    public var goal: CompiledGoal

    public init(activity: CompiledActivity, goal: CompiledGoal = .open) {
        self.activity = activity
        self.goal = goal
    }
}

/// Ordered legs, open goals, automatic transitions (annex E "Race day").
public struct CompiledSwimBikeRunWorkout: Codable, Hashable, Sendable {
    public var displayName: String
    public var legs: [CompiledLeg]

    public init(displayName: String, legs: [CompiledLeg]) {
        self.displayName = displayName
        self.legs = legs
    }
}

/// The compiled workout intermediate (annex E).
public enum CompiledWorkout: Codable, Hashable, Sendable {
    case custom(CompiledCustomWorkout)
    case singleGoal(CompiledSingleGoalWorkout)
    case swimBikeRun(CompiledSwimBikeRunWorkout)

    public var displayName: String {
        switch self {
        case .custom(let workout): return workout.displayName
        case .singleGoal(let workout): return workout.displayName
        case .swimBikeRun(let workout): return workout.displayName
        }
    }
}

/// Result of compiling one session. A brick compiles to two custom workouts in order (bike then run),
/// because per leg intervals are not expressible in a multisport workout (spec section 4.1).
public struct CompiledSession: Codable, Hashable, Sendable {
    public var sessionID: String
    public var workouts: [CompiledWorkout]
    /// Plain lines for the session card about what the watch will and will not show (annex E).
    public var notes: [String]
    /// True when the session must be shown as a printed set card on the phone and run by the phone player
    /// (annex E tier 2 fallback and tier 3).
    public var usesPhoneSetCard: Bool

    public init(sessionID: String, workouts: [CompiledWorkout], notes: [String] = [], usesPhoneSetCard: Bool = false) {
        self.sessionID = sessionID
        self.workouts = workouts
        self.notes = notes
        self.usesPhoneSetCard = usesPhoneSetCard
    }
}

/// Capability tiers (annex E "Capability tiers"). Tiers are keyed by supports checks plus an explicit setting,
/// never by version sniffing.
public enum WatchTier: String, Codable, Hashable, Sendable, CaseIterable {
    /// Assumes the watchOS 11 feature set, each goal and alert gated by supports checks.
    case standard
    /// "My watch runs watchOS 10": pool swims as a goal only attempt or the phone set card.
    case olderWatch
    /// No watch, unpaired, or authorization denied: the phone player leads.
    case noWatch
}

/// Results of the runtime supports checks (annex E, B12), supplied by the app so the compiler stays pure.
public struct DeviceCapabilities: Codable, Hashable, Sendable {
    public var tier: WatchTier
    public var supportsRunSpeedAlert: Bool
    /// Outdoor run power range alerts only (annex E).
    public var supportsRunPowerAlertOutdoor: Bool
    public var supportsBikePowerAlert: Bool
    public var supportsBikeHeartRateAlert: Bool
    public var supportsSwimHeartRateAlert: Bool
    public var supportsPoolSwimDistanceWithTimeGoal: Bool
    public var supportsStepDisplayNames: Bool

    public init(
        tier: WatchTier = .standard,
        supportsRunSpeedAlert: Bool = true,
        supportsRunPowerAlertOutdoor: Bool = true,
        supportsBikePowerAlert: Bool = true,
        supportsBikeHeartRateAlert: Bool = true,
        supportsSwimHeartRateAlert: Bool = true,
        supportsPoolSwimDistanceWithTimeGoal: Bool = true,
        supportsStepDisplayNames: Bool = true
    ) {
        self.tier = tier
        self.supportsRunSpeedAlert = supportsRunSpeedAlert
        self.supportsRunPowerAlertOutdoor = supportsRunPowerAlertOutdoor
        self.supportsBikePowerAlert = supportsBikePowerAlert
        self.supportsBikeHeartRateAlert = supportsBikeHeartRateAlert
        self.supportsSwimHeartRateAlert = supportsSwimHeartRateAlert
        self.supportsPoolSwimDistanceWithTimeGoal = supportsPoolSwimDistanceWithTimeGoal
        self.supportsStepDisplayNames = supportsStepDisplayNames
    }

    /// Every check passes, watchOS 11 feature set.
    public static let standard = DeviceCapabilities()

    /// Older watch tier: no pool distance with time goal, no step names.
    public static let olderWatch = DeviceCapabilities(
        tier: .olderWatch,
        supportsPoolSwimDistanceWithTimeGoal: false,
        supportsStepDisplayNames: false)

    /// No usable watch: everything off.
    public static let noWatch = DeviceCapabilities(
        tier: .noWatch,
        supportsRunSpeedAlert: false,
        supportsRunPowerAlertOutdoor: false,
        supportsBikePowerAlert: false,
        supportsBikeHeartRateAlert: false,
        supportsSwimHeartRateAlert: false,
        supportsPoolSwimDistanceWithTimeGoal: false,
        supportsStepDisplayNames: false)
}
