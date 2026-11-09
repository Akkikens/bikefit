import XCTest
@testable import BricklinePlanKit

// A gentle start is for someone brand new to training: no hard efforts and no maximal tests anywhere in the plan
// (nothing above level 3), two easier opening weeks, and a lighter week after every second load week.
final class GentleStartTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    private func beginner(hours: Double = 4, gentle: Bool = true) -> AthleteProfile {
        AthleteProfile(
            level: .firstTimer, weeklyHours: hours, availableWeekdays: Set(Weekday.allCases),
            poolWeekdays: [.tuesday, .thursday, .saturday], hasWatch: false, hasPowerMeter: false,
            hasTrainer: false, prefersRunWalk: true, gentleStart: gentle)
    }

    private func estimatedBenchmarks(_ date: Date) -> Benchmarks {
        Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: 130, isEstimated: true, date: date),
            ftpWatts: nil,
            thresholdPaceSecondsPerKm: BenchmarkValue(value: 390, isEstimated: true, date: date))
    }

    private func plan(_ distance: RaceDistance, weeks: Int, athlete: AthleteProfile) throws -> Plan {
        let start = day(2026, 11, 9)
        let race = cal.date(byAdding: .day, value: 7 * weeks - 3, to: start) ?? start
        return try PlanKit().makePlan(
            raceDistance: distance, raceDate: race, startDate: start, athlete: athlete,
            benchmarks: estimatedBenchmarks(start), calendar: cal)
    }

    func testGentlePlanHasNoHardEffortsOrTestsInBase() throws {
        for weeks in [8, 10, 12] {
            let p = try plan(.sprint, weeks: weeks, athlete: beginner())
            let base = p.weeks.filter { $0.phase == .base }
            XCTAssertFalse(base.isEmpty)
            for week in base {
                XCTAssertFalse(week.isTest, "week \(week.index) is a test week")
                for s in week.sessions {
                    XCTAssertFalse(s.isQuality, "\(s.name) is quality in base")
                    XCTAssertFalse(s.isTest, "\(s.name) is a test in base")
                    let top = s.steps.map(\.level).max() ?? 1
                    XCTAssertLessThanOrEqual(top, 2, "\(s.name) has a level \(top) step in base")
                }
            }
        }
    }

    func testGentlePlanNeverAsksForMaximalTestsOrVeryHardSteps() throws {
        for distance in RaceDistance.allCases {
            let weeks = distance.parameters.planWeeks.upperBound
            let p = try plan(distance, weeks: weeks, athlete: beginner(hours: distance.parameters.weeklyHours.lowerBound))
            for week in p.weeks {
                XCTAssertFalse(week.isTest)
                XCTAssertLessThanOrEqual(week.sessions.filter(\.isQuality).count, 1, "week \(week.index)")
                for s in week.sessions {
                    XCTAssertFalse(s.isTest)
                    XCTAssertFalse(s.steps.contains { $0.level > 3 }, "\(s.name) has a step above steady")
                }
            }
        }
    }

    func testGentleRecoversAfterEverySecondLoadWeek() throws {
        let p = try plan(.olympic, weeks: 14, athlete: beginner(hours: 6))
        var run = 0
        var longest = 0
        for week in p.weeks where week.phase != .taper {
            if week.isRecovery { run = 0 } else { run += 1; longest = max(longest, run) }
        }
        XCTAssertLessThanOrEqual(longest, 3, "a gentle plan should not stack more than a short run of load weeks")
        let recoveries = p.weeks.filter(\.isRecovery).count
        let standard = try plan(.olympic, weeks: 14, athlete: beginner(hours: 6, gentle: false)).weeks.filter(\.isRecovery).count
        XCTAssertGreaterThan(recoveries, standard)
    }

    func testGentleBasePlanRecoversAfterEverySecondLoadWeek() throws {
        let start = day(2026, 11, 9)
        let gentle = try PlanKit().makeBasePlan(
            startDate: start, athlete: beginner(), benchmarks: estimatedBenchmarks(start), calendar: cal)
        XCTAssertEqual(gentle.weeks.prefix(4).map(\.isRecovery), [false, false, true, false])
        let regular = try PlanKit().makeBasePlan(
            startDate: start, athlete: beginner(gentle: false), benchmarks: estimatedBenchmarks(start), calendar: cal)
        XCTAssertEqual(regular.weeks.prefix(4).map(\.isRecovery), [false, false, false, true])
    }

    func testGentleOpeningWeeksAreSmallerAndShort() throws {
        let p = try plan(.sprint, weeks: 10, athlete: beginner(hours: 3))
        let hours = p.weeks.map(\.plannedHours)
        XCTAssertLessThan(hours[0], 0.75 * 3, "week 0 is well under the target")
        XCTAssertLessThan(hours[0], hours[1])
        XCTAssertLessThan(hours[0], hours[3])
        for week in p.weeks.prefix(2) {
            for s in week.sessions {
                XCTAssertLessThanOrEqual(s.durationSeconds, 2700, "\(s.name) in week \(week.index) is long for an opening week")
            }
        }
    }

    func testStandardFirstTimerStillGetsQualityInBase() throws {
        let p = try plan(.olympic, weeks: 14, athlete: beginner(hours: 6, gentle: false))
        let base = p.weeks.filter { $0.phase == .base }
        XCTAssertTrue(base.contains { $0.sessions.contains { $0.isQuality } }, "the default path is unchanged")
    }

    func testGentleBasePlanHasNoQualityOrTests() throws {
        let p = try PlanKit().makeBasePlan(
            startDate: day(2026, 11, 9), athlete: beginner(), benchmarks: estimatedBenchmarks(day(2026, 11, 9)), calendar: cal)
        for s in p.allSessions {
            XCTAssertFalse(s.isQuality)
            XCTAssertFalse(s.isTest)
            XCTAssertLessThanOrEqual(s.steps.map(\.level).max() ?? 1, 2)
        }
    }

    func testProfileSavedBeforeGentleStartStillDecodes() throws {
        let old = #"{"level":"firstTimer","weeklyHours":5,"availableWeekdays":[2,3],"poolWeekdays":[3],"hasWatch":false,"hasPowerMeter":false,"hasTrainer":false,"prefersRunWalk":true}"#
        let decoded = try JSONDecoder().decode(AthleteProfile.self, from: Data(old.utf8))
        XCTAssertFalse(decoded.gentleStart)
        let round = try JSONDecoder().decode(AthleteProfile.self, from: JSONEncoder().encode(beginner()))
        XCTAssertTrue(round.gentleStart)
    }
}

