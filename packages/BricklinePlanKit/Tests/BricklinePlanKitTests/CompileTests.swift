import XCTest
@testable import BricklinePlanKit
#if canImport(WorkoutKit)
import HealthKit
import WorkoutKit
#endif

// Tests for the session compiler (annex E). They run on the platform neutral representation, with a fixed
// stand-in zone calculator so the numbers here do not depend on the zone tables.

/// Fixed zone math: just enough of annex A to give the compiler concrete targets.
private struct FixedZones: ZoneCalculator {
    func swimOffsetRange(_ zone: SwimZone) -> ValueRange {
        switch zone {
        case .easy: return ValueRange(8, 15)
        case .steady: return ValueRange(4, 7)
        case .threshold: return ValueRange(-3, 3)
        case .vo2: return ValueRange(-8, -4)
        }
    }
    func swimPaceRange(_ zone: SwimZone, css: Double) -> ValueRange {
        let o = swimOffsetRange(zone)
        return ValueRange(css + o.lower, css + o.upper)
    }
    func runPaceRange(_ zone: RunZone, thresholdPace: Double) -> ValueRange {
        switch zone {
        case .easy: return ValueRange(thresholdPace + 45, thresholdPace + 90)
        case .steady: return ValueRange(thresholdPace + 20, thresholdPace + 45)
        case .threshold:
            let half = max(thresholdPace * 0.03, 10)
            return ValueRange(thresholdPace - half, thresholdPace + half)
        case .vo2: return ValueRange(thresholdPace - 25, thresholdPace - 15)
        }
    }
    func bikePowerRange(_ zone: BikePowerZone, ftp: Double) -> ValueRange {
        let bands: [BikePowerZone: (Double, Double)] = [
            .z1: (0, 0.55), .z2: (0.56, 0.75), .z3: (0.76, 0.90), .z4: (0.91, 1.05),
            .z5: (1.06, 1.20), .z6: (1.21, 1.50), .z7: (1.51, 3.0)
        ]
        let b = bands[zone] ?? (0, 0.55)
        return ValueRange(b.0 * ftp, b.1 * ftp)
    }
    func heartRateRange(_ zone: HeartRateZone, lthr: Double) -> ValueRange {
        let bands: [HeartRateZone: (Double, Double)] = [
            .z1: (0, 0.81), .z2: (0.81, 0.89), .z3: (0.89, 0.94), .z4: (0.94, 1.02), .z5: (1.02, 1.2)
        ]
        let b = bands[zone] ?? (0, 0.81)
        return ValueRange(b.0 * lthr, b.1 * lthr)
    }
    func resolveTarget(for step: Step, athlete: AthleteProfile, benchmarks: Benchmarks, nudgeSteps: Int) -> StepTarget {
        let scale = 1 + 0.02 * Double(nudgeSteps)
        switch step.sport {
        case .swim:
            guard benchmarks.cssSecondsPer100m != nil else { return .rpe(ValueRange(3, 4)) }
            return .cssOffset(swimOffsetRange(SwimZone(level: step.level)))
        case .bike:
            if athlete.hasPowerMeter, let ftp = benchmarks.ftpWatts?.value {
                let r = bikePowerRange(BikePowerZone(level: step.level), ftp: ftp * scale)
                return .powerRange(r)
            }
            if let lthr = benchmarks.lthrBpm?.value {
                return .heartRateRange(heartRateRange(HeartRateZone(level: step.level), lthr: lthr * scale))
            }
            return .rpe(ValueRange(4, 5))
        case .run:
            if let pace = benchmarks.thresholdPaceSecondsPerKm?.value {
                let r = runPaceRange(RunZone(level: step.level), thresholdPace: pace / scale)
                return .pacePerKm(r)
            }
            return .rpe(ValueRange(4, 5))
        }
    }
    func cssFromTest(time400Seconds: Double, time200Seconds: Double, on date: Date) throws -> BenchmarkValue {
        throw PlanKitError.cssTestRejected
    }
    func ftpFromTest(best20MinutePower: Double, on date: Date) throws -> BenchmarkValue {
        throw PlanKitError.invalidInput("unused")
    }
    func bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: Double, on date: Date) throws -> BenchmarkValue {
        throw PlanKitError.invalidInput("unused")
    }
    func runThresholdFromTest(distanceKilometres: Double, finalTwentyMinuteAverageHeartRate: Double?, on date: Date) throws -> Benchmarks {
        throw PlanKitError.invalidInput("unused")
    }
    func seedFTP(fromPower samples: [SeriesSample], on date: Date) -> BenchmarkValue? { nil }
    func seedBikeLTHR(fromHeartRate samples: [SeriesSample], on date: Date) -> BenchmarkValue? { nil }
    func seedRunBenchmarks(speed: [SeriesSample], heartRate: [SeriesSample], on date: Date) -> Benchmarks { Benchmarks() }
}

