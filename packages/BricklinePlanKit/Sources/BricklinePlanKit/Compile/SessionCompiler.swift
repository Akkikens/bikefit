import Foundation

/// Compiles planned sessions to the platform neutral workout intermediate (annex E).
///
/// - Each session becomes a custom workout: one warm up step, interval blocks (work and recovery steps with
///   goals and alerts) and one cool down step. Step display names carry the session's own step names.
/// - Goals are distance or time only (energy goals are not supported in custom workouts). A step that states a
///   distance gets a distance goal, otherwise a time goal. Pool swim work reps get the distance with time goal,
///   which carries the CSS pace target.
/// - Alerts are explicit ranges only, never zone alerts: run pace as a speed range, bike power or heart rate
///   range, run power range outdoors only, swim heart rate only.
/// - Which goals and alerts survive is decided by `CapabilityTiering` from the supports checks. A step whose
///   goal or alert is dropped ships with the goal only and says so in `limitation`; the session notes say in plain
///   words what the watch will and will not show.
/// - A brick compiles to two custom workouts in order, bike then run (spec section 4.1).
///
/// `CompiledSession.workouts` is the payload for the watch (Sunday Sync). It is empty when the session stays on
/// the phone (no watch, or a pool swim the older watch cannot take); `usesPhoneSetCard` is then true. The phone
/// player gets the full fidelity version from `compilePhoneWorkouts`.
public struct DefaultSessionCompiler: SessionCompiler {
    private let zones: any ZoneCalculator

    public init(zones: any ZoneCalculator = DefaultZoneCalculator()) {
        self.zones = zones
    }

    // MARK: - SessionCompiler

    /// Annex E. Capability flags are converted to a `CapabilityReport` and compiled by the report level method.
    public func compile(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        capabilities: DeviceCapabilities,
        indoor: Bool
    ) throws -> CompiledSession {
        try compile(
            session,
            athlete: athlete,
            benchmarks: benchmarks,
            zoneNudgeSteps: zoneNudgeSteps,
            report: CapabilityReport(capabilities: capabilities),
            indoor: indoor)
    }

    /// Annex E "Race day": ordered legs from `distance.legs`, open goals, automatic transitions. The pacing plan
    /// lives on the race morning screen, not in the watch workout. The swim is open water, expressed as
    /// `.outdoor` for the swim leg.
    public func compileRaceDay(distance: RaceDistance, displayName: String) -> CompiledWorkout {
        let legs = distance.legs.map { leg in
            CompiledLeg(activity: CompiledActivity(sport: leg.sport, location: .outdoor), goal: .open)
        }
        return .swimBikeRun(CompiledSwimBikeRunWorkout(displayName: displayName, legs: legs))
    }

    // MARK: - Report level API

    /// Compiles a session against a full `CapabilityReport` (annex E "Capability tiers"). Throws
    /// `PlanKitError.uncompilableSession` for a session with no steps, a brick missing a part, or steps whose
    /// sport does not belong to the session.
    public func compile(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        report: CapabilityReport,
        indoor: Bool
    ) throws -> CompiledSession {
        let parts = try makeParts(for: session, indoor: indoor)
        let context = Context(zones: zones, athlete: athlete, benchmarks: benchmarks, nudges: zoneNudgeSteps)

        var notes: [String] = []
        func addNote(_ text: String) {
            if !text.isEmpty && !notes.contains(text) { notes.append(text) }
        }

        if parts.count > 1 {
            addNote("This brick is two workouts on your watch: bike first, then run. Start the run workout as soon as you rack the bike.")
        }
        if session.isOpenWater && session.sport == .swim {
            addNote("Open water workouts cannot go to the watch, so this is the pool version. The open water plan is on the session card.")
        }

        var customs: [CompiledCustomWorkout] = []
        var workouts: [CompiledWorkout] = []
        var phoneOnly = false
        var needsSetCard = false

        for part in parts {
            let delivery = CapabilityTiering.delivery(for: part.activity, report: report)
            let built = buildCustom(part, delivery: delivery, context: context)
            customs.append(built.workout)
            built.facts.notes(sport: part.sport, forWatch: delivery.delivery == .customWorkout).forEach(addNote)
            delivery.lines.forEach(addNote)

            switch delivery.delivery {
            case .customWorkout:
                workouts.append(.custom(built.workout))
            case .goalOnlyWorkout:
                needsSetCard = true
                if let single = goalOnlyWorkout(for: part) {
                    workouts.append(.singleGoal(single))
                } else {
                    phoneOnly = true
                }
            case .phoneOnly:
                phoneOnly = true
            }
        }

        if phoneOnly {
            // One part cannot go to the watch, so none of the session is split across devices.
            workouts = []
            needsSetCard = true
        }

        return CompiledSession(
            sessionID: session.id,
            workouts: workouts,
            notes: notes,
            usesPhoneSetCard: needsSetCard || phoneOnly)
    }

