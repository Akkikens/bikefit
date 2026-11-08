import Foundation

// Public entry points of the six engine modules. Each module owner provides one concrete struct with a public
// `init()` (and, where noted, an initializer taking collaborators), named `Default<Protocol>`. Every function
// is pure: dates and calendars come in as parameters, nothing reads the clock, randomness is never used
// (or is seeded explicitly), and failures are returned or thrown as `PlanKitError`, never trapped.

// MARK: - Zones

/// Zones from benchmarks, plus benchmark seeding helpers. Owner: Zones/. Concrete type: `DefaultZoneCalculator`.
/// Implements annex A.
public protocol ZoneCalculator: Sendable {
    /// Swim zone as an offset range in seconds per 100 m relative to CSS (annex A, swim):
    /// easy +8 to +15, steady +4 to +7, threshold -3 to +3, vo2 -8 to -4.
    func swimOffsetRange(_ zone: SwimZone) -> ValueRange

    /// Swim zone as an absolute pace range in seconds per 100 m: `css` plus the offset range.
    func swimPaceRange(_ zone: SwimZone, css: Double) -> ValueRange

    /// Run zone as pace in seconds per km (annex A, run). Easy = threshold + 45 to 90 s, steady = + 20 to 45 s,
    /// threshold = plus or minus 3 percent floored at plus or minus 10 s, vo2 = minus 15 to 25 s.
    func runPaceRange(_ zone: RunZone, thresholdPace: Double) -> ValueRange

    /// Bike power zone in watts from FTP (annex A, bike). Z7 is capped at 300 percent of FTP so ranges stay finite.
    func bikePowerRange(_ zone: BikePowerZone, ftp: Double) -> ValueRange

    /// Heart rate zone in bpm from LTHR (annex A table, one table for prescriptions and the load model).
    /// Z1 starts at 0 and Z5 is capped at 120 percent of LTHR so ranges stay finite.
    func heartRateRange(_ zone: HeartRateZone, lthr: Double) -> ValueRange

    /// Resolves a step's concrete target from its `level`, the athlete's gear and the current benchmarks.
    /// Order of preference: swim css offset or absolute pace; bike power when the athlete has a power meter and an
    /// FTP, else bike heart rate from LTHR; run pace from threshold pace, else run heart rate, else RPE.
    /// Falls back to `.rpe` when no benchmark exists. `nudgeSteps` (from `Plan.zoneNudgeSteps`) shifts the zone by
    /// about 2 percent per step toward harder (positive) or easier (negative). Estimated benchmarks resolve normally.
    func resolveTarget(
        for step: Step,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        nudgeSteps: Int
    ) -> StepTarget

    /// CSS pace per 100 m = (T400 minus T200) / 2, with times in seconds (annex A).
    /// Throws `PlanKitError.cssTestRejected` when the 200 m pace is not faster than the 400 m pace, and
    /// `PlanKitError.invalidInput` for non positive times.
    func cssFromTest(time400Seconds: Double, time200Seconds: Double, on date: Date) throws -> BenchmarkValue

    /// FTP = 0.95 times best 20 minute average power (annex A). Not estimated.
    func ftpFromTest(best20MinutePower: Double, on date: Date) throws -> BenchmarkValue

    /// Bike LTHR from the 30 minute solo time trial: the average heart rate of the final 20 minutes (annex A).
    func bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: Double, on date: Date) throws -> BenchmarkValue

    /// Run threshold pace per km = 1800 s divided by km covered in the 30 minute test (annex A), plus the optional
    /// LTHR (average heart rate of the final 20 minutes). Returns benchmarks with only the run fields set.
    func runThresholdFromTest(
        distanceKilometres: Double,
        finalTwentyMinuteAverageHeartRate: Double?,
        on date: Date
    ) throws -> Benchmarks

    /// Seeds FTP as 0.95 times the best 20 minute average of power samples. Nil when the samples cover less than
    /// 20 minutes. Labelled estimated (annex A "Seeding without tests").
    func seedFTP(fromPower samples: [SeriesSample], on date: Date) -> BenchmarkValue?

    /// Seeds bike LTHR from the best sustained 20 to 30 minute heart rate segment of a hard ride. Nil when too short.
    /// Labelled estimated.
    func seedBikeLTHR(fromHeartRate samples: [SeriesSample], on date: Date) -> BenchmarkValue?

    /// Seeds run threshold pace (from speed in metres per second) and run LTHR from the best sustained 20 to 30
    /// minute segments. Returns benchmarks with only the run fields set, labelled estimated. Empty when too short.
    func seedRunBenchmarks(
        speed: [SeriesSample],
        heartRate: [SeriesSample],
        on date: Date
    ) -> Benchmarks
}

// MARK: - Templates

