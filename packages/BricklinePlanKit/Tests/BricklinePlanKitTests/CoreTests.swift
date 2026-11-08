import XCTest
@testable import BricklinePlanKit

final class CoreTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    func testValueRangeOrdersBounds() {
        let r = ValueRange(10, 4)
        XCTAssertEqual(r.lower, 4)
        XCTAssertEqual(r.upper, 10)
        XCTAssertTrue(r.contains(7))
    }

    func testStepClampsAndRepeats() {
        let s = Step(sport: .run, kind: .work, durationSeconds: -5, level: 9, repeatGroupID: "g", repeatCount: 0, name: "x")
        XCTAssertEqual(s.durationSeconds, 0)
        XCTAssertEqual(s.level, 5)
        XCTAssertEqual(s.repeats, 1)
    }

    func testSessionTotalsExpandRepeats() {
        let steps = [
            Step(sport: .bike, kind: .warmUp, durationSeconds: 600, level: 2, name: "Warm up"),
            Step(sport: .bike, kind: .work, durationSeconds: 300, level: 4, repeatGroupID: "a", repeatCount: 4, name: "Hard"),
            Step(sport: .bike, kind: .recovery, durationSeconds: 120, level: 1, repeatGroupID: "a", repeatCount: 4, name: "Easy")
        ]
        let s = Session(id: "s", sport: .bike, name: "n", purpose: "p", steps: steps, scheduledDate: date(2026, 11, 9))
        XCTAssertEqual(s.durationSeconds, 600 + 4 * 300 + 4 * 120)
    }

    func testSessionIDIsDeterministic() {
        let id = SessionID.make(weekIndex: 3, date: date(2026, 11, 9), sport: .run, slot: 1, calendar: calendar)
        XCTAssertEqual(id, "w03-20261109-run-1")
    }

    func testPlanRoundTripAndLookup() throws {
        let day = date(2026, 11, 9)
        let session = Session(id: "w00-20261109-swim-1", sport: .swim, name: "Swim", purpose: "p", steps: [], scheduledDate: day)
        let week = PlannedWeek(index: 0, startDate: day, phase: .base, days: [day: [session]], plannedHours: 4)
        let athlete = AthleteProfile(level: .intermediate, weeklyHours: 6, availableWeekdays: [.monday, .wednesday], poolWeekdays: [.monday])
        var plan = Plan(raceDistance: .olympic, raceDate: date(2027, 3, 1), startDate: day, weeks: [week], athlete: athlete, zoneNudgeSteps: [.run: 1])
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        XCTAssertEqual(decoded, plan)
        XCTAssertNotNil(plan.session(withID: session.id))
        XCTAssertTrue(plan.updateSession(id: session.id) { $0.state = .done })
        XCTAssertEqual(plan.session(withID: session.id)?.state, .done)
        XCTAssertFalse(plan.updateSession(id: "missing") { _ in })
        XCTAssertEqual(plan.weekIndex(containing: date(2026, 11, 12), calendar: calendar), 0)
        XCTAssertNil(plan.weekIndex(containing: date(2026, 11, 20), calendar: calendar))
    }

    func testBenchmarksLastTestDateIgnoresEstimates() {
        let tested = date(2026, 10, 1)
        let b = Benchmarks(
            ftpWatts: BenchmarkValue(value: 200, isEstimated: true, date: date(2026, 11, 1)),
            lthrBpm: BenchmarkValue(value: 165, isEstimated: false, date: tested))
        XCTAssertEqual(b.lastTestDate(for: .bike), tested)
        XCTAssertNil(b.lastTestDate(for: .swim))
        XCTAssertTrue(b.isOnlyEstimated(for: .run))
    }

    func testLevelCapsAndDistanceTable() {
        XCTAssertEqual(Level.firstTimer.maxQualityPerWeek, 2)
        XCTAssertEqual(Level.experienced.maxQualityPerWeek, 4)
        XCTAssertEqual(RaceDistance.half.parameters.planWeeks, 14...24)
        XCTAssertEqual(RaceDistance.sprint.parameters.windowOpensTMinusDays, 10)
        XCTAssertEqual(RaceDistance.olympic.legs.map(\.sport), [.swim, .bike, .run])
    }

    func testZoneLevelMapping() {
        XCTAssertEqual(SwimZone(level: 2), .easy)
        XCTAssertEqual(RunZone(level: 4), .threshold)
        XCTAssertEqual(HeartRateZone(level: 99), .z5)
        XCTAssertEqual(BikePowerZone(level: -3), .z1)
    }

    func testFuelingTierBoundaries() {
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 74 * 60), .fluidsOnly)
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 75 * 60), .moderate)
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 151 * 60), .high)
    }

    func testCompiledWorkoutRoundTrip() throws {
        let step = CompiledStep(kind: .work, displayName: "Rep", goal: .distanceWithTime(meters: 100, seconds: 90), alert: .heartRateRange(ValueRange(140, 150)))
        let workout = CompiledWorkout.custom(CompiledCustomWorkout(activity: CompiledActivity(sport: .swim, location: .pool), displayName: "Swim", blocks: [CompiledBlock(iterations: 4, steps: [step])]))
        let data = try JSONEncoder().encode(workout)
        XCTAssertEqual(try JSONDecoder().decode(CompiledWorkout.self, from: data), workout)
    }
}
