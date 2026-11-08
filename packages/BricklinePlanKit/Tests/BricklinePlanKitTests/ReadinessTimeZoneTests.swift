import XCTest
@testable import BricklinePlanKit

/// Readiness buckets nights, check-ins and Keep taps into the plan's own days. These tests run the same week in
/// zones with a daylight saving change inside the 42 day window, one with a 25 hour day, one whose day starts at
/// 01:00, and one far ahead of UTC, and with the plan stored in one zone and read with a device calendar in another.
final class ReadinessTimeZoneTests: XCTestCase {
    private typealias F = ReadinessFixtures

    private struct Zone {
        var id: String
        /// Monday of the plan's first week, as year, month, day in that zone.
        var monday: (Int, Int, Int)
    }

    private let zones: [Zone] = [
        Zone(id: "UTC", monday: (2026, 11, 2)),
        // Fall back on Sunday 1 November 2026: a 25 hour day inside the window.
        Zone(id: "America/New_York", monday: (2026, 11, 2)),
        Zone(id: "America/Havana", monday: (2026, 11, 2)),
        Zone(id: "Pacific/Auckland", monday: (2026, 11, 2)),
        // Spring forward at midnight on Sunday 6 September 2026: that day starts at 01:00 and has 23 hours.
        Zone(id: "America/Santiago", monday: (2026, 9, 7))
    ]