    /// The full fidelity workouts for the phone player (annex E "The phone player": it runs the same compiled
    /// session, steps, targets and cues). No device limits apply; run power alerts stay outdoor only.
    public func compilePhoneWorkouts(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        indoor: Bool
    ) throws -> [CompiledWorkout] {
        let compiled = try compile(
            session,
            athlete: athlete,
            benchmarks: benchmarks,
            zoneNudgeSteps: zoneNudgeSteps,
            report: .allSupported,
            indoor: indoor)
        return compiled.workouts
    }

    // MARK: - Session parts

    private struct Context {
        var zones: any ZoneCalculator
        var athlete: AthleteProfile
        var benchmarks: Benchmarks
        var nudges: [Sport: Int]
    }

    /// One workout worth of steps: a whole session, or one half of a brick.
    private struct Part {
        var sport: Sport
        var activity: CompiledActivity
        var name: String
        var steps: [Step]
        /// A maximal effort test: no alerts, no target times, so the watch never anchors the result to the old
        /// benchmark the test is meant to replace.
        var isTest: Bool
    }

    private func makeParts(for session: Session, indoor: Bool) throws -> [Part] {
        let baseName = session.name.isEmpty ? CompileSupport.title(for: session.sport) : session.name

        if let second = session.brickSecondSport {
            guard second != session.sport else {
                throw PlanKitError.uncompilableSession("A brick needs two different sports.")
            }
            let first = session.steps.filter { $0.sport == session.sport }
            let rest = session.steps.filter { $0.sport == second }
            guard !first.isEmpty, !rest.isEmpty,
                  first.count + rest.count == session.steps.count else {
                throw PlanKitError.uncompilableSession("A brick needs steps for both of its sports and no others.")
            }
            return [
                Part(
                    sport: session.sport,
                    activity: CompiledActivity(sport: session.sport, location: location(for: session.sport, indoor: indoor)),
                    name: "\(baseName): \(CompileSupport.title(for: session.sport).lowercased())",
                    steps: first,
                    isTest: session.isTest),
                Part(
                    sport: second,
                    // The trainer or treadmill flag applies to the first part. The transition run is outdoors.
                    activity: CompiledActivity(sport: second, location: location(for: second, indoor: false)),
                    name: "\(baseName): \(CompileSupport.title(for: second).lowercased())",
                    steps: rest,
                    isTest: session.isTest)
            ]
        }

        var steps = session.steps
        if session.sport == .swim && session.isOpenWater {
            // Every open water session carries a pool alternative (spec section 3.2); the watch gets the pool version.
            guard !session.poolAlternativeSteps.isEmpty else {
                throw PlanKitError.uncompilableSession("Open water session without a pool alternative.")
            }
            steps = session.poolAlternativeSteps
        }
        guard !steps.isEmpty else {
            throw PlanKitError.uncompilableSession("The session has no steps.")
        }
        guard steps.allSatisfy({ $0.sport == session.sport }) else {
            throw PlanKitError.uncompilableSession("The session has steps from another sport and is not a brick.")
        }
        return [
            Part(
                sport: session.sport,
                activity: CompiledActivity(sport: session.sport, location: location(for: session.sport, indoor: indoor)),
                name: baseName,
                steps: steps,
                isTest: session.isTest)
        ]
    }

    private func location(for sport: Sport, indoor: Bool) -> CompiledLocation {
        switch sport {
        case .swim: return .pool
        case .bike, .run: return indoor ? .indoor : .outdoor
        }
    }

    // MARK: - Custom workout assembly

