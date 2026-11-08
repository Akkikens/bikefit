import XCTest
@testable import BricklinePlanKit

/// Shared builders for the readiness tests, plus a few checks that the builders produce what the other tests assume.
///
/// The standard baseline is built so its statistics can be done by hand. Thirty five baseline nights (7 to 41 days
/// before today) carry log HRV of 4.0 plus 0.05 times the cycle -1, 1, 0, 2, -2, repeated 7 times. The offsets sum
/// to zero, so the mean is exactly 4.0, and the sum of squares is 7 x 10 x 0.0025 = 0.175, so the sample SD is
/// sqrt(0.175 / 34) = 0.071743. Thresholds: baseline minus 0.5 SD = 3.96413, baseline minus 1 SD = 3.92826.
enum ReadinessFixtures {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? Date(timeIntervalSince1970: 0)
    }

    /// Monday 2 November 2026, the first day of the fixture plan.
    static let planStart = date(2026, 11, 2)
    static let monday = date(2026, 11, 2)
    static let tuesday = date(2026, 11, 3)
    static let wednesday = date(2026, 11, 4)
    /// The day most tests run on: Thursday, which holds the bike intervals.
    static let thursday = date(2026, 11, 5)
    static let friday = date(2026, 11, 6)

    static let sdOfStandardBaseline = (0.175 / 34).squareRoot()
    static let baselineMean = 4.0

    static func day(_ offset: Int, from base: Date = thursday) -> Date { calendar.addDays(offset, to: base) }

    // MARK: Plan

    static func step(
        _ sport: Sport, _ kind: StepKind, _ minutes: Double, level: Int, group: String? = nil, count: Int? = nil,
        name: String = "Step"
    ) -> Step {
        let target: StepTarget = sport == .swim ? .cssOffset(ValueRange(8, 15)) : .rpe(ZoneConstants.rpeRange(forLevel: level))
        return Step(sport: sport, kind: kind, durationSeconds: minutes * 60, level: level, target: target,
                    repeatGroupID: group, repeatCount: count, name: name)
    }

    static func session(
        week: Int, day: Date, sport: Sport, name: String, steps: [Step], quality: Bool = false, slot: Int = 1
    ) -> Session {
        Session(id: SessionID.make(weekIndex: week, date: day, sport: sport, slot: slot, calendar: calendar),
                sport: sport, name: name, purpose: "Purpose.", steps: steps, scheduledDate: day, isQuality: quality)
    }

    /// Mon easy swim, Tue threshold run (quality), Thu bike intervals (quality), Fri easy swim, Sat long run,
    /// Sun long ride. Wednesday is free. With `saturdayHardBike` Saturday also holds a hard bike session.
    static func weekSessions(index: Int, monday: Date, saturdayHardBike: Bool) -> [Session] {
        func d(_ offset: Int) -> Date { calendar.addDays(offset, to: monday) }
        var list: [Session] = [
            session(week: index, day: d(0), sport: .swim, name: "Easy swim",
                    steps: [step(.swim, .work, 45, level: 2, name: "Easy")]),
            session(week: index, day: d(1), sport: .run, name: "Threshold run", steps: [
                step(.run, .warmUp, 10, level: 2, name: "Warm up"),
                step(.run, .work, 8, level: 4, group: "g", count: 3, name: "Threshold"),
                step(.run, .recovery, 2, level: 1, group: "g", count: 3, name: "Jog"),
                step(.run, .coolDown, 10, level: 2, name: "Cool down")
            ], quality: true),
            session(week: index, day: d(3), sport: .bike, name: "Bike intervals", steps: [
                step(.bike, .warmUp, 15, level: 2, name: "Warm up"),
                step(.bike, .work, 8, level: 4, group: "b", count: 4, name: "Threshold"),
                step(.bike, .recovery, 2, level: 1, group: "b", count: 4, name: "Spin"),
                step(.bike, .coolDown, 10, level: 2, name: "Cool down")
            ], quality: true),
            session(week: index, day: d(4), sport: .swim, name: "Easy swim",
                    steps: [step(.swim, .work, 45, level: 2, name: "Easy")]),
            session(week: index, day: d(5), sport: .run, name: "Long run",
                    steps: [step(.run, .work, 75, level: 2, name: "Easy")]),
            session(week: index, day: d(6), sport: .bike, name: "Long ride",
                    steps: [step(.bike, .work, 120, level: 2, name: "Easy")])
        ]
        if saturdayHardBike {
            list.append(session(week: index, day: d(5), sport: .bike, name: "Hill repeats", steps: [
                step(.bike, .warmUp, 15, level: 2, name: "Warm up"),
                step(.bike, .work, 5, level: 5, group: "h", count: 5, name: "Hard"),
                step(.bike, .recovery, 3, level: 1, group: "h", count: 5, name: "Spin"),
                step(.bike, .coolDown, 10, level: 2, name: "Cool down")
            ], quality: true))
        }
        return list
    }

    static func plan(
        weeks count: Int = 4,
        available: Set<Weekday>? = nil,
        saturdayHardBike: Bool = false,
        raceDistance: RaceDistance? = nil,
        raceDate: Date? = nil
    ) -> Plan {
        var weeks: [PlannedWeek] = []
        for index in 0..<count {
            let start = calendar.addDays(7 * index, to: planStart)
            var week = PlannedWeek(index: index, startDate: start, phase: .base)
            for item in weekSessions(index: index, monday: start, saturdayHardBike: saturdayHardBike && index == 0) {
                week.days[calendar.startOfDay(for: item.scheduledDate), default: []].append(item)
            }
            week.plannedHours = week.sessions.reduce(0) { $0 + $1.durationHours }
            weeks.append(week)
        }
        let athlete = AthleteProfile(
            level: .intermediate, weeklyHours: 8, availableWeekdays: available ?? Set(Weekday.allCases),
            poolWeekdays: [.monday, .wednesday, .friday], hasWatch: true)
        return Plan(raceDistance: raceDistance, raceDate: raceDate, startDate: planStart, weeks: weeks, athlete: athlete,
                    timeZoneIdentifier: "UTC")
    }

    // MARK: Nights

    static let hrvCycle: [Double] = [-1, 1, 0, 2, -2].map { 0.05 * $0 }
    static let rhrCycle: [Double] = [-2, 2, 0, 2, -2]
    static let sleepCycle: [Double] = [-20, 0, 20, 0, 0]

    /// One source's nights: 35 standard baseline nights on `baselineDays`, then the latest 7 from the closures
    /// (days before today 0 through 6; a nil result leaves that value out, and a night with no value is skipped).
    /// Defaults describe an athlete exactly at baseline, with resting heart rate 52 and 7h 10m of sleep.
    static func nights(
        source: ReadinessSource = .oura,
        today: Date = thursday,
        baselineDays: ClosedRange<Int> = 7...41,
        recentLnHRV: (Int) -> Double? = { _ in 4.0 },
        recentRHR: (Int) -> Double? = { _ in 52 },
        recentSleep: (Int) -> Double? = { _ in 430 }
    ) -> [ReadinessNight] {
        var out: [ReadinessNight] = []
        for age in baselineDays {
            let index = age - 7
            let slot = ((index % 5) + 5) % 5
            out.append(ReadinessNight(
                date: day(-age, from: today), source: source,
                hrvMilliseconds: exp(4.0 + hrvCycle[slot]),
                restingHeartRate: 52 + rhrCycle[slot],
                sleepMinutes: 420 + sleepCycle[slot]))
        }
        for age in 0..<7 {
            let ln = recentLnHRV(age)
            let hrv = ln.map { exp($0) }
            let rhr = recentRHR(age)
            let sleep = recentSleep(age)
            if hrv == nil && rhr == nil && sleep == nil { continue }
            out.append(ReadinessNight(
                date: day(-age, from: today), source: source,
                hrvMilliseconds: hrv, restingHeartRate: rhr, sleepMinutes: sleep))
        }
        return out
    }

    /// Standard inputs for one device: calibrated, synced this morning.
    static func inputs(
        source: ReadinessSource = .oura,
        recentLnHRV: @escaping (Int) -> Double? = { _ in 4.0 },
        recentRHR: @escaping (Int) -> Double? = { _ in 52 },
        recentSleep: @escaping (Int) -> Double? = { _ in 430 },
        checkIns: [ReadinessCheckIn] = [],
        overrides: [Date] = [],
        preferred: ReadinessSource? = nil
    ) -> ReadinessInputs {
        ReadinessInputs(
            nights: nights(source: source, recentLnHRV: recentLnHRV, recentRHR: recentRHR, recentSleep: recentSleep),
            checkIns: checkIns, overrides: overrides, lastSyncDate: thursday, preferredRecoverySource: preferred)
    }

    static func checkIn(_ age: Int, _ score: Int) -> ReadinessCheckIn {
        ReadinessCheckIn(date: day(-age), score: score)
    }

    /// An earlier readiness plan change in the history, `age` days ago.
    static func change(rule: AdaptationRuleID = .readinessDefer, age: Int) -> AdaptationEvent {
        AdaptationEvent(
            rule: rule, reasonLine: "Earlier change.", date: day(-age), isStructural: rule != .sleepNote,
            sessionIDs: ["x"], advisory: AdvisoryChange())
    }

    static func ruleSet() -> ReadinessRules { ReadinessRules() }
}

