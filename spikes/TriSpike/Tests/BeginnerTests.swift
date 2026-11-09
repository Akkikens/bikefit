import XCTest
import BricklinePlanKit
@testable import TriSpike

/// The beginner pass: starting point answers, the gentle plan, the super sprint, race day guide, coaching and the
/// "feels too hard" control. No test traps: failures are assertions only.
final class BeginnerTests: XCTestCase {
    private let cal = EngineBuilder.calendar()
    private var monday: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12)) ?? Date() }
    private func day(_ offset: Int) -> Date { cal.startOfDay(for: cal.addDays(offset, to: monday)) }

    private func neverTrained(race: RaceChoice = .superSprint, raceInDays: Int = 83, hours: Int = 8) -> SetupData {
        var d = SetupData()
        d.raceChoice = race
        d.raceDate = day(raceInDays)
        d.experience = .firstTimer
        d.hoursPerWeek = hours
        d.swimAbility = .notYet
        d.bikeAbility = .notYet
        d.runAbility = .notYet
        return d
    }

    private func model(_ d: SetupData, today: Int = 0, completions: [String: CompletionRecord] = [:],
                       eased: Set<String> = []) -> EngineModel {
        EngineBuilder.build(setup: d, planStart: day(0), today: day(today), completions: completions, easedWeeks: eased, calendar: cal)
    }

    // MARK: Starting point mapping

    func testNoAnswersFollowsTheExperienceThePersonPicked() {
        let p = StartingPoint()
        XCTAssertFalse(p.anyAnswered)
        XCTAssertFalse(p.needsGentleStart)
        for e in ExperienceChoice.allCases { XCTAssertEqual(p.resolvedLevel(experience: e), e) }
    }

    func testNeverTrainedIsAGentleFirstTimer() {
        let p = StartingPoint(swim: .notYet, bike: .notYet, run: .notYet)
        XCTAssertTrue(p.needsGentleStart)
        for e in ExperienceChoice.allCases { XCTAssertEqual(p.resolvedLevel(experience: e), .firstTimer, "answers can lower the level") }
        XCTAssertTrue(p.prefersRunWalk(experience: .experienced))
    }

    func testAnswersNeverRaiseTheLevel() {
        let p = StartingPoint(swim: .comfortably, bike: .comfortably, run: .comfortably)
        XCTAssertFalse(p.needsGentleStart)
        XCTAssertEqual(p.resolvedLevel(experience: .firstTimer), .firstTimer)
        XCTAssertEqual(p.resolvedLevel(experience: .experienced), .experienced)
    }

    func testTwoNotYetsOrALowScoreAreGentleAndOneNotYetIsNot() {
        XCTAssertTrue(StartingPoint(swim: .notYet, bike: .comfortably, run: .notYet).needsGentleStart)
        XCTAssertTrue(StartingPoint(swim: .withEffort, bike: .withEffort, run: .withEffort).needsGentleStart)
        let one = StartingPoint(swim: .notYet, bike: .comfortably, run: .comfortably)
        XCTAssertFalse(one.needsGentleStart)
        XCTAssertEqual(one.resolvedLevel(experience: .experienced), .intermediate, "one gap keeps the top level out of reach")
    }

    func testRunWalkIsOfferedUnlessTheRunIsComfortable() {
        XCTAssertTrue(StartingPoint(swim: .comfortably, bike: .comfortably, run: .withEffort).prefersRunWalk(experience: .intermediate))
        XCTAssertFalse(StartingPoint(swim: .comfortably, bike: .comfortably, run: .comfortably).prefersRunWalk(experience: .intermediate))
    }

    func testGentleStartCapsHoursButOnlyForAGentleStart() {
        XCTAssertEqual(neverTrained(hours: 10).effectiveHours, StartingPoint.gentleHoursCap)
        var d = SetupData(); d.hoursPerWeek = 10; d.experience = .intermediate
        XCTAssertEqual(d.effectiveHours, 10)
    }

    // MARK: Skipping the questions

    func testAFirstTimerWhoSkipsTheQuestionsStillGetsTheGentlePlan() {
        var d = neverTrained(hours: 8)
        d.swimAbility = nil; d.bikeAbility = nil; d.runAbility = nil
        XCTAssertTrue(d.isGentleStart)
        XCTAssertEqual(d.effectiveHours, StartingPoint.gentleHoursCap)
        let m = model(d)
        guard let plan = m.plan else { return XCTFail("no plan: \(m.problem ?? "")") }
        XCTAssertTrue(plan.athlete.gentleStart)
        for week in plan.weeks {
            XCTAssertFalse(week.isTest, "week \(week.index) has a test")
            for s in week.sessions {
                XCTAssertFalse(s.isQuality, s.name)
                XCTAssertLessThanOrEqual(s.steps.map(\.level).max() ?? 1, 3, s.name)
            }
        }
        d.experience = .intermediate
        XCTAssertFalse(d.isGentleStart, "someone who picked more experience and skipped is not forced gentle")
    }

    // MARK: A gentle start meeting a race that needs more time

    func testGentleStartWithHalfIronGetsAPlainMessageAndNeverTheEngineText() {
        let d = neverTrained(race: .half, raceInDays: 200, hours: 10)
        XCTAssertNotNil(d.gentleRaceNote)
        let m = model(d)
        let problem = m.problem ?? ""
        XCTAssertFalse(problem.isEmpty)
        XCTAssertFalse(problem.contains("weekly hours too low"), problem)
        XCTAssertFalse(problem.lowercased().contains("infeasible"), problem)
        XCTAssertTrue(problem.contains("at least 6 hours"), problem)
        XCTAssertTrue(problem.contains("sprint"), problem)
        XCTAssertFalse(problem.contains("\u{2014}") || problem.contains("\u{2013}"), problem)
        XCTAssertNotNil(m.plan, "a base plan still shows while the race is changed")
        XCTAssertEqual(d.gentleRaceAlternatives, [.superSprint, .sprint, .olympic])
    }

    func testGentleStartWithOlympicOrShorterHasNoRaceNote() {
        for race in [RaceChoice.superSprint, .sprint, .olympic] {
            let d = neverTrained(race: race, raceInDays: 150, hours: 10)
            XCTAssertNil(d.gentleRaceNote, race.title)
            XCTAssertNil(model(d).problem, race.title)
        }
        var regular = neverTrained(race: .half, raceInDays: 200, hours: 10)
        regular.experience = .intermediate
        regular.swimAbility = .comfortably; regular.bikeAbility = .comfortably; regular.runAbility = .comfortably
        XCTAssertNil(regular.gentleRaceNote)
    }

    func testSavedSetupWithoutAnswersStillDecodes() throws {
        let old = #"{"hasOnboarded":true,"raceChoice":"sprint","hoursPerWeek":6}"#
        let d = try JSONDecoder().decode(SetupData.self, from: Data(old.utf8))
        XCTAssertNil(d.swimAbility)
        XCTAssertEqual(d.raceChoice, .sprint)
        let round = try JSONDecoder().decode(SetupData.self, from: JSONEncoder().encode(neverTrained()))
        XCTAssertEqual(round.runAbility, .notYet)
        XCTAssertEqual(round.raceChoice, .superSprint)
    }

    // MARK: A never trained beginner gets a safe plan

    func testNeverTrainedBeginnerPlanHasNothingAboveTheirLevel() {
        let d = neverTrained()
        let m = model(d)
        guard let plan = m.plan else { return XCTFail("no plan: \(m.problem ?? "")") }
        XCTAssertTrue(plan.athlete.gentleStart)
        XCTAssertEqual(plan.athlete.level, .firstTimer)
        XCTAssertTrue(plan.athlete.prefersRunWalk)
        XCTAssertLessThanOrEqual(plan.athlete.weeklyHours, Double(StartingPoint.gentleHoursCap))
        XCTAssertEqual(plan.raceDistance, .sprint, "a super sprint is planned on the engine's shortest distance")
        for week in plan.weeks {
            XCTAssertFalse(week.isTest, "week \(week.index) has a test")
            let hard = week.sessions.filter(\.isQuality)
            XCTAssertLessThanOrEqual(hard.count, 1, "week \(week.index)")
            if week.phase == .base {
                XCTAssertTrue(hard.isEmpty, "no hard session in a base week")
                for s in week.sessions { XCTAssertLessThanOrEqual(s.steps.map(\.level).max() ?? 1, 2, s.name) }
            }
            for s in week.sessions {
                XCTAssertFalse(s.isTest)
                XCTAssertFalse(s.steps.contains { $0.level > 3 }, "\(s.name) has a step above steady")
            }
        }
    }

    func testGentlePlanHasMoreRecoveryWeeksThanTheDefault() {
        var regular = neverTrained()
        regular.swimAbility = nil; regular.bikeAbility = nil; regular.runAbility = nil
        regular.experience = .intermediate
        let gentle = model(neverTrained(race: .olympic, raceInDays: 111)).plan?.weeks.filter(\.isRecovery).count ?? 0
        regular.raceChoice = .olympic; regular.raceDate = day(111)
        let normal = model(regular).plan?.weeks.filter(\.isRecovery).count ?? 0
        XCTAssertGreaterThan(gentle, normal)
    }

    func testFirstWeekSessionsOfABeginnerAreAllEasy() {
        let m = model(neverTrained())
        let first = m.week.flatMap(\.sessions)
        XCTAssertFalse(first.isEmpty)
        for s in first { XCTAssertLessThanOrEqual(s.steps.map(\.level).max() ?? 1, 2, s.name) }
    }

    // MARK: Super sprint

    func testSuperSprintIsTheShortestRaceAndShowsItsOwnLegs() {
        XCTAssertEqual(RaceChoice.superSprint.summary, "Swim 400 m, bike 10 km, run 2.5 km")
        XCTAssertTrue(RaceChoice.superSprint.isBeginnerRace)
        XCTAssertEqual(RaceChoice.allCases.first, .superSprint)
        let m = model(neverTrained())
        let names = m.race.legs.map(\.name)
        XCTAssertEqual(names, ["Swim 400 m", "Bike 10 km", "Run 2.5 km"])
        let sprint = model(neverTrained(race: .sprint)).race.legs
        for (a, b) in zip(m.race.legs, sprint) { XCTAssertLessThan(a.seconds, b.seconds, a.name) }
    }

    // MARK: "This feels too hard"

    func testEasingTheWeekMakesWhatIsLeftEasyAndShorterAndLeavesDoneWork() {
        var d = SetupData()
        d.raceChoice = .olympic; d.raceDate = day(83); d.experience = .intermediate; d.hoursPerWeek = 8
        let base = model(d, today: 14)
        guard let weekPlan = base.weekPlan else { return XCTFail("no plan") }
        let c = weekPlan.resolvedCalendar(cal)
        guard let idx = weekPlan.weekIndex(containing: day(14), calendar: c) else { return XCTFail("no week") }
        let key = EaseStore.weekKey(weekPlan.weeks[idx].startDate, calendar: c)
        let eased = model(d, today: 14, eased: [key])
        XCTAssertTrue(eased.weekEased)
        XCTAssertFalse(base.weekEased)
        let before = base.week.flatMap(\.sessions), after = eased.week.flatMap(\.sessions)
        XCTAssertEqual(before.count, after.count)
        var changed = 0
        for (b, a) in zip(before, after) where (a.scheduledDate ?? .distantPast) >= day(14) {
            XCTAssertLessThanOrEqual(a.steps.map(\.level).max() ?? 1, 2, a.name)
            XCTAssertLessThanOrEqual(a.steps.reduce(0) { $0 + $1.seconds }, b.steps.reduce(0) { $0 + $1.seconds } + 1)
            XCTAssertEqual(a.reason, EaseWeek.reason)
            changed += 1
        }
        XCTAssertGreaterThan(changed, 0)
        // Earlier days in the week are untouched.
        for (b, a) in zip(before, after) where (a.scheduledDate ?? .distantFuture) < day(14) {
            XCTAssertEqual(a.steps.count, b.steps.count)
            XCTAssertNil(a.reason)
        }
    }

    func testEasedSessionsKeepTheirIdSoCompletionsStillMatch() {
        var d = SetupData()
        d.raceChoice = .olympic; d.raceDate = day(83); d.experience = .intermediate; d.hoursPerWeek = 8
        let base = model(d, today: 14)
        guard let wp = base.weekPlan, let idx = wp.weekIndex(containing: day(14), calendar: wp.resolvedCalendar(cal)) else { return XCTFail() }
        let key = EaseStore.weekKey(wp.weeks[idx].startDate, calendar: wp.resolvedCalendar(cal))
        let eased = model(d, today: 14, eased: [key])
        XCTAssertEqual(base.week.flatMap(\.sessions).map(\.engineID), eased.week.flatMap(\.sessions).map(\.engineID))
    }

    // MARK: Copy

    private let jargon = PlainCopy.bannedInPlainText + ["t1", "t2", "transition", "drafting", "ftp", "tss", "ctl", "atl"]

    private func assertPlain(_ text: String, allowing allowed: [String] = [], _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let lower = text.lowercased()
        XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "dash in \(label): \(text)", file: file, line: line)
        let words = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for term in jargon where !allowed.contains(term) {
            let hit = term.contains(" ") ? lower.contains(term) : words.contains(term)
            XCTAssertFalse(hit, "unexplained \"\(term)\" in \(label): \(text)", file: file, line: line)
        }
    }

    func testStartingPointCopyIsPlainAndDashFree() {
        for q in StartQuestion.allCases {
            assertPlain(q.title, "title"); assertPlain(q.prompt, "prompt")
            for a in StartAbility.allCases { assertPlain(q.answer(a), "answer") }
        }
        let combos: [StartingPoint] = [StartingPoint(), StartingPoint(swim: .notYet, bike: .notYet, run: .notYet),
                                       StartingPoint(swim: .comfortably, bike: .comfortably, run: .comfortably),
                                       StartingPoint(swim: .notYet, bike: .withEffort, run: .withEffort)]
        for p in combos {
            assertPlain(p.headline, "headline"); assertPlain(p.detail, "detail")
            for l in p.helpLines { assertPlain(l, "help") }
        }
    }

    func testRaceDayGuideHasNoUnexplainedJargonAndLinksTheGlossary() {
        for race in RaceChoice.allCases {
            for section in RaceDayGuide.sections(for: race) {
                for s in [section.title] + section.lines { assertPlain(s, "guide \(race.rawValue)/\(section.id)") }
                // The link label may name T1 and T2: it is the JargonText that explains them.
                if let label = section.termLabel { assertPlain(label, allowing: ["t1", "t2"], "guide link") }
                if section.id == "swimToBike" || section.id == "bikeToRun" {
                    XCTAssertEqual(section.term, .transition, "changing areas link the glossary")
                }
            }
            for s in RaceDayGuide.allText(for: race) { assertPlain(s, allowing: ["t1", "t2"], "guide text") }
        }
        XCTAssertTrue(RaceDayGuide.sections(for: .superSprint).contains { $0.id == "welcome" })
        XCTAssertFalse(RaceDayGuide.sections(for: .olympic).contains { $0.id == "welcome" })
    }

    func testGearListIsSplitAndNeedsNoPowerMeterOrWatch() {
        XCTAssertFalse(RaceDayGuide.requiredGear.isEmpty)
        XCTAssertFalse(RaceDayGuide.niceToHaveGear.isEmpty)
        let required = RaceDayGuide.requiredGear.map(\.name).joined(separator: " ").lowercased()
        for word in ["power meter", "watch", "gps", "heart rate"] { XCTAssertFalse(required.contains(word), word) }
        XCTAssertTrue(RaceDayGuide.gearIntro.lowercased().contains("power meter"))
        XCTAssertTrue(Set(RaceDayGuide.requiredGear.map(\.name)).isDisjoint(with: RaceDayGuide.niceToHaveGear.map(\.name)))
    }

    func testCoachingLinesAreShortPlainAndTalkBased() {
        for kind in [TriSpike.StepKind.warm, .work, .recovery, .cool] {
            for level in 1...5 {
                let line = Coaching.line(kind: kind, level: level)
                assertPlain(line, "coaching \(kind)/\(level)")
                XCTAssertLessThan(line.count, 100, line)
            }
        }
        XCTAssertTrue(Coaching.line(kind: .work, level: 2).contains("talk"))
        XCTAssertTrue(Coaching.line(kind: .warm, level: 1).contains("easy"))
        for sport in TriSpike.Sport.allCases {
            for top in 1...5 {
                for l in Coaching.sessionLines(sport: sport, topLevel: top, isRunWalk: sport == .run) { assertPlain(l, "session coaching") }
            }
        }
    }

    func testEaseCopyIsPlainAndKind() {
        for s in [EaseWeek.reason, EaseWeek.rule, EaseWeek.confirmMessage] { assertPlain(s, "ease") }
        let all = (EaseWeek.reason + EaseWeek.rule + EaseWeek.confirmMessage).lowercased()
        for shame in ["fail", "weak", "lazy", "give up", "quit"] { XCTAssertFalse(all.contains(shame), shame) }
    }

    func testRaceChoiceCopyIsDashFree() {
        for r in RaceChoice.allCases {
            for s in [r.title, r.summary, r.blurb, r.typicalWeeks, r.obPlanPhrase, r.obRacePhrase] { assertPlain(s, "race") }
        }
    }
}
