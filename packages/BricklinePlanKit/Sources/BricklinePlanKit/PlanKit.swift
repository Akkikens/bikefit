import Foundation

/// One entry point that wires the six engine modules together. Every function is pure: dates and calendars come
/// in as parameters, nothing reads the clock, and failures are thrown as `PlanKitError` or returned.
///
/// A `PlanKit` value holds the concrete engines. The app uses `PlanKit()` for production behaviour and may
/// pass its own engines (for example a stub zone calculator) through `init(zones:templates:adaptation:load:race:compiler:)`.
public struct PlanKit: Sendable {
    public let zones: any ZoneCalculator
    public let templates: any TemplateEngine
    public let adaptation: any AdaptationEngine
    public let load: any LoadModel
    public let race: any RaceWindow
    public let compiler: any SessionCompiler

    /// Default wiring. The adaptation engine and the compiler share one zone calculator and one load model.
    public init() {
        let zones = DefaultZoneCalculator()
        let load = DefaultLoadModel()
        self.zones = zones
        self.templates = DefaultTemplateEngine()
        self.adaptation = DefaultAdaptationEngine(loadModel: load, zones: zones)
        self.load = load
        self.race = DefaultRaceWindow()
        self.compiler = DefaultSessionCompiler(zones: zones)
    }

    public init(
        zones: any ZoneCalculator,
        templates: any TemplateEngine,
        adaptation: any AdaptationEngine,
        load: any LoadModel,
        race: any RaceWindow,
        compiler: any SessionCompiler
    ) {
        self.zones = zones
        self.templates = templates
        self.adaptation = adaptation
        self.load = load
        self.race = race
        self.compiler = compiler
    }

    /// Shared default instance.
    public static let standard = PlanKit()

    // MARK: Plans (annex A retest rotation, annex B)

    /// Number of weeks a race plan spans, clamped to the distance's supported length.
    public func planWeekCount(
        raceDistance: RaceDistance, raceDate: Date, startDate: Date, calendar: Calendar
    ) throws -> Int {
        try templates.planWeekCount(
            raceDistance: raceDistance, raceDate: raceDate, startDate: startDate, calendar: calendar)
    }

    /// Builds a race plan.
    public func makePlan(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date,
        athlete: AthleteProfile,
        benchmarks: Benchmarks = Benchmarks(),
        calendar: Calendar
    ) throws -> Plan {
        try templates.makePlan(
            raceDistance: raceDistance, raceDate: raceDate, startDate: startDate,
            athlete: athlete, benchmarks: benchmarks, calendar: calendar)
    }

    /// Builds the rolling base plan used when there is no race yet.
    public func makeBasePlan(
        startDate: Date, athlete: AthleteProfile, benchmarks: Benchmarks = Benchmarks(), calendar: Calendar
    ) throws -> Plan {
        try templates.makeBasePlan(
            startDate: startDate, athlete: athlete, benchmarks: benchmarks, calendar: calendar)
    }

    /// Converts a base plan to a race plan, keeping completed history.
    public func convertToRacePlan(
        _ base: Plan, raceDistance: RaceDistance, raceDate: Date, today: Date,
        benchmarks: Benchmarks = Benchmarks(), calendar: Calendar
    ) throws -> Plan {
        try templates.convertToRacePlan(
            base, raceDistance: raceDistance, raceDate: raceDate, today: today,
            benchmarks: benchmarks, calendar: calendar)
    }

    /// Re-plans after the race date moved or was cancelled (nil date gives a base plan).
    public func replan(
        _ plan: Plan, raceDistance: RaceDistance?, raceDate: Date?, today: Date,
        benchmarks: Benchmarks = Benchmarks(), calendar: Calendar
    ) throws -> Plan {
        try templates.replan(
            plan, raceDistance: raceDistance, raceDate: raceDate, today: today,
            benchmarks: benchmarks, calendar: calendar)
    }

    // MARK: Adaptation (annex C)

    /// Evaluates the eight adaptation rules for `context.today`.
    public func adapt(_ plan: Plan, context: AdaptationContext, calendar: Calendar) -> AdaptationResult {
        adaptation.apply(to: plan, context: context, calendar: calendar)
    }