    private func buildCustom(
        _ part: Part,
        delivery: ActivityDelivery,
        context: Context
    ) -> (workout: CompiledCustomWorkout, facts: PartFacts) {
        var facts = PartFacts()
        var steps = part.steps

        var warmUp: CompiledStep?
        if let first = steps.first, first.kind == .warmUp, first.repeatGroupID == nil {
            warmUp = compileStep(first, kind: .warmUp, activity: part.activity, delivery: delivery, context: context, facts: &facts, isTest: part.isTest)
            steps.removeFirst()
        }

        var coolDown: CompiledStep?
        if let last = steps.last, last.kind == .coolDown, last.repeatGroupID == nil {
            coolDown = compileStep(last, kind: .coolDown, activity: part.activity, delivery: delivery, context: context, facts: &facts, isTest: part.isTest)
            steps.removeLast()
        }

        var blocks: [CompiledBlock] = []
        var pending: [Step] = []
        var pendingGroup: String?

        func flush() {
            guard !pending.isEmpty else { return }
            let iterations = pendingGroup == nil ? 1 : (pending.first?.repeats ?? 1)
            let compiled = pending.map { step in
                compileStep(
                    step, kind: intervalKind(for: step), activity: part.activity,
                    delivery: delivery, context: context, facts: &facts, isTest: part.isTest)
            }
            blocks.append(CompiledBlock(iterations: iterations, steps: compiled))
            pending = []
        }

        for step in steps {
            if !pending.isEmpty && step.repeatGroupID != pendingGroup {
                flush()
            }
            if pending.isEmpty { pendingGroup = step.repeatGroupID }
            pending.append(step)
        }
        flush()

        let workout = CompiledCustomWorkout(
            activity: part.activity,
            displayName: part.name,
            warmUp: warmUp,
            blocks: blocks,
            coolDown: coolDown)
        return (workout, facts)
    }

    /// Interval blocks only hold work and recovery. A stray warm up or cool down step inside a block keeps its
    /// intensity: easy steps become recovery, harder ones work.
    private func intervalKind(for step: Step) -> StepKind {
        switch step.kind {
        case .work, .recovery: return step.kind
        case .warmUp, .coolDown: return step.level <= 2 ? .recovery : .work
        }
    }

