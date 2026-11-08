import XCTest
@testable import BricklinePlanKit

// End to end smoke test through the PlanKit facade: plan, compile, adapt, race window.

final class PlanKitSmokeTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    private func benchmarks(on date: Date) -> Benchmarks {
        Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: 105, isEstimated: false, date: date),
            ftpWatts: BenchmarkValue(value: 220, isEstimated: false, date: date),
            lthrBpm: BenchmarkValue(value: 165, isEstimated: false, date: date),
            thresholdPaceSecondsPerKm: BenchmarkValue(value: 330, isEstimated: false, date: date),
            runLthrBpm: BenchmarkValue(value: 172, isEstimated: false, date: date))
    }

    private var athlete: AthleteProfile {
        AthleteProfile(
            level: .intermediate, weeklyHours: 8,
            availableWeekdays: Set(Weekday.allCases),
            poolWeekdays: [.tuesday, .thursday, .saturday],
            hasWatch: true, hasPowerMeter: true, hasTrainer: true, prefersRunWalk: false)
    }

    func testOlympicPlanCompilesAdaptsAndExplains() throws {
        let kit = PlanKit()
        let start = day(2026, 11, 9)
        let raceDate = day(2027, 3, 7)
        let marks = benchmarks(on: day(2026, 11, 2))

        let plan = try kit.makePlan(
            raceDistance: .olympic, raceDate: raceDate, startDate: start,
            athlete: athlete, benchmarks: marks, calendar: calendar)
        XCTAssertEqual(plan.raceDistance, .olympic)
        XCTAssertFalse(plan.weeks.isEmpty)
        XCTAssertFalse(plan.allSessions.isEmpty)

        // Every session compiles on a standard watch, on an older watch and with no watch.
        for caps in [DeviceCapabilities.standard, .olderWatch, .noWatch] {
            let compiled = try kit.compileAll(plan, benchmarks: marks, capabilities: caps, indoor: false)
            XCTAssertEqual(compiled.count, plan.allSessions.count)
            XCTAssertTrue(compiled.allSatisfy { $0.failure == nil }, "no session may fail to compile")
            for entry in compiled {
                let result = try XCTUnwrap(entry.compiled)
                XCTAssertEqual(result.sessionID, entry.sessionID)
                if caps.tier == .noWatch {
                    XCTAssertTrue(result.workouts.isEmpty)
                    XCTAssertTrue(result.usesPhoneSetCard)
                }
            }
            // Date order, as documented.
            XCTAssertEqual(compiled.map(\.sessionID), plan.allSessions.filter { $0.state != .skipped }.map(\.id))
        }
        let standard = kit.compileAll(plan, benchmarks: marks)
        XCTAssertTrue(standard.contains { !($0.compiled?.workouts.isEmpty ?? true) })

        // Skip the first planned session after the start, evaluated on that day.
        guard let skipped = plan.allSessions.first(where: { $0.state == .planned && $0.scheduledDate > start })
        else { return XCTFail("no session to skip") }
        let today = skipped.scheduledDate
        let context = AdaptationContext(
            today: today,
            events: [.sessionSkipped(sessionID: skipped.id, on: today)],
            benchmarks: marks)
        let result = kit.adapt(plan, context: context, calendar: calendar)
        XCTAssertFalse(result.events.isEmpty, "a skip must fire at least one rule")
        for event in result.events {
            XCTAssertFalse(event.reasonLine.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(event.reasonLine.contains("\u{2014}") || event.reasonLine.contains("\u{2013}"))
        }
        XCTAssertTrue(result.events.contains { $0.rule == .skippedMove })
        // The skipped session either moved to a later day or was dropped (annex C rule 1).
        if let after = result.plan.session(withID: skipped.id) {
            XCTAssertTrue(after.state == .skipped || after.scheduledDate > skipped.scheduledDate)
        } else {
            XCTFail("the skipped session must stay in the plan")
        }

        // Same inputs, same output.
        let again = kit.adapt(plan, context: context, calendar: calendar)
        XCTAssertEqual(again.plan, result.plan)
        XCTAssertEqual(again.events, result.events)

        // The adapted plan still compiles.
        XCTAssertTrue(kit.compileAll(result.plan, benchmarks: marks).allSatisfy { $0.failure == nil })
    }

    func testRaceWindowAndRaceDayThroughFacade() throws {
        let kit = PlanKit.standard
        let raceDate = day(2027, 3, 7)
        XCTAssertTrue(kit.isRaceWindowActive(
            raceDate: raceDate, distance: .olympic, today: day(2027, 3, 1), calendar: calendar))
        XCTAssertFalse(kit.isRaceWindowActive(
            raceDate: raceDate, distance: .olympic, today: day(2027, 1, 1), calendar: calendar))

        let details = RaceDetails(
            distance: .olympic, raceDate: raceDate, startMinutesAfterMidnight: 7 * 60, hasBikeRecord: true)
        let entries = kit.raceWindow(for: details, calendar: calendar)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertLessThanOrEqual(kit.raceWindow(for: details, calendar: calendar, forNotifications: true).count,
                                 entries.count)

        let card = kit.racePlan(
            distance: .olympic, athlete: athlete, benchmarks: benchmarks(on: day(2026, 11, 2)))
        XCTAssertFalse(card.fueling.isEmpty)

        if case .swimBikeRun(let workout) = kit.compileRaceDay(distance: .olympic, displayName: "Race day") {
            XCTAssertEqual(workout.legs.count, 3)
        } else {
            XCTFail("race day must compile to a swim bike run workout")
        }
    }

    func testBasePlanConvertsToRacePlanThroughFacade() throws {
        let kit = PlanKit()
        let start = day(2026, 11, 9)
        let base = try kit.makeBasePlan(startDate: start, athlete: athlete, calendar: calendar)
        XCTAssertNil(base.raceDate)
        let race = try kit.convertToRacePlan(
            base, raceDistance: .olympic, raceDate: day(2027, 4, 4), today: start, calendar: calendar)
        XCTAssertEqual(race.raceDistance, .olympic)
    }
}