final class EasedSessionTests: XCTestCase {
    func testEasedSessionIsEasyShorterAndKeepsItsId() throws {
        let hard = Session(
            id: "w3-d2-run", sport: .run, name: "Threshold run", purpose: "Builds pace.",
            steps: [
                Step(sport: .run, kind: .warmUp, durationSeconds: 600, level: 2, name: "Warm up"),
                Step(sport: .run, kind: .work, durationSeconds: 480, level: 4, repeatGroupID: "g", repeatCount: 3, name: "Threshold interval"),
                Step(sport: .run, kind: .recovery, durationSeconds: 120, level: 1, repeatGroupID: "g", repeatCount: 3, name: "Easy jog"),
                Step(sport: .run, kind: .coolDown, durationSeconds: 600, level: 1, name: "Cool down")
            ],
            scheduledDate: Date(timeIntervalSince1970: 0), isQuality: true)
        let eased = PlanKit().easedSession(hard)
        XCTAssertEqual(eased.id, hard.id)
        XCTAssertFalse(eased.isQuality)
        XCTAssertLessThanOrEqual(eased.steps.map(\.level).max() ?? 1, 2)
        XCTAssertLessThan(eased.durationSeconds, hard.durationSeconds)
        XCTAssertGreaterThan(eased.durationSeconds, hard.durationSeconds * 0.4)
        XCTAssertEqual(eased.name, "Easy run")
    }

    func testEasedSessionNeverTrapsOnOddInput() {
        let empty = Session(id: "x", sport: .swim, name: "Empty", purpose: "", steps: [], scheduledDate: Date())
        XCTAssertEqual(PlanKit().easedSession(empty, shortenBy: .nan).steps.count, 0)
        XCTAssertEqual(PlanKit().easedSession(empty, shortenBy: 5).steps.count, 0)
    }
}