final class ReadinessFixtureTests: XCTestCase {
    func testStandardBaselineHasHandComputedStatistics() {
        let stats = BaselineCalculator.baseline(
            for: .oura, nights: ReadinessFixtures.nights(), today: ReadinessFixtures.thursday,
            calendar: ReadinessFixtures.calendar)
        XCTAssertEqual(stats.hrv.mean ?? 0, 4.0, accuracy: 1e-12)
        XCTAssertEqual(stats.hrv.standardDeviation ?? 0, ReadinessFixtures.sdOfStandardBaseline, accuracy: 1e-12)
        XCTAssertEqual(stats.hrv.baselineNights, 35)
        XCTAssertEqual(stats.hrv.recentNights, 7)
        XCTAssertEqual(stats.sleepMedianMinutes ?? 0, 420, accuracy: 1e-9)
    }

    func testFixturePlanHasThursdayBikeIntervalsAsQuality() {
        let plan = ReadinessFixtures.plan()
        let thursday = plan.adaptSessions(on: ReadinessFixtures.thursday, calendar: ReadinessFixtures.calendar)
        XCTAssertEqual(thursday.map(\.name), ["Bike intervals"])
        XCTAssertTrue(thursday[0].isQuality)
        XCTAssertEqual(plan.weeks.count, 4)
    }

    func testRecentClosureCanLeaveNightsOut() {
        let list = ReadinessFixtures.nights(recentLnHRV: { $0 < 2 ? 4.0 : nil }, recentRHR: { _ in nil }, recentSleep: { _ in nil })
        XCTAssertEqual(list.filter { $0.hrvMilliseconds != nil }.count, 35 + 2)
        XCTAssertEqual(list.count, 37)
    }
}