    /// Older watch pool swims: a goal only single workout with the part's total distance, else its total time.
    /// Nil when the part states neither, which sends the session to the phone.
    private func goalOnlyWorkout(for part: Part) -> CompiledSingleGoalWorkout? {
        let meters = part.steps.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) * Double($1.repeats) }
        let seconds = part.steps.reduce(0.0) { $0 + $1.durationSeconds * Double($1.repeats) }
        let goal: CompiledGoal
        if CompileSupport.isPositiveFinite(meters) {
            goal = .distance(meters: meters)
        } else if CompileSupport.isPositiveFinite(seconds) {
            goal = .time(seconds: seconds)
        } else {
            return nil
        }
        return CompiledSingleGoalWorkout(activity: part.activity, displayName: part.name, goal: goal)
    }

    // MARK: - Step compilation

    private func compileStep(
        _ step: Step,
        kind: StepKind,
        activity: CompiledActivity,
        delivery: ActivityDelivery,
        context: Context,
        facts: inout PartFacts,
        isTest: Bool
    ) -> CompiledStep {
        // A test step runs on feel only: the RPE text and the goal stay, alerts and target times do not.
        let resolved = isTest
            ? StepTarget.rpe(ZoneConstants.rpeRange(forLevel: step.level))
            : resolveTarget(for: step, activity: activity, context: context)
        var limitations: [String] = []
        let feelOnly = isTest || (step.sport == .run && DefaultZoneCalculator.isFeelOnlyRunStep(step, athlete: context.athlete))

        // Alert (annex E "Alerts"): explicit ranges only, gated by the tier.
        let request = alertRequest(for: resolved, sport: step.sport)
        var alert = CompiledAlert.none
        if request == .none {
            let usable = step.sport == .swim
                ? swimPacePer100m(resolved, benchmarks: context.benchmarks) != nil
                : isConcrete(resolved, sport: step.sport)
            if !usable && !feelOnly { facts.noZones = true }
        } else {
            let allowed = isAllowed(request, delivery: delivery)
            if allowed {
                alert = request.compiled
                facts.alertsSent = true
            } else {
                let kindWord = alertWord(request)
                let target = CompileSupport.describe(request, sport: step.sport)
                if step.sport == .run, case .power = request, activity.location != .outdoor {
                    facts.runPowerIndoor = true
                    limitations.append("Run power alerts work outdoors only. Target \(target).")
                } else {
                    facts.droppedAlerts.insert(kindWord)
                    limitations.append("No \(kindWord) alert on this watch. Target \(target).")
                }
            }
        }

        // Goal (annex E "Goals"): distance or time, never energy.
        let goal = compileGoal(
            step, kind: kind, activity: activity, delivery: delivery,
            resolved: resolved, context: context, facts: &facts, limitations: &limitations)

        return CompiledStep(
            kind: kind,
            displayName: displayName(for: step, kind: kind),
            goal: goal,
            alert: alert,
            rpeText: rpeText(for: step, resolved: resolved),
            limitation: limitations.isEmpty ? nil : limitations.joined(separator: " "))
    }

    private func displayName(for step: Step, kind: StepKind) -> String {
        let trimmed = step.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CompileSupport.stockLabel(for: kind) : trimmed
    }

    /// A step that states a distance gets a distance goal; otherwise a time goal. Pool swim work reps with a
    /// known CSS pace get the distance with time goal.
    private func compileGoal(
        _ step: Step,
        kind: StepKind,
        activity: CompiledActivity,
        delivery: ActivityDelivery,
        resolved: StepTarget,
        context: Context,
        facts: inout PartFacts,
        limitations: inout [String]
    ) -> CompiledGoal {
        let meters = step.distanceMeters ?? 0
        let seconds = step.durationSeconds

        func timeGoal() -> CompiledGoal {
            guard CompileSupport.isPositiveFinite(seconds), delivery.allowsTimeGoal else { return .open }
            return .time(seconds: seconds)
        }

        guard CompileSupport.isPositiveFinite(meters) else { return timeGoal() }

        let distanceGoal: CompiledGoal = delivery.allowsDistanceGoal ? .distance(meters: meters) : timeGoal()

        guard activity.sport == .swim, activity.location == .pool, kind == .work,
              let pace = swimPacePer100m(resolved, benchmarks: context.benchmarks) else {
            return distanceGoal
        }
        let repSeconds = (pace * meters / 100).rounded()
        guard CompileSupport.isPositiveFinite(repSeconds) else { return distanceGoal }

        if delivery.allowsDistanceWithTimeGoal {
            return .distanceWithTime(meters: meters, seconds: repSeconds)
        }
        facts.withTimeDropped = true
        limitations.append("No time goal on this watch. Target \(CompileSupport.clock(repSeconds)) for \(CompileSupport.safeInt(meters)) m.")
        return distanceGoal
    }

    // MARK: - Targets

    /// Resolves the concrete target through the zone calculator (annex A) with the net zone nudge for the step's
    /// sport (annex C rule 3). A concrete target already on the step is the fallback when the calculator can only
    /// answer with feel, so a hand edited step keeps its numbers.
    private func resolveTarget(for step: Step, activity: CompiledActivity, context: Context) -> StepTarget {
        let nudge = context.nudges[step.sport] ?? 0
        let resolved = context.zones.resolveTarget(
            for: step, athlete: context.athlete, benchmarks: context.benchmarks, nudgeSteps: nudge)
        if isConcrete(resolved, sport: step.sport) { return resolved }
        if isConcrete(step.target, sport: step.sport) { return step.target }
        if step.sport == .swim, case .cssOffset = step.target, context.benchmarks.cssSecondsPer100m != nil {
            return step.target
        }
        return resolved
    }

    /// A target that carries numbers an alert or goal can use, as opposed to feel only.
    private func isConcrete(_ target: StepTarget, sport: Sport) -> Bool {
        switch target {
        case .pacePerKm, .pacePer100m, .speedRange, .powerRange, .heartRateRange, .cssOffset: return true
        case .rpe, .none: return false
        }
    }

    private func alertRequest(for target: StepTarget, sport: Sport) -> AlertRequest {
        switch sport {
        case .swim:
            // Swim steps take heart rate alerts only. The CSS pace rides on the distance with time goal.
            if case .heartRateRange(let range) = target, CompileSupport.isUsableAlertRange(range) {
                return .heartRate(range)
            }
            return .none
        case .bike:
            switch target {
            case .powerRange(let range) where CompileSupport.isUsableAlertRange(range): return .power(range)
            case .heartRateRange(let range) where CompileSupport.isUsableAlertRange(range): return .heartRate(range)
            default: return .none
            }
        case .run:
            switch target {
            case .pacePerKm(let range):
                if let speeds = CompileSupport.speedRange(fromPaceRange: range), CompileSupport.isUsableAlertRange(speeds) {
                    return .speed(speeds)
                }
                return .none
            case .speedRange(let range) where CompileSupport.isUsableAlertRange(range): return .speed(range)
            case .powerRange(let range) where CompileSupport.isUsableAlertRange(range): return .power(range)
            case .heartRateRange(let range) where CompileSupport.isUsableAlertRange(range): return .heartRate(range)
            default: return .none
            }
        }
    }

    private func isAllowed(_ request: AlertRequest, delivery: ActivityDelivery) -> Bool {
        switch request {
        case .none: return false
        case .speed: return delivery.allowsSpeedAlert
        case .power: return delivery.allowsPowerAlert
        case .heartRate: return delivery.allowsHeartRateAlert
        }
    }

    private func alertWord(_ request: AlertRequest) -> String {
        switch request {
        case .none: return ""
        case .speed: return "pace"
        case .power: return "power"
        case .heartRate: return "heart rate"
        }
    }

    /// Swim pace in seconds per 100 m from a resolved target. Accepts an absolute swim pace (the midpoint of the
    /// range), a CSS offset (needs the CSS benchmark) or a speed range in metres per second (the midpoint of the
    /// two paces). A run pace is never read as a swim pace.
    private func swimPacePer100m(_ target: StepTarget, benchmarks: Benchmarks) -> Double? {
        let pace: Double?
        switch target {
        case .pacePer100m(let range):
            pace = range.midpoint
        case .cssOffset(let range):
            guard let css = benchmarks.cssSecondsPer100m?.value, CompileSupport.isPositiveFinite(css) else { return nil }
            pace = css + range.midpoint
        case .speedRange(let range):
            if CompileSupport.isPositiveFinite(range.lower), CompileSupport.isPositiveFinite(range.upper) {
                pace = (100 / range.lower + 100 / range.upper) / 2
            } else {
                pace = nil
            }
        default:
            pace = nil
        }
        guard let value = pace, value.isFinite, (20...600).contains(value) else { return nil }
        return value
    }

    /// Feel description for the step (annex A): an RPE target if there is one, else the level default, with the
    /// step's own cue appended.
    private func rpeText(for step: Step, resolved: StepTarget) -> String {
        var base: String
        switch (step.target, resolved) {
        case (.rpe(let range), _): base = CompileSupport.rpeText(for: range)
        case (_, .rpe(let range)): base = CompileSupport.rpeText(for: range)
        default: base = CompileSupport.rpeText(forLevel: step.level)
        }
        if let note = step.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            if note.contains("RPE") { return note }
            base += ". " + note
        }
        return base
    }
}

