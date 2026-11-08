import XCTest
@testable import BricklinePlanKit

/// Tests for the review fixes in the compiler, the zone calculator, the race window, the Load model, the model
/// types and the PlanKit facade.
final class ReviewEngineTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    private let day0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let zones = DefaultZoneCalculator()
    private let compiler = DefaultSessionCompiler()

    private func athlete(power: Bool = true, runWalk: Bool = false) -> AthleteProfile {
        AthleteProfile(
            level: .intermediate, weeklyHours: 8, availableWeekdays: Set(Weekday.allCases),
            poolWeekdays: [.tuesday, .thursday, .saturday], hasWatch: true, hasPowerMeter: power, prefersRunWalk: runWalk)
    }

    private func allBenchmarks() -> Benchmarks {
        Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: 105, isEstimated: false, date: day0),
            ftpWatts: BenchmarkValue(value: 220, isEstimated: false, date: day0),
            lthrBpm: BenchmarkValue(value: 165, isEstimated: false, date: day0),
            thresholdPaceSecondsPerKm: BenchmarkValue(value: 330, isEstimated: false, date: day0),
            runLthrBpm: BenchmarkValue(value: 172, isEstimated: false, date: day0))
    }

    private func buildContext(runWalk: Bool = false, distance: RaceDistance = .olympic, level: Level = .intermediate) -> BuildContext {
        BuildContext(
            level: level, phase: .build, distance: distance, runWalk: runWalk, css: 105, allowSteady: true,
            brickRunSeconds: 600)
    }

    private func steps(of workout: CompiledWorkout) -> [CompiledStep] {
        guard case let .custom(custom) = workout else { return [] }
        return [custom.warmUp].compactMap { $0 } + custom.blocks.flatMap(\.steps) + [custom.coolDown].compactMap { $0 }
    }

    // MARK: Walk steps

    func testRunWalkSessionCarriesNoPaceAlertOnWalkBreaksWarmUpOrCoolDown() throws {
        let ctx = buildContext(runWalk: true, distance: .sprint, level: .firstTimer)
        let built = StepFactory.build(.runEasy, seconds: 2400, ctx: ctx).steps
        let session = Session(
            id: "rw", sport: .run, name: "Run walk session", purpose: "Purpose.", steps: built, scheduledDate: day0)
        let compiled = try compiler.compile(
            session, athlete: athlete(runWalk: true), benchmarks: allBenchmarks(), zoneNudgeSteps: [:],
            capabilities: .standard, indoor: false)
        let all = compiled.workouts.flatMap(steps(of:))
        XCTAssertFalse(all.isEmpty)
        for step in all where step.displayName.lowercased().contains("walk") {
            XCTAssertEqual(step.alert, CompiledAlert.none, "\(step.displayName) must not buzz")
        }
        let interval = try XCTUnwrap(all.first { $0.displayName == "Easy run interval" })
        if case .speedRange = interval.alert {} else { XCTFail("the running interval keeps its pace alert") }
        XCTAssertFalse(compiled.notes.contains { $0.contains("zones are set yet") }, "feel only steps are not a missing zone")
    }

    func testEasyWarmUpsRecoveriesAndCoolDownsResolveToFeel() {
        let b = allBenchmarks()
        func resolve(_ kind: StepKind, level: Int, name: String = "Step") -> StepTarget {
            let step = Step(sport: .run, kind: kind, durationSeconds: 300, level: level, target: .rpe(ValueRange(1, 2)), name: name)
            return zones.resolveTarget(for: step, athlete: athlete(), benchmarks: b, nudgeSteps: 0)
        }
        XCTAssertEqual(resolve(.warmUp, level: 1), .rpe(ValueRange(1, 2)))
        XCTAssertEqual(resolve(.recovery, level: 1), .rpe(ValueRange(1, 2)))
        XCTAssertEqual(resolve(.coolDown, level: 1), .rpe(ValueRange(1, 2)))
        if case .pacePerKm = resolve(.work, level: 2) {} else { XCTFail("an easy running step keeps its pace range") }
        let walker = Step(sport: .run, kind: .work, durationSeconds: 60, level: 2, target: .rpe(ValueRange(3, 4)), name: "Walk break")
        XCTAssertEqual(
            zones.resolveTarget(for: walker, athlete: athlete(runWalk: true), benchmarks: b, nudgeSteps: 0),
            .rpe(ValueRange(3, 4)))
    }

    func testSwimTargetsResolveToAbsolutePacePerHundredMetres() {
        let step = Step(sport: .swim, kind: .work, durationSeconds: 100, distanceMeters: 100, level: 4, target: .cssOffset(ValueRange(-3, 3)), name: "Rep")
        let resolved = zones.resolveTarget(for: step, athlete: athlete(), benchmarks: allBenchmarks(), nudgeSteps: 0)
        XCTAssertEqual(resolved, .pacePer100m(ValueRange(102, 108)))
    }

    func testSwimGoalsReadSwimPacesAndNeverReadARunPaceAsOne() throws {
        func compile(_ target: StepTarget) throws -> CompiledStep {
            let rep = Step(sport: .swim, kind: .work, durationSeconds: 105, distanceMeters: 100, level: 3, target: target, name: "Rep")
            let session = Session(id: "s", sport: .swim, name: "Swim", purpose: "P.", steps: [rep], scheduledDate: day0)
            let compiled = try compiler.compile(
                session, athlete: athlete(), benchmarks: allBenchmarks(), zoneNudgeSteps: [:],
                capabilities: .standard, indoor: false)
            return try XCTUnwrap(compiled.workouts.flatMap(steps(of:)).first)
        }
        XCTAssertEqual(try compile(.pacePer100m(ValueRange(100, 110))).goal, .distanceWithTime(meters: 100, seconds: 105))
        // A run pace of 250 s/km on a swim step used to be guessed as 250 s per 100 m. Now it is simply not a swim
        // pace, so the rep carries its distance only.
        XCTAssertEqual(try compile(.pacePerKm(ValueRange(250, 260))).goal, .distance(meters: 100))
    }

    // MARK: Test sessions

    func testTestSessionsCarryNoAlertsAndNoTargetTimes() throws {
        let kinds: [SessionKind] = [.swimTest, .bikeTestFTP, .bikeTestLTHR, .runTest]
        for kind in kinds {
            let built = StepFactory.build(kind, seconds: 0, ctx: buildContext())
            func session(isTest: Bool) -> Session {
                Session(
                    id: "t-\(kind.rawValue)", sport: kind.sport, name: SessionLibrary.name(for: kind), purpose: "P.",
                    steps: built.steps, scheduledDate: day0, isQuality: true, isTest: isTest, benchmarkKind: kind.benchmarkKind)
            }
            let compiled = try compiler.compile(
                session(isTest: true), athlete: athlete(), benchmarks: allBenchmarks(), zoneNudgeSteps: [.bike: 2, .run: 2],
                capabilities: .standard, indoor: false)
            let all = compiled.workouts.flatMap(steps(of:))
            XCTAssertFalse(all.isEmpty, "\(kind)")
            for step in all {
                XCTAssertEqual(step.alert, CompiledAlert.none, "\(kind) \(step.displayName)")
                if case .distanceWithTime = step.goal { XCTFail("\(kind) \(step.displayName) has a target time") }
                XCTAssertNotNil(step.rpeText)
            }
            XCTAssertFalse(compiled.notes.contains { $0.contains("zones are set yet") }, "\(kind) notes: \(compiled.notes)")

            // The same steps in an ordinary session do get alerts when zones exist, so the test flag is what matters.
            if kind != .swimTest {
                let ordinary = try compiler.compile(
                    session(isTest: false), athlete: athlete(), benchmarks: allBenchmarks(), zoneNudgeSteps: [:],
                    capabilities: .standard, indoor: false)
                XCTAssertTrue(ordinary.workouts.flatMap(steps(of:)).contains { $0.alert != CompiledAlert.none }, "\(kind)")
            }
        }
    }

    // MARK: Open water

    func testOpenWaterSessionWithoutAPoolAlternativeIsRefused() throws {
        let rep = Step(sport: .swim, kind: .work, durationSeconds: 600, level: 2, target: .rpe(ValueRange(3, 4)), name: "Swim")
        var open = Session(
            id: "ow", sport: .swim, name: "Open water", purpose: "P.", steps: [rep], scheduledDate: day0, isOpenWater: true)
        XCTAssertThrowsError(try compiler.compile(
            open, athlete: athlete(), benchmarks: Benchmarks(), zoneNudgeSteps: [:], capabilities: .standard, indoor: false)) {
            guard case .uncompilableSession? = $0 as? PlanKitError else { return XCTFail("\($0)") }
        }
        open.poolAlternativeSteps = [rep]
        let compiled = try compiler.compile(
            open, athlete: athlete(), benchmarks: Benchmarks(), zoneNudgeSteps: [:], capabilities: .standard, indoor: false)
        XCTAssertTrue(compiled.notes.contains { $0.contains("pool version") })
    }

    // MARK: Facade

    private func smallPlan() throws -> Plan {
        try PlanKit().makePlan(
            raceDistance: .sprint, raceDate: date(2027, 1, 24), startDate: date(2026, 11, 9), athlete: athlete(),
            benchmarks: allBenchmarks(), calendar: cal)
    }

    func testCompileAllReportsOneBadSessionWithoutBlockingTheWeek() throws {
        var plan = try smallPlan()
        let bad = Session(id: "bad", sport: .run, name: "Empty", purpose: "P.", steps: [], scheduledDate: plan.weeks[1].startDate)
        plan.adaptInsert(bad, calendar: cal)
        let results = PlanKit().compileAll(plan, benchmarks: allBenchmarks())
        XCTAssertEqual(results.compactMap { $0.failure != nil ? $0.sessionID : nil }, ["bad"])
        XCTAssertEqual(results.count, plan.allSessions.count)
        XCTAssertEqual(results.map(\.sessionID), plan.allSessions.map(\.id), "date order")
        XCTAssertTrue(results.filter { $0.sessionID != "bad" }.allSatisfy { $0.compiled != nil })
    }

    func testPhoneWorkoutsAreReachableThroughTheFacadeAndIgnoreWatchLimits() throws {
        let plan = try smallPlan()
        let kit = PlanKit()
        let swim = try XCTUnwrap(plan.allSessions.first { $0.sport == .swim })
        let watch = try kit.compile(swim, in: plan, benchmarks: allBenchmarks(), capabilities: .noWatch)
        XCTAssertTrue(watch.workouts.isEmpty)
        let phone = try kit.compilePhoneWorkouts(swim, in: plan, benchmarks: allBenchmarks())
        XCTAssertFalse(phone.isEmpty)
    }

    func testDebriefAndBikeSpeedThroughTheFacade() throws {
        let kit = PlanKit()
        let b = allBenchmarks()
        let typical = kit.racePlan(distance: .olympic, athlete: athlete(), benchmarks: b)
        let bike = try XCTUnwrap(typical.pacing.targets.first { $0.leg.sport == .bike })
        XCTAssertEqual(bike.durationBasis, .typicalForLevel, "an FTP band does not give a leg time")

        let report = kit.debrief(card: typical.pacing, actuals: RaceActuals(swimSeconds: 1500, bikeSeconds: 3700, runSeconds: 3000))
        let bikeRow = try XCTUnwrap(report.legs.first { $0.leg.sport == .bike })
        XCTAssertEqual(bikeRow.deviation, .noPlan)
        XCTAssertTrue(bikeRow.line.contains("typical time for your level"), bikeRow.line)
        XCTAssertFalse(bikeRow.line.contains("slower") || bikeRow.line.contains("faster"))
        XCTAssertTrue(report.summaryLine.contains("typical times for your level"), report.summaryLine)
        // Swim and run came from the athlete's own benchmarks, so they keep a verdict.
        XCTAssertNotEqual(try XCTUnwrap(report.legs.first { $0.leg.sport == .swim }).deviation, .noPlan)

        let entered = kit.racePlan(distance: .olympic, athlete: athlete(), benchmarks: b, bikeSpeedKph: 30)
        let enteredBike = try XCTUnwrap(entered.pacing.targets.first { $0.leg.sport == .bike })
        XCTAssertEqual(enteredBike.durationBasis, .athleteEntered)
        XCTAssertEqual(enteredBike.expectedDurationSeconds.midpoint, 40.0 / 30 * 3600, accuracy: 120)
        let verdict = kit.debrief(card: entered.pacing, actuals: RaceActuals(bikeSeconds: 6000))
        XCTAssertEqual(verdict.legs.first { $0.leg.sport == .bike }?.deviation, .slower)

        let nonsense = kit.racePlan(distance: .olympic, athlete: athlete(), benchmarks: b, bikeSpeedKph: 400)
        XCTAssertEqual(nonsense.pacing.targets.first { $0.leg.sport == .bike }?.durationBasis, .typicalForLevel)
        let noSwimTest = kit.racePlan(distance: .olympic, athlete: athlete(), benchmarks: Benchmarks())
        XCTAssertEqual(noSwimTest.pacing.targets.first { $0.leg.sport == .swim }?.durationBasis, .typicalForLevel)
        XCTAssertEqual(typical.pacing.targets.first { $0.leg.sport == .swim }?.durationBasis, .fromBenchmark)
    }

    func testFuelingNearATierEdgeTakesTheLowerTierWhenTheTimeIsOnlyTypical() throws {
        let leg = RaceLeg(sport: .bike, distanceKm: 40)
        let range = ValueRange(4500, 5100) // midpoint 80 minutes, five minutes over the 75 minute edge
        func advice(_ basis: DurationBasis) throws -> FuelingAdvice {
            let target = PacingTarget(leg: leg, target: .rpe(ValueRange(6, 7)), expectedDurationSeconds: range, summary: "", durationBasis: basis)
            let card = PacingCard(distance: .olympic, targets: [target], caveat: "")
            return try XCTUnwrap(DefaultRaceWindow().fueling(for: card).first)
        }
        XCTAssertEqual(try advice(.fromBenchmark).tier, .moderate)
        let typical = try advice(.typicalForLevel)
        XCTAssertEqual(typical.tier, .fluidsOnly)
        XCTAssertTrue(typical.practiceLine.contains("either side of a fueling step"))
    }

    func testMergedBenchmarksLetATestBeatASeedAndNewerBeatOlder() {
        let tested = BenchmarkValue(value: 250, isEstimated: false, date: date(2026, 10, 1))
        let seed = BenchmarkValue(value: 270, isEstimated: true, date: date(2026, 12, 1))
        let newerTest = BenchmarkValue(value: 255, isEstimated: false, date: date(2026, 11, 1))
        let current = Benchmarks(ftpWatts: tested, lthrBpm: seed)
        let merged = current.merged(with: Benchmarks(ftpWatts: seed, thresholdPaceSecondsPerKm: tested))
        XCTAssertEqual(merged.ftpWatts, tested, "a later seed never overwrites a test")
        XCTAssertEqual(merged.lthrBpm, seed)
        XCTAssertEqual(merged.thresholdPaceSecondsPerKm, tested)
        XCTAssertEqual(current.merged(with: Benchmarks(ftpWatts: newerTest)).ftpWatts, newerTest)
        XCTAssertEqual(Benchmarks(ftpWatts: newerTest).merged(with: Benchmarks(ftpWatts: tested)).ftpWatts, newerTest)
        XCTAssertEqual(Benchmarks(lthrBpm: seed).merged(with: Benchmarks(lthrBpm: BenchmarkValue(value: 160, isEstimated: true, date: date(2027, 1, 1)))).lthrBpm?.value, 160)
    }

    func testPlanWeekCountReplanRealignAndFitnessFormThroughTheFacade() throws {
        let kit = PlanKit()
        let plan = try smallPlan()
        XCTAssertEqual(
            try kit.planWeekCount(raceDistance: .sprint, raceDate: date(2027, 1, 24), startDate: date(2026, 11, 9), calendar: cal),
            plan.weeks.count)

        let moved = try kit.replan(
            plan, raceDistance: .sprint, raceDate: date(2027, 2, 14), today: date(2026, 11, 16),
            benchmarks: allBenchmarks(), calendar: cal)
        XCTAssertEqual(moved.raceDate, date(2027, 2, 14))
        XCTAssertGreaterThan(moved.weeks.count, plan.weeks.count)
        let cancelled = try kit.replan(
            plan, raceDistance: nil, raceDate: nil, today: date(2026, 11, 16), benchmarks: allBenchmarks(), calendar: cal)
        XCTAssertNil(cancelled.raceDate)

        var missed = plan
        for session in missed.allSessions where session.scheduledDate < missed.weeks[2].startDate {
            missed.updateSession(id: session.id) { $0.state = .done }
        }
        let aligned = try kit.realign(
            .compress, plan: missed, context: AdaptationContext(today: missed.weeks[3].startDate), calendar: cal)
        XCTAssertFalse(aligned.events.isEmpty)

        let workouts = (0..<50).map { offset in
            CompletedWorkout(
                id: "w\(offset)", sport: .run, start: cal.addDays(offset, to: date(2026, 9, 1)), durationSeconds: 3600,
                averageHeartRate: 150, source: .healthKit)
        }
        let few = kit.fitnessForm(workouts: workouts, benchmarks: allBenchmarks(), from: date(2026, 9, 1), through: date(2026, 9, 20), calendar: cal)
        XCTAssertFalse(few.hasFullHistory)
        let full = kit.fitnessForm(workouts: workouts, benchmarks: allBenchmarks(), from: date(2026, 9, 1), through: date(2026, 10, 20), calendar: cal)
        XCTAssertTrue(full.hasFullHistory)
        XCTAssertEqual(full.series.count, full.daily.count)
    }

    // MARK: Zones

    func testImplausibleTestResultsAskForARetest() throws {
        XCTAssertEqual(zones.evaluateCSSTest(time400Seconds: 100, time200Seconds: 10, on: day0), .retest(.implausibleTimes))
        XCTAssertEqual(zones.evaluateCSSTest(time400Seconds: 1500, time200Seconds: 400, on: day0), .retest(.implausibleTimes))
        XCTAssertThrowsError(try zones.cssFromTest(time400Seconds: 100, time200Seconds: 10, on: day0)) {
            guard case .invalidInput? = $0 as? PlanKitError else { return XCTFail("\($0)") }
        }
        guard case .accepted(let css) = zones.evaluateCSSTest(time400Seconds: 420, time200Seconds: 200, on: day0) else {
            return XCTFail("a real result is accepted")
        }
        XCTAssertEqual(css.value, 110, accuracy: 0.001)
        XCTAssertFalse(CSSRetestReason.implausibleTimes.message.isEmpty)

        XCTAssertThrowsError(try zones.ftpFromTest(best20MinutePower: 1e9, on: day0))
        XCTAssertThrowsError(try zones.ftpFromTest(best20MinutePower: 5, on: day0))
        XCTAssertEqual(try zones.ftpFromTest(best20MinutePower: 250, on: day0).value, 237.5, accuracy: 0.001)
        XCTAssertThrowsError(try zones.runThresholdFromTest(distanceKilometres: 0.01, finalTwentyMinuteAverageHeartRate: nil, on: day0))
        XCTAssertNoThrow(try zones.runThresholdFromTest(distanceKilometres: 5.5, finalTwentyMinuteAverageHeartRate: 170, on: day0))
    }

    func testRacePacingAndZonesShareOneSetOfBounds() {
        XCTAssertEqual(RacePacingPlaceholders.cssBounds, ZoneConstants.cssBounds)
        XCTAssertEqual(RacePacingPlaceholders.ftpBounds, ZoneConstants.ftpBounds)
        XCTAssertEqual(RacePacingPlaceholders.thresholdPaceBounds, ZoneConstants.thresholdPaceBounds)
    }

    func testRunSeedFromTwentyMinutesIsSlowedAboutFourPercentAndThirtyIsNot() {
        func speed(minutes: Double) -> [SeriesSample] {
            stride(from: 0.0, through: minutes * 60, by: 5).map { SeriesSample(offsetSeconds: $0, value: 3.0) }
        }
        let short = zones.seedRunBenchmarks(speed: speed(minutes: 20), heartRate: [], on: day0)
        let long = zones.seedRunBenchmarks(speed: speed(minutes: 30), heartRate: [], on: day0)
        let flat = 1000 / 3.0
        XCTAssertEqual(long.thresholdPaceSecondsPerKm?.value ?? 0, flat, accuracy: 0.01)
        XCTAssertEqual(short.thresholdPaceSecondsPerKm?.value ?? 0, flat * 1.04, accuracy: 0.5)
        XCTAssertEqual(short.thresholdPaceSecondsPerKm?.isEstimated, true)
    }

    // MARK: Load

    func testHeartRateFactorsMatchThePowerPathAtZoneMidpointsWithinSevenPercent() {
        for index in 0..<5 {
            let fraction = LoadConstants.powerZoneMidpointFractions[index]
            let power = fraction * fraction * 100
            let heartRate = LoadConstants.heartRateZoneFactorsPerHour[index]
            XCTAssertLessThanOrEqual(abs(heartRate - power) / power, LoadConstants.heartRatePowerParityTolerance, "Z\(index + 1)")
        }
    }

    func testBothHeartRateClassifiersAgreeOnEveryBandEdge() {
        // LTHR 100 makes the bpm equal to the percent, so edges are exact.
        let probes: [Double] = [50, 80.9, 81, 81.1, 88.9, 89, 89.1, 93.9, 94, 94.1, 101.9, 102, 102.1, 130]
        for bpm in probes {
            XCTAssertEqual(
                LoadConstants.heartRateLevel(fractionOfLTHR: bpm / 100),
                zones.heartRateZone(forBpm: bpm, lthr: 100).rawValue, "\(bpm) percent of LTHR")
        }
    }

    func testVariableRideWithoutAdjustedPowerIsMarkedEstimated() {
        let model = DefaultLoadModel()
        let b = allBenchmarks()
        let averageOnly = CompletedWorkout(id: "a", sport: .bike, start: day0, durationSeconds: 3600, averagePower: 200, source: .healthKit)
        let withAdjusted = CompletedWorkout(
            id: "b", sport: .bike, start: day0, durationSeconds: 3600, averagePower: 200, adjustedPower: 215, source: .healthKit)
        XCTAssertTrue(model.load(for: averageOnly, benchmarks: b).isEstimated)
        XCTAssertFalse(model.load(for: withAdjusted, benchmarks: b).isEstimated)
    }

    func testWeekLoadIsSummedInDayOrderSoTheBitsNeverDependOnTheDictionary() throws {
        let plan = try smallPlan()
        let model = DefaultLoadModel()
        for week in plan.weeks {
            var expected = 0.0
            for key in week.days.keys.sorted() {
                expected += (week.days[key] ?? []).reduce(0) { $0 + model.plannedLoad(for: $1, benchmarks: allBenchmarks()).load }
            }
            XCTAssertEqual(model.plannedLoad(for: week, benchmarks: allBenchmarks()), expected)
        }
    }

    // MARK: Race window

    func testRaceEveDinnerAdviceSurvivesTheDailyNotificationCap() throws {
        let window = DefaultRaceWindow()
        let race = RaceDetails(distance: .olympic, raceDate: date(2027, 3, 7), startMinutesAfterMidnight: 7 * 60)
        let capped = window.cappedForNotifications(window.entries(for: race, calendar: cal))
        XCTAssertFalse(capped.contains { $0.kind == .carbLoad }, "one notification a day")
        let pack = capped.first { $0.kind == .packTonight }
        XCTAssertTrue(try XCTUnwrap(pack).text.contains("dinner"), "the pack reminder carries the dinner advice")
        // The 70.3 carb load sits on its own day and stays separate.
        let half = RaceDetails(distance: .half, raceDate: date(2027, 6, 6), startMinutesAfterMidnight: 7 * 60)
        let cappedHalf = window.cappedForNotifications(window.entries(for: half, calendar: cal))
        XCTAssertTrue(cappedHalf.contains { $0.kind == .carbLoad })
        XCTAssertEqual(cappedHalf.first { $0.kind == .packTonight }?.text, RaceWindowCopy.packTonightText)
    }

    func testWakeUpTextSaysWhenToEatAndWarnsWhenTheLeadTimesDoNotFit() throws {
        let window = DefaultRaceWindow()
        let normal = RaceDetails(distance: .olympic, raceDate: date(2027, 3, 7), startMinutesAfterMidnight: 7 * 60)
        let wake = try XCTUnwrap(window.entries(for: normal, calendar: cal).first { $0.kind == .wakeUp })
        XCTAssertTrue(wake.text.contains("eat about 2 hours before the start"), wake.text)
        XCTAssertFalse(wake.text.contains("minutes for breakfast"))
        XCTAssertFalse(window.wakeUpIsClamped(for: normal))

        let tight = RaceDetails(
            distance: .olympic, raceDate: date(2027, 3, 7), startMinutesAfterMidnight: 4 * 60, transitMinutes: 20,
            setupMinutes: 45, breakfastLeadMinutes: 300)
        XCTAssertTrue(window.wakeUpIsClamped(for: tight))
        let clamped = try XCTUnwrap(window.entries(for: tight, calendar: cal).first { $0.kind == .wakeUp })
        XCTAssertEqual(clamped.minutesAfterMidnight, 0)
        XCTAssertTrue(clamped.text.contains(RaceWindowCopy.wakeUpClampedWarning))
        XCTAssertFalse(clamped.text.contains("minus"))
    }

    func testRaceWindowAndLoadCountDaysCorrectlyOnDaylightSavingEdgeDays() throws {
        for zone in ["America/Havana", "America/Santiago", "Africa/Cairo", "Australia/Lord_Howe"] {
            var local = cal
            local.timeZone = TimeZone(identifier: zone) ?? cal.timeZone
            let dstDay = local.date(from: DateComponents(year: 2026, month: 3, day: 8)) ?? day0
            let raceDate = local.addDays(10, to: dstDay)
            let window = DefaultRaceWindow()
            // Sprint window is 10 days: open exactly 10 days out, closed 11 days out.
            XCTAssertTrue(window.isWindowActive(raceDate: raceDate, distance: .sprint, today: dstDay, calendar: local), zone)
            XCTAssertFalse(window.isWindowActive(raceDate: raceDate, distance: .sprint, today: local.addDays(-1, to: dstDay), calendar: local), zone)
            let samples = DefaultLoadModel().dailyLoads(
                workouts: [], benchmarks: Benchmarks(), from: dstDay, through: local.addDays(5, to: dstDay), calendar: local)
            XCTAssertEqual(samples.count, 6, zone)
        }
    }

    // MARK: Openers, copy

    func testOpenersAndSteadyBlocksReadTheSharedRaceEffortTable() {
        for distance in RaceDistance.allCases {
            let ctx = buildContext(distance: distance)
            let bike = StepFactory.build(.bikeOpeners, seconds: 1800, ctx: ctx).steps.filter { $0.name == "Opener" }
            let run = StepFactory.build(.runOpeners, seconds: 1800, ctx: ctx).steps.filter { $0.name == "Opener" }
            XCTAssertEqual(bike.first?.level, RacePacingPlaceholders.trainingLevel(forRaceEffort: .bike, distance: distance))
            XCTAssertEqual(run.first?.level, RacePacingPlaceholders.trainingLevel(forRaceEffort: .run, distance: distance))
            // The opener zone sits within one zone of the middle of the race band.
            let band = RacePacingPlaceholders.bikeFTPFraction(distance)
            let raceZone = zones.bikePowerZone(forWatts: band.midpoint * 100, ftp: 100).rawValue
            XCTAssertLessThanOrEqual(abs((bike.first?.level ?? 0) - raceZone), 1, "\(distance) bike")
        }
        XCTAssertEqual(RacePacingPlaceholders.trainingLevel(forRaceEffort: .bike, distance: .half), 3)
        let half = StepFactory.build(.bikeLong, seconds: 14_400, ctx: buildContext(distance: .half)).steps
        XCTAssertTrue(half.contains { ($0.note ?? "").contains("a little above race effort") })
        let olympic = StepFactory.build(.bikeLong, seconds: 10_800, ctx: buildContext(distance: .olympic)).steps
        XCTAssertTrue(olympic.contains { ($0.note ?? "").contains("close to the effort you plan") })
    }

    func testSessionCopyIsHonest() {
        XCTAssertEqual(SessionLibrary.name(for: .swimEndurance), "Endurance swim")
        XCTAssertFalse(SessionLibrary.purpose(for: .swimSpeed).contains("plenty of rest"))
        XCTAssertFalse(SessionLibrary.purpose(for: .bikeVO2).contains("easier"))
        XCTAssertEqual(SessionLibrary.purpose(for: .bikeVO2), "Short, very hard efforts raise your top end.")
    }

    // MARK: Model types

    func testDecodingKeepsTheTypeInvariants() throws {
        let decoder = JSONDecoder()
        let range = try decoder.decode(ValueRange.self, from: Data(#"{"lower":5,"upper":1}"#.utf8))
        XCTAssertEqual(range, ValueRange(1, 5))
        XCTAssertLessThanOrEqual(range.lower, range.upper)

        let encoded = try JSONEncoder().encode(Step(sport: .run, kind: .work, durationSeconds: 60, level: 3, name: "x"))
        var text = String(decoding: encoded, as: UTF8.self)
        text = text.replacingOccurrences(of: "\"durationSeconds\":60", with: "\"durationSeconds\":-5")
        text = text.replacingOccurrences(of: "\"level\":3", with: "\"level\":99")
        let step = try decoder.decode(Step.self, from: Data(text.utf8))
        XCTAssertEqual(step.durationSeconds, 0)
        XCTAssertEqual(step.level, 5)

        let workout = CompletedWorkout(id: "w", sport: .run, start: day0, durationSeconds: 100, source: .manual)
        var workoutText = String(decoding: try JSONEncoder().encode(workout), as: UTF8.self)
        workoutText = workoutText.replacingOccurrences(of: "\"durationSeconds\":100", with: "\"durationSeconds\":-50")
        XCTAssertEqual(try decoder.decode(CompletedWorkout.self, from: Data(workoutText.utf8)).durationSeconds, 0)
        XCTAssertEqual(workout.workIntervalAveragePower, nil)
    }

    func testAPlanFromANewerVersionIsRefusedWithAReadableError() throws {
        let plan = try smallPlan()
        var text = String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)
        text = text.replacingOccurrences(of: "\"version\":1", with: "\"version\":99")
        XCTAssertThrowsError(try JSONDecoder().decode(Plan.self, from: Data(text.utf8))) { error in
            guard case let DecodingError.dataCorrupted(context) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(context.debugDescription.contains("newer version"))
        }
        // The current version still decodes.
        XCTAssertEqual(try JSONDecoder().decode(Plan.self, from: JSONEncoder().encode(plan)), plan)
    }

    func testModelTypesAreIdentifiableAndErrorsReadCalmly() throws {
        let plan = try smallPlan()
        XCTAssertEqual(plan.weeks[2].id, 2)
        let session = try XCTUnwrap(plan.allSessions.first)
        XCTAssertEqual(session.id, plan.allSessions[0].id)
        let errors: [PlanKitError] = [
            .invalidInput("x"), .cssTestRejected, .missingBenchmark(.bikeFTP), .raceDateTooSoon(minimumWeeks: 8, availableWeeks: 3),
            .infeasibleProfile("no pool"), .sessionNotFound("a"), .realignmentUnavailable, .uncompilableSession("empty"),
            .malformedShareCode
        ]
        for error in errors {
            let text = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), text)
        }
    }

    func testTheForbiddenMarksAreAbsentFromTheNewCopy() {
        let marks = ["T" + "SS", "N" + "P", "T" + "PU"]
        var copy: [String] = [AdaptationConstants.taperLockReason, RaceWindowCopy.packAndDinnerText, RaceWindowCopy.wakeUpClampedWarning]
        copy.append(contentsOf: CSSRetestReason.implausibleTimes.message.split(separator: ".").map(String.init))
        copy.append(contentsOf: [PlanWarning.hoursClampedToMaximum(used: 10).message, PlanWarning.qualityEased(weekIndex: 1, name: "x").message])
        for text in copy {
            for mark in marks { XCTAssertFalse(text.contains(mark), text) }
            for word in ["doc" + "tor", "inj" + "ur", "ill" + "ness"] { XCTAssertFalse(text.lowercased().contains(word), text) }
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"))
        }
    }
}
