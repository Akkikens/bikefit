import XCTest
@testable import BricklinePlanKit

/// One test per behaviour fixed after the readiness review: the pending realignment reservation, source changes,
/// the statistics floors, rule 11 and rule 10 details, Garmin, cross week moves, keep planned session, the sync
/// guard, sleep fragments, unwell nights, bad input and the API shape.
final class ReadinessReviewFixTests: XCTestCase {
    private typealias F = ReadinessFixtures
    private let today = ReadinessFixtures.thursday
    private var calendar: Calendar { F.calendar }

    private func run(
        _ inputs: ReadinessInputs,
        plan: Plan? = nil,
        today: Date = ReadinessFixtures.thursday,
        history: [AdaptationEvent] = [],
        athleteEvents: [AthleteEvent] = [],
        reserved: Bool = false
    ) -> ReadinessResult {
        F.ruleSet().apply(
            to: plan ?? F.plan(), inputs: inputs, today: today, calendar: calendar,
            history: history, athleteEvents: athleteEvents, structuralReserved: reserved)
    }

    private func lowWeek(source: ReadinessSource = .oura) -> ReadinessInputs {
        F.inputs(source: source, recentLnHRV: { _ in 3.95 })
    }

    private func thursdayBike(_ plan: Plan) -> Session? {
        plan.adaptSessions(on: today, calendar: calendar).first
    }

    private func hardBike(week: Int, day: Date, slot: Int = 2) -> Session {
        F.session(week: week, day: day, sport: .bike, name: "Hill repeats", steps: [
            F.step(.bike, .warmUp, 15, level: 2, name: "Warm up"),
            F.step(.bike, .work, 5, level: 5, group: "h", count: 5, name: "Hard"),
            F.step(.bike, .coolDown, 10, level: 2, name: "Cool down")
        ], quality: true, slot: slot)
    }

    private func invalidInput(_ error: Error?) -> String? {
        if case let .invalidInput(text)? = error as? PlanKitError { return text }
        return nil
    }

    // MARK: Pending realignment reserves the day

    func testAPendingRealignmentPromptKeepsRules10And11OutOfTheDay() throws {
        let kit = PlanKit.standard
        let tuesday = F.date(2026, 11, 10)
        var state = AdaptationState(plan: F.plan())
        // Week 0 was missed in full, so rule 2 raises its prompt today. The week is low, with a short night too.
        let inputs = ReadinessInputs(
            nights: F.nights(today: tuesday, recentLnHRV: { _ in 3.95 }, recentSleep: { $0 == 0 ? 340 : 430 }),
            lastSyncDate: tuesday)
        let result = kit.adapt(&state, today: tuesday, readiness: inputs, calendar: calendar)

        XCTAssertNotNil(result.pendingRealignment)
        XCTAssertTrue(result.events.contains { $0.rule == .realignmentPrompt })
        XCTAssertFalse(result.events.contains { $0.rule == .readinessDefer || $0.rule == .readinessEasy })
        XCTAssertEqual(state.plan.adaptSessions(on: tuesday, calendar: calendar).map(\.name), ["Threshold run"])
        // Rule 12 is not structural, so its note is still written.
        XCTAssertTrue(result.events.contains { $0.rule == .sleepNote })
        XCTAssertEqual(result.readinessAssessment?.hasRoomForChange, false)
        XCTAssertEqual(result.readinessAssessment?.canChangePlanToday, false)
        // The athlete's confirmation of the same prompt still works.
        XCTAssertNoThrow(try state.realign(.compress, using: kit.adaptation, today: tuesday, calendar: calendar))
    }

    func testStructuralReservedBlocksOnlyThePlanChanges() {
        let reserved = run(lowWeek(), reserved: true)
        XCTAssertTrue(reserved.events.isEmpty)
        XCTAssertEqual(reserved.plan, F.plan())
        XCTAssertFalse(reserved.assessment.hasRoomForChange)
        XCTAssertEqual(run(lowWeek(), reserved: false).events.map(\.rule), [.readinessDefer])
        let note = run(F.inputs(recentSleep: { $0 == 0 ? 340 : 430 }), reserved: true)
        XCTAssertEqual(note.events.map(\.rule), [.sleepNote])
    }

    func testPlanKitReadinessOnStateTakesThePendingFlag() {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        let blocked = kit.readiness(state: &state, inputs: lowWeek(), today: today, calendar: calendar, pendingRealignment: true)
        XCTAssertTrue(state.history.isEmpty)
        XCTAssertEqual(state.plan, F.plan())
        XCTAssertFalse(blocked.hasRoomForChange)
        kit.readiness(state: &state, inputs: lowWeek(), today: today, calendar: calendar)
        XCTAssertEqual(state.history.map(\.rule), [.readinessDefer])
        XCTAssertNotEqual(state.plan, F.plan())
    }