/// What happened while compiling one part, collected to write the plain words session notes.
private struct PartFacts {
    var alertsSent = false
    var droppedAlerts: Set<String> = []
    var runPowerIndoor = false
    var withTimeDropped = false
    var noZones = false

    /// `forWatch` is false when the part does not go to the watch as a custom workout; only the missing zones
    /// line applies then.
    func notes(sport: Sport, forWatch: Bool) -> [String] {
        var lines: [String] = []
        let word = CapabilityTiering.sportWord(sport)
        guard forWatch else {
            if noZones {
                lines.append("No \(word) zones are set yet, so these steps run on feel with no alerts. A \(word) test adds pace or power ranges.")
            }
            return lines
        }
        if alertsSent {
            lines.append("Alert ranges on your watch are fixed from your zones today. They do not follow the zones set on the watch itself.")
        }
        for kind in droppedAlerts.sorted() {
            lines.append("Your watch will not show \(kind) alerts for the \(word), so those steps carry a goal only. The targets are on the session card.")
        }
        if runPowerIndoor {
            lines.append("Run power alerts work outdoors only, so indoor run steps carry a goal only. The power targets are on the session card.")
        }
        if withTimeDropped {
            lines.append("Your watch cannot take a time goal on pool reps, so each rep carries a distance goal only. The target time per rep is on the session card.")
        }
        if noZones {
            lines.append("No \(word) zones are set yet, so these steps run on feel with no alerts. A \(word) test adds pace or power ranges.")
        }
        return lines
    }
}