/// Builds plans from templates. Owner: Templates/. Concrete type: `DefaultTemplateEngine`. Implements annex B and
/// the retest rotation of annex A. Fully deterministic: identical inputs give an identical `Plan`, including ids.
///
/// Week layout contract: week `k` covers the seven days starting at `Plan.startDate + 7k`; the final week contains
/// the race date. `Plan.startDate` is the first day of a calendar week (`calendar.firstWeekday`) on or before the
/// requested start, and days of week 0 before the requested start are left empty. The plan records the time zone
/// it was built in. Sessions sit on `athlete.availableWeekdays`; pool sessions only on `athlete.poolWeekdays`.
public protocol TemplateEngine: Sendable {
    /// Number of weeks a plan spans from `startDate` to `raceDate`, clamped to the distance's supported plan
    /// length (annex B). Throws `PlanKitError.raceDateTooSoon` when fewer than the minimum weeks remain.
    func planWeekCount(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date,
        calendar: Calendar
    ) throws -> Int

    /// Builds a race plan: phases, 3 plus 1 loading blocks, recovery and test weeks, taper, weekly bricks,
    /// quality caps by level, at least one fully easy session per scheduled sport per week (annex B).
    /// `benchmarks` decides which sports test first (annex A retest rotation) and whether targets start estimated.
    /// Throws `PlanKitError.raceDateTooSoon` or `PlanKitError.infeasibleProfile`.
    func makePlan(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan

    /// "No race yet" mode: a rolling 4 week base block with a test week (annex B). `raceDistance` and `raceDate`
    /// of the result are nil.
    func makeBasePlan(
        startDate: Date,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan

    /// Converts a base plan to a race plan when a race date arrives, keeping completed history.
    func convertToRacePlan(
        _ base: Plan,
        raceDistance: RaceDistance,
        raceDate: Date,
        today: Date,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan

    /// Re plans from `today` after the race date moved or was cancelled (`raceDate` nil means cancelled and yields
    /// a base plan), keeping completed history (annex G "Race date moved or cancelled").
    func replan(
        _ plan: Plan,
        raceDistance: RaceDistance?,
        raceDate: Date?,
        today: Date,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan
}

// MARK: - Adaptation

/// Applies the eight ordered rules of annex C. Owner: Adaptation/. Concrete type: `DefaultAdaptationEngine`, whose
/// initializer takes the collaborators it needs: `init(loadModel: any LoadModel, zones: any ZoneCalculator)`
/// (defaults `DefaultLoadModel()` and `DefaultZoneCalculator()`). Thresholds live in one constants file
/// (`AdaptationConstants`). Every fired rule writes a non empty reason line. At most one structural change per day.
public protocol AdaptationEngine: Sendable {
    /// Evaluates the rules in order for `context.today` and returns the new plan, the newly fired events and any
    /// pending realignment prompt. Calling it twice with the same inputs gives the same output.
    func apply(to plan: Plan, context: AdaptationContext, calendar: Calendar) -> AdaptationResult

    /// Applies the athlete's confirmed rule 2 choice. A confirmed realignment counts as that day's single
    /// structural change (annex C). Throws `PlanKitError.realignmentUnavailable` for `.shiftPlan` when the race
    /// date does not allow it.
    func applyRealignment(
        _ option: RealignmentOption,
        to plan: Plan,
        context: AdaptationContext,
        calendar: Calendar
    ) throws -> AdaptationResult
}

// MARK: - Load

/// Load, Fitness, Fatigue and Form. Owner: Load/. Concrete type: `DefaultLoadModel`. Implements annex D.
/// The metric names are Load, Fitness, Fatigue (internal) and Form.
public protocol LoadModel: Sendable {
    /// Load of a recorded workout. With power: (adjusted power / FTP) squared times hours times 100, using
    /// `adjustedPower` when present, else `averagePower`. Without power: time in the five LTHR zones times the
    /// per zone factors 20, 40, 65, 100, 135 per hour. Swims without heart rate use duration times the zone factor
    /// of the planned level and are flagged estimated. With no usable data the result is zero and estimated.
    func load(for workout: CompletedWorkout, benchmarks: Benchmarks) -> SessionLoad

    /// Planned Load of a session from its steps: each step's level maps to a midpoint intensity (power path) or a
    /// zone factor (heart rate path), summed over repeats.
    func plannedLoad(for session: Session, benchmarks: Benchmarks) -> SessionLoad

    /// Sum of planned Load of the week's sessions, used by annex C rule 5.
    func plannedLoad(for week: PlannedWeek, benchmarks: Benchmarks) -> Double

    /// Daily Load totals for every day from `from` to `through` inclusive (zero filled), in date order.
    func dailyLoads(
        workouts: [CompletedWorkout],
        benchmarks: Benchmarks,
        from: Date,
        through: Date,
        calendar: Calendar
    ) -> [LoadSample]

    /// Fitness (42 day), Fatigue (7 day) and Form series over consecutive daily samples, in date order.
    /// Exponentially weighted averages seeded at zero; Form for a day is yesterday's Fitness minus yesterday's
    /// Fatigue (annex D, B26).
    func fitnessForm(dailyLoads: [LoadSample], calendar: Calendar) -> [FitnessForm]

    /// Acute (7 day) over chronic (28 day) Load ratio as of a day, using average daily Load over each window.
    /// Nil when the chronic average is zero or the history is shorter than 28 days. Used by annex C rule 6.
    func acuteChronicRatio(dailyLoads: [LoadSample], asOf: Date, calendar: Calendar) -> Double?
}

// MARK: - Race window

/// Race window timeline, pacing and fueling. Owner: Race/. Concrete type: `DefaultRaceWindow`. Implements annex F.
/// Copy follows the language rules of spec section 6 and annex K.
public protocol RaceWindow: Sendable {
    /// True when `today` is inside the window: T minus 21 days (T minus 10 for Sprint) through race day.
    func isWindowActive(raceDate: Date, distance: RaceDistance, today: Date, calendar: Calendar) -> Bool

    /// Timeline entries in order of `tMinusDays` descending: bike service (T minus 14, only when a Bike record
    /// exists), travel and pack (travel flag), carb load (T minus 2 for 70.3, race eve for shorter), pack tonight
    /// (T minus 1), wake up (race day, start time minus transit minus setup minus breakfast lead).
    func entries(for race: RaceDetails, calendar: Calendar) -> [RaceWindowEntry]

    /// Pacing card from the athlete's own benchmarks. Always ranges. Falls back to RPE ranges when a benchmark
    /// is missing. The caveat scales with distance.
    func pacing(for distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks) -> PacingCard

    /// Same card with an optional bike speed the athlete expects to hold, in km/h. Without it the bike leg time is
    /// a typical value for the level and the card says so (`PacingTarget.durationBasis`).
    func pacing(for distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks, bikeSpeedKph: Double?) -> PacingCard

    /// Fueling advice per leg, keyed to each leg's expected duration from the pacing card.
    func fueling(for card: PacingCard) -> [FuelingAdvice]

    /// Planned versus actual per leg from a finished race (annex F "Debrief"). A leg whose planned time is only a
    /// typical value for the level is reported without a faster or slower verdict.
    func debrief(card: PacingCard, actuals: RaceActuals) -> RaceDebrief

    /// Applies the annex H cap to timeline entries: at most 1 per day and at most 4 in any week, the entries
    /// closest to race day winning. The wake up entry is always kept.
    func cappedForNotifications(_ entries: [RaceWindowEntry]) -> [RaceWindowEntry]
}

// MARK: - Compile

/// Compiles sessions to the platform neutral workout intermediate. Owner: Compile/. Concrete type:
/// `DefaultSessionCompiler`, whose initializer takes `zones: any ZoneCalculator` (default
/// `DefaultZoneCalculator()`). Implements annex E. A WorkoutKit bridge lives in Compile/ under
/// `#if canImport(WorkoutKit)` with `@available(iOS 18, macOS 15, watchOS 11, *)`; tests use only this protocol.
public protocol SessionCompiler: Sendable {
    /// Compiles one session. Targets resolve through `ZoneCalculator.resolveTarget` using
    /// `zoneNudgeSteps[step.sport]`. Run pace becomes speed range alerts, bike gets power or heart rate range
    /// alerts, swim gets heart rate alerts only with the CSS pace riding on the distance with time goal.
    /// Unsupported goals or alerts are dropped per `capabilities` and explained in `limitation` and `notes`.
    /// `indoor` marks trainer or treadmill sessions (power alerts for runs are outdoor only).
    /// A brick compiles to two custom workouts, bike then run.
    /// Throws `PlanKitError.uncompilableSession` for a session with no steps.
    func compile(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        capabilities: DeviceCapabilities,
        indoor: Bool
    ) throws -> CompiledSession

    /// Race day: ordered swim, bike, run legs with open goals (annex E "Race day").
    func compileRaceDay(distance: RaceDistance, displayName: String) -> CompiledWorkout

    /// The full fidelity workouts for the phone player (annex E "The phone player"): the same compiled session with
    /// no device limits. The default implementation compiles against a watch that supports everything.
    func compilePhoneWorkouts(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        indoor: Bool
    ) throws -> [CompiledWorkout]
}

extension SessionCompiler {
    public func compilePhoneWorkouts(
        _ session: Session,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        zoneNudgeSteps: [Sport: Int],
        indoor: Bool
    ) throws -> [CompiledWorkout] {
        try compile(
            session, athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: zoneNudgeSteps,
            capabilities: DeviceCapabilities.standard, indoor: indoor).workouts
    }
}