    /// Applies the athlete's confirmed realignment choice (rule 2).
    public func realign(
        _ option: RealignmentOption, plan: Plan, context: AdaptationContext, calendar: Calendar
    ) throws -> AdaptationResult {
        try adaptation.applyRealignment(option, to: plan, context: context, calendar: calendar)
    }

    // MARK: Compile (annex E)

    /// Compiles one session for the watch. Uses the plan's zone nudges.
    public func compile(
        _ session: Session,
        in plan: Plan,
        benchmarks: Benchmarks,
        capabilities: DeviceCapabilities = .standard,
        indoor: Bool = false
    ) throws -> CompiledSession {
        try compiler.compile(
            session, athlete: plan.athlete, benchmarks: benchmarks,
            zoneNudgeSteps: plan.effectiveZoneNudgeSteps(benchmarks: benchmarks), capabilities: capabilities, indoor: indoor)
    }

    /// Compiles every non-skipped session of the plan, in date order. One session that cannot compile does not
    /// block the others: each entry carries its own result, so the UI can offer a retry for the failures only.
    public func compileAll(
        _ plan: Plan,
        benchmarks: Benchmarks,
        capabilities: DeviceCapabilities = .standard,
        indoor: Bool = false
    ) -> [SessionCompileResult] {
        plan.allSessions.filter { $0.state != .skipped }.map { session in
            do {
                let compiled = try compile(
                    session, in: plan, benchmarks: benchmarks, capabilities: capabilities, indoor: indoor)
                return SessionCompileResult(sessionID: session.id, result: .success(compiled))
            } catch let error as PlanKitError {
                return SessionCompileResult(sessionID: session.id, result: .failure(error))
            } catch {
                return SessionCompileResult(
                    sessionID: session.id, result: .failure(.uncompilableSession(error.localizedDescription)))
            }
        }
    }

    /// The full fidelity workouts for the phone player, built with the injected compiler (annex E).
    public func compilePhoneWorkouts(
        _ session: Session, in plan: Plan, benchmarks: Benchmarks, indoor: Bool = false
    ) throws -> [CompiledWorkout] {
        try compiler.compilePhoneWorkouts(
            session, athlete: plan.athlete, benchmarks: benchmarks,
            zoneNudgeSteps: plan.effectiveZoneNudgeSteps(benchmarks: benchmarks), indoor: indoor)
    }

    // MARK: Editing

    /// Moves a planned session to another day of the same week, for drag to reschedule. The move follows the
    /// same rules as annex C rule 1: the athlete's days, pool days for swims, hard days kept apart, tests 48 hours
    /// apart, the long ride and long run a day apart, nothing heavy on race eve. Throws
    /// `PlanKitError.invalidInput` with a calm reason when the day is not allowed, and `.sessionNotFound` for an
    /// unknown id. Returns the edited plan and the `weekEdited` event the host appends to the athlete's log, so
    /// annex C rule 5 re checks the week on the next pass.
    public func moveSession(
        _ sessionID: String, to day: Date, in plan: Plan, today: Date, calendar: Calendar
    ) throws -> (plan: Plan, event: AthleteEvent) {
        let calendar = plan.resolvedCalendar(calendar)
        guard let session = plan.session(withID: sessionID) else { throw PlanKitError.sessionNotFound(sessionID) }
        guard session.state == .planned else {
            throw PlanKitError.invalidInput("Only a session that is still planned can move.")
        }
        guard let fromWeek = plan.weekIndex(containing: session.scheduledDate, calendar: calendar),
              let toWeek = plan.weekIndex(containing: day, calendar: calendar), fromWeek == toWeek else {
            throw PlanKitError.invalidInput("A session can only move to another day of the same week.")
        }
        let target = calendar.startOfDay(for: day)
        if target == calendar.startOfDay(for: session.scheduledDate) { return (plan, .weekEdited(weekIndex: fromWeek, on: today)) }
        if let reason = PlanMoveRules.problem(for: session, on: target, in: plan, calendar: calendar, emptyOnly: false) {
            throw PlanKitError.invalidInput(reason)
        }
        var edited = plan
        edited.adaptRemove(id: sessionID)
        var moved = session
        moved.scheduledDate = target
        edited.adaptInsert(moved, calendar: calendar)
        edited.adaptRefreshHours(weekIndex: fromWeek)
        return (edited, .weekEdited(weekIndex: fromWeek, on: today))
    }

