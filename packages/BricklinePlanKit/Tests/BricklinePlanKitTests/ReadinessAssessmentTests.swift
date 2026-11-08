import XCTest
@testable import BricklinePlanKit

/// What the Today card and the Sources screen show: status, lines, components, the source and why, copy scans, and
/// the integration with `PlanKit`.
final class ReadinessAssessmentTests: XCTestCase {
    private typealias F = ReadinessFixtures
    private let today = ReadinessFixtures.thursday
    private var calendar: Calendar { F.calendar }

    private func assess(
        _ inputs: ReadinessInputs, plan: Plan? = nil, history: [AdaptationEvent] = [], today: Date = ReadinessFixtures.thursday
    ) -> ReadinessResult {
        F.ruleSet().apply(to: plan ?? F.plan(), inputs: inputs, today: today, calendar: calendar, history: history)
    }

    // MARK: Lines

    func testOnTrackLineMatchesTheExample() {
        let result = assess(F.inputs())
        XCTAssertEqual(result.assessment.status, .onTrack)
        XCTAssertEqual(result.assessment.line, "HRV on track. Resting heart rate normal. Sleep 7h 10m.")
        XCTAssertEqual(result.assessment.hrv.level, .usual)
        XCTAssertEqual(result.assessment.restingHeartRate.level, .usual)
        XCTAssertEqual(result.assessment.sleep.level, .usual)
        XCTAssertFalse(result.assessment.checkIn.isAvailable)
        XCTAssertTrue(result.assessment.canChangePlanToday)
        XCTAssertFalse(result.assessment.usesCheckInsOnly)
        XCTAssertTrue(result.events.isEmpty)
    }

    func testLearningLineMatchesTheExample() {
        let nights = F.nights(baselineDays: 7...8)
        let result = assess(ReadinessInputs(nights: nights, lastSyncDate: today))
        XCTAssertEqual(result.assessment.status, .calibrating(night: 9, of: 14))
        XCTAssertEqual(result.assessment.line, "Learning your baseline, night 9 of 14.")
        XCTAssertEqual(result.assessment.calibration?.validNights, 9)
        XCTAssertFalse(result.assessment.canChangePlanToday)
    }

    func testBelowAndAboveUsualRange() {
        let below = assess(F.inputs(recentLnHRV: { _ in 3.95 }))
        XCTAssertEqual(below.assessment.status, .belowUsualRange)
        XCTAssertEqual(below.assessment.hrv.level, .below)
        XCTAssertEqual(below.assessment.hrv.text, "HRV below your usual range.")
        XCTAssertTrue(below.assessment.line.hasPrefix("HRV below your usual range. Resting heart rate normal."))

        let above = assess(F.inputs(recentLnHRV: { _ in 4.1 }))
        XCTAssertEqual(above.assessment.status, .onTrack, "a high reading is never acted on")
        XCTAssertEqual(above.assessment.hrv.level, .above)
        XCTAssertEqual(above.assessment.hrv.text, "HRV above your usual range.")
        XCTAssertTrue(above.events.isEmpty)
    }

    func testRestingHeartRateStates() {
        let up = assess(F.inputs(recentRHR: { $0 == 0 ? 60 : 52 })).assessment.restingHeartRate
        XCTAssertEqual(up.level, .above)
        XCTAssertEqual(up.text, "Resting heart rate up.")
        let down = assess(F.inputs(recentRHR: { $0 == 0 ? 46 : 52 })).assessment.restingHeartRate
        XCTAssertEqual(down.level, .below)
        XCTAssertEqual(down.text, "Resting heart rate lower than usual.")
        XCTAssertFalse(assess(F.inputs(recentRHR: { _ in nil })).assessment.restingHeartRate.isAvailable)
        XCTAssertFalse(assess(F.inputs(recentRHR: { $0 == 1 ? 52 : nil })).assessment.restingHeartRate.isAvailable, "last night only")
    }