final class CompileTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_000_000)
    private let testDate = Date(timeIntervalSince1970: 1_790_000_000)

    private var compiler: DefaultSessionCompiler { DefaultSessionCompiler(zones: FixedZones()) }

    private var athlete: AthleteProfile {
        AthleteProfile(
            level: .intermediate, weeklyHours: 8,
            availableWeekdays: [.monday, .wednesday, .saturday], poolWeekdays: [.monday],
            hasWatch: true, hasPowerMeter: true)
    }

    private var benchmarks: Benchmarks {
        Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: 95, isEstimated: false, date: testDate),
            ftpWatts: BenchmarkValue(value: 250, isEstimated: false, date: testDate),
            lthrBpm: BenchmarkValue(value: 170, isEstimated: false, date: testDate),
            thresholdPaceSecondsPerKm: BenchmarkValue(value: 300, isEstimated: false, date: testDate))
    }

    // MARK: Fixtures

    private func thresholdRun() -> Session {
        Session(
            id: "w02-20261111-run-1", sport: .run, name: "Threshold run", purpose: "Raise threshold.",
            steps: [
                Step(sport: .run, kind: .warmUp, durationSeconds: 600, level: 2, target: .rpe(ValueRange(3, 4)), name: "Easy jog"),
                Step(sport: .run, kind: .work, durationSeconds: 480, level: 4, target: .rpe(ValueRange(6, 7)),
                     repeatGroupID: "g1", repeatCount: 3, name: "Threshold"),
                Step(sport: .run, kind: .recovery, durationSeconds: 120, level: 1, target: .rpe(ValueRange(2, 3)),
                     repeatGroupID: "g1", repeatCount: 3, name: "Jog"),
                Step(sport: .run, kind: .coolDown, durationSeconds: 600, level: 2, name: "Cool down")
            ],
            scheduledDate: day, isQuality: true)
    }

    private func sweetSpotBike() -> Session {
        Session(
            id: "w02-20261112-bike-1", sport: .bike, name: "Sweet spot", purpose: "Build sustained power.",
            steps: [
                Step(sport: .bike, kind: .warmUp, durationSeconds: 900, level: 2, name: "Spin up"),
                Step(sport: .bike, kind: .work, durationSeconds: 1200, level: 4, target: .rpe(ValueRange(6, 7)),
                     repeatGroupID: "g1", repeatCount: 2, name: "Sweet spot"),
                Step(sport: .bike, kind: .recovery, durationSeconds: 300, level: 1,
                     repeatGroupID: "g1", repeatCount: 2, name: "Spin easy"),
                Step(sport: .bike, kind: .coolDown, durationSeconds: 600, level: 1, name: "Cool down")
            ],
            scheduledDate: day, isQuality: true)
    }

    private func poolSwim() -> Session {
        Session(
            id: "w02-20261109-swim-1", sport: .swim, name: "8 by 100", purpose: "Hold CSS pace.",
            steps: [
                Step(sport: .swim, kind: .warmUp, durationSeconds: 240, distanceMeters: 200, level: 2, name: "Easy 200"),
                Step(sport: .swim, kind: .work, durationSeconds: 95, distanceMeters: 100, level: 4,
                     target: .cssOffset(ValueRange(0, 0)), repeatGroupID: "g1", repeatCount: 8, name: "100 at CSS"),
                Step(sport: .swim, kind: .recovery, durationSeconds: 15, level: 1,
                     repeatGroupID: "g1", repeatCount: 8, name: "Rest"),
                Step(sport: .swim, kind: .coolDown, durationSeconds: 120, distanceMeters: 100, level: 1, name: "Easy 100")
            ],
            scheduledDate: day, isQuality: true)
    }

    private func brick() -> Session {
        Session(
            id: "w05-20261114-bike-1", sport: .bike, name: "Brick", purpose: "Practice the transition.",
            steps: [
                Step(sport: .bike, kind: .warmUp, durationSeconds: 600, level: 2, name: "Spin up"),
                Step(sport: .bike, kind: .work, durationSeconds: 2400, level: 3, name: "Steady"),
                Step(sport: .run, kind: .work, durationSeconds: 900, level: 3, name: "Run off the bike"),
                Step(sport: .run, kind: .coolDown, durationSeconds: 300, level: 1, name: "Walk it out")
            ],
            scheduledDate: day, brickSecondSport: .run, isQuality: true)
    }

    private func compile(
        _ session: Session,
        caps: DeviceCapabilities = .standard,
        benchmarks: Benchmarks? = nil,
        nudges: [Sport: Int] = [:],
        indoor: Bool = false
    ) throws -> CompiledSession {
        try compiler.compile(
            session, athlete: athlete, benchmarks: benchmarks ?? self.benchmarks,
            zoneNudgeSteps: nudges, capabilities: caps, indoor: indoor)
    }

    private func custom(_ workout: CompiledWorkout?, file: StaticString = #filePath, line: UInt = #line) -> CompiledCustomWorkout? {
        guard case .custom(let value)? = workout else {
            XCTFail("Expected a custom workout", file: file, line: line)
            return nil
        }
        return value
    }

    // MARK: Threshold run

    func testThresholdRunCompilesToSpeedRangeAlerts() throws {
        let compiled = try compile(thresholdRun())
        XCTAssertEqual(compiled.sessionID, "w02-20261111-run-1")
        XCTAssertEqual(compiled.workouts.count, 1)
        XCTAssertFalse(compiled.usesPhoneSetCard)
        guard let workout = custom(compiled.workouts.first) else { return }

        XCTAssertEqual(workout.activity, CompiledActivity(sport: .run, location: .outdoor))
        XCTAssertEqual(workout.displayName, "Threshold run")
        XCTAssertEqual(workout.warmUp?.goal, .time(seconds: 600))
        XCTAssertEqual(workout.warmUp?.displayName, "Easy jog")
        XCTAssertEqual(workout.coolDown?.goal, .time(seconds: 600))

        XCTAssertEqual(workout.blocks.count, 1)
        let block = workout.blocks[0]
        XCTAssertEqual(block.iterations, 3)
        XCTAssertEqual(block.steps.map(\.kind), [.work, .recovery])
        XCTAssertEqual(block.steps[0].goal, .time(seconds: 480))
        XCTAssertEqual(block.steps[0].rpeText, "RPE 6 to 7 of 10")

        // Threshold pace 300 s per km, plus or minus 10 s: 290 to 310 s per km is 3.226 to 3.448 m/s.
        guard case .speedRange(let speed) = block.steps[0].alert else {
            return XCTFail("Expected a speed range alert")
        }
        XCTAssertEqual(speed.lower, 1000.0 / 310.0, accuracy: 0.0001)
        XCTAssertEqual(speed.upper, 1000.0 / 290.0, accuracy: 0.0001)
        XCTAssertLessThan(speed.lower, speed.upper)
        XCTAssertTrue(compiled.notes.contains { $0.contains("fixed from your zones") })
    }

    func testZoneNudgeShiftsRanges() throws {
        let plain = try compile(thresholdRun())
        let nudged = try compile(thresholdRun(), nudges: [.run: 2])
        guard case .speedRange(let a)? = custom(plain.workouts.first)?.blocks.first?.steps.first?.alert,
              case .speedRange(let b)? = custom(nudged.workouts.first)?.blocks.first?.steps.first?.alert else {
            return XCTFail("Expected speed alerts")
        }
        XCTAssertGreaterThan(b.lower, a.lower)
        // A nudge on another sport changes nothing.
        let other = try compile(thresholdRun(), nudges: [.bike: 3])
        XCTAssertEqual(other, plain)
    }

    func testRunWithoutBenchmarksUsesFeelOnly() throws {
        let compiled = try compile(thresholdRun(), benchmarks: Benchmarks())
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.blocks[0].steps[0].alert, .none)
        XCTAssertNil(workout.blocks[0].steps[0].limitation)
        XCTAssertEqual(workout.blocks[0].steps[0].rpeText, "RPE 6 to 7 of 10")
        // With no zones the calculator answers with feel, and that feel text is used.
        XCTAssertEqual(workout.coolDown?.rpeText, "RPE 4 to 5 of 10")
        XCTAssertTrue(compiled.notes.contains { $0.contains("No run zones are set yet") })
    }

    // MARK: Sweet spot bike

    func testSweetSpotBikeCompilesToPowerRangeAlerts() throws {
        let compiled = try compile(sweetSpotBike())
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.activity, CompiledActivity(sport: .bike, location: .outdoor))
        XCTAssertEqual(workout.blocks.count, 1)
        XCTAssertEqual(workout.blocks[0].iterations, 2)
        XCTAssertEqual(workout.blocks[0].steps[0].goal, .time(seconds: 1200))
        guard case .powerRange(let watts) = workout.blocks[0].steps[0].alert else {
            return XCTFail("Expected a power range alert")
        }
        // Level 4 is 91 to 105 percent of an FTP of 250.
        XCTAssertEqual(watts.lower, 227.5, accuracy: 0.001)
        XCTAssertEqual(watts.upper, 262.5, accuracy: 0.001)
        XCTAssertEqual(workout.blocks[0].steps[1].kind, .recovery)
        XCTAssertEqual(workout.warmUp?.displayName, "Spin up")
        XCTAssertEqual(workout.coolDown?.goal, .time(seconds: 600))
    }

    func testBikeWithoutPowerMeterUsesHeartRateRange() throws {
        var rider = athlete
        rider.hasPowerMeter = false
        let compiled = try compiler.compile(
            sweetSpotBike(), athlete: rider, benchmarks: benchmarks, zoneNudgeSteps: [:],
            capabilities: .standard, indoor: true)
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.activity.location, .indoor)
        guard case .heartRateRange(let bpm) = workout.blocks[0].steps[0].alert else {
            return XCTFail("Expected a heart rate range alert")
        }
        XCTAssertEqual(bpm.lower, 0.94 * 170, accuracy: 0.001)
        XCTAssertEqual(bpm.upper, 1.02 * 170, accuracy: 0.001)
    }

    func testUnsupportedBikePowerAlertShipsGoalOnly() throws {
        var caps = DeviceCapabilities.standard
        caps.supportsBikePowerAlert = false
        let compiled = try compile(sweetSpotBike(), caps: caps)
        guard let workout = custom(compiled.workouts.first) else { return }
        let work = workout.blocks[0].steps[0]
        XCTAssertEqual(work.alert, .none)
        XCTAssertEqual(work.goal, .time(seconds: 1200))
        XCTAssertEqual(work.limitation, "No power alert on this watch. Target 228 to 263 watts.")
        XCTAssertTrue(compiled.notes.contains { $0.contains("will not show power alerts for the bike") })
        XCTAssertFalse(compiled.usesPhoneSetCard)
    }

    // MARK: Pool swim

    func testEightByHundredPoolSwimUsesDistanceWithTimeGoal() throws {
        let compiled = try compile(poolSwim())
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.activity, CompiledActivity(sport: .swim, location: .pool))
        XCTAssertEqual(workout.warmUp?.goal, .distance(meters: 200))
        XCTAssertEqual(workout.coolDown?.goal, .distance(meters: 100))
        XCTAssertEqual(workout.blocks.count, 1)
        XCTAssertEqual(workout.blocks[0].iterations, 8)
        let rep = workout.blocks[0].steps[0]
        XCTAssertEqual(rep.kind, .work)
        XCTAssertEqual(rep.goal, .distanceWithTime(meters: 100, seconds: 95))
        XCTAssertEqual(rep.alert, .none)
        XCTAssertEqual(workout.blocks[0].steps[1].goal, .time(seconds: 15))
        XCTAssertNil(rep.limitation)
    }

    func testPoolPaceFollowsZoneOffset() throws {
        var session = poolSwim()
        session.steps[1].level = 5
        session.steps[1].target = .none
        let compiled = try compile(session)
        // Level 5 is CSS minus 8 to minus 4, midpoint minus 6: 89 s per 100 m.
        XCTAssertEqual(custom(compiled.workouts.first)?.blocks[0].steps[0].goal, .distanceWithTime(meters: 100, seconds: 89))
    }

    func testSwimWithoutCSSFallsBackToDistanceGoal() throws {
        let compiled = try compile(poolSwim(), benchmarks: Benchmarks())
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.blocks[0].steps[0].goal, .distance(meters: 100))
        XCTAssertNil(workout.blocks[0].steps[0].limitation)
        XCTAssertTrue(compiled.notes.contains { $0.contains("No swim zones are set yet") })
    }

    func testMissingDistanceWithTimeSupportDowngradesToDistanceGoal() throws {
        var caps = DeviceCapabilities.standard
        caps.supportsPoolSwimDistanceWithTimeGoal = false
        let compiled = try compile(poolSwim(), caps: caps)
        guard let workout = custom(compiled.workouts.first) else { return }
        let rep = workout.blocks[0].steps[0]
        XCTAssertEqual(rep.goal, .distance(meters: 100))
        XCTAssertEqual(rep.limitation, "No time goal on this watch. Target 1:35 for 100 m.")
        XCTAssertTrue(compiled.notes.contains { $0.contains("cannot take a time goal on pool reps") })
    }

    func testOpenWaterSwimCompilesItsPoolAlternative() throws {
        var session = poolSwim()
        session.isOpenWater = true
        session.poolAlternativeSteps = [
            Step(sport: .swim, kind: .work, durationSeconds: 1200, distanceMeters: 800, level: 3, name: "Steady 800")
        ]
        let compiled = try compile(session)
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertEqual(workout.activity.location, .pool)
        XCTAssertEqual(workout.blocks[0].steps.count, 1)
        XCTAssertEqual(workout.blocks[0].steps[0].displayName, "Steady 800")
        XCTAssertTrue(compiled.notes.contains { $0.contains("Open water workouts cannot go to the watch") })
    }

    // MARK: Brick

    func testBrickCompilesToTwoWorkoutsBikeThenRun() throws {
        let compiled = try compile(brick())
        XCTAssertEqual(compiled.workouts.count, 2)
        guard let bike = custom(compiled.workouts.first), let run = custom(compiled.workouts.last) else { return }
        XCTAssertEqual(bike.activity.sport, .bike)
        XCTAssertEqual(run.activity.sport, .run)
        XCTAssertEqual(bike.displayName, "Brick: bike")
        XCTAssertEqual(run.displayName, "Brick: run")
        XCTAssertEqual(bike.warmUp?.goal, .time(seconds: 600))
        XCTAssertEqual(bike.blocks[0].steps[0].goal, .time(seconds: 2400))
        XCTAssertNil(run.warmUp)
        XCTAssertEqual(run.blocks[0].steps[0].goal, .time(seconds: 900))
        XCTAssertEqual(run.coolDown?.goal, .time(seconds: 300))
        XCTAssertTrue(compiled.notes.contains { $0.contains("bike first, then run") })
    }

    func testIndoorFlagMovesTheBikePartIndoorsAndKeepsTheRunOutdoors() throws {
        let compiled = try compile(brick(), indoor: true)
        XCTAssertEqual(custom(compiled.workouts.first)?.activity.location, .indoor)
        XCTAssertEqual(custom(compiled.workouts.last)?.activity.location, .outdoor)
    }

    func testBrickMissingAPartThrows() {
        var session = brick()
        session.steps = session.steps.filter { $0.sport == .bike }
        XCTAssertThrowsError(try compile(session)) { error in
            guard case PlanKitError.uncompilableSession = error else { return XCTFail("Wrong error \(error)") }
        }
    }

    // MARK: Race day

    func testRaceDayLegsAreOrderedWithOpenGoals() {
        for distance in RaceDistance.allCases {
            let workout = compiler.compileRaceDay(distance: distance, displayName: "Race day")
            guard case .swimBikeRun(let race) = workout else { return XCTFail("Expected swim bike run") }
            XCTAssertEqual(workout.displayName, "Race day")
            XCTAssertEqual(race.legs.map(\.activity.sport), [.swim, .bike, .run])
            XCTAssertEqual(race.legs.map(\.goal), [.open, .open, .open])
            XCTAssertEqual(race.legs[0].activity.location, .outdoor)
        }
    }

    // MARK: Capability tiers

    func testOlderWatchSendsPoolSwimAsGoalOnlyWorkout() throws {
        let compiled = try compile(poolSwim(), caps: .olderWatch)
        XCTAssertEqual(compiled.workouts.count, 1)
        guard case .singleGoal(let single) = compiled.workouts[0] else { return XCTFail("Expected a single goal workout") }
        XCTAssertEqual(single.activity, CompiledActivity(sport: .swim, location: .pool))
        // 200 + 8 by 100 + 100.
        XCTAssertEqual(single.goal, .distance(meters: 1100))
        XCTAssertTrue(compiled.usesPhoneSetCard)
        XCTAssertTrue(compiled.notes.contains { $0.contains("total distance goal only") })
    }

    func testOlderWatchPoolSwimFallsBackToPrintedSetCardWhenChecksFail() throws {
        var pool = ActivityCapability.allSupported(sport: .swim, location: .pool)
        pool.supportsDistanceGoal = false
        var activities = CapabilityReport.allSupported.activities.filter { !($0.sport == .swim) }
        activities.append(pool)
        let report = CapabilityReport(activities: activities, olderWatchSetting: true)
        let compiled = try compiler.compile(
            poolSwim(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:], report: report, indoor: false)
        XCTAssertTrue(compiled.workouts.isEmpty)
        XCTAssertTrue(compiled.usesPhoneSetCard)
        XCTAssertTrue(compiled.notes.contains { $0.contains("stays on your phone") })
    }

    func testOlderWatchRunKeepsAlertsButUsesStockLabels() throws {
        let compiled = try compile(thresholdRun(), caps: .olderWatch)
        guard let workout = custom(compiled.workouts.first) else { return }
        XCTAssertFalse(compiled.usesPhoneSetCard)
        if case .speedRange = workout.blocks[0].steps[0].alert {} else { XCTFail("Run alerts still ship") }
        XCTAssertEqual(workout.blocks[0].steps[0].displayName, "Threshold")
        XCTAssertTrue(compiled.notes.contains { $0.contains("stock Work and Recovery labels") })
        XCTAssertEqual(CapabilityTiering.delivery(
            for: CompiledActivity(sport: .run, location: .outdoor),
            report: CapabilityReport(capabilities: .olderWatch)).showsStepNames, false)
    }

    func testOlderWatchPoolSwimNeverGetsTheTimeGoal() {
        let report = CapabilityReport(capabilities: DeviceCapabilities(tier: .olderWatch))
        let delivery = CapabilityTiering.delivery(for: CompiledActivity(sport: .swim, location: .pool), report: report)
        XCTAssertEqual(delivery.delivery, .goalOnlyWorkout)
        XCTAssertFalse(delivery.allowsDistanceWithTimeGoal)
        XCTAssertFalse(delivery.allowsHeartRateAlert)
    }

    func testNoWatchKeepsSessionOnPhoneAndPhoneWorkoutsKeepTargets() throws {
        let compiled = try compile(thresholdRun(), caps: .noWatch)
        XCTAssertTrue(compiled.workouts.isEmpty)
        XCTAssertTrue(compiled.usesPhoneSetCard)
        XCTAssertTrue(compiled.notes.contains { $0.contains("No watch is connected") })
        XCTAssertFalse(compiled.notes.contains { $0.contains("Alert ranges on your watch") })

        let phone = try compiler.compilePhoneWorkouts(
            thresholdRun(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:], indoor: false)
        XCTAssertEqual(phone.count, 1)
        if case .speedRange = custom(phone.first)?.blocks.first?.steps.first?.alert {} else {
            XCTFail("The phone player keeps every target")
        }
    }

    func testRunPowerAlertsAreOutdoorOnly() throws {
        var session = thresholdRun()
        session.steps[1].target = .powerRange(ValueRange(200, 230))
        // The calculator answers with feel only, so the step's own concrete target is used.
        let bare = Benchmarks()
        let outdoor = try compile(session, benchmarks: bare, indoor: false)
        if case .powerRange(let range)? = custom(outdoor.workouts.first)?.blocks.first?.steps.first?.alert {
            XCTAssertEqual(range, ValueRange(200, 230))
        } else {
            XCTFail("Outdoor run power alert expected")
        }

        let indoor = try compile(session, benchmarks: bare, indoor: true)
        let step = custom(indoor.workouts.first)?.blocks.first?.steps.first
        XCTAssertEqual(step?.alert, CompiledAlert.none)
        XCTAssertEqual(step?.limitation, "Run power alerts work outdoors only. Target 200 to 230 watts.")
        XCTAssertTrue(indoor.notes.contains { $0.contains("outdoors only") })
    }

    func testSwimAcceptsHeartRateAlertsOnly() throws {
        var session = poolSwim()
        session.steps[1].target = .heartRateRange(ValueRange(140, 155))
        let bare = Benchmarks()
        var caps = DeviceCapabilities.standard
        caps.supportsSwimHeartRateAlert = true
        let compiled = try compile(session, caps: caps, benchmarks: bare)
        XCTAssertEqual(custom(compiled.workouts.first)?.blocks.first?.steps.first?.alert, .heartRateRange(ValueRange(140, 155)))

        caps.supportsSwimHeartRateAlert = false
        let dropped = try compile(session, caps: caps, benchmarks: bare)
        XCTAssertEqual(custom(dropped.workouts.first)?.blocks.first?.steps.first?.alert, CompiledAlert.none)
    }

    func testCapabilityReportRoundTripsToDeviceCapabilities() {
        XCTAssertEqual(CapabilityReport.allSupported.deviceCapabilities, .standard)
        XCTAssertEqual(CapabilityReport.allSupported.tier, .standard)
        XCTAssertEqual(CapabilityReport(capabilities: .standard).deviceCapabilities, .standard)

        var older = CapabilityReport.allSupported
        older.olderWatchSetting = true
        XCTAssertEqual(older.tier, .olderWatch)
        XCTAssertFalse(older.deviceCapabilities.supportsStepDisplayNames)
        XCTAssertFalse(older.deviceCapabilities.supportsPoolSwimDistanceWithTimeGoal)

        var gone = CapabilityReport.allSupported
        gone.watchAvailable = false
        XCTAssertEqual(gone.tier, .noWatch)
        XCTAssertEqual(gone.deviceCapabilities, .noWatch)
    }

    func testMissingActivityEntryCountsAsUnsupported() throws {
        let report = CapabilityReport(activities: [])
        let compiled = try compiler.compile(
            thresholdRun(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:], report: report, indoor: false)
        XCTAssertTrue(compiled.workouts.isEmpty)
        XCTAssertTrue(compiled.usesPhoneSetCard)
        XCTAssertTrue(CapabilityTiering.summary(for: report).allSatisfy { $0.contains("stays on your phone") })
    }

    func testDefaultZoneCalculatorGivesRangeAlertsEndToEnd() throws {
        let real = DefaultSessionCompiler()
        let run = try real.compile(
            thresholdRun(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:],
            capabilities: .standard, indoor: false)
        guard case .speedRange(let speed)? = custom(run.workouts.first)?.blocks.first?.steps.first?.alert else {
            return XCTFail("Expected a speed range alert from the default zones")
        }
        XCTAssertTrue(speed.lower > 0 && speed.upper > speed.lower)
        XCTAssertTrue(speed.contains(1000.0 / 300.0), "Threshold pace sits inside its own work zone")

        let bike = try real.compile(
            sweetSpotBike(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:],
            capabilities: .standard, indoor: false)
        if case .powerRange(let watts)? = custom(bike.workouts.first)?.blocks.first?.steps.first?.alert {
            XCTAssertTrue(watts.lower > 0 && watts.upper > watts.lower)
        } else {
            XCTFail("Expected a power range alert from the default zones")
        }

        let swim = try real.compile(
            poolSwim(), athlete: athlete, benchmarks: benchmarks, zoneNudgeSteps: [:],
            capabilities: .standard, indoor: false)
        if case .distanceWithTime(let meters, let seconds)? = custom(swim.workouts.first)?.blocks.first?.steps.first?.goal {
            XCTAssertEqual(meters, 100)
            XCTAssertTrue((85...105).contains(seconds), "Level 4 swim reps sit near CSS of 95 s per 100 m")
        } else {
            XCTFail("Expected a distance with time goal from the default zones")
        }
    }

    // MARK: Failure paths and hygiene

    func testSessionWithoutStepsThrows() {
        let empty = Session(id: "x", sport: .run, name: "Empty", purpose: "none", steps: [], scheduledDate: day)
        XCTAssertThrowsError(try compile(empty)) { error in
            XCTAssertEqual(error as? PlanKitError, .uncompilableSession("The session has no steps."))
        }
    }

    func testMixedSportStepsWithoutBrickThrow() {
        var session = thresholdRun()
        session.steps[0].sport = .bike
        XCTAssertThrowsError(try compile(session)) { error in
            guard case PlanKitError.uncompilableSession = error else { return XCTFail("Wrong error \(error)") }
        }
    }

    func testAbsurdValuesDoNotTrap() throws {
        var session = thresholdRun()
        session.steps[0].durationSeconds = .infinity
        session.steps[1].target = .pacePerKm(ValueRange(.nan, .infinity))
        _ = try compile(session, benchmarks: Benchmarks())
        XCTAssertEqual(CompileSupport.clock(.nan), "0:00")
        XCTAssertEqual(CompileSupport.clock(1e30), "277777:46:40")
        XCTAssertNil(CompileSupport.speedRange(fromPaceRange: ValueRange(0, 300)))
    }

    func testCompilingTwiceGivesTheSameResult() throws {
        XCTAssertEqual(try compile(brick()), try compile(brick()))
        XCTAssertEqual(try compile(poolSwim()), try compile(poolSwim()))
    }

    func testCopyHasNoDashesOrBannedMarks() throws {
        let sessions = [thresholdRun(), sweetSpotBike(), poolSwim(), brick()]
        var texts: [String] = []
        for caps in [DeviceCapabilities.standard, .olderWatch, .noWatch] {
            for session in sessions {
                let compiled = try compile(session, caps: caps, benchmarks: Benchmarks())
                texts.append(contentsOf: compiled.notes)
            }
        }
        var limited = DeviceCapabilities.standard
        limited.supportsBikePowerAlert = false
        limited.supportsPoolSwimDistanceWithTimeGoal = false
        for session in sessions {
            let compiled = try compile(session, caps: limited)
            texts.append(contentsOf: compiled.notes)
            for case .custom(let workout) in compiled.workouts {
                let steps = (workout.warmUp.map { [$0] } ?? []) + workout.blocks.flatMap(\.steps) + (workout.coolDown.map { [$0] } ?? [])
                texts.append(contentsOf: steps.compactMap(\.limitation))
                texts.append(contentsOf: steps.compactMap(\.rpeText))
            }
        }
        texts.append(contentsOf: CapabilityTiering.summary(for: .allSupported))
        XCTAssertFalse(texts.isEmpty)
        // Spelled in pieces so this file itself stays clear of the copy scan.
        let banned = ["doc" + "tor", "inj" + "ury", "ill" + "ness"]
        for text in texts {
            XCTAssertFalse(text.contains("\u{2014}"), text)
            XCTAssertFalse(text.contains("\u{2013}"), text)
            for word in banned {
                XCTAssertFalse(text.lowercased().contains(word), text)
            }
        }
    }

    func testCompiledSessionRoundTripsThroughJSON() throws {
        let compiled = try compile(poolSwim())
        let data = try JSONEncoder().encode(compiled)
        XCTAssertEqual(try JSONDecoder().decode(CompiledSession.self, from: data), compiled)
    }

    // MARK: WorkoutKit bridge

    #if canImport(WorkoutKit)
    @available(iOS 18, macOS 15, watchOS 11, *)
    func testBridgeBuildsCustomWorkoutFromThresholdRun() throws {
        let compiled = try compile(thresholdRun())
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let plans = WorkoutKitBridge.makePlans(from: compiled, capabilities: .standard) { _ in id }
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].id, id)
        guard case .custom(let workout) = plans[0].workout else { return XCTFail("Expected a custom workout") }
        XCTAssertEqual(workout.activity, .running)
        XCTAssertEqual(workout.location, .outdoor)
        XCTAssertEqual(workout.displayName, "Threshold run")
        XCTAssertEqual(workout.blocks.count, 1)
        XCTAssertEqual(workout.blocks[0].iterations, 3)
        XCTAssertEqual(workout.blocks[0].steps.map(\.purpose), [.work, .recovery])
        XCTAssertEqual(workout.blocks[0].steps[0].step.goal, .time(480, .seconds))
        XCTAssertEqual(workout.blocks[0].steps[0].step.displayName, "Threshold")
        XCTAssertTrue(workout.blocks[0].steps[0].step.alert is SpeedRangeAlert)
        XCTAssertEqual(workout.warmup?.goal, .time(600, .seconds))
    }

    @available(iOS 18, macOS 15, watchOS 11, *)
    func testBridgeOmitsStepNamesOnTheOlderWatchTier() throws {
        let compiled = try compile(thresholdRun(), caps: .olderWatch)
        let plans = WorkoutKitBridge.makePlans(from: compiled, capabilities: .olderWatch) { _ in UUID() }
        guard case .custom(let workout)? = plans.first?.workout else { return XCTFail("Expected a custom workout") }
        XCTAssertNil(workout.warmup?.displayName)
        XCTAssertNil(workout.blocks[0].steps[0].step.displayName)
    }

    @available(iOS 18, macOS 15, watchOS 11, *)
    func testBridgeMapsPoolSwimGoalAndHeartRateAndPowerAlerts() throws {
        let compiled = try compile(poolSwim())
        guard let swim = custom(compiled.workouts.first) else { return }
        let rep = WorkoutKitBridge.workoutStep(from: swim.blocks[0].steps[0], includeName: true)
        XCTAssertEqual(
            rep.goal,
            .poolSwimDistanceWithTime(
                Measurement(value: 100, unit: UnitLength.meters), Measurement(value: 95, unit: UnitDuration.seconds)))
        XCTAssertTrue(WorkoutKitBridge.alert(from: .powerRange(ValueRange(200, 250))) is PowerRangeAlert)
        XCTAssertTrue(WorkoutKitBridge.alert(from: .heartRateRange(ValueRange(140, 155))) is HeartRateRangeAlert)
        XCTAssertNil(WorkoutKitBridge.alert(from: .none))
        XCTAssertNil(WorkoutKitBridge.alert(from: .powerRange(ValueRange(.nan, 250))))
    }

    @available(iOS 18, macOS 15, watchOS 11, *)
    func testBridgeBuildsSingleGoalAndRaceDayPlans() throws {
        let single = try compile(poolSwim(), caps: .olderWatch)
        let plans = WorkoutKitBridge.makePlans(from: single, capabilities: .olderWatch) { _ in UUID() }
        guard case .goal(let goal)? = plans.first?.workout else { return XCTFail("Expected a goal workout") }
        XCTAssertEqual(goal.activity, .swimming)
        XCTAssertEqual(goal.swimmingLocation, .pool)
        XCTAssertEqual(goal.goal, .distance(1100, .meters))

        let race = compiler.compileRaceDay(distance: .olympic, displayName: "Race day")
        let plan = WorkoutKitBridge.makePlan(from: race, id: UUID(), includeStepNames: true)
        guard case .swimBikeRun(let workout) = plan.workout else { return XCTFail("Expected swim bike run") }
        XCTAssertEqual(workout.activities, [.swimming(.openWater), .cycling(.outdoor), .running(.outdoor)])
        XCTAssertTrue(SwimBikeRunWorkout.supportsActivityOrdering(workout.activities))
    }
    #endif
}
