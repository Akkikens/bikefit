import XCTest
@testable import BricklinePlanKit

/// Annex C rules 9 to 13: each rule firing and not firing, the guardrails, the undo, and the properties every
/// readiness change must keep (downward only, quality sessions only, advisory, deterministic).
final class ReadinessRulesTests: XCTestCase {
    private typealias F = ReadinessFixtures
    private let today = ReadinessFixtures.thursday
    private var calendar: Calendar { F.calendar }

    // MARK: Helpers

    private func run(
        _ inputs: ReadinessInputs,
        plan: Plan? = nil,
        today: Date = ReadinessFixtures.thursday,
        history: [AdaptationEvent] = [],
        athleteEvents: [AthleteEvent] = []
    ) -> ReadinessResult {
        F.ruleSet().apply(
            to: plan ?? F.plan(), inputs: inputs, today: today, calendar: calendar,
            history: history, athleteEvents: athleteEvents)
    }

    /// Seven nights with the 7 night mean below baseline minus 0.5 SD (3.9641) and no single morning below minus 1 SD
    /// (3.9283), so only rule 10 can fire.
    private func lowWeek(source: ReadinessSource = .oura) -> ReadinessInputs {
        F.inputs(source: source, recentLnHRV: { _ in 3.95 })
    }

    /// Two mornings below minus 1 SD, the other five at 3.98, and resting heart rate up this morning. Rule 11 fires.
    private func swapWeek(source: ReadinessSource = .oura) -> ReadinessInputs {
        F.inputs(source: source, recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 58 : 52 })
    }

    private func thursdayBike(_ plan: Plan) -> Session? {
        plan.adaptSessions(on: today, calendar: calendar).first
    }

    private func assertPlanUnchanged(_ result: ReadinessResult, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.plan, F.plan(), file: file, line: line)
    }

    // MARK: Rule 10

    func testRule10MovesTodaysQualitySessionToTheNextFreeDay() throws {
        let before = F.plan()
        let result = run(lowWeek())
        XCTAssertEqual(result.events.count, 1)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .readinessDefer)
        XCTAssertEqual(event.ruleNumber, 10)
        XCTAssertEqual(event.reasonLine, "Moved Thursday's bike intervals to Friday. Your 7 night HRV is below your usual range.")
        XCTAssertTrue(event.isStructural)
        XCTAssertTrue(event.isAdvisory)
        XCTAssertEqual(event.date, today)
        XCTAssertEqual(event.sport, .bike)
        let original = try XCTUnwrap(before.adaptSessions(on: today, calendar: calendar).first)
        XCTAssertEqual(event.sessionIDs, [original.id])
        XCTAssertEqual(event.advisory?.originalSessions, [original])

        XCTAssertTrue(result.plan.adaptSessions(on: today, calendar: calendar).isEmpty)
        let moved = try XCTUnwrap(result.plan.session(withID: original.id))
        XCTAssertEqual(moved.scheduledDate, F.friday)
        XCTAssertTrue(moved.isQuality)
        XCTAssertEqual(moved.steps, original.steps)
        XCTAssertEqual(result.plan.weeks[0].plannedHours, before.weeks[0].plannedHours, accuracy: 1e-9)
        XCTAssertEqual(result.assessment.status, .belowUsualRange)
        XCTAssertFalse(result.assessment.canChangePlanToday)
    }

    func testRule10DoesNotFireInsideTheUsualRange() {
        for ln in [4.0, 3.98, 3.97, 4.1] {
            let result = run(F.inputs(recentLnHRV: { _ in ln }))
            XCTAssertTrue(result.events.isEmpty, "ln \(ln)")
            assertPlanUnchanged(result)
        }
    }

    func testRule10ThresholdIsHalfASDBelowTheBaseline() {
        let limit = 4.0 - 0.5 * F.sdOfStandardBaseline
        XCTAssertTrue(run(F.inputs(recentLnHRV: { _ in limit + 0.002 })).events.isEmpty)
        XCTAssertEqual(run(F.inputs(recentLnHRV: { _ in limit - 0.002 })).events.map(\.rule), [.readinessDefer])
    }

    func testRule10UsesTheSevenNightMeanNotOneNight() {
        // One poor morning (two SD down) inside an otherwise normal week: the mean stays above the limit.
        let result = run(F.inputs(recentLnHRV: { $0 == 0 ? 3.85 : 4.0 }))
        XCTAssertTrue(result.events.isEmpty)
        // A week whose mean is low although no single morning is far down.
        XCTAssertEqual(run(F.inputs(recentLnHRV: { _ in 3.96 })).events.count, 1)
    }

    func testRule10LeavesEasySessionsAlone() {
        // Monday holds an easy swim only.
        let result = run(lowWeek(), today: F.monday)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.plan, F.plan())
    }

    func testRule10DoesNothingOnADayWithNoSession() {
        let result = run(lowWeek(), today: F.wednesday)
        XCTAssertTrue(result.events.isEmpty)
    }

    func testRule10BecomesEasyWhenNoLaterDayIsAllowed() throws {
        // The athlete trains Monday to Thursday only, so Thursday has no later free day.
        let plan = F.plan(available: [.monday, .tuesday, .wednesday, .thursday])
        let original = try XCTUnwrap(thursdayBike(plan))
        let result = run(lowWeek(), plan: plan)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .readinessDefer)
        XCTAssertEqual(event.reasonLine,
                       "Today's bike intervals became an easy ride. Your 7 night HRV is below your usual range. Tap to keep the original.")
        let eased = try XCTUnwrap(result.plan.session(withID: original.id))
        XCTAssertEqual(eased.scheduledDate, today)
        XCTAssertFalse(eased.isQuality)
        XCTAssertEqual(eased.name, "Easy ride")
        XCTAssertLessThanOrEqual(eased.steps.map(\.level).max() ?? 9, 2)
        // Rule 10 makes the session easy at its full length.
        XCTAssertEqual(eased.durationSeconds, original.durationSeconds, accuracy: 1e-9)
        XCTAssertEqual(event.advisory?.originalSessions, [original])
    }

    func testRule10KeepsHardDaysApart() throws {
        // Saturday holds a hard bike session, so Friday, Saturday and Sunday are all unusable for Thursday's ride.
        let plan = F.plan(saturdayHardBike: true)
        let result = run(lowWeek(), plan: plan)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertTrue(event.reasonLine.hasPrefix("Today's bike intervals became an easy ride."), event.reasonLine)
        let hardDays = result.plan.allSessions.filter { $0.isQuality }.map { calendar.startOfDay(for: $0.scheduledDate) }
        XCTAssertEqual(Set(hardDays).count, hardDays.count, "never two quality sessions on one day")
    }

    func testRule10MoveStaysInTheSameWeek() throws {
        // A race three weeks out keeps the taper lock closed, so the rule is free to act.
        let plan = F.plan(raceDistance: .sprint, raceDate: F.date(2026, 11, 20))
        let result = run(lowWeek(), plan: plan)
        let moved = try XCTUnwrap(result.plan.session(withID: result.events.first?.sessionIDs.first ?? ""))
        XCTAssertTrue(moved.scheduledDate > today)
        XCTAssertEqual(result.plan.weekIndex(containing: moved.scheduledDate, calendar: calendar), 0)
    }

    func testRule10UsesTheSamePlacementRulesAsAMoveByHand() throws {
        // With the race on Saturday 7 November, Friday is race eve and a hard session may not go there. Rule 10
        // asks the shared placement rules, so it never picks such a day.
        var plan = F.plan()
        plan.raceDistance = .half
        plan.raceDate = F.date(2026, 11, 7)
        let hard = try XCTUnwrap(thursdayBike(plan))
        XCTAssertEqual(
            PlanMoveRules.problem(for: hard, on: F.friday, in: plan, calendar: calendar, emptyOnly: false),
            "Keep the day before the race easy.")
        // The half distance window is open, so the taper lock stops readiness before any move is considered.
        XCTAssertTrue(run(lowWeek(), plan: plan).events.isEmpty)
    }

    func testAppleWatchHRVAloneCannotTriggerRule10() {
        let result = run(lowWeek(source: .appleWatch))
        XCTAssertTrue(result.events.isEmpty)
        assertPlanUnchanged(result)
        // The athlete still sees where the 7 night HRV stands.
        XCTAssertEqual(result.assessment.status, .belowUsualRange)
        XCTAssertEqual(result.assessment.source?.source, .appleWatch)
    }

    func testOtherSourcesCanTriggerRule10() {
        for source in [ReadinessSource.oura, .whoop] {
            XCTAssertEqual(run(lowWeek(source: source)).events.map(\.rule), [.readinessDefer], "\(source)")
        }
    }

    func testAppleWatchLowButOuraNormalMeansNoChange() {
        // Oura wins the default order, and its own baseline is on track. Apple Watch values are never mixed in.
        let oura = F.nights(source: .oura)
        let apple = F.nights(source: .appleWatch, recentLnHRV: { _ in 3.5 })
        let inputs = ReadinessInputs(nights: oura + apple, lastSyncDate: today)
        let result = run(inputs)
        XCTAssertEqual(result.assessment.source?.source, .oura)
        XCTAssertTrue(result.events.isEmpty)
    }

    func testOuraLowButAppleWatchNormalStillFollowsOura() {
        let oura = F.nights(source: .oura, recentLnHRV: { _ in 3.95 })
        let apple = F.nights(source: .appleWatch)
        let result = run(ReadinessInputs(nights: oura + apple, lastSyncDate: today))
        XCTAssertEqual(result.events.map(\.rule), [.readinessDefer])
    }

    // MARK: Rule 11

    func testRule11MakesTodaysQualitySessionEasyAtEightyPercent() throws {
        let before = F.plan()
        let original = try XCTUnwrap(thursdayBike(before))
        let result = run(swapWeek())
        XCTAssertEqual(result.events.count, 1)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .readinessEasy)
        XCTAssertEqual(event.ruleNumber, 11)
        XCTAssertEqual(
            event.reasonLine,
            "Today's bike intervals became an easy ride. Your HRV has been below your usual range two mornings running and resting heart rate is up. Tap to keep the original.")
        XCTAssertTrue(event.isStructural)
        XCTAssertTrue(event.isAdvisory)
        XCTAssertEqual(event.advisory?.originalSessions, [original])

        let eased = try XCTUnwrap(result.plan.session(withID: original.id))
        XCTAssertEqual(eased.scheduledDate, today)
        XCTAssertFalse(eased.isQuality)
        XCTAssertLessThanOrEqual(eased.steps.map(\.level).max() ?? 9, 2)
        let ratio = eased.durationSeconds / original.durationSeconds
        XCTAssertGreaterThan(ratio, 0.72)
        XCTAssertLessThanOrEqual(ratio, 0.8 + 1e-9)
        XCTAssertLessThan(result.plan.weeks[0].plannedHours, before.weeks[0].plannedHours)
        XCTAssertEqual(result.plan.weeks[0].plannedHours, result.plan.weeks[0].sessions.reduce(0) { $0 + $1.durationHours }, accuracy: 1e-9)
    }

    func testRule11IsCheckedBeforeRule10() {
        // The same week also satisfies rule 10, but only one structural change fits in a day and rule 11 is stronger.
        let result = run(swapWeek())
        XCTAssertEqual(result.events.filter(\.isStructural).map(\.rule), [.readinessEasy])
    }

    func testRule11SecondSignalCanBeALowCheckIn() throws {
        let inputs = F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, checkIns: [F.checkIn(0, 2)])
        let result = run(inputs)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .readinessEasy)
        XCTAssertEqual(
            event.reasonLine,
            "Today's bike intervals became an easy ride. Your HRV has been below your usual range two mornings running and your check-in was low. Tap to keep the original.")
    }

    func testRule11CheckInFromYesterdayMorningDoesNotCount() {
        // The reason line says the check-in was low, so it has to be today's. Yesterday's 1 with today's 5 is not a
        // second signal, so the swap does not fire (this week's 7 night mean is low, so rule 10 defers instead).
        let inputs = F.inputs(
            recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, checkIns: [F.checkIn(1, 1), F.checkIn(0, 5)])
        XCTAssertEqual(run(inputs).events.map(\.rule), [.readinessDefer])
        let yesterdayOnly = F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, checkIns: [F.checkIn(1, 1)])
        XCTAssertFalse(run(yesterdayOnly).events.map(\.rule).contains(.readinessEasy))
    }

    func testRule11NeedsASecondSignalElseRule10Applies() {
        // Two low mornings, resting heart rate 53 is under one SD up (about 53.8), check-in 4 is fine.
        let inputs = F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 53 : 52 }, checkIns: [F.checkIn(0, 4)])
        let result = run(inputs)
        XCTAssertEqual(result.events.map(\.rule), [.readinessDefer])
        XCTAssertTrue(result.events[0].reasonLine.hasPrefix("Moved Thursday's bike intervals to Friday."))
    }

    func testRule11NeedsTwoMorningsBelowOneSD() {
        // Only this morning is low.
        let one = F.inputs(recentLnHRV: { $0 == 0 ? 3.90 : 3.99 }, recentRHR: { $0 == 0 ? 58 : 52 })
        XCTAssertTrue(run(one).events.isEmpty)
        // Yesterday sits between minus 1 SD and minus 0.5 SD.
        let near = F.inputs(recentLnHRV: { $0 == 0 ? 3.90 : ($0 == 1 ? 3.94 : 3.98) }, recentRHR: { $0 == 0 ? 58 : 52 })
        XCTAssertFalse(run(near).events.contains { $0.rule == .readinessEasy })
        // Two mornings, but not consecutive (today and two days ago).
        let gap = F.inputs(recentLnHRV: { [0, 2].contains($0) ? 3.90 : 3.99 }, recentRHR: { $0 == 0 ? 58 : 52 })
        XCTAssertTrue(run(gap).events.isEmpty)
    }

    func testRule11NeedsMissingMorningsToBePresent() {
        // Yesterday's night is missing, so there are not two consecutive mornings.
        let inputs = F.inputs(recentLnHRV: { $0 == 1 ? nil : 3.90 }, recentRHR: { $0 == 0 ? 58 : 52 })
        XCTAssertFalse(run(inputs).events.contains { $0.rule == .readinessEasy })
    }

    func testRule11ThresholdIsOneSDBelowTheBaseline() {
        let limit = 4.0 - F.sdOfStandardBaseline
        let rhr: (Int) -> Double? = { $0 == 0 ? 58 : 52 }
        let above = F.inputs(recentLnHRV: { $0 < 2 ? limit + 0.002 : 4.0 }, recentRHR: rhr)
        XCTAssertFalse(run(above).events.contains { $0.rule == .readinessEasy })
        let below = F.inputs(recentLnHRV: { $0 < 2 ? limit - 0.002 : 4.0 }, recentRHR: rhr)
        XCTAssertEqual(run(below).events.map(\.rule), [.readinessEasy])
    }

    func testRule11RestingHeartRateThresholdIsOneSDAboveTheBaseline() {
        let values = (0..<35).map { log(52 + F.rhrCycle[$0 % 5]) }
        let mean = values.reduce(0, +) / 35
        let sd = (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / 34).squareRoot()
        let hrv: (Int) -> Double? = { $0 < 2 ? 3.90 : 4.0 }
        let justUnder = exp(mean + sd - 0.01)
        let justOver = exp(mean + sd + 0.01)
        XCTAssertFalse(run(F.inputs(recentLnHRV: hrv, recentRHR: { $0 == 0 ? justUnder : 52 })).events.contains { $0.rule == .readinessEasy })
        XCTAssertTrue(run(F.inputs(recentLnHRV: hrv, recentRHR: { $0 == 0 ? justOver : 52 })).events.contains { $0.rule == .readinessEasy })
    }

    func testRule11WorksWithAppleWatchBecauseItNeedsASecondSignal() {
        let result = run(swapWeek(source: .appleWatch))
        XCTAssertEqual(result.events.map(\.rule), [.readinessEasy])
        // Without the second signal the same Apple Watch week does nothing.
        let alone = F.inputs(source: .appleWatch, recentLnHRV: { $0 < 2 ? 3.90 : 3.98 })
        XCTAssertTrue(run(alone).events.isEmpty)
    }

    func testRule11EasesABrickAndKeepsItNamed() throws {
        var plan = F.plan()
        let original = try XCTUnwrap(thursdayBike(plan))
        plan.updateSession(id: original.id) { $0.brickSecondSport = .run; $0.name = "Brick: ride then run" }
        let result = run(swapWeek(), plan: plan)
        let line = try XCTUnwrap(result.events.first?.reasonLine)
        XCTAssertTrue(line.hasPrefix("Today's brick became an easy brick."), line)
    }

    // MARK: Rule 11 with no device

    func testRule11WithNoDeviceNeedsTwoLowCheckIns() throws {
        let inputs = ReadinessInputs(checkIns: [F.checkIn(0, 2), F.checkIn(1, 1)])
        let result = run(inputs)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .readinessEasy)
        XCTAssertEqual(event.reasonLine,
                       "Today's bike intervals became an easy ride. Your last two check-ins were low. Tap to keep the original.")
        XCTAssertEqual(result.assessment.status, .noData)
        XCTAssertTrue(result.assessment.usesCheckInsOnly)
    }

    func testRule11WithNoDeviceDoesNotFireOnOneOrANonConsecutivePair() {
        XCTAssertTrue(run(ReadinessInputs(checkIns: [F.checkIn(0, 1)])).events.isEmpty)
        XCTAssertTrue(run(ReadinessInputs(checkIns: [F.checkIn(0, 2), F.checkIn(1, 3)])).events.isEmpty)
        XCTAssertTrue(run(ReadinessInputs(checkIns: [F.checkIn(0, 2), F.checkIn(2, 2)])).events.isEmpty)
        XCTAssertTrue(run(ReadinessInputs(checkIns: [F.checkIn(1, 2), F.checkIn(2, 2)])).events.isEmpty)
    }

    func testCheckInPreferenceMeansNoDeviceEvenWithNights() {
        let inputs = ReadinessInputs(
            nights: F.nights(recentLnHRV: { _ in 3.95 }), checkIns: [F.checkIn(0, 2), F.checkIn(1, 2)],
            lastSyncDate: nil, preferredRecoverySource: .manual)
        let result = run(inputs)
        XCTAssertEqual(result.events.map(\.rule), [.readinessEasy])
        XCTAssertTrue(result.assessment.usesCheckInsOnly)
    }

    func testRule11WithNoDeviceNeverFiresOnADeviceUsersCalibrationGap() {
        // Nine valid nights: still learning. Two low check-ins do not override the gate.
        let nights = F.nights(baselineDays: 7...8)
        let inputs = ReadinessInputs(nights: nights, checkIns: [F.checkIn(0, 1), F.checkIn(1, 1)], lastSyncDate: today)
        let result = run(inputs)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.status, .calibrating(night: 9, of: 14))
    }

    func testDuplicateCheckInsUseTheLatestTap() {
        let early = ReadinessCheckIn(date: F.date(2026, 11, 5, hour: 6), score: 1)
        let late = ReadinessCheckIn(date: F.date(2026, 11, 5, hour: 9), score: 4)
        let yesterday = F.checkIn(1, 2)
        XCTAssertTrue(run(ReadinessInputs(checkIns: [early, late, yesterday])).events.isEmpty)
        XCTAssertTrue(run(ReadinessInputs(checkIns: [late, early, yesterday])).events.isEmpty)
    }

    func testCheckInScoreIsClamped() {
        XCTAssertEqual(ReadinessCheckIn(date: today, score: 0).score, 1)
        XCTAssertEqual(ReadinessCheckIn(date: today, score: 9).score, 5)
        XCTAssertEqual(ReadinessCheckIn(date: today, score: 3).score, 3)
    }

    // MARK: Rule 9, calibration gate

    func testNoRuleFiresBeforeFourteenValidNights() {
        // 6 baseline nights plus 7 recent: thirteen valid nights, however low the week is.
        let thirteen = F.nights(baselineDays: 7...12, recentLnHRV: { $0 < 2 ? 3.7 : 3.8 }, recentRHR: { $0 == 0 ? 60 : 52 })
        let result = run(ReadinessInputs(nights: thirteen, checkIns: [F.checkIn(0, 1)], lastSyncDate: today))
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.status, .calibrating(night: 13, of: 14))
        XCTAssertEqual(result.assessment.line, "Learning your baseline, night 13 of 14.")
        assertPlanUnchanged(result)
    }

    func testTheRulesOpenAtFourteenValidNightsWithTenInTheBaseline() {
        // Seven recent plus ten baseline nights: seventeen valid nights, fourteen or more with ten in the baseline.
        let open = F.nights(baselineDays: 7...16, recentLnHRV: { _ in 3.8 })
        let result = run(ReadinessInputs(nights: open, lastSyncDate: today))
        XCTAssertEqual(result.events.map(\.rule), [.readinessDefer])
        XCTAssertEqual(result.assessment.calibration?.isCalibrated, true)
        // Fourteen valid nights with only seven in the baseline is still learning, and reads night 13.
        let thin = F.nights(baselineDays: 7...13, recentLnHRV: { _ in 3.8 })
        let thinResult = run(ReadinessInputs(nights: thin, lastSyncDate: today))
        XCTAssertTrue(thinResult.events.isEmpty)
        XCTAssertEqual(thinResult.assessment.status, .calibrating(night: 13, of: 14))
        XCTAssertEqual(thinResult.assessment.calibration?.validNights, 14)
    }

    func testCalibrationTransitionsNightByNight() {
        for count in 1...20 {
            let recent = min(count, 7)
            let baselineCount = count - recent
            // With no baseline nights the baseline days are put outside the 42 day window.
            let baselineDays = baselineCount == 0 ? 90...90 : 7...(6 + baselineCount)
            let nights = F.nights(
                baselineDays: baselineDays,
                recentLnHRV: { $0 < recent ? 3.8 : nil }, recentRHR: { _ in nil }, recentSleep: { _ in nil })
            let status = run(ReadinessInputs(nights: nights, lastSyncDate: today)).assessment.status
            if count < 14 {
                XCTAssertEqual(status, .calibrating(night: count, of: 14), "count \(count)")
            } else if count < 17 {
                // Fourteen valid nights, but fewer than ten in the baseline: still night 13.
                XCTAssertEqual(status, .calibrating(night: 13, of: 14), "count \(count)")
            } else {
                XCTAssertNotEqual(status, .calibrating(night: count, of: 14), "count \(count)")
                XCTAssertEqual(status, .belowUsualRange, "count \(count)")
            }
        }
    }

    func testFewerThanThreeValidNightsInTheLastSevenTurnsRulesOff() {
        // Plenty of history, but only two valid nights this week.
        let nights = F.nights(
            recentLnHRV: { $0 < 2 ? 3.7 : nil }, recentRHR: { $0 < 2 ? ($0 == 0 ? 60 : 52) : nil }, recentSleep: { $0 < 2 ? 430 : nil })
        let result = run(ReadinessInputs(nights: nights, checkIns: [F.checkIn(0, 1)], lastSyncDate: today))
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.status, .paused(.tooFewRecentNights))
        // The third valid night brings the rules back.
        let three = F.nights(
            recentLnHRV: { $0 < 3 ? 3.7 : nil }, recentRHR: { $0 < 3 ? ($0 == 0 ? 60 : 52) : nil }, recentSleep: { $0 < 3 ? 430 : nil })
        XCTAssertFalse(run(ReadinessInputs(nights: three, lastSyncDate: today)).events.isEmpty)
    }

    func testSwitchingSourceRestartsCalibrationAndSilencesTheRules() {
        // Six weeks of Apple Watch, then an Oura ring with a low week. Oura has 5 nights, so the rules are off.
        let apple = F.nights(source: .appleWatch)
        let oura = (0..<5).map { ReadinessNight(date: F.day(-$0), source: .oura, hrvMilliseconds: exp(3.5), restingHeartRate: 60) }
        let inputs = ReadinessInputs(nights: apple + oura, checkIns: [F.checkIn(0, 1), F.checkIn(1, 1)], lastSyncDate: today)
        let result = run(inputs)
        XCTAssertEqual(result.assessment.source?.source, .oura)
        XCTAssertEqual(result.assessment.status, .calibrating(night: 5, of: 14))
        XCTAssertTrue(result.events.isEmpty)
        // The athlete can go back to the calibrated source. Apple Watch is on baseline, so still nothing, but the
        // status is no longer calibrating.
        let back = run(ReadinessInputs(
            nights: apple + oura, lastSyncDate: today, preferredRecoverySource: .appleWatch))
        XCTAssertEqual(back.assessment.status, .onTrack)
    }

    func testChosenSourceWithoutNightsIsNoData() {
        let inputs = ReadinessInputs(nights: F.nights(source: .oura), lastSyncDate: today, preferredRecoverySource: .whoop)
        let result = run(inputs)
        XCTAssertEqual(result.assessment.status, .noData)
        XCTAssertEqual(result.assessment.line, "No WHOOP nights yet.")
        XCTAssertTrue(result.events.isEmpty)
    }

    // MARK: Rule 12, sleep note

    func testRule12WritesANoteAndNeverChangesThePlan() throws {
        let result = run(F.inputs(recentSleep: { $0 == 0 ? 340 : 430 }))
        XCTAssertEqual(result.events.count, 1)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(event.rule, .sleepNote)
        XCTAssertEqual(event.reasonLine, "Short night. Sleep was 5h 40m, about 1h 20m under your usual.")
        XCTAssertFalse(event.isStructural)
        XCTAssertTrue(event.sessionIDs.isEmpty)
        XCTAssertFalse(event.isAdvisory, "a note changes nothing, so there is no Keep planned session")
        XCTAssertFalse(event.canKeepPlannedSession)
        XCTAssertNil(event.advisory)
        assertPlanUnchanged(result)
        XCTAssertEqual(result.assessment.sleepNote, event.reasonLine)
    }

    func testRule12ThresholdsAreSixHoursAndOneHourUnderTheMedian() {
        func note(_ sleep: Double, median: Double = 420) -> Bool {
            var nights = F.nights(recentSleep: { $0 == 0 ? sleep : 430 })
            nights = nights.map { n in
                var copy = n
                if n.date <= F.day(-7) { copy.sleepMinutes = median }
                return copy
            }
            return run(ReadinessInputs(nights: nights, lastSyncDate: today)).events.contains { $0.rule == .sleepNote }
        }
        XCTAssertTrue(note(360))
        XCTAssertTrue(note(300))
        XCTAssertFalse(note(361))
        XCTAssertFalse(note(400, median: 480), "under the median by an hour, but more than 6 hours of sleep")
        XCTAssertFalse(note(350, median: 380), "6 hours or less, but only 30 minutes under the median")
        XCTAssertTrue(note(320, median: 380))
        XCTAssertFalse(note(321, median: 380))
        XCTAssertTrue(note(300, median: 360), "exactly one hour under")
    }

    func testRule12RoundsTheGapToTenMinutes() {
        let result = run(F.inputs(recentSleep: { $0 == 0 ? 341 : 430 }))
        XCTAssertEqual(result.events.first?.reasonLine, "Short night. Sleep was 5h 41m, about 1h 20m under your usual.")
        XCTAssertEqual(ReadinessCopy.sleepNote(sleepMinutes: 300, medianMinutes: 420), "Short night. Sleep was 5h, about 2h under your usual.")
    }

    func testRule12NeedsLastNightsSleepAndATrustedMedian() {
        XCTAssertTrue(run(F.inputs(recentSleep: { $0 == 1 ? 300 : 430 })).events.isEmpty, "yesterday's short night is not today's note")
        XCTAssertTrue(run(F.inputs(recentSleep: { _ in nil })).events.isEmpty)
        // Median needs five baseline nights with sleep.
        let sparse = F.nights(recentSleep: { $0 == 0 ? 300 : 430 }).map { n -> ReadinessNight in
            var copy = n
            let age = calendar.daysBetween(n.date, F.thursday)
            if age >= 7 && age > 10 { copy.sleepMinutes = nil }
            return copy
        }
        let baselineSleepNights = sparse.filter { $0.date <= F.day(-7) && $0.sleepMinutes != nil }.count
        XCTAssertLessThan(baselineSleepNights, ReadinessConstants.minimumSleepNightsForMedian)
        XCTAssertTrue(run(ReadinessInputs(nights: sparse, lastSyncDate: today)).events.isEmpty)
    }

    func testRule12IsOffWhileLearning() {
        let nights = F.nights(baselineDays: 7...8, recentSleep: { $0 == 0 ? 300 : 430 })
        let result = run(ReadinessInputs(nights: nights, lastSyncDate: today))
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertNil(result.assessment.sleepNote)
    }

    func testRule12CanSitBesideAPlanChange() {
        let result = run(F.inputs(recentLnHRV: { _ in 3.95 }, recentSleep: { $0 == 0 ? 340 : 430 }))
        XCTAssertEqual(result.events.map(\.rule), [.readinessDefer, .sleepNote])
        XCTAssertEqual(result.events.filter(\.isStructural).count, 1)
    }

    // MARK: Rule 13, guardrails

    func testAtMostTwoPlanChangesPerRollingSevenDays() {
        let low = lowWeek()
        XCTAssertEqual(run(low, history: [F.change(age: 3)]).events.map(\.rule), [.readinessDefer], "one change so far")
        XCTAssertTrue(run(low, history: [F.change(age: 3), F.change(rule: .readinessEasy, age: 5)]).events.isEmpty)
        XCTAssertTrue(run(low, history: [F.change(age: 1), F.change(age: 6)]).events.isEmpty, "6 days ago is inside the window")
        XCTAssertFalse(run(low, history: [F.change(age: 1), F.change(age: 7)]).events.isEmpty, "7 days ago is outside it")
        let capped = run(low, history: [F.change(age: 3), F.change(age: 5)])
        XCTAssertFalse(capped.assessment.canChangePlanToday)
        XCTAssertEqual(capped.assessment.planChangesInLast7Days, 2)
        assertPlanUnchanged(capped)
    }

    func testSleepNotesAndOtherRulesDoNotCountAsPlanChanges() {
        let notes = [F.change(rule: .sleepNote, age: 1), F.change(rule: .sleepNote, age: 2), F.change(rule: .sleepNote, age: 3)]
        XCTAssertFalse(run(lowWeek(), history: notes).events.isEmpty)
        let other = [
            AdaptationEvent(rule: .skippedMove, reasonLine: "Moved.", date: F.day(-2), isStructural: true),
            AdaptationEvent(rule: .loadSpike, reasonLine: "Spike.", date: F.day(-4), isStructural: true)
        ]
        XCTAssertFalse(run(lowWeek(), history: other).events.isEmpty)
    }

    func testThreeOverridesInFourteenDaysLeavesNotesOnly() {
        let overrides = [F.day(-1), F.day(-5), F.day(-13)]
        let inputs = F.inputs(recentLnHRV: { _ in 3.95 }, recentSleep: { $0 == 0 ? 340 : 430 }, overrides: overrides)
        let result = run(inputs)
        XCTAssertEqual(result.events.map(\.rule), [.sleepNote], "the note still shows")
        assertPlanUnchanged(result)
        XCTAssertEqual(result.assessment.status, .paused(.notesOnly))
        XCTAssertEqual(result.assessment.overridesInLast14Days, 3)
        XCTAssertFalse(result.assessment.canChangePlanToday)
        XCTAssertTrue(result.assessment.line.contains("notes only"), result.assessment.line)
    }

    func testTwoOverridesOrAnOldOneDoNotTriggerNotesOnly() {
        XCTAssertFalse(run(F.inputs(recentLnHRV: { _ in 3.95 }, overrides: [F.day(-1), F.day(-5)])).events.isEmpty)
        // The third tap is 14 days old, outside the window.
        XCTAssertFalse(run(F.inputs(recentLnHRV: { _ in 3.95 }, overrides: [F.day(-1), F.day(-5), F.day(-14)])).events.isEmpty)
        // Taps on one day count once.
        XCTAssertFalse(run(F.inputs(recentLnHRV: { _ in 3.95 }, overrides: [F.day(-1), F.day(-1), F.day(-1)])).events.isEmpty)
    }

    func testNoSyncForFortyEightHoursSilencesReadiness() {
        let now = F.date(2026, 11, 5, hour: 8)
        var inputs = F.inputs(recentLnHRV: { _ in 3.95 }, recentSleep: { $0 == 0 ? 340 : 430 })
        inputs.lastSyncDate = now.addingTimeInterval(-49 * 3600)
        let silent = run(inputs, today: now)
        XCTAssertTrue(silent.events.isEmpty, "no plan change and no note")
        XCTAssertEqual(silent.assessment.status, .paused(.noRecentSync))
        XCTAssertNil(silent.assessment.sleepNote)
        XCTAssertEqual(silent.plan, F.plan())

        inputs.lastSyncDate = now.addingTimeInterval(-48 * 3600)
        XCTAssertEqual(run(inputs, today: now).assessment.status, .paused(.noRecentSync), "48 hours exactly is silent")
        inputs.lastSyncDate = now.addingTimeInterval(-47 * 3600)
        XCTAssertFalse(run(inputs, today: now).events.isEmpty)
    }

    func testWithoutALastSyncDateTheLatestNightStandsIn() {
        // Latest night is four days old and nothing is dated after it.
        let old = F.nights(today: F.day(-4)).filter { $0.date <= F.day(-4) }
        let result = run(ReadinessInputs(nights: old, lastSyncDate: nil))
        XCTAssertEqual(result.assessment.status, .paused(.noRecentSync))
    }

    func testCheckInOnlyUsersAreNotSubjectToTheSyncGuard() {
        let inputs = ReadinessInputs(checkIns: [F.checkIn(0, 1), F.checkIn(1, 2)], lastSyncDate: nil)
        XCTAssertEqual(run(inputs).events.map(\.rule), [.readinessEasy])
    }

    func testTaperLockWins() {
        // A sprint race next Thursday: the window opened 10 days before race day.
        let plan = F.plan(raceDistance: .sprint, raceDate: F.date(2026, 11, 12))
        let inputs = F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 58 : 52 },
                              recentSleep: { $0 == 0 ? 340 : 430 })
        let result = run(inputs, plan: plan)
        XCTAssertEqual(result.events.map(\.rule), [.sleepNote], "only the note, which changes nothing")
        XCTAssertEqual(result.plan, plan)
        XCTAssertEqual(result.assessment.status, .paused(.raceWindow))
        XCTAssertTrue(result.assessment.line.contains("Race window"))
        // No-device check-ins are locked out as well.
        let checkIns = run(ReadinessInputs(checkIns: [F.checkIn(0, 1), F.checkIn(1, 1)]), plan: plan)
        XCTAssertTrue(checkIns.events.isEmpty)
        // Far from the race, the same data fires.
        let far = F.plan(raceDistance: .sprint, raceDate: F.date(2026, 12, 20))
        XCTAssertFalse(run(inputs, plan: far).events.filter(\.isStructural).isEmpty)
    }

    func testOneStructuralChangePerDay() {
        let spent = AdaptationEvent(rule: .skippedMove, reasonLine: "Moved to Friday.", date: today, isStructural: true)
        let result = run(lowWeek(), history: [spent])
        XCTAssertTrue(result.events.isEmpty)
        assertPlanUnchanged(result)
        XCTAssertFalse(result.assessment.canChangePlanToday)
        // A non structural event (a zone nudge) leaves the budget alone.
        let nudge = AdaptationEvent(rule: .zoneNudge, reasonLine: "Paces moved.", date: today, isStructural: false)
        XCTAssertFalse(run(lowWeek(), history: [nudge]).events.isEmpty)
        // So does a structural change on another day.
        let yesterday = AdaptationEvent(rule: .skippedMove, reasonLine: "Moved.", date: F.day(-1), isStructural: true)
        XCTAssertFalse(run(lowWeek(), history: [yesterday]).events.isEmpty)
    }

    func testAConfirmedRealignmentTodayUsesTheBudget() {
        let result = run(lowWeek(), athleteEvents: [.realignmentChosen(.compress, on: today)])
        XCTAssertTrue(result.events.isEmpty)
    }

    func testUnwellDaysBelongToRule4() {
        let result = run(lowWeek(), athleteEvents: [.unwellStarted(on: F.wednesday)])
        XCTAssertTrue(result.events.isEmpty)
        assertPlanUnchanged(result)
    }

    func testReadinessNeverFiresTwiceInADay() {
        let first = run(lowWeek())
        XCTAssertEqual(first.events.count, 1)
        let second = run(lowWeek(), plan: first.plan, history: first.events)
        XCTAssertTrue(second.events.isEmpty)
        XCTAssertEqual(second.plan, first.plan)
    }

    func testTheSleepNoteIsNotLoggedTwiceInADay() {
        let inputs = F.inputs(recentSleep: { $0 == 0 ? 340 : 430 })
        let first = run(inputs)
        XCTAssertEqual(first.events.map(\.rule), [.sleepNote])
        let second = run(inputs, history: first.events)
        XCTAssertTrue(second.events.isEmpty)
        XCTAssertNotNil(second.assessment.sleepNote, "the card still shows the note")
    }

    // MARK: Downward only, quality sessions only

    func testEveryChangeOnlyDefersOrSoftens() throws {
        let variants: [(String, ReadinessInputs, Plan)] = [
            ("rule 10 move", lowWeek(), F.plan()),
            ("rule 10 easy", lowWeek(), F.plan(available: [.monday, .tuesday, .wednesday, .thursday])),
            ("rule 11", swapWeek(), F.plan()),
            ("check-ins", ReadinessInputs(checkIns: [F.checkIn(0, 1), F.checkIn(1, 1)]), F.plan())
        ]
        for (name, inputs, plan) in variants {
            let result = run(inputs, plan: plan)
            XCTAssertEqual(result.events.count, 1, name)
            // Every session that did not change is identical; only today's quality session differs.
            let changedIDs = Set(result.events.flatMap(\.sessionIDs))
            XCTAssertEqual(changedIDs.count, 1, name)
            for session in plan.allSessions where !changedIDs.contains(session.id) {
                XCTAssertEqual(result.plan.session(withID: session.id), session, "\(name): \(session.name)")
            }
            // No load added: duration and the hardest step never go up, and the count of sessions is the same.
            XCTAssertEqual(result.plan.allSessions.count, plan.allSessions.count, name)
            for id in changedIDs {
                let before = try XCTUnwrap(plan.session(withID: id))
                let after = try XCTUnwrap(result.plan.session(withID: id))
                XCTAssertLessThanOrEqual(after.durationSeconds, before.durationSeconds + 1e-9, name)
                XCTAssertLessThanOrEqual(after.steps.map(\.level).max() ?? 0, before.steps.map(\.level).max() ?? 0, name)
                XCTAssertTrue(before.isQuality, "\(name): only quality sessions change")
            }
            let totalBefore = plan.allSessions.reduce(0) { $0 + $1.durationSeconds }
            let totalAfter = result.plan.allSessions.reduce(0) { $0 + $1.durationSeconds }
            XCTAssertLessThanOrEqual(totalAfter, totalBefore + 1e-9, name)
            // The quality count never grows.
            XCTAssertLessThanOrEqual(result.plan.allSessions.filter(\.isQuality).count, plan.allSessions.filter(\.isQuality).count, name)
        }
    }

    func testDoneAndSkippedSessionsAreNeverTouched() {
        var plan = F.plan()
        let id = thursdayBike(plan)?.id ?? ""
        plan.updateSession(id: id) { $0.state = .done }
        XCTAssertTrue(run(lowWeek(), plan: plan).events.isEmpty)
        plan.updateSession(id: id) { $0.state = .skipped }
        XCTAssertTrue(run(swapWeek(), plan: plan).events.isEmpty)
    }

    func testRulesNeverAddAnythingOnADayOffTheirPlan() {
        // Today after the plan ends: nothing to change, no crash.
        let result = run(lowWeek(), today: F.date(2027, 3, 1))
        XCTAssertTrue(result.events.filter(\.isStructural).isEmpty)
    }

    // MARK: Keep planned session

    func testKeepPlannedSessionRestoresARule10Move() throws {
        let before = F.plan()
        let result = run(lowWeek(), plan: before)
        let event = try XCTUnwrap(result.events.first)
        let kept = try F.ruleSet().keepPlannedSession(event, in: result.plan, today: today, calendar: calendar)
        XCTAssertEqual(kept.plan, before)
        XCTAssertEqual(kept.overrideDay, today)
    }

    func testKeepPlannedSessionRestoresARule11Swap() throws {
        let before = F.plan()
        let result = run(swapWeek(), plan: before)
        let event = try XCTUnwrap(result.events.first)
        let kept = try F.ruleSet().keepPlannedSession(event, in: result.plan, today: today, calendar: calendar)
        XCTAssertEqual(kept.plan, before)
    }

    func testKeepPlannedSessionRestoresARule10Easy() throws {
        let before = F.plan(available: [.monday, .tuesday, .wednesday, .thursday])
        let result = run(lowWeek(), plan: before)
        let event = try XCTUnwrap(result.events.first)
        XCTAssertEqual(try F.ruleSet().keepPlannedSession(event, in: result.plan, today: today, calendar: calendar).plan, before)
    }

    func testKeepPlannedSessionRoundTripCountsTowardOverrides() throws {
        var inputs = lowWeek()
        var plan = F.plan()
        var history: [AdaptationEvent] = []
        // Three days in a row the athlete keeps the planned session. Each day needs a quality session, so use the
        // run on Tuesday and Thursday of two weeks.
        let days = [F.tuesday, F.thursday, F.day(7, from: F.tuesday)]
        for (index, day) in days.enumerated() {
            let nights = F.nights(today: day, recentLnHRV: { _ in 3.95 })
            inputs.nights = nights
            inputs.lastSyncDate = day
            let result = run(inputs, plan: plan, today: day, history: history)
            let event = try XCTUnwrap(result.events.first, "day \(index)")
            history.append(contentsOf: result.events)
            let kept = try F.ruleSet().keepPlannedSession(event, in: result.plan, today: day, calendar: calendar)
            plan = kept.plan
            inputs = inputs.recordingOverride(on: kept.overrideDay)
        }
        XCTAssertEqual(inputs.overrides.count, 3)
        // The fourth day finds readiness in notes only.
        let next = F.day(7, from: F.thursday)
        inputs.nights = F.nights(today: next, recentLnHRV: { _ in 3.95 })
        inputs.lastSyncDate = next
        let result = run(inputs, plan: plan, today: next, history: [])
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.assessment.status, .paused(.notesOnly))
    }

    func testKeepPlannedSessionRefusesWhatCannotBeUndone() throws {
        let rules = F.ruleSet()
        let note = AdaptationEvent(rule: .sleepNote, reasonLine: "Short night.", date: today, isStructural: false, advisory: AdvisoryChange())
        XCTAssertThrowsError(try rules.keepPlannedSession(note, in: F.plan(), today: today, calendar: calendar))
        let plain = AdaptationEvent(rule: .skippedMove, reasonLine: "Moved.", date: today, isStructural: true)
        XCTAssertThrowsError(try rules.keepPlannedSession(plain, in: F.plan(), today: today, calendar: calendar))

        let result = run(lowWeek())
        let event = try XCTUnwrap(result.events.first)
        // The session has been done in the meantime.
        var done = result.plan
        done.updateSession(id: event.sessionIDs[0]) { $0.state = .done }
        XCTAssertThrowsError(try rules.keepPlannedSession(event, in: done, today: today, calendar: calendar)) {
            XCTAssertEqual(($0 as? PlanKitError), .invalidInput("Only a session that is still planned can go back."))
        }
        // The session left the plan.
        var gone = result.plan
        gone.adaptRemove(id: event.sessionIDs[0])
        XCTAssertThrowsError(try rules.keepPlannedSession(event, in: gone, today: today, calendar: calendar)) {
            XCTAssertEqual(($0 as? PlanKitError), .sessionNotFound(event.sessionIDs[0]))
        }
    }

    func testAnEventKeepsItsOriginalThroughCodable() throws {
        let result = run(swapWeek())
        let event = try XCTUnwrap(result.events.first)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AdaptationEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        let kept = try F.ruleSet().keepPlannedSession(decoded, in: result.plan, today: today, calendar: calendar)
        XCTAssertEqual(kept.plan, F.plan())
    }

    func testStoredEventsFromBeforeReadinessStillDecode() throws {
        let old = AdaptationEvent(rule: .skippedMove, reasonLine: "Moved to Friday.", date: today, isStructural: true)
        let data = try JSONEncoder().encode(old)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["advisory"] = nil
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AdaptationEvent.self, from: stripped)
        XCTAssertEqual(decoded, old)
        XCTAssertFalse(decoded.isAdvisory)
    }

    // MARK: Determinism

    func testSameInputsGiveSameOutputs() {
        let inputs = swapWeek()
        let a = run(inputs, history: [F.change(age: 4)])
        let b = run(inputs, history: [F.change(age: 4)])
        XCTAssertEqual(a.plan, b.plan)
        XCTAssertEqual(a.events, b.events)
        XCTAssertEqual(a.assessment, b.assessment)
    }

    func testInputOrderDoesNotChangeTheOutputs() {
        var inputs = swapWeek()
        inputs.checkIns = [F.checkIn(0, 2), F.checkIn(1, 4), F.checkIn(3, 5)]
        var shuffled = inputs
        shuffled.nights = Array(inputs.nights.reversed())
        shuffled.checkIns = Array(inputs.checkIns.reversed())
        let a = run(inputs)
        let b = run(shuffled)
        XCTAssertEqual(a.plan, b.plan)
        XCTAssertEqual(a.events, b.events)
        XCTAssertEqual(a.assessment, b.assessment)
    }

    func testTimeOfDayOfTodayDoesNotChangeThePlan() {
        let morning = run(lowWeek(), today: F.date(2026, 11, 5, hour: 6))
        let evening = run(lowWeek(), today: F.date(2026, 11, 5, hour: 21))
        XCTAssertEqual(morning.plan, evening.plan)
        XCTAssertEqual(morning.events, evening.events)
    }

    func testThePlansOwnTimeZoneIsUsedForDays() {
        var plan = F.plan()
        plan.timeZoneIdentifier = "UTC"
        var auckland = F.calendar
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland") ?? .current
        let result = F.ruleSet().apply(to: plan, inputs: lowWeek(), today: today, calendar: auckland)
        XCTAssertEqual(result.events.map(\.rule), [.readinessDefer])
        XCTAssertEqual(result.events.first?.date, today)
    }
}