    private func calendar(_ id: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: id) ?? TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func local(_ calendar: Calendar, _ monday: (Int, Int, Int), plusDays days: Int, hour: Int = 0, minute: Int = 0) -> Date {
        let start = calendar.date(from: DateComponents(year: monday.0, month: monday.1, day: monday.2)) ?? Date(timeIntervalSince1970: 0)
        let day = calendar.addDays(days, to: start)
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day) ?? day
    }

    /// Mon easy swim, Thu bike intervals (quality), Fri easy swim, Sat long run, Sun long ride, for 3 weeks.
    private func plan(_ zone: Zone, calendar: Calendar) -> Plan {
        func session(week: Int, day: Date, sport: Sport, name: String, steps: [Step], quality: Bool) -> Session {
            Session(
                id: SessionID.make(weekIndex: week, date: day, sport: sport, slot: 1, calendar: calendar),
                sport: sport, name: name, purpose: "Purpose.", steps: steps, scheduledDate: day, isQuality: quality)
        }
        var weeks: [PlannedWeek] = []
        let start = local(calendar, zone.monday, plusDays: 0)
        for index in 0..<3 {
            let monday = calendar.addDays(7 * index, to: start)
            func d(_ offset: Int) -> Date { calendar.addDays(offset, to: monday) }
            let list = [
                session(week: index, day: d(0), sport: .swim, name: "Easy swim",
                        steps: [F.step(.swim, .work, 45, level: 2, name: "Easy")], quality: false),
                session(week: index, day: d(3), sport: .bike, name: "Bike intervals", steps: [
                    F.step(.bike, .warmUp, 15, level: 2, name: "Warm up"),
                    F.step(.bike, .work, 8, level: 4, group: "b", count: 4, name: "Threshold"),
                    F.step(.bike, .recovery, 2, level: 1, group: "b", count: 4, name: "Spin"),
                    F.step(.bike, .coolDown, 10, level: 2, name: "Cool down")
                ], quality: true),
                session(week: index, day: d(4), sport: .swim, name: "Easy swim",
                        steps: [F.step(.swim, .work, 45, level: 2, name: "Easy")], quality: false),
                session(week: index, day: d(5), sport: .run, name: "Long run",
                        steps: [F.step(.run, .work, 75, level: 2, name: "Easy")], quality: false),
                session(week: index, day: d(6), sport: .bike, name: "Long ride",
                        steps: [F.step(.bike, .work, 120, level: 2, name: "Easy")], quality: false)
            ]
            var week = PlannedWeek(index: index, startDate: monday, phase: .base)
            for item in list { week.days[calendar.startOfDay(for: item.scheduledDate), default: []].append(item) }
            week.plannedHours = week.sessions.reduce(0) { $0 + $1.durationHours }
            weeks.append(week)
        }
        let athlete = AthleteProfile(
            level: .intermediate, weeklyHours: 8, availableWeekdays: Set(Weekday.allCases),
            poolWeekdays: [.monday, .wednesday, .friday], hasWatch: true)
        return Plan(raceDistance: nil, raceDate: nil, startDate: start, weeks: weeks, athlete: athlete, timeZoneIdentifier: zone.id)
    }

    /// 42 nights ending today, each stamped 07:30 local. Baseline nights follow the fixture cycle; the latest 7 sit at
    /// `recent` log HRV.
    private func nights(_ zone: Zone, calendar: Calendar, recent: Double) -> [ReadinessNight] {
        let todayOffset = 3
        return (0..<42).map { age in
            let date = local(calendar, zone.monday, plusDays: todayOffset - age, hour: 7, minute: 30)
            let slot = (((age - 7) % 5) + 5) % 5
            let ln = age < 7 ? recent : 4.0 + F.hrvCycle[slot]
            return ReadinessNight(
                date: date, source: .oura, hrvMilliseconds: exp(ln), restingHeartRate: 52 + F.rhrCycle[slot],
                sleepMinutes: 420 + F.sleepCycle[slot])
        }
    }

    func testTheSameLowWeekDefersToFridayInEveryZone() throws {
        for zone in zones {
            let cal = calendar(zone.id)
            let thursday = local(cal, zone.monday, plusDays: 3, hour: 9)
            let friday = local(cal, zone.monday, plusDays: 4)
            let plan = plan(zone, calendar: cal)
            let list = nights(zone, calendar: cal, recent: 3.95)

            // Baseline math sees 35 and 7 nights, however long the days around the change were.
            let baseline = BaselineCalculator.baseline(for: .oura, nights: list, today: thursday, calendar: cal)
            XCTAssertEqual(baseline.hrv.baselineNights, 35, zone.id)
            XCTAssertEqual(baseline.hrv.recentNights, 7, zone.id)
            XCTAssertEqual(baseline.calibration.validNights, 42, zone.id)
            XCTAssertEqual(baseline.hrvByDaysAgo.count, 42, zone.id)

            let result = ReadinessRules().apply(
                to: plan, inputs: ReadinessInputs(nights: list, lastSyncDate: thursday), today: thursday, calendar: cal)
            let event = try XCTUnwrap(result.events.first, zone.id)
            XCTAssertEqual(event.rule, .readinessDefer, zone.id)
            XCTAssertTrue(event.reasonLine.hasPrefix("Moved Thursday's bike intervals to Friday."), "\(zone.id): \(event.reasonLine)")
            let moved = try XCTUnwrap(result.plan.session(withID: event.sessionIDs[0]), zone.id)
            XCTAssertEqual(cal.startOfDay(for: moved.scheduledDate), friday, zone.id)
        }
    }

    func testCheckInsAndKeepTapsLandOnTheRightLocalDay() throws {
        for zone in zones {
            let cal = calendar(zone.id)
            let thursday = local(cal, zone.monday, plusDays: 3, hour: 9)
            let plan = plan(zone, calendar: cal)
            // Two check-ins late in the evening and early in the morning around today and yesterday.
            let checkIns = [
                ReadinessCheckIn(date: local(cal, zone.monday, plusDays: 3, hour: 0, minute: 5), score: 2),
                ReadinessCheckIn(date: local(cal, zone.monday, plusDays: 2, hour: 23, minute: 50), score: 2)
            ]
            let inputs = ReadinessInputs(checkIns: checkIns)
            let result = ReadinessRules().apply(to: plan, inputs: inputs, today: thursday, calendar: cal)
            XCTAssertEqual(result.events.map(\.rule), [.readinessEasy], "\(zone.id): yesterday 23:50 and today 00:05")
            XCTAssertEqual(result.assessment.checkIn.text, "Check-in 2 of 5.", zone.id)

            // Three taps on three local days count as three overrides.
            let taps = (1...3).map { local(cal, zone.monday, plusDays: 3 - $0, hour: 23, minute: 55) }
            let silent = ReadinessRules().apply(
                to: plan, inputs: ReadinessInputs(nights: nights(zone, calendar: cal, recent: 3.95), overrides: taps, lastSyncDate: thursday),
                today: thursday, calendar: cal)
            XCTAssertEqual(silent.assessment.overridesInLast14Days, 3, zone.id)
            XCTAssertEqual(silent.assessment.status, .paused(.notesOnly), zone.id)
        }
    }

    func testAPlanKeepsItsOwnZoneWhateverTheDeviceCalendarSays() throws {
        let zone = zones[1]
        let planCalendar = calendar(zone.id)
        let thursday = local(planCalendar, zone.monday, plusDays: 3, hour: 9)
        let friday = local(planCalendar, zone.monday, plusDays: 4)
        let plan = plan(zone, calendar: planCalendar)
        let list = nights(zone, calendar: planCalendar, recent: 3.95)
        let inputs = ReadinessInputs(nights: list, lastSyncDate: thursday)
        for device in ["Pacific/Auckland", "Asia/Kolkata", "America/Santiago"] {
            let result = ReadinessRules().apply(to: plan, inputs: inputs, today: thursday, calendar: calendar(device))
            let event = try XCTUnwrap(result.events.first, device)
            let moved = try XCTUnwrap(result.plan.session(withID: event.sessionIDs[0]), device)
            XCTAssertEqual(planCalendar.startOfDay(for: moved.scheduledDate), friday, device)
            // The undo works the same way on the plan's days.
            let kept = try ReadinessRules().keepPlannedSession(
                event, in: result.plan, today: thursday, calendar: calendar(device))
            XCTAssertEqual(kept.overrideDay, planCalendar.startOfDay(for: thursday), device)
        }
    }
}
