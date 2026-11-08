import XCTest
@testable import BricklinePlanKit

final class RaceTests: XCTestCase {
    private let window = DefaultRaceWindow()

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? Date(timeIntervalSince1970: 0)
    }

    private let raceDay = DateComponents(year: 2027, month: 6, day: 20)

    private func raceDate() -> Date { date(2027, 6, 20, hour: 7) }

    private func daysBefore(_ n: Int) -> Date {
        calendar.addDays(-n, to: date(2027, 6, 20, hour: 18))
    }

    private let athlete = AthleteProfile(level: .intermediate, weeklyHours: 8, availableWeekdays: [.monday, .wednesday, .saturday], poolWeekdays: [.monday])

    private func benchmarks(css: Double? = nil, ftp: Double? = nil, lthr: Double? = nil, threshold: Double? = nil, estimated: Bool = false) -> Benchmarks {
        let d = date(2027, 1, 1)
        return Benchmarks(
            cssSecondsPer100m: css.map { BenchmarkValue(value: $0, isEstimated: estimated, date: d) },
            ftpWatts: ftp.map { BenchmarkValue(value: $0, isEstimated: estimated, date: d) },
            lthrBpm: lthr.map { BenchmarkValue(value: $0, isEstimated: estimated, date: d) },
            thresholdPaceSecondsPerKm: threshold.map { BenchmarkValue(value: $0, isEstimated: estimated, date: d) })
    }

    // MARK: Window

    func testWindowOpensAtTMinus21ForOlympicAndHalf() {
        for distance in [RaceDistance.olympic, .half] {
            XCTAssertFalse(window.isWindowActive(raceDate: raceDate(), distance: distance, today: daysBefore(22), calendar: calendar), "\(distance)")
            XCTAssertTrue(window.isWindowActive(raceDate: raceDate(), distance: distance, today: daysBefore(21), calendar: calendar), "\(distance)")
            XCTAssertTrue(window.isWindowActive(raceDate: raceDate(), distance: distance, today: daysBefore(1), calendar: calendar), "\(distance)")
        }
    }

    func testWindowOpensAtTMinus10ForSprint() {
        XCTAssertFalse(window.isWindowActive(raceDate: raceDate(), distance: .sprint, today: daysBefore(11), calendar: calendar))
        XCTAssertTrue(window.isWindowActive(raceDate: raceDate(), distance: .sprint, today: daysBefore(10), calendar: calendar))
        XCTAssertFalse(window.isWindowActive(raceDate: raceDate(), distance: .sprint, today: daysBefore(21), calendar: calendar))
    }

    func testWindowIncludesRaceDayAndClosesAfter() {
        XCTAssertTrue(window.isWindowActive(raceDate: raceDate(), distance: .olympic, today: daysBefore(0), calendar: calendar))
        XCTAssertFalse(window.isWindowActive(raceDate: raceDate(), distance: .olympic, today: daysBefore(-1), calendar: calendar))
    }

    func testWindowIgnoresTimeOfDay() {
        let earlyMorningToday = calendar.addDays(-21, to: date(2027, 6, 20, hour: 0))
        XCTAssertTrue(window.isWindowActive(raceDate: date(2027, 6, 20, hour: 23), distance: .olympic, today: earlyMorningToday, calendar: calendar))
    }

    // MARK: Wake up math

    func testWakeUpMathFromAnnexF() {
        let race = RaceDetails(distance: .olympic, raceDate: raceDate(), startMinutesAfterMidnight: 7 * 60)
        // 420 minus 20 transit minus 45 setup minus 120 breakfast lead is 235, which is 3:55 AM.
        XCTAssertEqual(window.wakeUpMinutes(for: race), 235)
        let wake = window.entries(for: race, calendar: calendar).first { $0.kind == .wakeUp }
        XCTAssertEqual(wake?.tMinusDays, 0)
        XCTAssertEqual(wake?.minutesAfterMidnight, 235)
        XCTAssertTrue(try XCTUnwrap(wake).text.contains("3:55 AM"))
        XCTAssertTrue(try XCTUnwrap(wake).text.contains("7:00 AM"))
    }

    func testWakeUpMathUsesAllParameters() {
        let race = RaceDetails(distance: .half, raceDate: raceDate(), startMinutesAfterMidnight: 8 * 60 + 30, transitMinutes: 35, setupMinutes: 60, breakfastLeadMinutes: 90)
        XCTAssertEqual(window.wakeUpMinutes(for: race), 510 - 185)
    }

    func testWakeUpNeverGoesBelowMidnightAndIgnoresNegativeInputs() {
        let early = RaceDetails(distance: .sprint, raceDate: raceDate(), startMinutesAfterMidnight: 90)
        XCTAssertEqual(window.wakeUpMinutes(for: early), 0)
        let negative = RaceDetails(distance: .sprint, raceDate: raceDate(), startMinutesAfterMidnight: 420, transitMinutes: -50, setupMinutes: -10, breakfastLeadMinutes: 60)
        XCTAssertEqual(window.wakeUpMinutes(for: negative), 360)
        let wild = RaceDetails(distance: .sprint, raceDate: raceDate(), startMinutesAfterMidnight: 99_999)
        XCTAssertEqual(window.wakeUpMinutes(for: wild), max(24 * 60 - 1 - 185, 0))
        XCTAssertFalse(window.entries(for: wild, calendar: calendar).isEmpty)
    }

    func testClockFormatting() {
        XCTAssertEqual(RaceFormat.clock(minutesAfterMidnight: 0), "12:00 AM")
        XCTAssertEqual(RaceFormat.clock(minutesAfterMidnight: 12 * 60), "12:00 PM")
        XCTAssertEqual(RaceFormat.clock(minutesAfterMidnight: 13 * 60 + 5), "1:05 PM")
        XCTAssertEqual(RaceFormat.clock(minutesAfterMidnight: -10), "12:00 AM")
    }

    // MARK: Timeline entries

    func testBaseEntriesForShortRace() {
        let race = RaceDetails(distance: .olympic, raceDate: raceDate(), startMinutesAfterMidnight: 420)
        let entries = window.entries(for: race, calendar: calendar)
        XCTAssertEqual(entries.map(\.kind), [.carbLoad, .packTonight, .wakeUp])
        XCTAssertEqual(entries.map(\.tMinusDays), [1, 1, 0])
    }

    func testCarbLoadStartsTMinus2ForHalfAndRaceEveOtherwise() {
        for distance in RaceDistance.allCases {
            let race = RaceDetails(distance: distance, raceDate: raceDate(), startMinutesAfterMidnight: 420)
            let carb = window.entries(for: race, calendar: calendar).first { $0.kind == .carbLoad }
            XCTAssertEqual(carb?.tMinusDays, distance == .half ? 2 : 1, "\(distance)")
        }
    }

    func testPackTonightIsTMinus1() {
        let race = RaceDetails(distance: .half, raceDate: raceDate(), startMinutesAfterMidnight: 420)
        XCTAssertEqual(window.entries(for: race, calendar: calendar).first { $0.kind == .packTonight }?.tMinusDays, 1)
    }

    func testBikeServiceOnlyWithBikeRecordAtTMinus14() {
        var race = RaceDetails(distance: .olympic, raceDate: raceDate(), startMinutesAfterMidnight: 420)
        XCTAssertNil(window.entries(for: race, calendar: calendar).first { $0.kind == .bikeService })
        race.hasBikeRecord = true
        let entries = window.entries(for: race, calendar: calendar)
        XCTAssertEqual(entries.first?.kind, .bikeService)
        XCTAssertEqual(entries.first?.tMinusDays, 14)
    }

    func testBikeServiceClampsToSprintWindowOpening() {
        let race = RaceDetails(distance: .sprint, raceDate: raceDate(), startMinutesAfterMidnight: 420, hasBikeRecord: true)
        XCTAssertEqual(window.entries(for: race, calendar: calendar).first { $0.kind == .bikeService }?.tMinusDays, 10)
    }

    func testTravelAndPackFollowTheTravelFlag() {
        var race = RaceDetails(distance: .half, raceDate: raceDate(), startMinutesAfterMidnight: 420)
        XCTAssertNil(window.entries(for: race, calendar: calendar).first { $0.kind == .travel })
        XCTAssertNil(window.entries(for: race, calendar: calendar).first { $0.kind == .pack })
        race.isTravelRace = true
        let kinds = window.entries(for: race, calendar: calendar).map(\.kind)
        XCTAssertTrue(kinds.contains(.travel))
        XCTAssertTrue(kinds.contains(.pack))
    }

    func testEntriesAreOrderedByDescendingTMinusAndInsideTheWindow() {
        for distance in RaceDistance.allCases {
            let race = RaceDetails(distance: distance, raceDate: raceDate(), startMinutesAfterMidnight: 420, isTravelRace: true, hasBikeRecord: true)
            let entries = window.entries(for: race, calendar: calendar)
            XCTAssertEqual(entries.map(\.tMinusDays), entries.map(\.tMinusDays).sorted(by: >), "\(distance)")
            XCTAssertTrue(entries.allSatisfy { $0.tMinusDays >= 0 && $0.tMinusDays <= distance.parameters.windowOpensTMinusDays }, "\(distance)")
            XCTAssertEqual(entries.last?.kind, .wakeUp)
        }
    }

    func testCustomParametersMoveEntries() {
        let custom = DefaultRaceWindow(parameters: RaceWindowParameters(bikeServiceTMinus: 7, packTonightTMinus: 2))
        let race = RaceDetails(distance: .olympic, raceDate: raceDate(), startMinutesAfterMidnight: 420, hasBikeRecord: true)
        let entries = custom.entries(for: race, calendar: calendar)
        XCTAssertEqual(entries.first { $0.kind == .bikeService }?.tMinusDays, 7)
        XCTAssertEqual(entries.first { $0.kind == .packTonight }?.tMinusDays, 2)
    }

    // MARK: Notification cap (annex H)

    func testCapKeepsAtMostOnePerDayAndNearestToRaceDayWins() {
        let race = RaceDetails(distance: .olympic, raceDate: raceDate(), startMinutesAfterMidnight: 420)
        let capped = window.cappedForNotifications(window.entries(for: race, calendar: calendar))
        // Carb load and pack tonight both sit on race eve; pack tonight wins.
        XCTAssertEqual(capped.map(\.kind), [.packTonight, .wakeUp])
    }

    func testCapLimitsAnyWeekToFourAndKeepsWakeUp() {
        let race = RaceDetails(distance: .half, raceDate: raceDate(), startMinutesAfterMidnight: 420, isTravelRace: true, hasBikeRecord: true)
        let all = window.entries(for: race, calendar: calendar)
        XCTAssertEqual(all.count, 6)
        let capped = window.cappedForNotifications(all)
        XCTAssertEqual(capped.map(\.tMinusDays), [14, 3, 2, 1, 0])
        XCTAssertEqual(capped.last?.kind, .wakeUp)
        // Never more than four inside any seven day span.
        for start in -6...20 {
            let inSpan = capped.filter { $0.tMinusDays >= start && $0.tMinusDays <= start + 6 }.count
            XCTAssertLessThanOrEqual(inSpan, 4, "span starting T minus \(start)")
        }
    }

    func testCapAlwaysKeepsWakeUpEvenWhenOthersAreDropped() {
        let entries = (1...6).map { RaceWindowEntry(tMinusDays: $0, kind: .pack, text: "x") }
            + [RaceWindowEntry(tMinusDays: 0, kind: .wakeUp, text: "w", minutesAfterMidnight: 200)]
        let capped = window.cappedForNotifications(entries)
        XCTAssertTrue(capped.contains { $0.kind == .wakeUp })
        XCTAssertEqual(capped.count, 4)
        XCTAssertEqual(capped.map(\.tMinusDays), [3, 2, 1, 0])
    }

    func testCapOnEmptyAndDuplicateWakeUps() {
        XCTAssertTrue(window.cappedForNotifications([]).isEmpty)
        let twice = [RaceWindowEntry(tMinusDays: 0, kind: .wakeUp, text: "a"), RaceWindowEntry(tMinusDays: 0, kind: .wakeUp, text: "b")]
        XCTAssertEqual(window.cappedForNotifications(twice).count, 1)
    }

    // MARK: Pacing

    func testPacingWithAllBenchmarksGivesRangesForEveryLeg() {
        let card = window.pacing(for: .olympic, athlete: athlete, benchmarks: benchmarks(css: 100, ftp: 250, threshold: 300))
        XCTAssertEqual(card.targets.map(\.leg.sport), [.swim, .bike, .run])
        guard case .cssOffset(let swim) = card.targets[0].target,
              case .powerRange(let bike) = card.targets[1].target,
              case .pacePerKm(let run) = card.targets[2].target else {
            return XCTFail("expected resolved targets")
        }
        XCTAssertEqual(swim, ValueRange(2, 5))
        XCTAssertEqual(bike.lower, 250 * 0.78, accuracy: 0.001)
        XCTAssertEqual(bike.upper, 250 * 0.88, accuracy: 0.001)
        XCTAssertEqual(run, ValueRange(310, 325))
        for target in card.targets {
            XCTAssertGreaterThan(target.expectedDurationSeconds.width, 0, "ranges, never single splits")
            XCTAssertGreaterThan(target.expectedDurationSeconds.lower, 0)
            XCTAssertFalse(target.summary.isEmpty)
        }
        // 15 blocks of 100 m at 102 to 105 s each.
        XCTAssertEqual(card.targets[0].expectedDurationSeconds.lower, 15 * 102, accuracy: 0.001)
        XCTAssertEqual(card.targets[0].expectedDurationSeconds.upper, 15 * 105, accuracy: 0.001)
        XCTAssertEqual(card.targets[2].expectedDurationSeconds.lower, 10 * 310, accuracy: 0.001)
    }

    func testPacingFallsBackToHeartRateThenFeel() {
        let hr = window.pacing(for: .sprint, athlete: athlete, benchmarks: benchmarks(lthr: 170))
        guard case .heartRateRange(let bpm) = hr.targets[1].target else { return XCTFail("expected heart rate") }
        XCTAssertEqual(bpm.lower, 170 * 0.94, accuracy: 0.001)
        XCTAssertEqual(bpm.upper, 170.0, accuracy: 0.001)

        let none = window.pacing(for: .sprint, athlete: athlete, benchmarks: Benchmarks())
        for target in none.targets {
            guard case .rpe(let rpe) = target.target else { return XCTFail("expected rpe for \(target.leg.sport)") }
            XCTAssertEqual(rpe, ValueRange(7, 8))
            XCTAssertGreaterThan(target.expectedDurationSeconds.lower, 0)
        }
    }

    func testPacingPrefersFTPOverLTHR() {
        let card = window.pacing(for: .half, athlete: athlete, benchmarks: benchmarks(ftp: 200, lthr: 170))
        guard case .powerRange = card.targets[1].target else { return XCTFail("expected power") }
    }

    func testPacingGetsEasierWithDistance() {
        let b = benchmarks(css: 100, ftp: 250, threshold: 300)
        var lastBike = Double.infinity
        var lastRun = 0.0
        for distance in [RaceDistance.sprint, .olympic, .half] {
            let card = window.pacing(for: distance, athlete: athlete, benchmarks: b)
            guard case .powerRange(let bike) = card.targets[1].target, case .pacePerKm(let run) = card.targets[2].target else { return XCTFail() }
            XCTAssertLessThan(bike.upper, lastBike)
            XCTAssertGreaterThan(run.lower, lastRun)
            lastBike = bike.upper
            lastRun = run.lower
        }
    }

    func testPacingMarksEstimatedBenchmarksAndRejectsNonsense() {
        let estimated = window.pacing(for: .olympic, athlete: athlete, benchmarks: benchmarks(ftp: 250, estimated: true))
        XCTAssertTrue(estimated.targets[1].summary.contains("estimate"))
        let junk = Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: .nan, isEstimated: false, date: date(2027, 1, 1)),
            ftpWatts: BenchmarkValue(value: 1e300, isEstimated: false, date: date(2027, 1, 1)),
            thresholdPaceSecondsPerKm: BenchmarkValue(value: -5, isEstimated: false, date: date(2027, 1, 1)))
        let card = window.pacing(for: .olympic, athlete: athlete, benchmarks: junk)
        for target in card.targets {
            guard case .rpe = target.target else { return XCTFail("junk benchmark should fall back to feel") }
            XCTAssertTrue(target.expectedDurationSeconds.lower.isFinite)
        }
    }

    func testPacingIsDeterministic() {
        let b = benchmarks(css: 105, ftp: 230, threshold: 320)
        XCTAssertEqual(window.pacing(for: .half, athlete: athlete, benchmarks: b), window.pacing(for: .half, athlete: athlete, benchmarks: b))
    }

    // MARK: Caveat

    func testCaveatScalesByDistance() {
        XCTAssertEqual(RaceWindowCopy.caveat(for: .sprint), RaceWindowCopy.shortCourseCaveat)
        XCTAssertEqual(RaceWindowCopy.caveat(for: .olympic), RaceWindowCopy.shortCourseCaveat)
        XCTAssertEqual(RaceWindowCopy.caveat(for: .half), RaceWindowCopy.longCourseCaveat)
        XCTAssertNotEqual(RaceWindowCopy.shortCourseCaveat, RaceWindowCopy.longCourseCaveat)
        for distance in RaceDistance.allCases {
            let card = window.pacing(for: distance, athlete: athlete, benchmarks: Benchmarks())
            XCTAssertEqual(card.caveat, RaceWindowCopy.caveat(for: distance))
            XCTAssertTrue(card.caveat.contains("several percent"), "\(distance)")
            XCTAssertTrue(card.caveat.contains("ranges"), "\(distance)")
            XCTAssertFalse(card.caveat.contains("15 to 25"), "\(distance): the 15 to 25 minute line is for full distance only")
        }
        XCTAssertTrue(RaceWindowCopy.fullDistanceCaveat.contains("15 to 25 minutes"))
    }

    // MARK: Fueling tiers

    private func card(bikeSeconds: Double, runSeconds: Double = 1800, swimSeconds: Double = 1200) -> PacingCard {
        func target(_ sport: Sport, _ km: Double, _ seconds: Double) -> PacingTarget {
            PacingTarget(leg: RaceLeg(sport: sport, distanceKm: km), target: .none, expectedDurationSeconds: ValueRange(seconds, seconds), summary: "s")
        }
        return PacingCard(distance: .half, targets: [target(.swim, 1.9, swimSeconds), target(.bike, 90, bikeSeconds), target(.run, 21.1, runSeconds)], caveat: "c")
    }

    func testTierBoundaries() {
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 74 * 60 + 59), .fluidsOnly)
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 75 * 60), .moderate)
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 150 * 60), .moderate)
        XCTAssertEqual(FuelingTier.tier(forDurationSeconds: 150 * 60 + 1), .high)
    }

    func testFuelingTiersAtLegBoundaries() {
        let cases: [(Double, FuelingTier)] = [(74 * 60 + 59, .fluidsOnly), (75 * 60, .moderate), (150 * 60, .moderate), (150 * 60 + 1, .high)]
        for (seconds, expected) in cases {
            let advice = window.fueling(for: card(bikeSeconds: seconds))
            XCTAssertEqual(advice[1].tier, expected, "bike at \(seconds)")
            XCTAssertEqual(advice[1].carbsGramsPerHour == nil, expected == .fluidsOnly)
        }
    }

    func testFuelingAdviceMatchesLegOrderAndEveryTierCarriesBothLines() {
        let advice = window.fueling(for: card(bikeSeconds: 160 * 60, runSeconds: 100 * 60))
        XCTAssertEqual(advice.map(\.leg.sport), [.swim, .bike, .run])
        for item in advice {
            XCTAssertFalse(item.practiceLine.isEmpty)
            XCTAssertEqual(item.stomachLine, RaceWindowCopy.stomachLine)
            XCTAssertTrue(item.stomachLine.contains("stomach trouble"))
        }
    }

    func testHighTierRangesDifferForBikeAndRun() {
        let advice = window.fueling(for: card(bikeSeconds: 200 * 60, runSeconds: 160 * 60))
        XCTAssertEqual(advice[1].tier, .high)
        XCTAssertEqual(advice[1].carbsGramsPerHour, ValueRange(60, 90))
        XCTAssertEqual(advice[2].tier, .high)
        XCTAssertEqual(advice[2].carbsGramsPerHour, ValueRange(50, 70))
        XCTAssertTrue(advice[1].practiceLine.contains("glucose and fructose"))
    }

    func testModerateTierScalesFromThirtyTowardSixty() {
        var lastLower = 0.0
        for minutes in stride(from: 75.0, through: 150.0, by: 15.0) {
            let range = DefaultRaceWindow.moderateCarbs(forDurationSeconds: minutes * 60)
            XCTAssertGreaterThanOrEqual(range.lower, 30)
            XCTAssertLessThanOrEqual(range.upper, 60)
            XCTAssertGreaterThanOrEqual(range.lower, lastLower)
            lastLower = range.lower
        }
        XCTAssertEqual(DefaultRaceWindow.moderateCarbs(forDurationSeconds: 75 * 60), ValueRange(30, 35))
        XCTAssertEqual(DefaultRaceWindow.moderateCarbs(forDurationSeconds: 150 * 60), ValueRange(55, 60))
    }

    func testSwimIsAlwaysFluidsOnlyEvenWhenSlow() {
        let advice = window.fueling(for: card(bikeSeconds: 100 * 60, swimSeconds: 120 * 60))
        XCTAssertEqual(advice[0].tier, .fluidsOnly)
        XCTAssertNil(advice[0].carbsGramsPerHour)
    }

    func testFuelingHandlesUnusableDurations() {
        let weird = PacingCard(distance: .sprint, targets: [
            PacingTarget(leg: RaceLeg(sport: .bike, distanceKm: 20), target: .none, expectedDurationSeconds: ValueRange(.nan, .nan), summary: ""),
            PacingTarget(leg: RaceLeg(sport: .run, distanceKm: 5), target: .none, expectedDurationSeconds: ValueRange(-10, -5), summary: "")
        ], caveat: "")
        let advice = window.fueling(for: weird)
        XCTAssertEqual(advice.map(\.tier), [.fluidsOnly, .fluidsOnly])
        XCTAssertTrue(window.fueling(for: PacingCard(distance: .sprint, targets: [], caveat: "")).isEmpty)
    }

    func testFuelingFromRealPacingCards() {
        let b = benchmarks(css: 100, ftp: 250, threshold: 300)
        let sprint = window.fueling(for: window.pacing(for: .sprint, athlete: athlete, benchmarks: b))
        XCTAssertTrue(sprint.allSatisfy { $0.tier == .fluidsOnly })
        let half = window.fueling(for: window.pacing(for: .half, athlete: athlete, benchmarks: b))
        // Intermediate placeholder speeds put the 90 km bike near 3 to 3.6 hours, and the run near 2 hours.
        XCTAssertEqual(half.map(\.tier), [.fluidsOnly, .high, .moderate])
    }

    // MARK: Debrief

    func testDebriefClassifiesEachLeg() {
        let planned = card(bikeSeconds: 3600, runSeconds: 1800, swimSeconds: 1200)
        // Planned ranges are single points here, so inside means exactly equal.
        let actuals = RaceActuals(swimSeconds: 1100, transition1Seconds: 90, bikeSeconds: 3600, transition2Seconds: 60, runSeconds: 1900)
        let debrief = window.debrief(card: planned, actuals: actuals)
        XCTAssertEqual(debrief.legs.map(\.deviation), [.faster, .within, .slower])
        XCTAssertEqual(debrief.legs[0].deltaSeconds, -100, accuracy: 0.001)
        XCTAssertEqual(debrief.legs[1].deltaSeconds, 0)
        XCTAssertEqual(debrief.legs[2].deltaSeconds, 100, accuracy: 0.001)
        XCTAssertEqual(debrief.actualLegsTotalSeconds ?? 0, 6600, accuracy: 0.001)
        XCTAssertEqual(debrief.totalRecordedSeconds, 6750, accuracy: 0.001)
        XCTAssertEqual(debrief.plannedLegsTotalSeconds, ValueRange(6600, 6600))
        XCTAssertEqual(debrief.transitions.map(\.seconds), [90, 60])
        XCTAssertEqual(debrief.prompts.count, 2)
        XCTAssertTrue(debrief.legs[0].line.contains("faster"))
        XCTAssertTrue(debrief.legs[1].line.contains("inside"))
        XCTAssertTrue(debrief.legs[2].line.contains("slower"))
        XCTAssertTrue(debrief.summaryLine.contains("1:52:30"))
    }

    func testDebriefUsesRangeBoundsNotMidpoint() {
        let target = PacingTarget(leg: RaceLeg(sport: .run, distanceKm: 10), target: .none, expectedDurationSeconds: ValueRange(3000, 3300), summary: "")
        let pacingCard = PacingCard(distance: .olympic, targets: [target], caveat: "")
        for (actual, expected) in [(2999.0, LegDeviation.faster), (3000, .within), (3300, .within), (3301, .slower)] {
            let result = window.debrief(card: pacingCard, actuals: RaceActuals(runSeconds: actual))
            XCTAssertEqual(result.legs[0].deviation, expected, "actual \(actual)")
        }
    }

    func testDebriefHandlesMissingAndInvalidTimes() {
        let planned = card(bikeSeconds: 3600)
        let partial = window.debrief(card: planned, actuals: RaceActuals(swimSeconds: .nan, bikeSeconds: 3500, runSeconds: -1))
        XCTAssertEqual(partial.legs.map(\.deviation), [.notRecorded, .faster, .notRecorded])
        XCTAssertNil(partial.actualLegsTotalSeconds)
        XCTAssertEqual(partial.totalRecordedSeconds, 3500, accuracy: 0.001)
        XCTAssertTrue(partial.summaryLine.contains("partial"))
        XCTAssertEqual(partial.transitions.map(\.seconds), [nil, nil])

        let empty = window.debrief(card: planned, actuals: RaceActuals())
        XCTAssertEqual(empty.totalRecordedSeconds, 0)
        XCTAssertTrue(empty.summaryLine.contains("No times"))
        let noCard = window.debrief(card: PacingCard(distance: .sprint, targets: [], caveat: ""), actuals: RaceActuals(swimSeconds: 100))
        XCTAssertNil(noCard.actualLegsTotalSeconds)
    }

    // MARK: Copy rules

    func testAllCopyAvoidsForbiddenWordsDashesAndSodium() {
        var texts: [String] = [RaceWindowCopy.shortCourseCaveat, RaceWindowCopy.longCourseCaveat, RaceWindowCopy.fullDistanceCaveat, RaceWindowCopy.stomachLine]
        texts += RaceWindowCopy.debriefPrompts
        for distance in RaceDistance.allCases {
            let race = RaceDetails(distance: distance, raceDate: raceDate(), startMinutesAfterMidnight: 420, isTravelRace: true, hasBikeRecord: true)
            texts += window.entries(for: race, calendar: calendar).map(\.text)
            for b in [Benchmarks(), benchmarks(css: 100, ftp: 250, threshold: 300), benchmarks(lthr: 165, estimated: true)] {
                let pacing = window.pacing(for: distance, athlete: athlete, benchmarks: b)
                texts.append(pacing.caveat)
                texts += pacing.targets.map(\.summary)
                for item in window.fueling(for: pacing) { texts += [item.practiceLine, item.stomachLine] }
                let debrief = window.debrief(card: pacing, actuals: RaceActuals(swimSeconds: 1, bikeSeconds: 99999, runSeconds: 2000))
                texts += debrief.legs.map(\.line) + debrief.transitions.map(\.line) + [debrief.summaryLine]
            }
        }
        let forbidden = ["diagnose", "treat", "doctor", "injury", "illness", "clinical", "medical", "sodium", "salt", "prevent", "AI coach"]
        let marks = ["T" + "SS", "I" + "F", "N" + "P", "T" + "P", "T" + "PU"]
        for text in texts {
            XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "dash in: \(text)")
            let lower = text.lowercased()
            for word in forbidden { XCTAssertFalse(lower.contains(word), "'\(word)' in: \(text)") }
            let tokens = text.split { !$0.isLetter }.map(String.init)
            for mark in marks { XCTAssertFalse(tokens.contains(mark), "'\(mark)' in: \(text)") }
        }
        XCTAssertGreaterThan(texts.count, 50)
    }
}
