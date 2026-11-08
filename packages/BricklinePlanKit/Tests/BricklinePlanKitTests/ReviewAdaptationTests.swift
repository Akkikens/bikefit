import XCTest
@testable import BricklinePlanKit

/// Tests for the review fixes in the adaptation engine: gap based re-entry, like with like zone nudges, nudge reset
/// on a retest, the shared test protocols, skip handling, move rules and the rule 5 and rule 6 details.
final class ReviewAdaptationTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    private func athlete(
        _ level: Level = .intermediate, hours: Double = 8, power: Bool = false, days: Set<Weekday> = Set(Weekday.allCases)
    ) -> AthleteProfile {
        AthleteProfile(
            level: level, weeklyHours: hours, availableWeekdays: days,
            poolWeekdays: [.tuesday, .thursday, .saturday], hasWatch: true, hasPowerMeter: power)
    }

    private let templates = DefaultTemplateEngine()
    private let engine = DefaultAdaptationEngine()
    private let load = DefaultLoadModel()

    private func olympic(weeks: Int, power: Bool = false, benchmarks: Benchmarks = Benchmarks()) throws -> Plan {
        let start = date(2026, 11, 9)
        let race = cal.addDays(7 * (weeks - 1) + 6, to: start)
        return try templates.makePlan(
            raceDistance: .olympic, raceDate: race, startDate: start, athlete: athlete(power: power),
            benchmarks: benchmarks, calendar: cal)
    }

    /// Marks every session dated before `day` as done, so only the weeks the test wants are missed.
    private func markDone(_ plan: inout Plan, before day: Date) {
        for session in plan.allSessions where session.scheduledDate < day {
            plan.updateSession(id: session.id) { $0.state = .done }
        }
    }

    private func weekLoad(_ plan: Plan, _ index: Int) -> Double {
        load.plannedLoad(for: plan.adaptWeekWithoutSkipped(index) ?? plan.weeks[index], benchmarks: Benchmarks())
    }

    // MARK: Rule 2 re-entry

    func testCompressAfterAFullyMissedWeekReturnsBelowNinetyPercentOfThePreMissWeek() throws {
        var plan = try olympic(weeks: 14)
        let missedStart = plan.weeks[4].startDate
        markDone(&plan, before: missedStart)
        let today = plan.weeks[5].startDate
        let before = weekLoad(plan, 5)
        let reference = weekLoad(plan, 2)
        XCTAssertGreaterThan(before / reference, 0.95, "the template plans the week after the miss at full volume")

        let result = try engine.applyRealignment(
            .compress, to: plan, context: AdaptationContext(today: today), calendar: cal)
        let after = weekLoad(result.plan, 5)
        XCTAssertLessThan(after / reference, 0.90, "first week back is \(after / reference) of the pre miss week")
        XCTAssertTrue(result.events[0].reasonLine.contains("builds back in steps"))
        // The race arc is untouched: peak and taper sessions are identical.
        let peakStart = try XCTUnwrap(plan.weeks.firstIndex { $0.phase == .peak })
        for index in peakStart..<plan.weeks.count {
            XCTAssertEqual(result.plan.weeks[index].sessions, plan.weeks[index].sessions, "week \(index)")
        }
    }

    func testReentryUsesActualRecentLoadWhenItIsLowerThanPlanned() throws {
        var plan = try olympic(weeks: 14)
        markDone(&plan, before: plan.weeks[4].startDate)
        let today = plan.weeks[5].startDate
        let planned = weekLoad(plan, 2)
        // The athlete only did a quarter of the planned load in the last 28 days.
        var loads: [LoadSample] = []
        for offset in 1...28 {
            loads.append(LoadSample(date: cal.addDays(-offset, to: today), load: planned * 0.25 / 7))
        }
        let result = try engine.applyRealignment(
            .compress, to: plan, context: AdaptationContext(today: today, dailyLoads: loads), calendar: cal)
        let after = weekLoad(result.plan, 5)
        let before = weekLoad(plan, 5)
        XCTAssertLessThan(after, before * 0.5, "the cap follows the quarter of the load that was actually done")
    }

    func testReentryFactorsFollowTheGapTable() {
        let factors = [
            (3, 0.85), (7, 0.85), (8, 0.70), (14, 0.70), (15, 0.55), (28, 0.55), (29, 0.50), (90, 0.50)
        ]
        let run = DefaultAdaptationEngine()
        for (gap, expected) in factors {
            XCTAssertEqual(run.reentryFactor(gapDays: gap), expected, accuracy: 0.0001, "gap \(gap)")
        }
    }

    func testCompressInsidePeakTrimsNothingAndDoesNotPromiseSteps() throws {
        var plan = try olympic(weeks: 14)
        let peak = try XCTUnwrap(plan.weeks.firstIndex { $0.phase == .peak && !$0.isRecovery })
        markDone(&plan, before: plan.weeks[peak - 1].startDate)
        let today = plan.weeks[peak].startDate
        let result = try engine.applyRealignment(
            .compress, to: plan, context: AdaptationContext(today: today), calendar: cal)
        XCTAssertEqual(result.events[0].reasonLine, "Plan resumed from today. Missed sessions are set aside")
        XCTAssertFalse(result.events[0].reasonLine.contains("builds back in steps"))
    }

    func testShiftAfterATwoWeekGapInsertsAnEasierReentryWeekAndFlagsFollowContent() throws {
        var plan = try olympic(weeks: 14)
        markDone(&plan, before: plan.weeks[3].startDate)
        let today = plan.weeks[5].startDate
        let result = try engine.applyRealignment(
            .shiftPlan, to: plan, context: AdaptationContext(today: today), calendar: cal)
        XCTAssertTrue(result.events[0].reasonLine.contains("easier week first"), result.events[0].reasonLine)
        let current = result.plan.weeks[5]
        XCTAssertFalse(current.sessions.filter { $0.scheduledDate >= today && $0.state == .planned }.isEmpty,
                       "the current week holds the re-entry sessions")
        XCTAssertTrue(current.sessions.allSatisfy { !$0.isTest || $0.state != .planned }, "no test in a re-entry week")
        XCTAssertLessThan(current.plannedHours, plan.weeks[2].plannedHours * 0.9)
        // Flags follow content: a week is a test week only while it holds a live test.
        for week in result.plan.weeks where week.index >= 3 {
            let hasTest = week.sessions.contains { $0.isTest && $0.state != .skipped }
            XCTAssertEqual(week.isTest, hasTest, "week \(week.index) test flag")
        }
        // Peak and taper keep their dates.
        let peakStart = try XCTUnwrap(plan.weeks.firstIndex { $0.phase == .peak })
        for index in peakStart..<plan.weeks.count {
            XCTAssertEqual(result.plan.weeks[index].sessions.map(\.scheduledDate), plan.weeks[index].sessions.map(\.scheduledDate))
        }
    }

    func testShiftAfterASingleMissedWeekAddsNoReentryWeek() throws {
        var plan = try olympic(weeks: 14)
        markDone(&plan, before: plan.weeks[4].startDate)
        let today = plan.weeks[5].startDate
        let result = try engine.applyRealignment(
            .shiftPlan, to: plan, context: AdaptationContext(today: today), calendar: cal)
        XCTAssertFalse(result.events[0].reasonLine.contains("easier week first"))
    }

    // MARK: Rule 3

    private func nudgeFixture(workInterval: Double?, wholeAverage: Double?, extraSteps: Int = 0)
        throws -> (plan: Plan, context: AdaptationContext, ids: [String])
    {
        let ftp = BenchmarkValue(value: 220, isEstimated: false, date: date(2026, 11, 1))
        let benchmarks = Benchmarks(ftpWatts: ftp)
        var plan = try olympic(weeks: 14, power: true, benchmarks: benchmarks)
        let rides = plan.allSessions.filter {
            $0.sport == .bike && $0.isQuality && !$0.isTest && $0.benchmarkKind == nil && $0.steps.contains { $0.kind == .work && $0.level == 4 }
        }.prefix(3)
        XCTAssertEqual(rides.count, 3)
        let today = cal.addDays(1, to: try XCTUnwrap(rides.last).scheduledDate)
        markDone(&plan, before: today)
        var workouts: [CompletedWorkout] = []
        for ride in rides {
            workouts.append(CompletedWorkout(
                id: "w-\(ride.id)", sport: .bike, start: cal.addDays(0, to: ride.scheduledDate).addingTimeInterval(8 * 3600),
                durationSeconds: ride.durationSeconds, averagePower: wholeAverage,
                plannedSessionID: ride.id, source: .healthKit, workIntervalAveragePower: workInterval))
        }
        if extraSteps != 0 {
            plan.zoneNudgeSteps[.bike] = extraSteps
            plan.zoneNudgeBaselineDates[.bike] = ftp.date
        }
        let context = AdaptationContext(today: today, completedWorkouts: workouts, benchmarks: benchmarks)
        return (plan, context, rides.map(\.id))
    }

    func testRideAtZoneMidpointsWithEasyPartsDoesNotNudgeFromTheWholeWorkoutAverage() throws {
        // Warm up and recoveries ridden at 50 percent of FTP drag the whole workout average far below the work
        // target. Only whole workout averages exist, so the session cannot be compared and nothing moves.
        let fixture = try nudgeFixture(workInterval: nil, wholeAverage: 153)
        let result = engine.apply(to: fixture.plan, context: fixture.context, calendar: cal)
        XCTAssertFalse(result.events.contains { $0.rule == .zoneNudge })
        XCTAssertNil(result.plan.zoneNudgeSteps[.bike])
    }

    func testWorkIntervalsOnTargetDoNotNudge() throws {
        let fixture = try nudgeFixture(workInterval: 220 * 0.98, wholeAverage: 150)
        let result = engine.apply(to: fixture.plan, context: fixture.context, calendar: cal)
        XCTAssertFalse(result.events.contains { $0.rule == .zoneNudge })
    }

    func testWorkIntervalsAboveTargetNudgeOneStepAndRecordTheBenchmarkDate() throws {
        let fixture = try nudgeFixture(workInterval: 220 * 0.98 * 1.08, wholeAverage: 150)
        let result = engine.apply(to: fixture.plan, context: fixture.context, calendar: cal)
        let event = try XCTUnwrap(result.events.first { $0.rule == .zoneNudge })
        XCTAssertTrue(event.reasonLine.contains("higher than target"))
        XCTAssertEqual(result.plan.zoneNudgeSteps[.bike], 1)
        XCTAssertEqual(result.plan.zoneNudgeBaselineDates[.bike], date(2026, 11, 1))
    }

    func testNudgeStopsAtFiveSteps() throws {
        let fixture = try nudgeFixture(workInterval: 220 * 0.98 * 1.5 * 1.08, wholeAverage: 150, extraSteps: 5)
        // 50 percent over target is an outlier, so use a modest rise on top of the already nudged target instead.
        let nudgedTarget = 220 * 1.10 * 0.98
        let workouts = fixture.context.completedWorkouts.map { workout -> CompletedWorkout in
            var copy = workout
            copy.workIntervalAveragePower = nudgedTarget * 1.08
            return copy
        }
        var context = fixture.context
        context.completedWorkouts = workouts
        let result = engine.apply(to: fixture.plan, context: context, calendar: cal)
        XCTAssertEqual(result.plan.zoneNudgeSteps[.bike], 5, "five steps is the cap")
        XCTAssertFalse(result.events.contains { $0.rule == .zoneNudge })
    }

    func testNudgeResetsWhenANewTestedBenchmarkArrives() throws {
        let old = BenchmarkValue(value: 220, isEstimated: false, date: date(2026, 11, 1))
        let retested = BenchmarkValue(value: 235, isEstimated: false, date: date(2026, 12, 20))
        var plan = try olympic(weeks: 14, power: true, benchmarks: Benchmarks(ftpWatts: old))
        plan.zoneNudgeSteps[.bike] = 3
        plan.zoneNudgeBaselineDates[.bike] = old.date
        let fresh = Benchmarks(ftpWatts: retested)

        XCTAssertEqual(plan.effectiveZoneNudgeSteps(benchmarks: Benchmarks(ftpWatts: old))[.bike], 3)
        XCTAssertNil(plan.effectiveZoneNudgeSteps(benchmarks: fresh)[.bike])

        // The compiled target equals the un nudged zone.
        let kit = PlanKit()
        let ride = try XCTUnwrap(plan.allSessions.first { $0.sport == .bike && $0.isQuality && !$0.isTest })
        var clean = plan
        clean.zoneNudgeSteps = [:]
        clean.zoneNudgeBaselineDates = [:]
        let staleCompiled = try kit.compile(ride, in: plan, benchmarks: fresh)
        let cleanCompiled = try kit.compile(ride, in: clean, benchmarks: fresh)
        XCTAssertEqual(staleCompiled.workouts, cleanCompiled.workouts)

        // The engine also clears the stored nudge.
        let result = engine.apply(
            to: plan, context: AdaptationContext(today: date(2026, 12, 21), benchmarks: fresh), calendar: cal)
        XCTAssertNil(result.plan.zoneNudgeSteps[.bike])
        XCTAssertNil(result.plan.zoneNudgeBaselineDates[.bike])
    }

    func testNudgeNeverResetsWithoutANewerTest() throws {
        let value = BenchmarkValue(value: 220, isEstimated: false, date: date(2026, 11, 1))
        var plan = try olympic(weeks: 14, power: true, benchmarks: Benchmarks(ftpWatts: value))
        plan.zoneNudgeSteps[.bike] = 2
        plan.zoneNudgeBaselineDates[.bike] = value.date
        let kept = plan.normalizingNudges(benchmarks: Benchmarks(ftpWatts: value))
        XCTAssertEqual(kept.zoneNudgeSteps[.bike], 2)
        XCTAssertEqual(plan.resettingNudge(for: .bike).zoneNudgeSteps[.bike], nil)
    }

    // MARK: Rule 8 uses the shared protocols

    func testRuleEightTestSessionsAreTheTemplateTestSessions() throws {
        let plan = try olympic(weeks: 14)
        let run = AdaptationRun(context: AdaptationContext(today: date(2026, 11, 9)), calendar: cal)
        let css = DefaultTemplateEngine.swimCSS(benchmarks: Benchmarks(), level: .intermediate)
        let pairs: [(BenchmarkKind, SessionKind)] = [
            (.swimCSS, .swimTest), (.bikeFTP, .bikeTestFTP), (.bikeLTHR, .bikeTestLTHR), (.runThreshold, .runTest)
        ]
        for (kind, sessionKind) in pairs {
            let inserted = engine.makeTestSession(kind: kind, id: "x", date: date(2026, 11, 9), plan: plan, run: run)
            let ctx = BuildContext(
                level: .intermediate, phase: .base, distance: .olympic, runWalk: false, css: css, allowSteady: false,
                brickRunSeconds: 0)
            let templateSteps = StepFactory.build(sessionKind, seconds: 0, ctx: ctx).steps
            XCTAssertEqual(inserted.steps, templateSteps, "\(kind)")
            XCTAssertEqual(inserted.name, SessionLibrary.name(for: sessionKind))
            XCTAssertTrue(inserted.isTest && inserted.isQuality)
            XCTAssertEqual(inserted.benchmarkKind, kind)
        }
    }

    func testPowerTestAllowsTenMinutesBetweenTheClearingEffortAndTheTwentyMinuteEffort() throws {
        let ctx = BuildContext(
            level: .intermediate, phase: .base, distance: .olympic, runWalk: false, css: 110, allowSteady: false,
            brickRunSeconds: 0)
        let steps = StepFactory.build(.bikeTestFTP, seconds: 0, ctx: ctx).steps
        let clearing = steps.firstIndex { $0.name == "Clearing effort" }
        let recovery = steps.first { $0.kind == .recovery }
        XCTAssertNotNil(clearing)
        XCTAssertEqual(recovery?.durationSeconds, 600)
        let effort = steps.first { $0.name == "20 minute test effort" }
        XCTAssertEqual(effort?.target, .rpe(ValueRange(8, 9)))
        for step in steps where step.kind == .work {
            XCTAssertTrue(try XCTUnwrap(step.note, step.name).contains("Stop if anything feels wrong"), step.name)
        }
        let swim = StepFactory.build(.swimTest, seconds: 0, ctx: ctx).steps
        XCTAssertTrue(try XCTUnwrap(swim.first { $0.name == "400 m all out" }?.note).contains("other people around"))
    }

    // MARK: Rule 1

    private func hardRideAndEasyWeekPlan(available: Set<Weekday> = Set(Weekday.allCases)) -> Plan {
        let monday = date(2026, 11, 9)
        func day(_ n: Int) -> Date { cal.addDays(n, to: monday) }
        func step(_ sport: Sport, _ minutes: Double, level: Int) -> Step {
            Step(sport: sport, kind: .work, durationSeconds: minutes * 60, level: level,
                 target: .rpe(ZoneConstants.rpeRange(forLevel: level)), name: "Step")
        }
        func session(_ n: Int, _ sport: Sport, _ name: String, _ minutes: Double, level: Int = 2, quality: Bool = false) -> Session {
            Session(
                id: SessionID.make(weekIndex: 0, date: day(n), sport: sport, slot: 1, calendar: cal), sport: sport,
                name: name, purpose: "Purpose.", steps: [step(sport, minutes, level: level)], scheduledDate: day(n),
                isQuality: quality)
        }
        var week = PlannedWeek(index: 0, startDate: monday, phase: .base)
        for s in [
            session(0, .swim, "Easy swim", 45),
            session(2, .run, "Long run", 75),
            session(3, .bike, "Easy spin", 40),
            session(5, .bike, "Long ride", 120)
        ] {
            week.days[s.scheduledDate, default: []].append(s)
        }
        week.plannedHours = week.sessions.reduce(0) { $0 + $1.durationHours }
        return Plan(
            raceDistance: nil, raceDate: nil, startDate: monday, weeks: [week],
            athlete: AthleteProfile(
                level: .intermediate, weeklyHours: 8, availableWeekdays: available, poolWeekdays: [.monday],
                hasWatch: true))
    }

    func testSkippedLongRunNeverLandsNextToTheLongRide() {
        let plan = hardRideAndEasyWeekPlan()
        let longRun = plan.allSessions.first { $0.name == "Long run" }
        XCTAssertNotNil(longRun)
        let wednesday = date(2026, 11, 11)
        let context = AdaptationContext(
            today: wednesday, events: [.sessionSkipped(sessionID: longRun?.id ?? "", on: wednesday)])
        let result = engine.apply(to: plan, context: context, calendar: cal)
        let moved = result.plan.allSessions.first { $0.name == "Long run" }
        // Long ride is Saturday. Friday, Saturday and Sunday sit within a day of it; Thursday does not.
        XCTAssertEqual(moved?.scheduledDate, date(2026, 11, 12))
    }

    func testSkippedLongRunDropsWhenOnlyDaysNextToTheLongRideRemain() {
        let plan = hardRideAndEasyWeekPlan(available: [.monday, .tuesday, .wednesday, .friday, .saturday, .sunday])
        let longRun = plan.allSessions.first { $0.name == "Long run" }
        let wednesday = date(2026, 11, 11)
        let context = AdaptationContext(
            today: wednesday, events: [.sessionSkipped(sessionID: longRun?.id ?? "", on: wednesday)])
        let result = engine.apply(to: plan, context: context, calendar: cal)
        XCTAssertEqual(result.plan.allSessions.first { $0.name == "Long run" }?.state, .skipped)
    }

    func testRuleOneLineDoesNotTalkAboutHardDaysForAnEasyMove() {
        var plan = hardRideAndEasyWeekPlan()
        for session in plan.allSessions where session.scheduledDate < date(2026, 11, 12) {
            plan.updateSession(id: session.id) { $0.state = .done }
        }
        let easy = plan.allSessions.first { $0.name == "Easy spin" }
        let thursday = date(2026, 11, 12)
        let context = AdaptationContext(
            today: thursday, events: [.sessionSkipped(sessionID: easy?.id ?? "", on: thursday)])
        let result = engine.apply(to: plan, context: context, calendar: cal)
        let line = result.events.first { $0.rule == .skippedMove }?.reasonLine ?? ""
        XCTAssertTrue(line.hasPrefix("Moved to "), line)
        XCTAssertTrue(line.hasSuffix("to keep your week balanced"), line)
        XCTAssertFalse(line.contains("hard days"))
    }

    func testASecondSkipOfTheSameSessionOnALaterDayIsHonoured() throws {
        var plan = try olympic(weeks: 14)
        let target = try XCTUnwrap(plan.weeks[1].sessions.first { $0.sport == .bike && !$0.isQuality })
        markDone(&plan, before: target.scheduledDate)
        var state = AdaptationState(plan: plan)
        state.record(.sessionSkipped(sessionID: target.id, on: target.scheduledDate))
        let first = state.apply(using: engine, today: target.scheduledDate, calendar: cal)
        XCTAssertTrue(first.events.contains { $0.rule == .skippedMove })
        let secondDay = try XCTUnwrap(state.plan.session(withID: target.id)).scheduledDate
        XCTAssertGreaterThan(secondDay, target.scheduledDate)

        // Everything else before the second day was done, so only the re-skip is in play.
        for session in state.plan.allSessions where session.scheduledDate < secondDay && session.id != target.id {
            state.plan.updateSession(id: session.id) { $0.state = .done }
        }
        // Both skip events stay in the athlete's log, as the host contract says.
        state.record(.sessionSkipped(sessionID: target.id, on: secondDay))
        let second = state.apply(using: engine, today: secondDay, calendar: cal)
        XCTAssertTrue(second.events.contains { $0.rule == .skippedMove }, "the second skip must fire")
        let finalSession = try XCTUnwrap(state.plan.session(withID: target.id))
        XCTAssertTrue(finalSession.state == .skipped || finalSession.scheduledDate > secondDay)
        XCTAssertEqual(state.history.filter { $0.rule == .skippedMove }.count, 2)
    }

    // MARK: Rule 5

    func testEditedPeakWeekIsClampedButADesignedPeakWeekIsNot() throws {
        var plan = try olympic(weeks: 16)
        let peak = try XCTUnwrap(plan.weeks.first { $0.phase == .peak && !$0.isRecovery })
        let today = peak.startDate
        markDone(&plan, before: today)
        let designed = engine.apply(
            to: plan,
            context: AdaptationContext(today: today, events: [.weekEdited(weekIndex: peak.index, on: today)]),
            calendar: cal)
        XCTAssertFalse(designed.events.contains { $0.rule == .rampClamp }, "a designed peak week is exempt")

        // The athlete adds extra hours to the peak week.
        var edited = plan
        markDone(&edited, before: today)
        let freeDay = try XCTUnwrap((1..<7).map { cal.addDays($0, to: peak.startDate) }.first {
            edited.adaptSessions(on: $0, calendar: cal).isEmpty && $0 > today
        })
        let extra = Session(
            id: edited.adaptNewSessionID(weekIndex: peak.index, date: freeDay, sport: .run, calendar: cal),
            sport: .run, name: "Extra run", purpose: "Extra.",
            steps: [Step(sport: .run, kind: .work, durationSeconds: 3 * 3600, level: 2, target: .rpe(ValueRange(3, 4)), name: "Run")],
            scheduledDate: freeDay)
        edited.adaptInsert(extra, calendar: cal)
        edited.adaptRefreshHours(weekIndex: peak.index)
        let result = engine.apply(
            to: edited,
            context: AdaptationContext(today: today, events: [.weekEdited(weekIndex: peak.index, on: today)]),
            calendar: cal)
        XCTAssertTrue(result.events.contains { $0.rule == .rampClamp }, "an edited peak week is policed like any week")
    }

    func testReferenceLoadIgnoresSkippedSessions() throws {
        var plan = try olympic(weeks: 14)
        let run = AdaptationRun(context: AdaptationContext(today: plan.weeks[4].startDate), calendar: cal)
        let full = try XCTUnwrap(engine.referenceLoad(plan: plan, before: 4, run: run))
        let week = plan.weeks[full.week]
        for session in week.sessions.prefix(2) { plan.updateSession(id: session.id) { $0.state = .skipped } }
        let trimmed = try XCTUnwrap(engine.referenceLoad(plan: plan, before: 4, run: run))
        XCTAssertLessThan(trimmed.load, full.load)
    }

    func testRuleFiveRechecksWeeksThatOtherRulesTouched() throws {
        let plan = try olympic(weeks: 16)
        let peak = try XCTUnwrap(plan.weeks.first { $0.phase == .peak && !$0.isRecovery })
        var edited = plan
        let freeDay = try XCTUnwrap((1..<7).map { cal.addDays($0, to: peak.startDate) }.first {
            edited.adaptSessions(on: $0, calendar: cal).isEmpty
        })
        edited.adaptInsert(Session(
            id: edited.adaptNewSessionID(weekIndex: peak.index, date: freeDay, sport: .run, calendar: cal),
            sport: .run, name: "Extra run", purpose: "Extra.",
            steps: [Step(sport: .run, kind: .work, durationSeconds: 3 * 3600, level: 2, target: .rpe(ValueRange(3, 4)), name: "Run")],
            scheduledDate: freeDay), calendar: cal)
        edited.adaptRefreshHours(weekIndex: peak.index)
        let run = AdaptationRun(context: AdaptationContext(today: peak.startDate), calendar: cal)
        XCTAssertNil(engine.rule5(plan: edited, run: run), "no weekEdited event, nothing to check")
        XCTAssertNotNil(engine.rule5(plan: edited, run: run, extraWeeks: [peak.index]))
    }

    // MARK: Rule 6 and rule 7

    private struct SpikeLoad: LoadModel {
        let base = DefaultLoadModel()
        func load(for workout: CompletedWorkout, benchmarks: Benchmarks) -> SessionLoad { base.load(for: workout, benchmarks: benchmarks) }
        func plannedLoad(for session: Session, benchmarks: Benchmarks) -> SessionLoad { base.plannedLoad(for: session, benchmarks: benchmarks) }
        func plannedLoad(for week: PlannedWeek, benchmarks: Benchmarks) -> Double { base.plannedLoad(for: week, benchmarks: benchmarks) }
        func dailyLoads(workouts: [CompletedWorkout], benchmarks: Benchmarks, from: Date, through: Date, calendar: Calendar) -> [LoadSample] { [] }
        func fitnessForm(dailyLoads: [LoadSample], calendar: Calendar) -> [FitnessForm] { [] }
        func acuteChronicRatio(dailyLoads: [LoadSample], asOf: Date, calendar: Calendar) -> Double? { 1.8 }
    }

    func testLoadSpikeFlagsTheWeekAndTheFlagClearsOnceTheWeekPasses() throws {
        var plan = try olympic(weeks: 14)
        let spiky = DefaultAdaptationEngine(loadModel: SpikeLoad())
        // A day with a hard session: the caution brings it down to easy and flags the week.
        let hardDay = try XCTUnwrap(plan.weeks[4].sessions.first { $0.isQuality && !$0.isTest })
        let today = hardDay.scheduledDate
        markDone(&plan, before: today)
        let history = [CompletedWorkout(
            id: "old", sport: .run, start: cal.addDays(-40, to: today), durationSeconds: 3600, source: .healthKit)]
        let result = spiky.apply(to: plan, context: AdaptationContext(today: today, completedWorkouts: history), calendar: cal)
        XCTAssertTrue(result.events.contains { $0.rule == .loadSpike }, "\(result.events.map(\.reasonLine)) \(String(describing: result.pendingRealignment)) today \(today) week \(String(describing: plan.weekIndex(containing: today, calendar: cal)))")
        XCTAssertTrue(result.plan.weeks[4].cautionFlag)

        let later = cal.addDays(8, to: today)
        let next = spiky.apply(to: result.plan, context: AdaptationContext(today: later), calendar: cal)
        XCTAssertFalse(next.plan.weeks[4].cautionFlag, "the flag clears when the week has passed")
    }

    func testTaperLockLineSaysRaceWindowNotRaceWeek() {
        XCTAssertTrue(AdaptationConstants.taperLockReason.hasPrefix("Race window"))
        XCTAssertFalse(AdaptationConstants.taperLockReason.contains("Race week"))
    }

    // MARK: Move rules through the facade

    func testMoveSessionFollowsTheSameRulesAsRuleOne() throws {
        let kit = PlanKit()
        let plan = hardRideAndEasyWeekPlan()
        let longRun = try XCTUnwrap(plan.allSessions.first { $0.name == "Long run" })
        let today = date(2026, 11, 9)

        let moved = try kit.moveSession(longRun.id, to: date(2026, 11, 12), in: plan, today: today, calendar: cal)
        XCTAssertEqual(moved.plan.session(withID: longRun.id)?.scheduledDate, date(2026, 11, 12))
        XCTAssertEqual(moved.event, .weekEdited(weekIndex: 0, on: today))
        XCTAssertEqual(
            moved.plan.weeks[0].plannedHours, moved.plan.weeks[0].sessions.reduce(0) { $0 + $1.durationHours }, accuracy: 0.001)

        // Next to the long ride.
        XCTAssertThrowsError(try kit.moveSession(longRun.id, to: date(2026, 11, 14), in: plan, today: today, calendar: cal))
        XCTAssertThrowsError(try kit.moveSession(longRun.id, to: date(2026, 11, 13), in: plan, today: today, calendar: cal)) { error in
            XCTAssertNotNil((error as? PlanKitError)?.errorDescription)
        }
        // Another week and an unknown id.
        XCTAssertThrowsError(try kit.moveSession(longRun.id, to: date(2026, 11, 17), in: plan, today: today, calendar: cal))
        XCTAssertThrowsError(try kit.moveSession("nope", to: date(2026, 11, 12), in: plan, today: today, calendar: cal)) {
            XCTAssertEqual($0 as? PlanKitError, .sessionNotFound("nope"))
        }
        // A swim only goes to a pool day (Monday is the only one).
        let swim = try XCTUnwrap(plan.allSessions.first { $0.sport == .swim })
        XCTAssertThrowsError(try kit.moveSession(swim.id, to: date(2026, 11, 11), in: plan, today: today, calendar: cal))
    }

    func testAdaptationStateKeepsHistoryAndEventsTogether() throws {
        let plan = hardRideAndEasyWeekPlan()
        var state = AdaptationState(plan: plan)
        let easy = try XCTUnwrap(plan.allSessions.first { $0.name == "Easy spin" })
        let thursday = date(2026, 11, 12)
        state.record(.sessionSkipped(sessionID: easy.id, on: thursday))
        let result = PlanKit().adapt(&state, today: thursday, calendar: cal)
        XCTAssertFalse(result.events.isEmpty)
        XCTAssertEqual(state.history, result.events)
        XCTAssertEqual(state.plan, result.plan)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(AdaptationState.self, from: data), state)
    }
}