    /// Runs the eight adaptation rules on a plan that is kept together with its logs. The fired events go into
    /// `state.history` for you.
    @discardableResult
    public func adapt(
        _ state: inout AdaptationState,
        today: Date,
        completedWorkouts: [CompletedWorkout] = [],
        benchmarks: Benchmarks = Benchmarks(),
        dailyLoads: [LoadSample] = [],
        calendar: Calendar
    ) -> AdaptationResult {
        state.apply(
            using: adaptation, today: today, completedWorkouts: completedWorkouts, benchmarks: benchmarks,
            dailyLoads: dailyLoads, calendar: calendar)
    }

    /// Race day multisport workout with open goals.
    public func compileRaceDay(distance: RaceDistance, displayName: String) -> CompiledWorkout {
        compiler.compileRaceDay(distance: distance, displayName: displayName)
    }

    // MARK: Race window (annex F)

    public func isRaceWindowActive(
        raceDate: Date, distance: RaceDistance, today: Date, calendar: Calendar
    ) -> Bool {
        race.isWindowActive(raceDate: raceDate, distance: distance, today: today, calendar: calendar)
    }

    /// Timeline entries, capped for notifications when `forNotifications` is true.
    public func raceWindow(
        for details: RaceDetails, calendar: Calendar, forNotifications: Bool = false
    ) -> [RaceWindowEntry] {
        let entries = race.entries(for: details, calendar: calendar)
        return forNotifications ? race.cappedForNotifications(entries) : entries
    }

    /// Pacing card and per-leg fueling advice for a race distance. `bikeSpeedKph` is the speed the athlete expects
    /// to hold on the course; without it the bike leg time is a typical value for the level and says so.
    public func racePlan(
        distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks, bikeSpeedKph: Double? = nil
    ) -> (pacing: PacingCard, fueling: [FuelingAdvice]) {
        let card = race.pacing(for: distance, athlete: athlete, benchmarks: benchmarks, bikeSpeedKph: bikeSpeedKph)
        return (card, race.fueling(for: card))
    }

    /// Planned versus actual per leg after the race (annex F "Debrief").
    public func debrief(card: PacingCard, actuals: RaceActuals) -> RaceDebrief {
        race.debrief(card: card, actuals: actuals)
    }

    // MARK: Load (annex D)

    /// Daily Load, then Fitness, Fatigue and Form, over a date range. `hasFullHistory` is false until the range
    /// holds at least 42 days (`LoadConstants.fullHistoryDays`): Fitness is seeded at zero, so before that Form
    /// shows a large negative for athletes whose earlier training is not loaded. The UI shows "building" instead.
    public func fitnessForm(
        workouts: [CompletedWorkout], benchmarks: Benchmarks, from: Date, through: Date, calendar: Calendar
    ) -> (daily: [LoadSample], series: [FitnessForm], hasFullHistory: Bool) {
        let daily = load.dailyLoads(
            workouts: workouts, benchmarks: benchmarks, from: from, through: through, calendar: calendar)
        return (daily, load.fitnessForm(dailyLoads: daily, calendar: calendar), daily.count >= LoadConstants.fullHistoryDays)
    }
}

/// One session's compile outcome, see `PlanKit.compileAll`.
public struct SessionCompileResult: Sendable {
    public var sessionID: String
    public var result: Result<CompiledSession, PlanKitError>

    public init(sessionID: String, result: Result<CompiledSession, PlanKitError>) {
        self.sessionID = sessionID
        self.result = result
    }

    /// The compiled session when it compiled.
    public var compiled: CompiledSession? {
        if case let .success(value) = result { return value }
        return nil
    }

    /// The error when it did not.
    public var failure: PlanKitError? {
        if case let .failure(error) = result { return error }
        return nil
    }
}
