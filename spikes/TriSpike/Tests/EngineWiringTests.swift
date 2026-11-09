import XCTest
import BricklinePlanKit
@testable import TriSpike

/// The screens read the engine, so these tests build the engine's plan for known answers and check that every
/// number the screens print is the engine's number, and that Today, Week, Detail and Race agree with each other.
/// No test traps: failures are assertions only.
final class EngineWiringTests: XCTestCase {
    // MARK: Fixtures

    private let cal = EngineBuilder.calendar()

    /// Monday 9 November 2026, midday.
    private var monday: Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12)) ?? Date()
    }

    private func day(_ offset: Int) -> Date { cal.startOfDay(for: cal.addDays(offset, to: monday)) }

    private func setup(raceInDays: Int = 83, race: RaceChoice = .olympic, power: Bool = false,
                       experience: ExperienceChoice = .firstTimer, hours: Int = 7) -> SetupData {
        var d = SetupData()
        d.raceChoice = race
        d.raceDate = day(raceInDays)
        d.hasPowerMeter = power
        d.experience = experience
        d.hoursPerWeek = hours
        return d
    }

    private func model(_ d: SetupData, startedDaysAgo: Int = 0, today offset: Int = 0,
                       completions: [String: CompletionRecord] = [:]) -> EngineModel {
        EngineBuilder.build(setup: d, planStart: day(-startedDaysAgo), today: day(offset), completions: completions, calendar: cal)
    }

    private func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Every session of every week as the screens would show it.
    private func allScreenSessions(_ m: EngineModel, _ d: SetupData) -> [TriSpike.Session] {
        guard let plan = m.plan else { return [] }
        return plan.allSessions.map { EngineBuilder.makeSession($0, plan: plan, benchmarks: m.benchmarks, completion: nil) }
    }

    // MARK: Plan shape

    func testTwelveWeekOlympicPlanHasTwelveWeeks() {
        // Race on the Sunday of the twelfth week from a Monday start.
        let m = model(setup(raceInDays: 83))
        XCTAssertNil(m.problem)
        XCTAssertEqual(m.plan?.weeks.count, 12)
        XCTAssertEqual(m.totalWeeks, 12)
        XCTAssertEqual(m.currentWeek, 1)
        XCTAssertEqual(m.daysToRace, 83)
        XCTAssertEqual(m.phases.reduce(0) { $0 + $1.1 }, 12)
    }

    func testTotalWeeksAlwaysEqualsTheEnginePlan() {
        for days in [55, 70, 83, 84, 100, 150, 200] {
            let m = model(setup(raceInDays: days))
            XCTAssertEqual(m.totalWeeks, m.plan?.weeks.count ?? 1, "race in \(days) days")
            XCTAssertTrue((1...m.totalWeeks).contains(m.currentWeek), "race in \(days) days")
        }
    }

    func testTaperIsLastAndPhasesRunInOrder() {
        let m = model(setup(raceInDays: 83))
        XCTAssertEqual(m.phases.last?.0, .taper)
        XCTAssertEqual(m.plan?.weeks.last?.phase, BricklinePlanKit.Phase.taper)
        let order: [TriSpike.Phase] = [.base, .build, .peak, .taper]
        let indexes = m.phases.compactMap { p in order.firstIndex(of: p.0) }
        XCTAssertEqual(indexes, indexes.sorted())
        // The engine's weeks are in the same order as the phase list the arc bar draws.
        var expanded: [TriSpike.Phase] = []
        for (phase, n) in m.phases { expanded += Array(repeating: phase, count: n) }
        let engine = (m.plan?.weeks ?? []).map { w -> TriSpike.Phase in
            switch w.phase { case .base: .base; case .build: .build; case .peak: .peak; case .taper: .taper }
        }
        XCTAssertEqual(expanded, engine)
    }

    func testRaceDayFallsInTheLastWeek() {
        let d = setup(raceInDays: 83)
        let m = model(d)
        guard let plan = m.plan, let race = plan.raceDate else { return XCTFail("no plan") }
        XCTAssertEqual(plan.weekIndex(containing: race, calendar: cal), plan.weeks.count - 1)
        XCTAssertEqual(race, cal.startOfDay(for: d.raceDate))
    }

    func testRecoveryAndTestWeeksComeFromTheEngineWeeks() {
        let m = model(setup(raceInDays: 120))
        let recovery = Set((m.plan?.weeks ?? []).filter(\.isRecovery).map { $0.index + 1 })
        let tests = Set((m.plan?.weeks ?? []).filter(\.isTest).map { $0.index + 1 })
        XCTAssertEqual(m.recoveryWeeks, recovery)
        XCTAssertEqual(m.testWeeks, tests)
        XCTAssertFalse(recovery.isEmpty)
        XCTAssertFalse(recovery.contains(m.totalWeeks), "the last week is a taper week, not a recovery week")
    }

    func testCurrentWeekAdvancesWithTheCalendar() {
        let d = setup(raceInDays: 83)
        XCTAssertEqual(model(d, today: 0).currentWeek, 1)
        XCTAssertEqual(model(d, today: 7).currentWeek, 2)
        XCTAssertEqual(model(d, today: 21).currentWeek, 4)
        XCTAssertEqual(model(d, today: 83).currentWeek, 12)
        let late = model(d, today: 200)
        XCTAssertTrue((1...late.totalWeeks).contains(late.currentWeek))
        XCTAssertEqual(late.daysToRace, 0)
    }

    func testRaceFarAwayBridgesWithBaseWeeksUntilThePlanBegins() {
        let m = model(setup(raceInDays: 300))
        XCTAssertNil(m.problem)
        XCTAssertEqual(m.currentWeek, 1)
        XCTAssertEqual(m.week.count, 7)
        XCTAssertFalse(m.week.flatMap(\.sessions).isEmpty, "the bridge weeks still have sessions")
        XCTAssertEqual(m.totalWeeks, m.plan?.weeks.count)
    }

    func testRaceTooSoonFallsBackToABasePlanWithACalmReason() {
        let m = model(setup(raceInDays: 30))
        XCTAssertNotNil(m.problem)
        XCTAssertTrue(m.problem?.contains("at least") ?? false)
        XCTAssertNil(m.plan?.raceDistance)
        XCTAssertEqual(m.totalWeeks, 4)
        XCTAssertFalse(m.week.flatMap(\.sessions).isEmpty)
    }

    func testNoRaceYetUsesTheEnginesRollingBaseBlock() {
        var d = setup()
        d.noRaceYet = true
        let m = model(d)
        XCTAssertFalse(m.hasRace)
        XCTAssertNil(m.plan?.raceDistance)
        XCTAssertEqual(m.totalWeeks, 4)
        XCTAssertEqual(m.phases.count, 1)
        // Five weeks in, a new block has started.
        XCTAssertEqual(model(d, startedDaysAgo: 35, today: 0).currentWeek, 2)
    }

    func testPoolDaysOutsideTrainingDaysStillGiveAPlan() {
        var d = setup()
        d.trainingDays = [2, 4, 6, 1]
        d.poolDays = [3]
        let m = model(d)
        XCTAssertNotNil(m.plan)
        XCTAssertNotNil(m.problem)
    }

    func testRestDayHasNoSessions() {
        // The default answers train six days, so one day of the week is a rest day.
        let m = model(setup())
        XCTAssertEqual(m.week.count, 7)
        XCTAssertTrue(m.week.contains { $0.sessions.isEmpty })
        XCTAssertEqual(m.week.filter(\.isToday).count, 1)
        XCTAssertEqual(m.week.first?.date, day(0))
    }

    // MARK: Consistency across screens

    func testWeekSessionsAreTheEnginesSessionsForThatWeek() {
        let m = model(setup(), today: 14)
        guard let plan = m.plan else { return XCTFail("no plan") }
        let engineIDs = Set(plan.weeks[m.currentWeek - 1].sessions.map(\.id))
        let screenIDs = Set(m.week.flatMap(\.sessions).compactMap(\.engineID))
        XCTAssertEqual(screenIDs, engineIDs)
    }

    func testSessionDurationsMatchTheEngine() {
        let m = model(setup())
        guard let plan = m.plan else { return XCTFail("no plan") }
        for s in m.week.flatMap(\.sessions) {
            guard let id = s.engineID, let e = plan.session(withID: id) else { return XCTFail("missing \(s.name)") }
            XCTAssertEqual(s.minutes, Int((e.durationSeconds / 60).rounded()), s.name)
            XCTAssertEqual(s.steps.reduce(0) { $0 + $1.seconds }, e.durationSeconds, accuracy: 0.001, s.name)
            XCTAssertEqual(s.sport.rawValue, e.sport.rawValue)
            XCTAssertEqual(s.brickSecond?.rawValue, e.brickSecondSport?.rawValue)
        }
    }

    func testWeekHoursMatchTheEngineWeek() {
        let m = model(setup(), today: 21)
        guard let plan = m.plan else { return XCTFail("no plan") }
        let minutes = m.week.flatMap(\.sessions).reduce(0.0) { $0 + Double($1.minutes) }
        XCTAssertEqual(minutes / 60, plan.weeks[m.currentWeek - 1].plannedHours, accuracy: 0.5)
    }

    func testSwimsCarryEngineMeters() {
        let m = model(setup())
        for s in m.week.flatMap(\.sessions) where s.sport == .swim && s.brickSecond == nil {
            guard let id = s.engineID, let e = m.plan?.session(withID: id) else { return XCTFail("missing") }
            if e.distanceMeters > 0 { XCTAssertEqual(Double(s.totalMeters ?? 0), e.distanceMeters.rounded(), accuracy: Double(e.steps.count), s.name) }
        }
    }

    func testRepeatSetsAreExpandedWithTheEnginesCount() {
        let m = model(setup(experience: .experienced, hours: 9), today: 40)
        var sawRepeat = false
        for s in allScreenSessions(m, setup()) {
            for g in Set(s.steps.compactMap(\.group)) {
                let works = s.steps.filter { $0.group == g && $0.kind == .work }
                sawRepeat = true
                XCTAssertEqual(works.first?.repeatCount, works.count, s.name)
            }
        }
        XCTAssertTrue(sawRepeat)
    }

    func testRaceLegsAreTheEnginePacingCard() {
        let d = setup()
        let m = model(d)
        let (card, _) = PlanKit.standard.racePlan(distance: .olympic, athlete: EngineBuilder.athlete(d), benchmarks: m.benchmarks)
        XCTAssertEqual(m.race.legs.count, 3)
        for (leg, target) in zip(m.race.legs, card.targets) {
            XCTAssertEqual(leg.seconds, target.expectedDurationSeconds.midpoint, accuracy: 0.001)
            XCTAssertEqual(leg.sport.rawValue, target.leg.sport.rawValue)
        }
        XCTAssertEqual(m.race.legs[0].meters, 1500)
        XCTAssertEqual(m.race.legs[1].name, "Bike 40 km")
        XCTAssertEqual(m.race.legs[2].name, "Run 10 km")
    }

    func testRaceTimelineAndWakeTimeComeFromTheEngine() {
        let d = setup()
        let m = model(d)
        let details = RaceDetails(distance: .olympic, raceDate: d.raceDate, startMinutesAfterMidnight: EngineBuilder.defaultStartMinutes)
        let entries = PlanKit.standard.raceWindow(for: details, calendar: cal)
        XCTAssertEqual(m.race.timeline.count, entries.count)
        XCTAssertEqual(m.race.wakeMinutes, entries.first { $0.kind == .wakeUp }?.minutesAfterMidnight)
        XCTAssertEqual(m.race.timeline.last?.daysBefore, nil)
        XCTAssertFalse(m.race.fueling.isEmpty)
    }

    func testDaysToRaceAgreesBetweenCountdownAndEngineDates() {
        let d = setup(raceInDays: 83)
        let m = model(d, today: 10)
        XCTAssertEqual(m.daysToRace, 73)
        XCTAssertEqual(m.plan?.raceDate, day(83))
    }

    // MARK: Benchmarks and wording

    func testEstimatesAreLabelledAndEnteredNumbersAreNot() {
        var d = setup(power: true)
        d.useEstimates = true
        let est = EngineBuilder.benchmarks(d, today: day(0))
        XCTAssertEqual(est.cssSecondsPer100m?.isEstimated, true)
        XCTAssertEqual(est.ftpWatts?.isEstimated, true)
        XCTAssertEqual(est.thresholdPaceSecondsPerKm?.isEstimated, true)

        d.useEstimates = false
        d.cssSecondsPer100 = 105
        d.ftpWatts = 230
        d.thresholdPaceSecondsPerKm = 290
        let entered = EngineBuilder.benchmarks(d, today: day(0))
        XCTAssertEqual(entered.cssSecondsPer100m?.value, 105)
        XCTAssertEqual(entered.cssSecondsPer100m?.isEstimated, false)
        XCTAssertEqual(entered.ftpWatts?.value, 230)
        XCTAssertEqual(entered.thresholdPaceSecondsPerKm?.value, 290)

        // A box left empty stays an estimate.
        d.ftpWatts = nil
        XCTAssertEqual(EngineBuilder.benchmarks(d, today: day(0)).ftpWatts?.isEstimated, true)
    }

    func testEnteredSwimPaceDrivesTheSwimTarget() {
        var d = setup()
        d.useEstimates = false
        d.cssSecondsPer100 = 100
        d.thresholdPaceSecondsPerKm = 300
        let m = model(d)
        let swims = allScreenSessions(m, d).filter { $0.sport == .swim && $0.headlineTarget?.unit == "per 100 m" }
        XCTAssertFalse(swims.isEmpty)
        for s in swims {
            XCTAssertFalse(s.targetsEstimated, s.name)
            let value = s.headlineTarget?.value ?? ""
            let parts = value.split(separator: ":").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2)
            let seconds = (parts.first ?? 0) * 60 + (parts.last ?? 0)
            XCTAssertTrue((85...125).contains(seconds), "\(s.name): \(value)")
        }
    }

    func testNoPowerMeterMeansNoWattsAnywhereOnTheBike() {
        let d = setup(power: false)
        let m = model(d)
        XCTAssertNil(m.benchmarks.ftpWatts)
        let bikes = allScreenSessions(m, d).filter { $0.sport == .bike }
        XCTAssertFalse(bikes.isEmpty)
        for s in bikes {
            XCTAssertFalse(s.usesPower, s.name)
            XCTAssertEqual(s.targetLabel, "how it feels", s.name)
            XCTAssertEqual(s.headlineTarget?.unit, "effort", s.name)
            for step in s.steps { XCTAssertFalse((step.target ?? "").lowercased().contains("watt"), "\(s.name): \(step.target ?? "")") }
            XCTAssertFalse(s.watchLine.lowercased().contains("power"), s.watchLine)
        }
        for leg in m.race.legs { XCTAssertFalse((leg.target ?? "").contains("watts")) }
    }

    func testPowerMeterGivesWattsOnTheBike() {
        let d = setup(power: true)
        let m = model(d)
        XCTAssertNotNil(m.benchmarks.ftpWatts)
        let bikes = allScreenSessions(m, d).filter { $0.sport == .bike }
        XCTAssertTrue(bikes.contains { $0.usesPower && $0.targetLabel == "target power" })
        XCTAssertTrue(bikes.contains { $0.steps.contains { ($0.target ?? "").hasSuffix(" watts") } })
        XCTAssertTrue(m.race.legs.contains { ($0.target ?? "").hasSuffix(" watts") })
        // A guessed power number is marked as an estimate.
        XCTAssertTrue(bikes.filter(\.usesPower).allSatisfy(\.targetsEstimated))
    }

    func testNamesCarryUnitsAndNoShorthandOrJargon() {
        for d in [setup(power: true), setup(power: false, experience: .experienced, hours: 9)] {
            for week in [0, 14, 40, 70] {
                let m = model(d, today: week)
                for s in allScreenSessions(m, d) {
                    XCTAssertFalse(s.name.contains(" x "), s.name)
                    XCTAssertFalse(s.name.contains("+"), s.name)
                    XCTAssertFalse(s.name.contains(":") && s.name.hasPrefix("Brick"), s.name)
                    XCTAssertTrue(s.name.contains(where: \.isNumber) || s.name.lowercased().contains("rest"), "no unit in: \(s.name)")
                    var texts = [s.name, s.purpose, s.watchLine]
                    for step in s.steps { texts += [step.name, step.target ?? "", step.distance ?? ""] }
                    for text in texts {
                        XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "dash in: \(text)")
                        let w = words(text)
                        for banned in ["threshold", "brick", "ftp", "css", "vo2", "lthr", "rpe", "tss", "ctl", "atl"] {
                            XCTAssertFalse(w.contains(banned), "\(banned) in plain text: \(text)")
                        }
                        XCTAssertFalse(text.lowercased().contains("sweet spot"), text)
                        XCTAssertFalse(text.lowercased().contains("critical swim speed"), text)
                        XCTAssertFalse(text.lowercased().contains("trainingpeaks"), text)
                    }
                }
            }
        }
    }

    func testTechnicalIdeasMoveIntoTheIdeaLine() {
        let d = setup(experience: .experienced, hours: 9)
        let m = model(d, today: 40)
        let sessions = allScreenSessions(m, d)
        let bricks = sessions.filter { $0.brickSecond != nil }
        XCTAssertFalse(bricks.isEmpty)
        for b in bricks {
            XCTAssertEqual(b.idea, .brick)
            XCTAssertTrue(b.name.hasPrefix("Ride "), b.name)
            XCTAssertTrue(b.name.contains(", then run"), b.name)
        }
        for s in sessions where s.name.hasPrefix("Steady hard run") { XCTAssertEqual(s.idea, .threshold) }
    }

    func testEveryEngineSessionNameHasAPlainTitle() {
        for kind in SessionKind.allCases {
            let s = BricklinePlanKit.Session(
                id: "t", sport: kind.sport, name: SessionLibrary.name(for: kind), purpose: SessionLibrary.purpose(for: kind),
                steps: [BricklinePlanKit.Step(sport: kind.sport, kind: .work, durationSeconds: 1800, level: 2, name: "Easy")],
                scheduledDate: day(0))
            let title = PlainCopy.title(for: s)
            XCTAssertTrue(title.contains(where: \.isNumber), "\(kind): \(title)")
            XCTAssertFalse(words(title).contains("threshold"), title)
            XCTAssertFalse(words(title).contains("brick"), title)
            XCTAssertFalse(PlainCopy.purpose(for: s).lowercased().contains("threshold"), "\(kind)")
            XCTAssertFalse(PlainCopy.purpose(for: s).lowercased().contains("critical swim speed"), "\(kind)")
        }
    }

    func testEngineCopyHasNoDashesOnTheRaceCard() {
        let m = model(setup(power: true))
        var strings = m.race.timeline.map(\.text) + m.race.fueling.map(\.text) + [m.race.caveat, m.race.stomachLine]
        strings += m.warnings + [m.problem ?? ""]
        strings += m.race.legs.map { $0.target ?? "" }
        for s in strings { XCTAssertFalse(s.contains("\u{2014}") || s.contains("\u{2013}"), "dash in: \(s)") }
    }

    // MARK: Load, Fitness, Form

    func testPlannedLoadIsTheEnginesPlannedLoad() {
        let m = model(setup())
        guard let plan = m.plan else { return XCTFail("no plan") }
        let engine = DefaultLoadModel()
        for s in m.week.flatMap(\.sessions) {
            guard let id = s.engineID, let e = plan.session(withID: id) else { return XCTFail("missing") }
            XCTAssertEqual(s.loadPoints, Int(engine.plannedLoad(for: e, benchmarks: m.benchmarks).load.rounded()), s.name)
            XCTAssertGreaterThan(s.loadPoints, 0, s.name)
            XCTAssertTrue(s.loadEstimated, "a plan is a forecast, so its Load is labelled estimated")
        }
    }

    func testCompletedSessionShowsDoneWithEngineLoadAndFeedsFitness() {
        let d = setup()
        let before = model(d)
        guard let target = before.week.flatMap(\.sessions).first, let id = target.engineID else { return XCTFail("no session") }
        let record = CompletionRecord(sessionID: id, minutes: 45, date: target.scheduledDate ?? day(0),
                                      sport: target.sport.rawValue, level: target.engineLevel)
        let after = model(d, completions: [id: record])
        let done = after.week.flatMap(\.sessions).first { $0.engineID == id }
        XCTAssertEqual(done?.state, .done)
        XCTAssertEqual(done?.doneMinutes, 45)
        XCTAssertEqual(done?.id, target.id, "the session keeps its identity when it is marked done")
        guard let plan = after.plan, let e = plan.session(withID: id) else { return XCTFail("missing") }
        let engine = DefaultLoadModel()
        let workout = CompletedWorkout(id: id, sport: e.sport, start: record.date, durationSeconds: 45 * 60,
                                       plannedSessionID: id, source: .phonePlayer)
        let expected = engine.load(for: workout, benchmarks: after.benchmarks, plannedLevel: engine.representativeLevel(for: e))
        XCTAssertEqual(done?.loadPoints, Int(expected.load.rounded()))
        XCTAssertNil(before.fitness)
        XCTAssertNotNil(after.fitness)
        XCTAssertEqual(after.fitness?.hasFullHistory, false, "Fitness says building until 42 days of history exist")
        XCTAssertGreaterThanOrEqual(after.fitness?.fitness ?? -1, 0)
    }

    func testFitnessAndFormMatchTheEngineSeries() {
        let d = setup()
        let m = model(d, today: 30)
        var records: [String: CompletionRecord] = [:]
        for i in stride(from: -20, to: 28, by: 2) {
            let id = "t\(i)"
            records[id] = CompletionRecord(sessionID: id, minutes: 50, date: day(i), sport: "run", level: 3)
        }
        guard let plan = m.weekPlan else { return XCTFail("no plan") }
        let summary = EngineBuilder.fitnessSummary(completions: records, plan: plan, benchmarks: m.benchmarks, today: day(30), calendar: cal)
        let workouts = records.values.map {
            CompletedWorkout(id: $0.sessionID, sport: .run, start: $0.date, durationSeconds: 3000, plannedSessionID: $0.sessionID, source: .phonePlayer)
        }
        let levels = Dictionary(uniqueKeysWithValues: records.keys.map { ($0, 3) })
        let model = DefaultLoadModel()
        let daily = model.dailyLoads(workouts: workouts, benchmarks: m.benchmarks, plannedLevels: levels, from: day(-20), through: day(30), calendar: cal)
        let last = model.fitnessForm(dailyLoads: daily, calendar: cal).last
        XCTAssertEqual(summary?.fitness ?? -1, last?.fitness ?? -2, accuracy: 0.0001)
        XCTAssertEqual(summary?.fatigue ?? -1, last?.fatigue ?? -2, accuracy: 0.0001)
        XCTAssertEqual(summary?.form ?? -1, last?.form ?? -2, accuracy: 0.0001)
        XCTAssertEqual(summary?.hasFullHistory, true, "51 days of history is more than 42")
        XCTAssertGreaterThan(summary?.fitness ?? 0, 0)
        // A short history says building.
        let short = EngineBuilder.fitnessSummary(completions: ["t0": CompletionRecord(sessionID: "t0", minutes: 50, date: day(25), sport: "run", level: 3)],
                                                 plan: plan, benchmarks: m.benchmarks, today: day(30), calendar: cal)
        XCTAssertEqual(short?.hasFullHistory, false)
    }

    // MARK: Compile for watch and phone

    func testEverySessionOfThePlanCompiles() {
        for power in [true, false] {
            let d = setup(power: power)
            let m = model(d)
            guard let plan = m.plan else { return XCTFail("no plan") }
            let results = PlanKit.standard.compileAll(plan, benchmarks: m.benchmarks)
            XCTAssertFalse(results.isEmpty)
            XCTAssertTrue(results.allSatisfy { $0.failure == nil }, "failures: \(results.compactMap { $0.failure })")
            for s in plan.allSessions.prefix(30) {
                let phone = try? PlanKit.standard.compilePhoneWorkouts(s, in: plan, benchmarks: m.benchmarks)
                XCTAssertFalse(phone?.isEmpty ?? true, s.name)
            }
        }
    }

    func testWatchLineDescribesWhatTheEngineCompiled() {
        let d = setup(power: true, experience: .experienced, hours: 9)
        let m = model(d, today: 40)
        for s in allScreenSessions(m, d) {
            XCTAssertTrue(s.watchLine.hasPrefix("Arrives as"), s.watchLine)
            if s.brickSecond != nil { XCTAssertTrue(s.watchLine.contains("two workouts"), s.watchLine) }
        }
    }

    func testStableIdentityAcrossRebuilds() {
        let d = setup()
        let a = model(d).week.flatMap(\.sessions).map(\.id)
        let b = model(d).week.flatMap(\.sessions).map(\.id)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set(a).count, a.count)
    }

    // MARK: The shared adapter (Today, Week, Detail, Race and onboarding read these)

    @MainActor
    func testScreensAndOnboardingPreviewAgree() {
        let saved = UserSetup.shared.data
        defer { UserSetup.shared.data = saved }
        var d = setup()
        d.raceDate = Calendar.current.date(byAdding: .day, value: 83, to: Date()) ?? Date()
        UserSetup.shared.data = d
        let preview = OBPlan.planWeeks(d)
        XCTAssertEqual(Demo.totalWeeks, preview, "the onboarding preview and the Week screen say the same number of weeks")
        XCTAssertEqual(Demo.phases.map(\.1), OBPlan.phases(for: d).map(\.weeks))
        XCTAssertEqual(Demo.phases.reduce(0) { $0 + $1.1 }, Demo.totalWeeks)
        XCTAssertEqual(Demo.week.count, 7)
        XCTAssertEqual(Demo.todaySessions, Demo.week.first(where: { $0.isToday })?.sessions ?? [])
        XCTAssertEqual(Demo.raceLegs.count, 3)
        XCTAssertEqual(Demo.raceName, "Olympic triathlon")
        XCTAssertNotNil(Demo.smokeSession)
        XCTAssertTrue(Demo.week.flatMap(\.sessions).allSatisfy { $0.engineID != nil })
    }

    @MainActor
    func testAdapterCompilesPhoneWorkoutsForAScreenSession() {
        let saved = UserSetup.shared.data
        defer { UserSetup.shared.data = saved }
        UserSetup.shared.data = setup()
        guard let s = Demo.week.flatMap(\.sessions).first else { return XCTFail("no session") }
        XCTAssertNotNil(EngineAdapter.shared.engineSession(for: s))
        XCTAssertFalse(EngineAdapter.shared.phoneWorkouts(for: s).isEmpty)
        XCTAssertNotNil(EngineAdapter.shared.compiled(for: s))
        if #available(iOS 18, *) { XCTAssertFalse(EngineAdapter.shared.workoutPlans(for: s).isEmpty) }
    }

    @MainActor
    func testRecordingACompletionMarksTheSessionDone() {
        let saved = UserSetup.shared.data
        let adapter = EngineAdapter.shared
        defer { UserSetup.shared.data = saved; adapter.clearCompletions() }
        adapter.clearCompletions()
        UserSetup.shared.data = setup()
        guard let s = Demo.week.flatMap(\.sessions).first(where: { $0.state == .planned }) else { return XCTFail("no session") }
        adapter.recordCompletion(of: s, minutes: 30)
        let after = Demo.week.flatMap(\.sessions).first { $0.engineID == s.engineID }
        XCTAssertEqual(after?.state, .done)
        XCTAssertEqual(after?.doneMinutes, 30)
        XCTAssertNotNil(Demo.fitness)
    }

    // MARK: Review fixes

    func testFallbackPlanDoesNotReanchorEveryDay() {
        // A race too soon for its plan: the fallback is a rolling block anchored on the start day.
        let d = setup(raceInDays: 30)
        let a = model(d, startedDaysAgo: 0, today: 0)
        let b = model(d, startedDaysAgo: 0, today: 14)
        XCTAssertNotNil(a.problem)
        XCTAssertEqual(a.currentWeek, 1)
        XCTAssertEqual(b.currentWeek, 3, "two weeks later it is week 3 of the block")
        let idsA = Set(a.engineSessions.keys), idsB = Set(b.engineSessions.keys)
        XCTAssertFalse(idsA.isDisjoint(with: idsB), "session ids stay put from day to day")
    }

    func testPastRaceFallbackIsStable() {
        let d = setup(raceInDays: -3)
        let a = model(d, startedDaysAgo: 10, today: 0)
        let b = model(d, startedDaysAgo: 10, today: 1)
        XCTAssertFalse(Set(a.engineSessions.keys).isDisjoint(with: Set(b.engineSessions.keys)))
    }

    func testFarRaceBridgeIsStableAndHonestAboutTheStart() {
        let d = setup(raceInDays: 300)
        let a = model(d, startedDaysAgo: 0, today: 0)
        let b = model(d, startedDaysAgo: 0, today: 10)
        XCTAssertNotNil(a.planBeginsOn)
        XCTAssertFalse(Set(a.engineSessions.keys.filter { $0.hasPrefix("w0") }).isDisjoint(with: Set(b.engineSessions.keys)))
        XCTAssertNil(model(setup(raceInDays: 83)).planBeginsOn)
    }

    func testManyEasedWeeksCollapseToOneLine() {
        var d = setup(raceInDays: 83, hours: 10)
        d.trainingDays = [2, 4]
        let m = model(d)
        XCTAssertLessThanOrEqual(m.warnings.count, 3)
        XCTAssertEqual(Set(m.warnings).count, m.warnings.count)
        XCTAssertFalse(m.warnings.contains { $0.hasPrefix("Week ") })
    }

    func testSanitizeRemovesBrickAndAerobic() {
        let lines = ["Today's brick became an easy brick.", "Builds the aerobic base. Sets your power zones.",
                     "Today's technique swim became an easy swim.", "Today's VO2 session and vo2 work"]
        for l in lines {
            let out = PlainCopy.sanitize(l).lowercased()
            for banned in PlainCopy.bannedInPlainText { XCTAssertFalse(out.contains(banned), "\(banned) in \(out)") }
        }
        XCTAssertEqual(PlainCopy.sanitize("Brick day"), "Ride then run day")
    }

    func testReadinessCopyForEveryKindIsPlain() {
        for kind in SessionKind.allCases {
            let name = SessionLibrary.name(for: kind, runWalk: false)
            let head = name.split(separator: ":").first.map(String.init) ?? name
            let line = "Today's \(head.lowercased()) became an easy session. Your HRV has been below your usual range two mornings running and resting heart rate is up. Tap to keep the original."
            let out = ReadinessPlainCopy.sessionReason(from: line).lowercased()
            for banned in PlainCopy.bannedInPlainText { XCTAssertFalse(out.contains(banned), "\(banned) in \(out)") }
        }
    }

    func testChangeSentenceDoesNotRepeatTheBelowRangeFact() {
        let out = ReadinessPlainCopy.changeSentence(from: "Today's long ride became an easy ride. Your HRV has been below your usual range two mornings running and resting heart rate is up. Tap to keep the original.")
        XCTAssertFalse(out.contains("below your usual range"))
        XCTAssertTrue(out.contains("resting heart rate is up"))
    }

    func testGarminOnlyHasNoHRVSource() {
        var d = SetupData(); d.devices = [.garmin]
        XCTAssertTrue(d.hasRecoverySource)
        XCTAssertFalse(d.hasHRVSource)
        d.devices = [.garmin, .oura]
        XCTAssertTrue(d.hasHRVSource)
    }
}