    func testSleepComponentAndLine() {
        let short = assess(F.inputs(recentSleep: { $0 == 0 ? 340 : 430 }))
        XCTAssertEqual(short.assessment.sleep.level, .below)
        XCTAssertEqual(short.assessment.sleep.text, "Sleep 5h 40m.")
        XCTAssertTrue(short.assessment.line.hasSuffix("Sleep 5h 40m."))
        XCTAssertEqual(ReadinessCopy.duration(minutes: 420), "7h")
        XCTAssertEqual(ReadinessCopy.duration(minutes: 45), "45m")
        XCTAssertEqual(ReadinessCopy.duration(minutes: 430), "7h 10m")
        XCTAssertEqual(ReadinessCopy.duration(minutes: -5), "0m")
    }

    func testCheckInIsAddedToTheLine() {
        let result = assess(F.inputs(checkIns: [F.checkIn(0, 4)]))
        XCTAssertEqual(result.assessment.checkIn.level, .usual)
        XCTAssertEqual(result.assessment.checkIn.text, "Check-in 4 of 5.")
        XCTAssertEqual(result.assessment.line, "HRV on track. Resting heart rate normal. Sleep 7h 10m. Check-in 4 of 5.")
        XCTAssertEqual(assess(F.inputs(checkIns: [F.checkIn(0, 2)])).assessment.checkIn.level, .below)
    }

    func testNoDataLines() {
        let empty = assess(ReadinessInputs())
        XCTAssertEqual(empty.assessment.status, .noData)
        XCTAssertEqual(empty.assessment.line, "No readiness data yet.")
        XCTAssertNil(empty.assessment.source)
        XCTAssertNil(empty.assessment.calibration)
        XCTAssertTrue(empty.events.isEmpty)

        let checkIns = assess(ReadinessInputs(checkIns: [F.checkIn(0, 4)]))
        XCTAssertEqual(checkIns.assessment.line, "Using check-ins only. Check-in 4 of 5.")
        XCTAssertTrue(checkIns.assessment.usesCheckInsOnly)
        XCTAssertTrue(checkIns.assessment.canChangePlanToday)
    }

    func testPausedLines() {
        var stale = F.inputs()
        stale.lastSyncDate = F.day(-3)
        XCTAssertEqual(assess(stale).assessment.line, "Readiness is paused. Your device has not synced in 48 hours.")

        let few = F.inputs(recentLnHRV: { $0 < 2 ? 4.0 : nil }, recentRHR: { _ in nil }, recentSleep: { _ in nil })
        let fewResult = assess(few)
        XCTAssertEqual(fewResult.assessment.status, .paused(.tooFewRecentNights))
        XCTAssertEqual(fewResult.assessment.line, "Readiness is paused until you have 3 nights of data in a week.")

        let notes = assess(F.inputs(overrides: [F.day(-1), F.day(-2), F.day(-3)]))
        XCTAssertEqual(notes.assessment.line,
                       "HRV on track. Resting heart rate normal. Sleep 7h 10m. Readiness shows notes only for now. You kept your planned session 3 times lately.")
    }

    // MARK: Source and why

    func testAssessmentNamesTheSourceAndTheReason() {
        let oura = F.nights(source: .oura)
        let apple = F.nights(source: .appleWatch)
        let result = assess(ReadinessInputs(nights: oura + apple, lastSyncDate: today))
        XCTAssertEqual(result.assessment.source?.source, .oura)
        XCTAssertEqual(result.assessment.source?.reason, .defaultOrder)
        XCTAssertEqual(result.assessment.source?.explanation, "Using Oura, the first of your sources with enough recent nights.")

        let chosen = assess(ReadinessInputs(nights: oura + apple, lastSyncDate: today, preferredRecoverySource: .appleWatch))
        XCTAssertEqual(chosen.assessment.source?.source, .appleWatch)
        XCTAssertEqual(chosen.assessment.source?.reason, .chosenByAthlete)

        let only = assess(F.inputs(source: .whoop))
        XCTAssertEqual(only.assessment.source?.reason, .onlySource)
    }

    func testChangeAndOverrideCountsAreExposed() {
        let result = assess(
            F.inputs(overrides: [F.day(-2), F.day(-4)]),
            history: [F.change(age: 1), F.change(rule: .readinessEasy, age: 2), F.change(age: 9)])
        XCTAssertEqual(result.assessment.planChangesInLast7Days, 2)
        XCTAssertEqual(result.assessment.overridesInLast14Days, 2)
    }