    func testARetestOrAnyAdaptationChangeEarlierTodayBeatsAReadinessChange() {
        // Precedence with rule 8 (and rules 1, 4 to 6): the adaptation rules go first and readiness yields.
        let retest = AdaptationEvent(
            rule: .retest, reasonLine: "Added a test.", date: today, isStructural: true, sessionIDs: ["test"])
        let result = run(lowWeek(), history: [retest])
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.plan, F.plan())
    }

    // MARK: Source change restarts calibration (rule 9)

    func testSourceChangeRestartsCalibrationEvenWhenTheNewSourceHasHistory() {
        let oura = F.nights(source: .oura)
        let whoop = F.nights(source: .whoop, recentLnHRV: { _ in 3.95 })
        var inputs = ReadinessInputs(nights: oura + whoop, lastSyncDate: today, preferredRecoverySource: .whoop)
        XCTAssertEqual(run(inputs).events.map(\.rule), [.readinessDefer], "no change reported, so WHOOP is calibrated")

        inputs.sourceChangedOn = today
        let result = run(inputs)
        XCTAssertEqual(result.assessment.status, .calibrating(night: 1, of: 14))
        XCTAssertEqual(result.assessment.line, "Learning your baseline, night 1 of 14.")
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.sourceChangedOn, today)
        XCTAssertEqual(result.assessment.calibration?.validNights, 1)

        inputs.sourceChangedOn = F.day(-12)
        XCTAssertEqual(run(inputs).assessment.status, .calibrating(night: 13, of: 14))
        inputs.sourceChangedOn = F.day(-13)
        XCTAssertEqual(run(inputs).events.map(\.rule), [.readinessDefer], "fourteen nights since the change opens the gate")
    }

    func testAnAutomaticFlipSeenThroughTheActiveSourceRestartsCalibration() {
        let nights = F.nights(source: .oura) + F.nights(source: .whoop, recentLnHRV: { _ in 3.95 })
        var inputs = ReadinessInputs(nights: nights, lastSyncDate: today, preferredRecoverySource: .whoop, activeSource: .oura)
        let flipped = run(inputs)
        XCTAssertEqual(flipped.assessment.status, .calibrating(night: 1, of: 14))
        XCTAssertEqual(flipped.assessment.sourceChangedOn, today)
        XCTAssertTrue(flipped.events.isEmpty)

        inputs.activeSource = .whoop
        let same = run(inputs)
        XCTAssertNil(same.assessment.sourceChangedOn)
        XCTAssertEqual(same.events.map(\.rule), [.readinessDefer])
    }

    func testASourceWithAQuietWeekIsKeptInsteadOfFlipping() {
        let quiet = F.nights(
            source: .oura, recentLnHRV: { $0 < 2 ? 4.0 : nil }, recentRHR: { $0 < 2 ? 52 : nil }, recentSleep: { $0 < 2 ? 430 : nil })
        let whoop = F.nights(source: .whoop)
        var inputs = ReadinessInputs(nights: quiet + whoop, lastSyncDate: today)
        XCTAssertEqual(run(inputs).assessment.source?.source, .whoop, "without history the order decides")

        inputs.activeSource = .oura
        let kept = run(inputs)
        XCTAssertEqual(kept.assessment.source?.source, .oura)
        XCTAssertEqual(kept.assessment.source?.reason, .keptCurrent)
        XCTAssertEqual(kept.assessment.source?.explanation, "Using Oura, the source you have been using.")
        XCTAssertEqual(kept.assessment.status, .paused(.tooFewRecentNights))
        XCTAssertNil(kept.assessment.sourceChangedOn, "no restart: the baseline did not change")

        // A ring that sent nothing all week is a real change.
        let dead = F.nights(source: .oura).filter { $0.date <= F.day(-7) }
        inputs = ReadinessInputs(nights: dead + whoop, lastSyncDate: today, activeSource: .oura)
        XCTAssertEqual(run(inputs).assessment.source?.source, .whoop)
    }

    // MARK: Statistics floors and the baseline length

    func testPerMetricFloorsStopSmallChangesFromFiringRule11() {
        var list: [ReadinessNight] = []
        for age in 7...41 {
            list.append(ReadinessNight(
                date: F.day(-age), source: .oura, hrvMilliseconds: 60,
                restingHeartRate: age % 2 == 0 ? 52 : 53, sleepMinutes: 420))
        }
        for age in 0..<7 {
            let ln = age < 2 ? log(60.0) - 0.06 : log(60.0)
            list.append(ReadinessNight(
                date: F.day(-age), source: .oura, hrvMilliseconds: exp(ln),
                restingHeartRate: age == 0 ? 54 : 52.5, sleepMinutes: 420))
        }
        // A flat baseline and a 1 bpm rise: under the old 2 percent floor both rules fired on this noise.
        let result = run(ReadinessInputs(nights: list, lastSyncDate: today))
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.restingHeartRate.level, .usual)
        XCTAssertEqual(result.assessment.hrv.level, .usual)
    }

    func testMetricBaselineFloorIsPerMetric() {
        var hrv = MetricBaseline(mean: 4, standardDeviation: 0.01)
        XCTAssertEqual(hrv.effectiveSD ?? 0, ReadinessConstants.minimumHRVLogSD, accuracy: 1e-12)
        hrv.floor = ReadinessConstants.minimumRestingHeartRateLogSD
        XCTAssertEqual(hrv.effectiveSD ?? 0, ReadinessConstants.minimumRestingHeartRateLogSD, accuracy: 1e-12)
        XCTAssertEqual(MetricBaseline(mean: 4, standardDeviation: 0.2).effectiveSD ?? 0, 0.2, accuracy: 1e-12)
    }

    func testASevenNightBaselineIsNotEnoughToFire() {
        // Fourteen valid nights, only seven of them in the baseline: no mean and SD, no rule, night 13.
        let thin = F.nights(baselineDays: 7...13, recentLnHRV: { _ in 3.6 })
        let result = run(ReadinessInputs(nights: thin, lastSyncDate: today))
        XCTAssertEqual(result.assessment.calibration?.baselineNights, 7)
        XCTAssertFalse(result.assessment.calibration?.isCalibrated ?? true)
        XCTAssertEqual(result.assessment.line, "Learning your baseline, night 13 of 14.")
        XCTAssertTrue(result.events.isEmpty)
    }

    // MARK: Rule 11 reads today's check-in

    func testRule11NeedsTodaysCheckInAndSaysSo() throws {
        let week: (Int) -> Double? = { $0 < 2 ? 3.90 : 3.98 }
        let fired = run(F.inputs(recentLnHRV: week, checkIns: [F.checkIn(1, 5), F.checkIn(0, 2)]))
        let event = try XCTUnwrap(fired.events.first)
        XCTAssertEqual(event.rule, .readinessEasy)
        XCTAssertTrue(event.reasonLine.contains("your check-in was low"))
        // The same low check-in from yesterday does not back a swap today.
        let stale = run(F.inputs(recentLnHRV: week, checkIns: [F.checkIn(1, 2)]))
        XCTAssertFalse(stale.events.contains { $0.rule == .readinessEasy })
    }

    // MARK: Garmin

    private func garminNights(todaySleep: Double = 420, hrv: (Int) -> Double? = { _ in nil }) -> [ReadinessNight] {
        (0..<42).map { age in
            ReadinessNight(
                date: F.day(-age), source: .garmin, hrvMilliseconds: hrv(age),
                restingHeartRate: 52 + F.rhrCycle[age % 5],
                sleepMinutes: age == 0 ? todaySleep : 420 + F.sleepCycle[age % 5])
        }
    }

    func testAGarminSourceWithSleepAndRestingHeartRateOnlyGetsTheSleepNote() throws {
        let result = run(ReadinessInputs(nights: garminNights(todaySleep: 300), lastSyncDate: today))
        XCTAssertEqual(result.assessment.source?.source, .garmin)
        XCTAssertEqual(result.assessment.calibration?.isCalibrated, true)
        XCTAssertNotEqual(result.assessment.status, .noData)
        XCTAssertEqual(result.events.map(\.rule), [.sleepNote])
        XCTAssertEqual(result.assessment.sleepNote, "Short night. Sleep was 5h, about 2h under your usual.")
        XCTAssertFalse(result.assessment.hrv.isAvailable)
        XCTAssertEqual(result.plan, F.plan())
    }

    func testGarminHRVCannotTriggerRule10OrRule11() {
        // Even if a host passes a Garmin HRV series with a collapse, none is read.
        let collapse = garminNights(hrv: { $0 < 7 ? 20 : 60 })
        let result = run(ReadinessInputs(nights: collapse, checkIns: [F.checkIn(0, 4)], lastSyncDate: today))
        XCTAssertFalse(result.events.contains { $0.rule == .readinessDefer || $0.rule == .readinessEasy })
        XCTAssertEqual(result.plan, F.plan())
        XCTAssertTrue(result.assessment.hrv.level == .unavailable)
    }

    func testAGarminSourceGetsTheCheckInFormOfRule11() throws {
        let nights = garminNights()
        let both = run(ReadinessInputs(nights: nights, checkIns: [F.checkIn(0, 1), F.checkIn(1, 2)], lastSyncDate: today))
        let event = try XCTUnwrap(both.events.first)
        XCTAssertEqual(event.rule, .readinessEasy)
        XCTAssertTrue(event.reasonLine.contains("Your last two check-ins were low."))
        let one = run(ReadinessInputs(nights: nights, checkIns: [F.checkIn(0, 1)], lastSyncDate: today))
        XCTAssertTrue(one.events.isEmpty)
    }

    func testAnHRVSourceWithoutAnHRVBaselineFallsBackToCheckIns() {
        let sleepOnly = (0..<42).map {
            ReadinessNight(date: F.day(-$0), source: .oura, sleepMinutes: 420)
        }
        let result = run(ReadinessInputs(
            nights: sleepOnly, checkIns: [F.checkIn(0, 2), F.checkIn(1, 2)], lastSyncDate: today))
        XCTAssertEqual(result.events.map(\.rule), [.readinessEasy])
        XCTAssertEqual(result.assessment.source?.source, .oura)
    }

    // MARK: Cross week placement

    func testAHardBikeCannotMoveToSundayBesideNextMondaysHardBike() throws {
        var plan = F.plan()
        let sunday = F.date(2026, 11, 8)
        let monday = F.date(2026, 11, 9)
        for session in plan.adaptSessions(on: sunday, calendar: calendar) { plan.adaptRemove(id: session.id) }
        XCTAssertTrue(plan.adaptInsert(hardBike(week: 1, day: monday), calendar: calendar))
        let bike = try XCTUnwrap(thursdayBike(plan))
        XCTAssertEqual(
            PlanMoveRules.problem(for: bike, on: sunday, in: plan, calendar: calendar, emptyOnly: false),
            "Hard days in the same sport need a day between them.")
        XCTAssertNil(PlanMoveRules.problem(
            for: bike, on: F.date(2026, 11, 7), in: plan, calendar: calendar, emptyOnly: false))
    }

    func testAHardBikeCannotMoveToMondayBesideLastSundaysHardBike() throws {
        var plan = F.plan()
        let sunday = F.date(2026, 11, 8)
        XCTAssertTrue(plan.adaptInsert(hardBike(week: 0, day: sunday), calendar: calendar))
        let nextThursday = F.date(2026, 11, 12)
        let bike = try XCTUnwrap(plan.adaptSessions(on: nextThursday, calendar: calendar).first)
        XCTAssertEqual(
            PlanMoveRules.problem(for: bike, on: F.date(2026, 11, 9), in: plan, calendar: calendar, emptyOnly: false),
            "Hard days in the same sport need a day between them.")
        // The by hand move uses the same rule.
        XCTAssertThrowsError(try PlanKit.standard.moveSession(
            bike.id, to: F.date(2026, 11, 9), in: plan, today: today, calendar: calendar))
    }

    func testTheLongRunAndLongRideKeepADayApartAcrossTheWeekBoundary() throws {
        let plan = F.plan()
        // Week 0 ends with the long ride on Sunday. A week 1 long run may not go to the Monday after it.
        let longRun = try XCTUnwrap(plan.adaptSessions(on: F.date(2026, 11, 14), calendar: calendar).first)
        XCTAssertEqual(longRun.name, "Long run")
        XCTAssertEqual(
            PlanMoveRules.problem(for: longRun, on: F.date(2026, 11, 9), in: plan, calendar: calendar, emptyOnly: false),
            "Keep the long ride and the long run at least a day apart.")
    }

    // MARK: Rule 10 destination and repeats

    func testRule10PrefersAnEmptyDayToAnOccupiedOne() throws {
        var plan = F.plan()
        let saturday = F.date(2026, 11, 7)
        for session in plan.adaptSessions(on: saturday, calendar: calendar) { plan.adaptRemove(id: session.id) }
        let withEmpty = run(lowWeek(), plan: plan)
        XCTAssertTrue(try XCTUnwrap(withEmpty.events.first).reasonLine.hasPrefix("Moved Thursday's bike intervals to Saturday."))
        // With no empty day, the occupied Friday (an easy swim in another sport) is the fallback.
        let none = run(lowWeek())
        XCTAssertTrue(try XCTUnwrap(none.events.first).reasonLine.hasPrefix("Moved Thursday's bike intervals to Friday."))
    }

    func testTheSharedMoveHelperMatchesRuleOnesOrder() throws {
        var plan = F.plan()
        let saturday = F.date(2026, 11, 7)
        for session in plan.adaptSessions(on: saturday, calendar: calendar) { plan.adaptRemove(id: session.id) }
        let bike = try XCTUnwrap(thursdayBike(plan))
        XCTAssertEqual(
            PlanMoveRules.firstAllowedDay(for: bike, from: F.friday, through: F.date(2026, 11, 8), in: plan, calendar: calendar),
            saturday)
        XCTAssertEqual(
            PlanMoveRules.firstAllowedDay(
                for: bike, from: F.friday, through: F.date(2026, 11, 8), in: plan, calendar: calendar,
                isExcluded: { $0 == saturday }),
            F.friday)
        XCTAssertNil(PlanMoveRules.firstAllowedDay(for: bike, from: F.friday, through: F.thursday, in: plan, calendar: calendar))
    }

    func testRule10DoesNotMoveTheSameSessionAgainOnTheNextDay() throws {
        let first = run(lowWeek())
        let event = try XCTUnwrap(first.events.first)
        XCTAssertTrue(event.reasonLine.hasPrefix("Moved Thursday's bike intervals to Friday."))

        // Friday: the 7 night mean is still low and the moved session is the hard session of the day.
        let nextDay = ReadinessInputs(
            nights: F.nights(today: F.friday, recentLnHRV: { _ in 3.95 }), lastSyncDate: F.friday)
        let second = run(nextDay, plan: first.plan, today: F.friday, history: first.events)
        let again = try XCTUnwrap(second.events.first)
        XCTAssertEqual(again.rule, .readinessDefer)
        XCTAssertTrue(again.reasonLine.hasPrefix("Today's bike intervals became an easy ride."), again.reasonLine)
        let session = try XCTUnwrap(second.plan.session(withID: event.sessionIDs[0]))
        XCTAssertEqual(calendar.startOfDay(for: session.scheduledDate), F.friday, "it stayed on Friday")
        XCTAssertFalse(AdaptationSupport.isHard(session))
        // Without the history the second day would have slid it to Saturday.
        let forgotten = run(nextDay, plan: first.plan, today: F.friday)
        XCTAssertTrue(try XCTUnwrap(forgotten.events.first).reasonLine.hasPrefix("Moved Friday's bike intervals to"))
    }

    func testSeveralHardSessionsGetALineBuiltFromCounts() throws {
        func plan(available: Set<Weekday>) -> Plan {
            var plan = F.plan(available: available)
            let hardRun = F.session(week: 0, day: today, sport: .run, name: "Hill run", steps: [
                F.step(.run, .warmUp, 10, level: 2, name: "Warm up"),
                F.step(.run, .work, 4, level: 5, group: "r", count: 5, name: "Hard"),
                F.step(.run, .coolDown, 10, level: 2, name: "Cool down")
            ], quality: true)
            XCTAssertTrue(plan.adaptInsert(hardRun, calendar: calendar))
            return plan
        }
        // Only Friday is open: one session moves there, the other has no day and becomes easy.
        let mixed = run(lowWeek(), plan: plan(available: [.monday, .tuesday, .wednesday, .thursday, .friday]))
        let mixedEvent = try XCTUnwrap(mixed.events.first)
        XCTAssertTrue(
            mixedEvent.reasonLine.hasPrefix("Moved 1 of today's 2 hard sessions to later days and made 1 easy."), mixedEvent.reasonLine)
        XCTAssertEqual(mixedEvent.sessionIDs.count, 2)
        // No later day open: both become easy.
        let eased = run(lowWeek(), plan: plan(available: [.monday, .tuesday, .wednesday, .thursday]))
        XCTAssertTrue(try XCTUnwrap(eased.events.first).reasonLine.hasPrefix("Today's 2 hard sessions became easy sessions."))
        // Open days for both: both move.
        let moved = run(lowWeek(), plan: plan(available: Set(Weekday.allCases)))
        XCTAssertTrue(try XCTUnwrap(moved.events.first).reasonLine.hasPrefix("Moved today's 2 hard sessions to later days."))
    }

    func testRule10OnASundayMakesTheSessionEasyAndNothingLandsInNextWeek() throws {
        var plan = F.plan()
        let sunday = F.date(2026, 11, 8)
        let hardRun = F.session(week: 0, day: sunday, sport: .run, name: "Threshold run", steps: [
            F.step(.run, .warmUp, 10, level: 2, name: "Warm up"),
            F.step(.run, .work, 8, level: 4, group: "g", count: 3, name: "Threshold"),
            F.step(.run, .coolDown, 10, level: 2, name: "Cool down")
        ], quality: true)
        XCTAssertTrue(plan.adaptInsert(hardRun, calendar: calendar))
        let inputs = ReadinessInputs(nights: F.nights(today: sunday, recentLnHRV: { _ in 3.95 }), lastSyncDate: sunday)
        let result = run(inputs, plan: plan, today: sunday)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertTrue(event.reasonLine.hasPrefix("Today's threshold run became an easy run."), event.reasonLine)
        XCTAssertEqual(result.plan.weeks[1], plan.weeks[1], "nothing moved into the next week")
        XCTAssertEqual(result.plan.weeks[0].sessions.count, plan.weeks[0].sessions.count)
    }

    func testNextFreeDayAndTheRaceEveLimitDirectly() throws {
        let kit = F.ruleSet()
        let bike = try XCTUnwrap(thursdayBike(F.plan()))
        func context(_ plan: Plan) -> AdaptationRun {
            AdaptationRun(context: AdaptationContext(today: today), calendar: calendar)
        }
        // Race on Sunday: Saturday is the eve and Sunday is race day, so only Friday is left.
        let sundayRace = F.plan(raceDistance: .sprint, raceDate: F.date(2026, 11, 8))
        XCTAssertEqual(kit.nextFreeDay(for: bike, in: sundayRace, run: context(sundayRace)), F.friday)
        // Race on Saturday: the eve is Friday and nothing heavy fits before it.
        let saturdayRace = F.plan(raceDistance: .sprint, raceDate: F.date(2026, 11, 7))
        XCTAssertNil(kit.nextFreeDay(for: bike, in: saturdayRace, run: context(saturdayRace)))
        // No race: Friday as before.
        XCTAssertEqual(kit.nextFreeDay(for: bike, in: F.plan(), run: context(F.plan())), F.friday)
    }

    // MARK: Keep planned session

    func testKeepPlannedSessionIsOnlyValidOnTheDayOfTheChange() throws {
        let fired = run(lowWeek())
        let event = try XCTUnwrap(fired.events.first)
        XCTAssertThrowsError(try F.ruleSet().keepPlannedSession(event, in: fired.plan, today: F.friday, calendar: calendar)) {
            XCTAssertEqual(invalidInput($0), "That change is from an earlier day.")
        }
        XCTAssertNoThrow(try F.ruleSet().keepPlannedSession(
            event, in: fired.plan, today: today.addingTimeInterval(20 * 3600), calendar: calendar))
    }

    func testKeepPlannedSessionRefusesWhenTheOriginalDayNoLongerTakesTheSession() throws {
        let fired = run(lowWeek())
        let event = try XCTUnwrap(fired.events.first)
        var edited = fired.plan
        XCTAssertTrue(edited.adaptInsert(hardBike(week: 0, day: today), calendar: calendar))
        XCTAssertThrowsError(try F.ruleSet().keepPlannedSession(event, in: edited, today: today, calendar: calendar)) {
            XCTAssertEqual(invalidInput($0), "That day already has a hard session.")
        }
        // The plan was not touched by the failed attempt, and the clean one still restores.
        XCTAssertEqual(try F.ruleSet().keepPlannedSession(event, in: fired.plan, today: today, calendar: calendar).plan, F.plan())
    }

    func testKeepPlannedSessionRestoresAMultiSessionRule11SwapWithoutTripOverItself() throws {
        var plan = F.plan()
        plan.adaptInsert(hardBike(week: 0, day: today), calendar: calendar)
        let inputs = F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 58 : 52 })
        let fired = run(inputs, plan: plan)
        let event = try XCTUnwrap(fired.events.first)
        XCTAssertEqual(event.sessionIDs.count, 2)
        let kept = try F.ruleSet().keepPlannedSession(event, in: fired.plan, today: today, calendar: calendar)
        // Both hard sessions are back in their original form (their order within the day may differ).
        let back = kept.plan.adaptSessions(on: today, calendar: calendar)
        let before = plan.adaptSessions(on: today, calendar: calendar)
        XCTAssertEqual(back.map(\.id).sorted(), before.map(\.id).sorted())
        for session in before { XCTAssertEqual(kept.plan.session(withID: session.id), session) }
    }

    func testKeepPlannedSessionOnStateRecordsTheTapAndIsIdempotent() throws {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        kit.adapt(&state, today: today, readiness: lowWeek(), calendar: calendar)
        let event = try XCTUnwrap(state.history.first { $0.rule == .readinessDefer })
        XCTAssertTrue(event.canKeepPlannedSession)

        try kit.keepPlannedSession(event, in: &state, today: today, calendar: calendar)
        XCTAssertEqual(state.plan, F.plan())
        let stored = try XCTUnwrap(state.history.first { $0.rule == .readinessDefer })
        XCTAssertEqual(stored.advisory?.keptOn, today)
        XCTAssertFalse(stored.canKeepPlannedSession)

        let snapshot = state
        try kit.keepPlannedSession(event, in: &state, today: today, calendar: calendar)
        XCTAssertEqual(state, snapshot, "a second tap does nothing")

        var stranger = AdaptationState(plan: F.plan())
        XCTAssertThrowsError(try kit.keepPlannedSession(event, in: &stranger, today: today, calendar: calendar)) {
            XCTAssertEqual(invalidInput($0), "That change is not in your log.")
        }
    }

    func testAKeptChangeStillCountsTowardTheCapOfTwo() throws {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        kit.adapt(&state, today: today, readiness: lowWeek(), calendar: calendar)
        let event = try XCTUnwrap(state.history.first { $0.rule == .readinessDefer })
        try kit.keepPlannedSession(event, in: &state, today: today, calendar: calendar)
        let next = ReadinessInputs(nights: F.nights(today: F.friday), lastSyncDate: F.friday)
        let result = run(next, plan: state.plan, today: F.friday, history: state.history)
        XCTAssertEqual(result.assessment.planChangesInLast7Days, 1)
        XCTAssertEqual(result.assessment.overridesInLast14Days, 1)
    }

    func testOverridesAreReadFromTheLogWithoutTheHostRememberingThem() {
        func kept(_ age: Int) -> AdaptationEvent {
            AdaptationEvent(
                rule: .readinessDefer, reasonLine: "Earlier.", date: F.day(-age), isStructural: true, sessionIDs: ["x"],
                advisory: AdvisoryChange(originalSessions: [], keptOn: F.day(-age)))
        }
        let result = run(F.inputs(), history: [kept(1), kept(2), kept(3)])
        XCTAssertEqual(result.assessment.overridesInLast14Days, 3)
        XCTAssertEqual(result.assessment.status, .paused(.notesOnly))
        // The same day from the log and from the optional list counts once.
        let overlap = run(
            ReadinessInputs(nights: F.nights(), overrides: [F.day(-1).addingTimeInterval(3600)], lastSyncDate: today),
            history: [kept(1), kept(1)])
        XCTAssertEqual(overlap.assessment.overridesInLast14Days, 1)
        // An old tap falls out of the window.
        XCTAssertEqual(run(F.inputs(), history: [kept(20)]).assessment.overridesInLast14Days, 0)
    }

    func testRecordingAnOverrideTwiceKeepsOneEntry() {
        let once = ReadinessInputs().recordingOverride(on: today)
        XCTAssertEqual(once.recordingOverride(on: today).overrides, [today])
    }

    func testPruningDropsOldOriginalsAndKeepsTheKeptMark() throws {
        var state = AdaptationState(plan: F.plan())
        let original = try XCTUnwrap(thursdayBike(F.plan()))
        func event(_ age: Int, kept: Date?) -> AdaptationEvent {
            AdaptationEvent(
                rule: .readinessDefer, reasonLine: "Change \(age).", date: F.day(-age), isStructural: true,
                sessionIDs: [original.id], advisory: AdvisoryChange(originalSessions: [original], keptOn: kept))
        }
        state.history = [event(3, kept: F.day(-3)), event(2, kept: nil), event(0, kept: nil)]
        state.pruneAdvisories(before: today, calendar: calendar)
        XCTAssertTrue(state.history[0].advisory?.originalSessions.isEmpty ?? false)
        XCTAssertEqual(state.history[0].advisory?.keptOn, F.day(-3))
        XCTAssertTrue(state.history[1].advisory?.originalSessions.isEmpty ?? false)
        XCTAssertFalse(state.history[1].canKeepPlannedSession)
        XCTAssertEqual(state.history[2].advisory?.originalSessions.count, 1, "today's change can still be kept")
        // Pruned and stored events still decode.
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(AdaptationState.self, from: data), state)
    }

    // MARK: Sync guard

    func testStaleNightsWithAFreshSyncDateStillSilenceReadiness() {
        // The host stamped the pull attempt as the sync date, but the newest night is four days old.
        let inputs = F.inputs(
            recentLnHRV: { $0 >= 4 ? 3.95 : nil }, recentRHR: { $0 >= 4 ? 52 : nil }, recentSleep: { $0 >= 4 ? 430 : nil })
        let result = run(inputs)
        XCTAssertEqual(result.assessment.status, .paused(.noRecentSync))
        XCTAssertTrue(result.events.isEmpty)
        // One day old is still fine.
        let yesterday = F.inputs(
            recentLnHRV: { $0 >= 1 ? 3.95 : nil }, recentRHR: { $0 >= 1 ? 52 : nil }, recentSleep: { $0 >= 1 ? 430 : nil })
        XCTAssertNotEqual(run(yesterday).assessment.status, .paused(.noRecentSync))
    }

    func testAFreshAppleWatchSyncCannotMaskADeadRing() {
        let deadRing = F.nights(source: .oura).filter { $0.date <= F.day(-4) }
        let watch = F.nights(source: .appleWatch)
        let nights = deadRing + watch
        var inputs = ReadinessInputs(
            nights: nights, lastSyncBySource: [.appleWatch: today, .oura: F.day(-4)], preferredRecoverySource: .oura)
        XCTAssertEqual(run(inputs).assessment.status, .paused(.noRecentSync))
        // The ring delivered, but its sync stamp is three days old while the watch's is fresh.
        inputs = ReadinessInputs(
            nights: F.nights(source: .oura) + watch, lastSyncDate: today,
            lastSyncBySource: [.oura: F.day(-3), .appleWatch: today], preferredRecoverySource: .oura)
        XCTAssertEqual(run(inputs).assessment.status, .paused(.noRecentSync))
        // The chosen source's own stamp wins over the single date.
        inputs.lastSyncBySource = [.oura: today]
        inputs.lastSyncDate = F.day(-5)
        XCTAssertNotEqual(run(inputs).assessment.status, .paused(.noRecentSync))
    }

    func testTheLatestNightOfTheChosenSourceNotOfAnySourceDecidesStaleness() {
        // Oura is silent for five days; Apple Watch delivered this morning. With the ring chosen, readiness is silent.
        let nights = F.nights(source: .oura).filter { $0.date <= F.day(-5) } + F.nights(source: .appleWatch)
        let result = run(ReadinessInputs(nights: nights, preferredRecoverySource: .oura))
        XCTAssertEqual(result.assessment.status, .paused(.noRecentSync))
    }

    func testTimeOfDayDoesNotMoveTheMomentATimestampedNightGoesStale() {
        // Nights dated 07:30. Newest is Wednesday: one whole day old at any hour of Thursday.
        let morning = F.nights(today: F.day(-1)).map { night -> ReadinessNight in
            var shifted = night
            shifted.date = night.date.addingTimeInterval(7.5 * 3600)
            return shifted
        }
        for hour in [0, 7, 23] {
            let now = F.date(2026, 11, 5, hour: hour)
            XCTAssertNotEqual(
                run(ReadinessInputs(nights: morning), today: now).assessment.status, .paused(.noRecentSync), "hour \(hour)")
        }
        // Newest night on Tuesday is two whole days old from the first minute of Thursday.
        let older = F.nights(today: F.day(-2)).map { night -> ReadinessNight in
            var shifted = night
            shifted.date = night.date.addingTimeInterval(23.5 * 3600)
            return shifted
        }
        for hour in [0, 12, 23] {
            let now = F.date(2026, 11, 5, hour: hour)
            XCTAssertEqual(
                run(ReadinessInputs(nights: older), today: now).assessment.status, .paused(.noRecentSync), "hour \(hour)")
        }
    }

    func testANotANumberSyncDateCountsAsStale() {
        var inputs = F.inputs()
        inputs.lastSyncDate = Date(timeIntervalSinceReferenceDate: .nan)
        XCTAssertEqual(run(inputs).assessment.status, .paused(.noRecentSync))
        inputs.lastSyncDate = nil
        inputs.lastSyncBySource = [.oura: Date(timeIntervalSinceReferenceDate: .nan)]
        XCTAssertEqual(run(inputs).assessment.status, .paused(.noRecentSync))
    }

    // MARK: Sleep fragments

    func testFragmentsOfOneNightAreSummedNotAveraged() {
        let nights = [
            ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: 240),
            ReadinessNight(date: F.day(0).addingTimeInterval(3600), source: .oura, sleepMinutes: 210)
        ]
        let b = BaselineCalculator.baseline(for: .oura, nights: nights, today: today, calendar: calendar)
        XCTAssertEqual(b.sleepByDaysAgo[0], 450)
    }

    func testALoneNapIsNotANightAndTheRangeAppliesToTheSum() {
        let nap = [ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: 90)]
        XCTAssertNil(BaselineCalculator.baseline(for: .oura, nights: nap, today: today, calendar: calendar).sleepByDaysAgo[0])
        // A 100 minute and a 40 minute fragment make a 140 minute night, which is a plausible record.
        let pieces = [
            ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: 100),
            ReadinessNight(date: F.day(0).addingTimeInterval(60), source: .oura, sleepMinutes: 40)
        ]
        XCTAssertEqual(BaselineCalculator.baseline(for: .oura, nights: pieces, today: today, calendar: calendar).sleepByDaysAgo[0], 140)
        // Non finite and negative pieces are dropped before the sum.
        let junk = pieces + [
            ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: .nan),
            ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: -50)
        ]
        XCTAssertEqual(BaselineCalculator.baseline(for: .oura, nights: junk, today: today, calendar: calendar).sleepByDaysAgo[0], 140)
    }

    func testAnExactDuplicateRecordCountsOnce() {
        let record = ReadinessNight(date: F.day(0), source: .oura, sleepMinutes: 240)
        let b = BaselineCalculator.baseline(for: .oura, nights: [record, record], today: today, calendar: calendar)
        XCTAssertEqual(b.sleepByDaysAgo[0], 240)
    }

    func testASixHourNightRecordedInFragmentsRaisesTheNoteButNotOneThatSumsToSevenHours() {
        func inputs(todayPieces: [Double]) -> ReadinessInputs {
            var list = F.nights(recentSleep: { $0 == 0 ? nil : 430 })
            for (index, minutes) in todayPieces.enumerated() {
                list.append(ReadinessNight(
                    date: F.day(0).addingTimeInterval(Double(index) * 60), source: .oura, sleepMinutes: minutes))
            }
            return ReadinessInputs(nights: list, lastSyncDate: today)
        }
        let short = run(inputs(todayPieces: [240, 120]))
        XCTAssertEqual(short.events.map(\.rule), [.sleepNote])
        XCTAssertEqual(short.assessment.sleep.value, 360)
        XCTAssertNil(run(inputs(todayPieces: [240, 180])).assessment.sleepNote)
    }

    // MARK: Unwell nights stay out of the baseline

    func testNightsInsideAnUnwellPeriodDoNotMoveTheBaseline() throws {
        var list = F.nights()
        for index in list.indices {
            let age = calendar.daysBetween(list[index].date, today)
            if (4...12).contains(age) { list[index].hrvMilliseconds = exp(3.5) }
        }
        let events: [AthleteEvent] = [.unwellStarted(on: F.day(-12)), .unwellEnded(on: F.day(-3))]
        let inputs = ReadinessInputs(nights: list, lastSyncDate: today)
        let with = run(inputs, athleteEvents: events)
        let reference = try XCTUnwrap(with.assessment.hrv.reference)
        XCTAssertEqual(log(reference), 4.0, accuracy: 0.03, "the unwell nights are left out")
        // The same nights outside an unwell period pull the mean down.
        let without = run(inputs)
        XCTAssertLessThan(log(try XCTUnwrap(without.assessment.hrv.reference)), 3.95)
        XCTAssertEqual(with.assessment.calibration?.validNights, 42 - 9)
    }

    // MARK: Inputs and types

    func testACheckInScoreIsClampedWhenDecodedAndWhenMutated() throws {
        func decode(_ score: Int) throws -> ReadinessCheckIn {
            try JSONDecoder().decode(ReadinessCheckIn.self, from: Data("{\"date\":0,\"score\":\(score)}".utf8))
        }
        XCTAssertEqual(try decode(99).score, 5)
        XCTAssertEqual(try decode(0).score, 1)
        XCTAssertEqual(try decode(-4).score, 1)
        XCTAssertEqual(try decode(3).score, 3)
        // A score set directly on the public field is clamped where it is read.
        var tap = F.checkIn(0, 3)
        tap.score = 99
        let result = run(F.inputs(checkIns: [tap]))
        XCTAssertEqual(result.assessment.checkIn.text, "Check-in 5 of 5.")
        tap.score = -3
        XCTAssertEqual(run(F.inputs(checkIns: [tap])).assessment.checkIn.text, "Check-in 1 of 5.")
        // A round trip keeps a valid value.
        let data = try JSONEncoder().encode(F.checkIn(0, 4))
        XCTAssertEqual(try JSONDecoder().decode(ReadinessCheckIn.self, from: data).score, 4)
    }

    func testInputsStoredBeforeTheSourceFieldsStillDecode() throws {
        let old = Data("{\"nights\":[],\"checkIns\":[],\"overrides\":[],\"preferredRecoverySource\":\"oura\"}".utf8)
        let inputs = try JSONDecoder().decode(ReadinessInputs.self, from: old)
        XCTAssertEqual(inputs.preferredRecoverySource, .oura)
        XCTAssertTrue(inputs.lastSyncBySource.isEmpty)
        XCTAssertNil(inputs.activeSource)
        let full = ReadinessInputs(
            nights: F.nights(), checkIns: [F.checkIn(0, 3)], overrides: [today], lastSyncDate: today,
            lastSyncBySource: [.oura: today], preferredRecoverySource: .whoop, activeSource: .oura, sourceChangedOn: today)
        XCTAssertEqual(try JSONDecoder().decode(ReadinessInputs.self, from: JSONEncoder().encode(full)), full)
    }

    func testRecoveryPreferenceMapsToTheStoredSetting() {
        var inputs = ReadinessInputs()
        XCTAssertEqual(inputs.recoveryPreference, .automatic)
        inputs.recoveryPreference = .source(.whoop)
        XCTAssertEqual(inputs.preferredRecoverySource, .whoop)
        XCTAssertEqual(inputs.recoveryPreference, .source(.whoop))
        inputs.recoveryPreference = .checkInsOnly
        XCTAssertEqual(inputs.preferredRecoverySource, .manual)
        XCTAssertEqual(inputs.recoveryPreference, .checkInsOnly)
        inputs.recoveryPreference = .automatic
        XCTAssertNil(inputs.preferredRecoverySource)
    }

    func testComponentsCarryTheNumbersBehindTheSentences() throws {
        let result = run(F.inputs(checkIns: [F.checkIn(0, 4)]))
        let hrv = result.assessment.hrv
        XCTAssertEqual(hrv.unit, .milliseconds)
        XCTAssertEqual(try XCTUnwrap(hrv.value), exp(4.0), accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(hrv.reference), exp(4.0), accuracy: 1e-6)
        let rhr = result.assessment.restingHeartRate
        XCTAssertEqual(rhr.unit, .beatsPerMinute)
        XCTAssertEqual(try XCTUnwrap(rhr.value), 52, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(rhr.reference), 52, accuracy: 0.1)
        let sleep = result.assessment.sleep
        XCTAssertEqual(sleep.unit, .minutes)
        XCTAssertEqual(sleep.value, 430)
        XCTAssertEqual(try XCTUnwrap(sleep.reference), 420, accuracy: 1e-9)
        XCTAssertEqual(result.assessment.checkIn.value, 4)
        XCTAssertEqual(result.assessment.checkIn.unit, .score)
        XCTAssertNil(ReadinessComponent().value)
    }

    func testCanChangePlanTodayNeedsAHardSessionButRoomDoesNot() {
        // Wednesday holds no session at all.
        let wednesday = F.wednesday
        let inputs = ReadinessInputs(nights: F.nights(today: wednesday), lastSyncDate: wednesday)
        let quiet = run(inputs, today: wednesday)
        XCTAssertTrue(quiet.assessment.hasRoomForChange)
        XCTAssertFalse(quiet.assessment.canChangePlanToday)
        let busy = run(F.inputs())
        XCTAssertTrue(busy.assessment.hasRoomForChange)
        XCTAssertTrue(busy.assessment.canChangePlanToday)
    }

    // MARK: Bad input never traps and never edits the plan

    func testNonFiniteAndExtremeInputsAreIgnored() {
        let bad = Date(timeIntervalSinceReferenceDate: .nan)
        var nights = F.nights()
        nights.append(ReadinessNight(
            date: today, source: .oura, hrvMilliseconds: .nan, restingHeartRate: .infinity, sleepMinutes: -.infinity))
        nights.append(ReadinessNight(date: bad, source: .oura, hrvMilliseconds: 1, restingHeartRate: 1, sleepMinutes: 1))
        nights.append(ReadinessNight(date: .distantPast, source: .oura, hrvMilliseconds: 40, restingHeartRate: 60, sleepMinutes: 200))
        nights.append(ReadinessNight(date: .distantFuture, source: .oura, hrvMilliseconds: 40, restingHeartRate: 60, sleepMinutes: 200))
        let inputs = ReadinessInputs(
            nights: nights,
            checkIns: [ReadinessCheckIn(date: bad, score: 1), ReadinessCheckIn(date: .distantPast, score: 1),
                       ReadinessCheckIn(date: .distantFuture, score: 1)],
            overrides: [bad, .distantPast, .distantFuture],
            lastSyncDate: .distantFuture,
            lastSyncBySource: [.oura: bad],
            sourceChangedOn: bad)
        let result = run(inputs)
        XCTAssertEqual(result.plan, F.plan())
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.overridesInLast14Days, 0)
        // The bad sync stamp makes the chosen source stale, which is the safe side.
        XCTAssertEqual(result.assessment.status, .paused(.noRecentSync))
        // Without that stamp the rest of the junk is simply ignored.
        var cleaned = inputs
        cleaned.lastSyncBySource = [:]
        cleaned.lastSyncDate = today
        let ok = run(cleaned)
        XCTAssertEqual(ok.plan, F.plan())
        XCTAssertEqual(ok.assessment.status, .onTrack)
        XCTAssertNil(ok.assessment.sourceChangedOn)
    }

    // MARK: Night builder

    func testBuilderDatesANightByTheWakeDayAndSumsFragments() throws {
        let start = F.date(2026, 11, 4, hour: 23)
        let intervals = [
            SleepInterval(start: start, end: start.addingTimeInterval(4 * 3600)),
            SleepInterval(start: start.addingTimeInterval(4 * 3600 + 600), end: start.addingTimeInterval(6 * 3600 + 600))
        ]
        let nights = ReadinessNightBuilder.nights(
            hrvSamples: [], restingHeartRate: [], sleepIntervals: intervals, source: .oura, calendar: calendar)
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].date, F.thursday, "woke on Thursday")
        XCTAssertEqual(nights[0].sleepMinutes, 360)
        XCTAssertEqual(nights[0].source, .oura)
    }

    func testBuilderMergesOverlapsAndDropsBadIntervals() {
        let start = F.date(2026, 11, 4, hour: 23)
        let intervals = [
            SleepInterval(start: start, end: start.addingTimeInterval(5 * 3600)),
            SleepInterval(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7 * 3600)),
            SleepInterval(start: start.addingTimeInterval(7 * 3600), end: start.addingTimeInterval(6 * 3600)),
            SleepInterval(start: Date(timeIntervalSinceReferenceDate: .nan), end: start)
        ]
        let nights = ReadinessNightBuilder.nights(
            hrvSamples: [], restingHeartRate: [], sleepIntervals: intervals, source: .whoop, calendar: calendar)
        XCTAssertEqual(nights.map(\.sleepMinutes), [420])
    }

    func testBuilderCountsHRVOnlyInsideSleepAndAveragesIt() throws {
        let start = F.date(2026, 11, 4, hour: 23)
        let sleep = [SleepInterval(start: start, end: start.addingTimeInterval(8 * 3600))]
        let samples = [
            ReadinessSample(date: start.addingTimeInterval(2 * 3600), value: 40),
            ReadinessSample(date: start.addingTimeInterval(5 * 3600), value: 60),
            ReadinessSample(date: F.date(2026, 11, 5, hour: 15), value: 200), // a daytime reading
            ReadinessSample(date: start.addingTimeInterval(3 * 3600), value: .nan)
        ]
        let nights = ReadinessNightBuilder.nights(
            hrvSamples: samples, restingHeartRate: [], sleepIntervals: sleep, source: .appleWatch, calendar: calendar)
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].hrvMilliseconds, 50)
        XCTAssertEqual(nights[0].source, .appleWatch)
    }

    func testBuilderDatesRestingHeartRateByItsCalendarDayAndNeedsNoSleep() {
        let samples = [
            ReadinessSample(date: F.date(2026, 11, 4, hour: 9), value: 50),
            ReadinessSample(date: F.date(2026, 11, 4, hour: 18), value: 52),
            ReadinessSample(date: F.date(2026, 11, 5, hour: 9), value: 54)
        ]
        let nights = ReadinessNightBuilder.nights(
            hrvSamples: [], restingHeartRate: samples, sleepIntervals: [], source: .garmin, calendar: calendar)
        XCTAssertEqual(nights.map(\.date), [F.wednesday, F.thursday])
        XCTAssertEqual(nights.map(\.restingHeartRate), [51, 54])
        XCTAssertNil(nights[0].sleepMinutes)
    }

    func testBuilderIsIndependentOfInputOrder() {
        let start = F.date(2026, 11, 4, hour: 23)
        let sleep = [
            SleepInterval(start: start, end: start.addingTimeInterval(3 * 3600)),
            SleepInterval(start: start.addingTimeInterval(4 * 3600), end: start.addingTimeInterval(8 * 3600))
        ]
        let hrv = [
            ReadinessSample(date: start.addingTimeInterval(3600), value: 40),
            ReadinessSample(date: start.addingTimeInterval(5 * 3600), value: 70)
        ]
        let forward = ReadinessNightBuilder.nights(
            hrvSamples: hrv, restingHeartRate: [], sleepIntervals: sleep, source: .oura, calendar: calendar)
        let backward = ReadinessNightBuilder.nights(
            hrvSamples: hrv.reversed(), restingHeartRate: [], sleepIntervals: sleep.reversed(), source: .oura, calendar: calendar)
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.first?.sleepMinutes, 420)
        XCTAssertEqual(forward.first?.hrvMilliseconds, 55)
        XCTAssertTrue(ReadinessNightBuilder.nights(
            hrvSamples: [], restingHeartRate: [], sleepIntervals: [], source: .oura, calendar: calendar).isEmpty)
    }
}
