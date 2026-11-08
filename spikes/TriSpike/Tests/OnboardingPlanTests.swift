import XCTest
@testable import TriSpike

/// Plan numbers must agree on every screen, and no screen may speak shorthand or dash punctuation.
/// No test traps: failures are assertions only.
final class OnboardingPlanTests: XCTestCase {
    private func clock(daysOut: Int, startedDaysAgo: Int = 0, noRace: Bool = false) -> (PlanClock, SetupData) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var d = SetupData()
        d.noRaceYet = noRace
        d.raceDate = cal.date(byAdding: .day, value: daysOut, to: today) ?? today
        let start = cal.date(byAdding: .day, value: -startedDaysAgo, to: today) ?? today
        return (PlanClock(setup: d, planStart: start, today: today), d)
    }

    func testPlanPreviewWeeksEqualWeekOfTotal() {
        // The default race is 12 weeks out, the onboarding preview says 12 weeks, and Today must say "of 12".
        let (c, d) = clock(daysOut: 84)
        XCTAssertEqual(OBPlan.planWeeks(d), 12)
        XCTAssertEqual(c.totalWeeks, OBPlan.planWeeks(d))
        XCTAssertEqual(c.currentWeek, 1)
        XCTAssertEqual(c.daysToRace, 84)
    }

    func testPhaseLengthsAddUpToTheTotalAndMatchThePreview() {
        for days in [56, 84, 120, 168, 250] {
            let (c, d) = clock(daysOut: days)
            XCTAssertEqual(c.phases.reduce(0) { $0 + $1.1 }, c.totalWeeks, "phases for \(days) days")
            let preview = OBPlan.phases(for: d).map(\.weeks)
            XCTAssertEqual(c.phases.map(\.1), preview, "preview and demo phases for \(days) days")
        }
    }

    func testCurrentWeekAdvancesAndStaysInRange() {
        let (c, _) = clock(daysOut: 84 - 15, startedDaysAgo: 15)
        XCTAssertEqual(c.totalWeeks, 12)
        XCTAssertEqual(c.currentWeek, 3)
        let (late, _) = clock(daysOut: 0, startedDaysAgo: 200)
        XCTAssertTrue((1...late.totalWeeks).contains(late.currentWeek))
        XCTAssertEqual(late.daysToRace, 0)
    }

    func testNoRaceHasNoCountdown() {
        let (c, _) = clock(daysOut: 10, noRace: true)
        XCTAssertNil(c.daysToRace)
        XCTAssertEqual(c.totalWeeks, 12)
        XCTAssertEqual(c.phases.count, 1)
    }

    func testFirstTimerIsTheDefaultExperience() {
        XCTAssertEqual(SetupData().experience, .firstTimer)
    }

    func testOnlyAppleWatchCanReceiveSessions() {
        for t in TrackerChoice.allCases {
            XCTAssertEqual(t.canReceiveSessionsOnWrist, t == .appleWatch, "\(t)")
        }
    }

    func testTrackersHaveDistinctSymbolsAndNoImportPromise() {
        XCTAssertEqual(Set(TrackerChoice.allCases.map(\.symbol)).count, TrackerChoice.allCases.count)
        for t in TrackerChoice.allCases {
            XCTAssertFalse(t.blurb.contains("Apple Health"), "\(t) promises a Health import that is not built")
        }
    }

    func testSafetyLinesJoinBackToTheAnnexString() {
        XCTAssertEqual(OnboardingSafetyStep.lines.joined(separator: " "), OnboardingSafetyStep.acknowledgement)
        XCTAssertEqual(OnboardingSafetyStep.lines.count, 3)
    }

    func testNoDashesInUserFacingStrings() {
        var strings: [String] = []
        for t in Term.allCases { strings += [t.title, t.short, t.explanation] }
        for t in TrackerChoice.allCases { strings += [t.title, t.blurb] }
        for r in RaceChoice.allCases { strings += [r.title, r.summary, r.blurb, r.typicalWeeks] }
        for e in ExperienceChoice.allCases { strings += [e.title, e.blurb] }
        for p in Phase.allCases { strings.append(p.plainLine) }
        for s in strings {
            XCTAssertFalse(s.contains("\u{2014}") || s.contains("\u{2013}"), "dash in: \(s)")
        }
    }

    @MainActor
    func testNoPowerMeterMeansNoWattsAnywhereOnTheBike() {
        let saved = UserSetup.shared.data
        defer { UserSetup.shared.data = saved }
        UserSetup.shared.data.hasPowerMeter = false
        let sessions = [Demo.sweetSpotBike, Demo.brick]
        for s in sessions {
            XCTAssertFalse(s.usesPower)
            XCTAssertEqual(s.targetLabel, "how it feels")
            for step in s.steps { XCTAssertFalse((step.target ?? "").lowercased().contains("watt"), "\(s.name): \(step.target ?? "")") }
            XCTAssertNotEqual(s.headlineTarget?.unit, "watts")
        }
        for leg in Demo.raceLegs { XCTAssertFalse((leg.target ?? "").contains("watts")) }

        UserSetup.shared.data.hasPowerMeter = true
        XCTAssertEqual(Demo.sweetSpotBike.headlineTarget?.unit, "watts")
        XCTAssertTrue(Demo.raceLegs.contains { ($0.target ?? "").contains("watts") })
    }

    @MainActor
    func testSessionNamesCarryUnitsAndNoShorthand() {
        for s in [Demo.cssSwim, Demo.sweetSpotBike, Demo.thresholdRun, Demo.easySwim, Demo.brick, Demo.longRun, Demo.skippedRun] {
            XCTAssertFalse(s.name.contains(" x "), s.name)
            XCTAssertFalse(s.name.contains("Hard steady"), s.name)
            XCTAssertFalse(s.name.contains("+"), s.name)
        }
    }
}