    func testAChangeTodayIsCountedInTheAssessment() {
        let result = assess(F.inputs(recentLnHRV: { _ in 3.95 }))
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.assessment.planChangesInLast7Days, 1)
        XCTAssertFalse(result.assessment.canChangePlanToday)
    }

    // MARK: Copy

    private static let restricted = ["doctor", "injury", "illness", "diagnos", "treat", "sick", "disease", "medical"]
    private static let causes = ["stress", "alcohol", "tired", "fatigue", "overtrain", "overreach", "because", "caused", "due to"]

    /// Another company's training metric names, which must never appear. Spelled in pieces so a search of the
    /// repository for the marks finds nothing.
    private static let brandMarks = ["TS" + "S", "I" + "F", "N" + "P", "T" + "P", "T" + "PU"]

    private func problems(in text: String) -> [String] {
        var found: [String] = []
        let lower = text.lowercased()
        for word in Self.restricted + Self.causes where lower.contains(word) { found.append(word) }
        if lower.range(of: "\\brest\\b", options: .regularExpression) != nil { found.append("rest") }
        if lower.range(of: "\\b(recover|recovery|relax)\\b", options: .regularExpression) != nil { found.append("recover") }
        for dash in ["\u{2014}", "\u{2013}", " - "] where text.contains(dash) { found.append("dash") }
        for mark in Self.brandMarks where text.range(of: "\\b\(mark)\\b", options: .regularExpression) != nil {
            found.append("mark")
        }
        return found
    }

    /// Every reason line and assessment text the module can produce, from real runs.
    private func allCopy() -> [String] {
        var lines: [String] = []
        let easyPlan = F.plan(available: [.monday, .tuesday, .wednesday, .thursday])
        let runs: [ReadinessResult] = [
            assess(F.inputs(recentLnHRV: { _ in 3.95 })),
            assess(F.inputs(recentLnHRV: { _ in 3.95 }), plan: easyPlan),
            assess(F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 58 : 52 })),
            assess(F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, checkIns: [F.checkIn(0, 2)])),
            assess(ReadinessInputs(checkIns: [F.checkIn(0, 1), F.checkIn(1, 2)])),
            assess(F.inputs(recentSleep: { $0 == 0 ? 330 : 430 })),
            assess(F.inputs(recentLnHRV: { _ in 3.95 }, recentSleep: { $0 == 0 ? 330 : 430 }, checkIns: [F.checkIn(0, 5)])),
            assess(F.inputs(overrides: [F.day(-1), F.day(-2), F.day(-3)])),
            assess(F.inputs(recentLnHRV: { $0 < 3 ? 4.0 : nil })),
            assess(F.inputs(recentLnHRV: { _ in 4.2 }, recentRHR: { $0 == 0 ? 45 : 52 })),
            assess(ReadinessInputs(nights: F.nights(baselineDays: 7...8), lastSyncDate: today)),
            assess(ReadinessInputs(checkIns: [F.checkIn(0, 3)])),
            assess(ReadinessInputs()),
            assess(ReadinessInputs(nights: F.nights(), lastSyncDate: F.day(-5))),
            assess(ReadinessInputs(nights: F.nights(), lastSyncDate: today, preferredRecoverySource: .whoop)),
            assess(F.inputs(recentLnHRV: { _ in 3.95 }), plan: F.plan(raceDistance: .sprint, raceDate: F.date(2026, 11, 12)))
        ]
        for result in runs {
            lines.append(contentsOf: result.events.map(\.reasonLine))
            let a = result.assessment
            lines.append(a.line)
            lines.append(contentsOf: [a.hrv.text, a.restingHeartRate.text, a.sleep.text, a.checkIn.text])
            if let note = a.sleepNote { lines.append(note) }
            if let source = a.source { lines.append(source.explanation) }
        }
        for reason in [ReadinessPauseReason.tooFewRecentNights, .noRecentSync, .notesOnly, .raceWindow] {
            lines.append(ReadinessCopy.pause(reason))
        }
        for source in ReadinessSource.allCases {
            lines.append(source.displayName)
            for why in [SourceChoiceReason.chosenByAthlete, .onlySource, .defaultOrder, .latestData] {
                lines.append(SourceChoice(source: source, reason: why).explanation)
            }
        }
        lines.append(contentsOf: [ReadinessCopy.keepOriginal, ReadinessCopy.keepOriginals, ReadinessCopy.hrvBelowFact, ReadinessConstants.keepPlannedSessionTitle])
        return lines.filter { !$0.isEmpty }
    }

    func testNoCopyUsesRestrictedWordsCausesOrDashes() {
        let lines = allCopy()
        XCTAssertGreaterThan(lines.count, 40)
        for line in lines {
            XCTAssertEqual(problems(in: line), [], line)
        }
    }

    func testEveryReasonLineIsOneSentenceForTheChangeThenFacts() {
        let easyPlan = F.plan(available: [.monday, .tuesday, .wednesday, .thursday])
        let events = [
            assess(F.inputs(recentLnHRV: { _ in 3.95 })).events,
            assess(F.inputs(recentLnHRV: { _ in 3.95 }), plan: easyPlan).events,
            assess(F.inputs(recentLnHRV: { $0 < 2 ? 3.90 : 3.98 }, recentRHR: { $0 == 0 ? 58 : 52 })).events,
            assess(ReadinessInputs(checkIns: [F.checkIn(0, 1), F.checkIn(1, 2)])).events
        ].flatMap { $0 }
        XCTAssertEqual(events.count, 4)
        for event in events {
            XCTAssertFalse(event.reasonLine.isEmpty)
            XCTAssertTrue(event.reasonLine.hasSuffix("."), event.reasonLine)
            let sentences = event.reasonLine.split(separator: ".").count
            XCTAssertTrue((2...3).contains(sentences), "\(sentences) sentences in: \(event.reasonLine)")
            XCTAssertTrue(event.isAdvisory)
            XCTAssertNotNil(event.advisory?.originalSessions.first)
        }
    }

    func testTheScannerWouldCatchWhatItShouldNot() {
        XCTAssertFalse(problems(in: "Your doctor said rest.").isEmpty)
        XCTAssertFalse(problems(in: "Fine \u{2014} but no").isEmpty)
        XCTAssertFalse(problems(in: "Fine \u{2013} but no").isEmpty)
        XCTAssertFalse(problems(in: "Likely an illness").isEmpty)
        XCTAssertFalse(problems(in: "Your \(Self.brandMarks[0]) is up").isEmpty)
        XCTAssertFalse(problems(in: "Your \(Self.brandMarks[1]) is up").isEmpty)
        XCTAssertTrue(problems(in: "Resting heart rate is up.").isEmpty)
    }

    // MARK: Codable

    func testAssessmentsRoundTripThroughJSON() throws {
        let results = [
            assess(F.inputs()), assess(F.inputs(recentLnHRV: { _ in 3.95 })), assess(ReadinessInputs()),
            assess(ReadinessInputs(nights: F.nights(baselineDays: 7...8), lastSyncDate: today)),
            assess(F.inputs(overrides: [F.day(-1), F.day(-2), F.day(-3)]))
        ]
        for result in results {
            let data = try JSONEncoder().encode(result.assessment)
            XCTAssertEqual(try JSONDecoder().decode(ReadinessAssessment.self, from: data), result.assessment)
        }
        let inputs = F.inputs(checkIns: [F.checkIn(0, 3)], overrides: [F.day(-1)], preferred: .whoop)
        let data = try JSONEncoder().encode(inputs)
        XCTAssertEqual(try JSONDecoder().decode(ReadinessInputs.self, from: data), inputs)
    }

    // MARK: Rule ids

    func testRuleIDsNineToThirteenExist() {
        XCTAssertEqual(AdaptationRuleID.allCases.map(\.rawValue), Array(1...13))
        XCTAssertEqual(AdaptationRuleID.readinessCalibration.rawValue, 9)
        XCTAssertEqual(AdaptationRuleID.readinessDefer.rawValue, 10)
        XCTAssertEqual(AdaptationRuleID.readinessEasy.rawValue, 11)
        XCTAssertEqual(AdaptationRuleID.sleepNote.rawValue, 12)
        XCTAssertEqual(AdaptationRuleID.readinessGuardrails.rawValue, 13)
        XCTAssertEqual(AdaptationRuleID.allCases.filter(\.isReadinessRule).count, 5)
        XCTAssertEqual(AdaptationRuleID.allCases.filter(\.isNormallyStructural).map(\.rawValue), [1, 2, 4, 5, 6, 8, 10, 11])
    }

    // MARK: PlanKit integration

    func testPlanKitReadinessMatchesTheRules() {
        let inputs = F.inputs(recentLnHRV: { _ in 3.95 })
        let direct = F.ruleSet().apply(to: F.plan(), inputs: inputs, today: today, calendar: calendar)
        let viaKit = PlanKit.standard.readiness(plan: F.plan(), inputs: inputs, today: today, calendar: calendar)
        XCTAssertEqual(viaKit.plan, direct.plan)
        XCTAssertEqual(viaKit.events, direct.events)
        XCTAssertEqual(viaKit.assessment, direct.assessment)
    }

    func testPlanKitKeepPlannedSession() throws {
        let kit = PlanKit.standard
        let fired = kit.readiness(plan: F.plan(), inputs: F.inputs(recentLnHRV: { _ in 3.95 }), today: today, calendar: calendar)
        let event = try XCTUnwrap(fired.events.first)
        let kept = try kit.keepPlannedSession(event, in: fired.plan, today: today, calendar: calendar)
        XCTAssertEqual(kept.plan, F.plan())
        XCTAssertEqual(F.inputs().recordingOverride(on: kept.overrideDay).overrides, [today])
    }

    func testAdaptWithoutReadinessInputsIsUnchanged() {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        let plain = kit.adaptation.apply(
            to: F.plan(), context: AdaptationContext(today: today), calendar: calendar)
        let result = kit.adapt(&state, today: today, calendar: calendar)
        XCTAssertEqual(result.plan, plain.plan)
        XCTAssertEqual(result.events, plain.events)
        XCTAssertNil(result.readinessAssessment)
        XCTAssertEqual(state.history, plain.events)
        XCTAssertEqual(state.plan, plain.plan)
    }

    func testAdaptWithReadinessInputsRunsReadinessAfterTheAdaptationRules() throws {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        let result = kit.adapt(&state, today: today, readiness: F.inputs(recentLnHRV: { _ in 3.95 }), calendar: calendar)
        let event = try XCTUnwrap(result.events.first { $0.rule == .readinessDefer })
        XCTAssertEqual(state.history.last, event)
        XCTAssertEqual(result.plan, state.plan)
        XCTAssertNotNil(result.readinessAssessment)
        XCTAssertEqual(state.plan.session(withID: event.sessionIDs[0])?.scheduledDate, F.friday)
        // A second pass the same day adds nothing.
        let again = kit.adapt(&state, today: today, readiness: F.inputs(recentLnHRV: { _ in 3.95 }), calendar: calendar)
        XCTAssertTrue(again.events.isEmpty)
        XCTAssertEqual(state.history.filter { $0.rule == .readinessDefer }.count, 1)
    }

    func testAdaptationStructuralChangeBlocksReadinessThatDay() {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        // The athlete skipped Tuesday's run today, so rule 1 spends the day's structural change first.
        let runID = F.plan().adaptSessions(on: F.tuesday, calendar: calendar).first?.id ?? ""
        state.record(.sessionSkipped(sessionID: runID, on: today))
        let result = kit.adapt(&state, today: today, readiness: F.inputs(recentLnHRV: { _ in 3.95 }), calendar: calendar)
        XCTAssertTrue(result.events.contains { $0.rule == .skippedMove })
        XCTAssertFalse(result.events.contains { $0.rule == .readinessDefer })
        XCTAssertNotNil(result.readinessAssessment)
    }

    func testReadinessThenAdaptationShareTheBudgetToo() {
        let kit = PlanKit.standard
        var state = AdaptationState(plan: F.plan())
        let fired = kit.readiness(plan: state.plan, inputs: F.inputs(recentLnHRV: { _ in 3.95 }), today: today, calendar: calendar)
        state.plan = fired.plan
        state.history.append(contentsOf: fired.events)
        let runID = F.plan().adaptSessions(on: F.tuesday, calendar: calendar).first?.id ?? ""
        state.record(.sessionSkipped(sessionID: runID, on: today))
        let result = kit.adapt(&state, today: today, calendar: calendar)
        XCTAssertFalse(result.events.contains { $0.rule == .skippedMove && $0.isStructural }, "the budget is spent")
    }
}
