import XCTest
@testable import BricklinePlanKit

/// Hand computed checks for annex A: zone tables, test math, target resolution, seeding and retest rotation.
final class ZonesTests: XCTestCase {
    private let zones = DefaultZoneCalculator()
    private let accuracy = 1e-6

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }

    private var start: Date { date(2026, 11, 9) }

    private func assertRange(
        _ range: ValueRange, _ lower: Double, _ upper: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(range.lower, lower, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(range.upper, upper, accuracy: accuracy, file: file, line: line)
    }

    /// A 1 Hz series made of (seconds, value) blocks laid end to end.
    private func series(_ blocks: [(seconds: Int, value: Double)], step: Int = 1) -> [SeriesSample] {
        var samples: [SeriesSample] = []
        var offset = 0
        for block in blocks {
            var t = 0
            while t < block.seconds {
                samples.append(SeriesSample(offsetSeconds: Double(offset + t), value: block.value))
                t += step
            }
            offset += block.seconds
        }
        return samples
    }

    // MARK: Swim zones

    func testSwimOffsets() {
        assertRange(zones.swimOffsetRange(.easy), 8, 15)
        assertRange(zones.swimOffsetRange(.steady), 4, 7)
        assertRange(zones.swimOffsetRange(.threshold), -3, 3)
        assertRange(zones.swimOffsetRange(.vo2), -8, -4)
    }

    func testSwimPaceRangesForCSS100() {
        assertRange(zones.swimPaceRange(.easy, css: 100), 108, 115)
        assertRange(zones.swimPaceRange(.steady, css: 100), 104, 107)
        assertRange(zones.swimPaceRange(.threshold, css: 100), 97, 103)
        assertRange(zones.swimPaceRange(.vo2, css: 100), 92, 96)
    }

    func testSwimPaceRangeWithBadCSSDoesNotTrap() {
        assertRange(zones.swimPaceRange(.easy, css: .nan), 8, 15)
        assertRange(zones.swimPaceRange(.vo2, css: -50), 0, 0)
    }

    // MARK: CSS test

    func testCSSFromTestHandComputed() throws {
        // (380 - 180) / 2 = 100 s per 100 m. 400 m pace is 95, 200 m pace is 90.
        let value = try zones.cssFromTest(time400Seconds: 380, time200Seconds: 180, on: start)
        XCTAssertEqual(value.value, 100, accuracy: accuracy)
        XCTAssertFalse(value.isEstimated)
        XCTAssertEqual(value.date, start)
    }

    func testCSSRejectsWhenTwoHundredNotFaster() {
        // 360 over 400 m is 90 per 100 m; 180 over 200 m is also 90. Equal is not faster.
        XCTAssertThrowsError(try zones.cssFromTest(time400Seconds: 360, time200Seconds: 180, on: start)) {
            XCTAssertEqual($0 as? PlanKitError, .cssTestRejected)
        }
        // 200 m slower than the 400 m pace.
        XCTAssertThrowsError(try zones.cssFromTest(time400Seconds: 340, time200Seconds: 180, on: start)) {
            XCTAssertEqual($0 as? PlanKitError, .cssTestRejected)
        }
        // 400 m time shorter than the 200 m time.
        XCTAssertThrowsError(try zones.cssFromTest(time400Seconds: 150, time200Seconds: 180, on: start)) {
            XCTAssertEqual($0 as? PlanKitError, .cssTestRejected)
        }
    }

    func testCSSJustFasterIsAccepted() throws {
        // 361 over 400 m is 90.25 per 100 m, 180 over 200 m is 90: faster, so accepted. (361 - 180) / 2 = 90.5.
        let value = try zones.cssFromTest(time400Seconds: 361, time200Seconds: 180, on: start)
        XCTAssertEqual(value.value, 90.5, accuracy: accuracy)
    }

    func testCSSInvalidTimesThrowInvalidInput() {
        for pair in [(0.0, 100.0), (400.0, 0.0), (-1.0, 100.0), (Double.nan, 100.0), (400.0, Double.infinity)] {
            XCTAssertThrowsError(try zones.cssFromTest(time400Seconds: pair.0, time200Seconds: pair.1, on: start)) {
                guard case .invalidInput = $0 as? PlanKitError else {
                    return XCTFail("expected invalidInput, got \($0)")
                }
            }
        }
    }

    func testCSSRetestDecisionIsAValueNotACrash() {
        XCTAssertEqual(
            zones.evaluateCSSTest(time400Seconds: 360, time200Seconds: 180, on: start),
            .retest(.twoHundredNotFaster))
        XCTAssertEqual(
            zones.evaluateCSSTest(time400Seconds: 0, time200Seconds: 180, on: start),
            .retest(.invalidTimes))
        guard case let .accepted(value) = zones.evaluateCSSTest(time400Seconds: 380, time200Seconds: 180, on: start) else {
            return XCTFail("expected accepted")
        }
        XCTAssertEqual(value.value, 100, accuracy: accuracy)
    }

    func testRetestMessagesAreCalmAndDashFree() {
        for reason in [CSSRetestReason.twoHundredNotFaster, .invalidTimes] {
            XCTAssertFalse(reason.message.isEmpty)
            XCTAssertFalse(reason.message.contains("\u{2014}"))
            XCTAssertFalse(reason.message.contains("\u{2013}"))
        }
    }

    // MARK: Bike power

    func testFTPFromTestIsNinetyFivePercent() throws {
        let value = try zones.ftpFromTest(best20MinutePower: 250, on: start)
        XCTAssertEqual(value.value, 237.5, accuracy: accuracy)
        XCTAssertFalse(value.isEstimated)
        XCTAssertThrowsError(try zones.ftpFromTest(best20MinutePower: 0, on: start))
        XCTAssertThrowsError(try zones.ftpFromTest(best20MinutePower: .nan, on: start))
    }

    func testBikePowerZonesForFTP200() {
        assertRange(zones.bikePowerRange(.z1, ftp: 200), 0, 110)
        assertRange(zones.bikePowerRange(.z2, ftp: 200), 112, 150)
        assertRange(zones.bikePowerRange(.z3, ftp: 200), 152, 180)
        assertRange(zones.bikePowerRange(.z4, ftp: 200), 182, 210)
        assertRange(zones.bikePowerRange(.z5, ftp: 200), 212, 240)
        assertRange(zones.bikePowerRange(.z6, ftp: 200), 242, 300)
        assertRange(zones.bikePowerRange(.z7, ftp: 200), 302, 600)
    }

    func testBikeZoneClassifierLeavesNoGap() {
        let ftp = 200.0
        XCTAssertEqual(zones.bikePowerZone(forWatts: 0, ftp: ftp), .z1)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 110, ftp: ftp), .z1)
        // 55.5 percent sits between the printed bands 55 and 56 and still belongs to a zone.
        XCTAssertEqual(zones.bikePowerZone(forWatts: 111, ftp: ftp), .z2)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 150, ftp: ftp), .z2)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 151, ftp: ftp), .z3)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 200, ftp: ftp), .z4)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 230, ftp: ftp), .z5)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 270, ftp: ftp), .z6)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 301, ftp: ftp), .z7)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 900, ftp: ftp), .z7)
        XCTAssertEqual(zones.bikePowerZone(forWatts: 200, ftp: 0), .z1)
    }

    func testBikeZoneZ7IsCappedAndFinite() {
        let z7 = zones.bikePowerRange(.z7, ftp: 250)
        XCTAssertEqual(z7.upper, 750, accuracy: accuracy)
        XCTAssertTrue(z7.upper.isFinite)
    }

    // MARK: Heart rate

    func testHeartRateBandsForLTHR160() {
        assertRange(zones.heartRateRange(.z1, lthr: 160), 0, 129.6)
        assertRange(zones.heartRateRange(.z2, lthr: 160), 129.6, 142.4)
        assertRange(zones.heartRateRange(.z3, lthr: 160), 142.4, 150.4)
        assertRange(zones.heartRateRange(.z4, lthr: 160), 150.4, 163.2)
        assertRange(zones.heartRateRange(.z5, lthr: 160), 163.2, 192)
    }

    func testHeartRateBandsTouchSoNoRateIsOutside() {
        let bands = HeartRateZone.allCases.map { zones.heartRateRange($0, lthr: 171) }
        for index in 1..<bands.count {
            XCTAssertEqual(bands[index].lower, bands[index - 1].upper, accuracy: accuracy)
        }
    }

    func testHeartRateZoneClassifier() {
        XCTAssertEqual(zones.heartRateZone(forBpm: 100, lthr: 160), .z1)
        XCTAssertEqual(zones.heartRateZone(forBpm: 129.6, lthr: 160), .z1)
        XCTAssertEqual(zones.heartRateZone(forBpm: 135, lthr: 160), .z2)
        XCTAssertEqual(zones.heartRateZone(forBpm: 146, lthr: 160), .z3)
        XCTAssertEqual(zones.heartRateZone(forBpm: 160, lthr: 160), .z4)
        XCTAssertEqual(zones.heartRateZone(forBpm: 170, lthr: 160), .z5)
        XCTAssertEqual(zones.heartRateZone(forBpm: 170, lthr: 0), .z1)
    }

    func testBikeLTHRFromTest() throws {
        let value = try zones.bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: 165, on: start)
        XCTAssertEqual(value.value, 165, accuracy: accuracy)
        XCTAssertFalse(value.isEstimated)
        XCTAssertThrowsError(try zones.bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: 0, on: start))
        XCTAssertThrowsError(try zones.bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: 400, on: start))
        XCTAssertThrowsError(try zones.bikeLTHRFromTest(finalTwentyMinuteAverageHeartRate: .nan, on: start))
    }

    // MARK: Run

    func testRunPaceBandsForThreshold300() {
        assertRange(zones.runPaceRange(.easy, thresholdPace: 300), 345, 390)
        assertRange(zones.runPaceRange(.steady, thresholdPace: 300), 320, 345)
        // 3 percent of 300 is 9, below the 10 second floor, so the floor applies.
        assertRange(zones.runPaceRange(.threshold, thresholdPace: 300), 290, 310)
        assertRange(zones.runPaceRange(.vo2, thresholdPace: 300), 275, 285)
    }

    func testRunThresholdBandUsesPercentAboveFloor() {
        // 3 percent of 400 is 12, above the floor.
        assertRange(zones.runPaceRange(.threshold, thresholdPace: 400), 388, 412)
        // 3 percent of 330 is 9.9, still under 10.
        assertRange(zones.runPaceRange(.threshold, thresholdPace: 330), 320, 340)
    }

    func testRunThresholdFromThirtyMinuteTest() throws {
        // 1800 s over 7.5 km is 240 s per km; over 6 km it is 300 s per km.
        let fast = try zones.runThresholdFromTest(distanceKilometres: 7.5, finalTwentyMinuteAverageHeartRate: 172, on: start)
        XCTAssertEqual(fast.thresholdPaceSecondsPerKm?.value ?? 0, 240, accuracy: accuracy)
        XCTAssertEqual(fast.runLthrBpm?.value ?? 0, 172, accuracy: accuracy)
        XCTAssertEqual(fast.thresholdPaceSecondsPerKm?.isEstimated, false)
        XCTAssertNil(fast.cssSecondsPer100m)
        XCTAssertNil(fast.ftpWatts)
        XCTAssertNil(fast.lthrBpm)

        let slow = try zones.runThresholdFromTest(distanceKilometres: 6, finalTwentyMinuteAverageHeartRate: nil, on: start)
        XCTAssertEqual(slow.thresholdPaceSecondsPerKm?.value ?? 0, 300, accuracy: accuracy)
        XCTAssertNil(slow.runLthrBpm)
    }

    func testRunThresholdRejectsBadInput() {
        for km in [0.0, -3.0, .nan, .infinity, 40.0] {
            XCTAssertThrowsError(try zones.runThresholdFromTest(distanceKilometres: km, finalTwentyMinuteAverageHeartRate: nil, on: start))
        }
        XCTAssertThrowsError(try zones.runThresholdFromTest(distanceKilometres: 6, finalTwentyMinuteAverageHeartRate: 5, on: start))
    }

    // MARK: Speed conversion

    func testPaceToSpeedConversions() {
        XCTAssertEqual(PaceConversion.speedMetersPerSecond(fromPacePerKm: 300) ?? 0, 1000.0 / 300, accuracy: accuracy)
        XCTAssertEqual(PaceConversion.speedMetersPerSecond(fromPacePer100m: 100) ?? 0, 1, accuracy: accuracy)
        XCTAssertEqual(PaceConversion.pacePerKm(fromSpeed: 4) ?? 0, 250, accuracy: accuracy)
        XCTAssertEqual(PaceConversion.pacePer100m(fromSpeed: 1.25) ?? 0, 80, accuracy: accuracy)
        XCTAssertNil(PaceConversion.speedMetersPerSecond(fromPacePerKm: 0))
        XCTAssertNil(PaceConversion.speedMetersPerSecond(fromPacePerKm: -5))
        XCTAssertNil(PaceConversion.speedMetersPerSecond(fromPacePerKm: .nan))
        XCTAssertNil(PaceConversion.pacePerKm(fromSpeed: 0))
    }

    func testPaceRangeInvertsToSpeedRange() throws {
        let speeds = try XCTUnwrap(PaceConversion.speedRange(fromPaceRangePerKm: ValueRange(290, 310)))
        // The slower pace is the lower speed.
        XCTAssertEqual(speeds.lower, 1000.0 / 310, accuracy: accuracy)
        XCTAssertEqual(speeds.upper, 1000.0 / 290, accuracy: accuracy)
        XCTAssertNil(PaceConversion.speedRange(fromPaceRangePerKm: ValueRange(0, 300)))
        let swim = try XCTUnwrap(PaceConversion.speedRange(fromPaceRangePer100m: ValueRange(97, 103)))
        XCTAssertEqual(swim.lower, 100.0 / 103, accuracy: accuracy)
        XCTAssertEqual(swim.upper, 100.0 / 97, accuracy: accuracy)
    }

    func testThresholdSpeedMatchesDistanceOverThirtyMinutes() {
        // 6 km in 1800 s is 3.3333 m/s, the reciprocal of 300 s per km.
        XCTAssertEqual(PaceConversion.thresholdSpeedMetersPerSecond(testDistanceKilometres: 6) ?? 0, 6000.0 / 1800, accuracy: accuracy)
        XCTAssertEqual(PaceConversion.thresholdPacePerKm(testDistanceKilometres: 6) ?? 0, 300, accuracy: accuracy)
        XCTAssertNil(PaceConversion.thresholdSpeedMetersPerSecond(testDistanceKilometres: 0))
    }

    // MARK: Target resolution

    private func athlete(power: Bool = false) -> AthleteProfile {
        AthleteProfile(
            level: .intermediate, weeklyHours: 8,
            availableWeekdays: [.monday, .wednesday, .saturday], poolWeekdays: [.monday],
            hasWatch: true, hasPowerMeter: power)
    }

    private func value(_ v: Double, estimated: Bool = false) -> BenchmarkValue {
        BenchmarkValue(value: v, isEstimated: estimated, date: start)
    }

    private func step(_ sport: Sport, level: Int, target: StepTarget = .rpe(ValueRange(6, 7))) -> Step {
        Step(sport: sport, kind: .work, durationSeconds: 600, level: level, target: target, name: "work")
    }

    func testBikeResolvesToPowerWithMeter() {
        let b = Benchmarks(ftpWatts: value(250), lthrBpm: value(170))
        let target = zones.resolveTarget(for: step(.bike, level: 4), athlete: athlete(power: true), benchmarks: b, nudgeSteps: 0)
        guard case let .powerRange(r) = target else { return XCTFail("expected power, got \(target)") }
        assertRange(r, 227.5, 262.5)
    }

    func testBikeFallsBackToHeartRateWithoutMeter() {
        let b = Benchmarks(ftpWatts: value(250), lthrBpm: value(170))
        let target = zones.resolveTarget(for: step(.bike, level: 3), athlete: athlete(power: false), benchmarks: b, nudgeSteps: 0)
        guard case let .heartRateRange(r) = target else { return XCTFail("expected heart rate, got \(target)") }
        assertRange(r, 151.3, 159.8)
    }

    func testBikeWithNothingFallsBackToRPE() {
        let target = zones.resolveTarget(for: step(.bike, level: 2, target: .none), athlete: athlete(power: true), benchmarks: Benchmarks(), nudgeSteps: 0)
        XCTAssertEqual(target, .rpe(ValueRange(3, 4)))
        let kept = zones.resolveTarget(for: step(.bike, level: 2), athlete: athlete(), benchmarks: Benchmarks(), nudgeSteps: 0)
        XCTAssertEqual(kept, .rpe(ValueRange(6, 7)))
    }

    func testBikePowerNudgeMovesTwoPercentPerStep() {
        let b = Benchmarks(ftpWatts: value(250))
        let up = zones.resolveTarget(for: step(.bike, level: 4), athlete: athlete(power: true), benchmarks: b, nudgeSteps: 1)
        guard case let .powerRange(r) = up else { return XCTFail("expected power") }
        // FTP 255: 91 to 105 percent is 232.05 to 267.75.
        assertRange(r, 232.05, 267.75)
        let down = zones.resolveTarget(for: step(.bike, level: 4), athlete: athlete(power: true), benchmarks: b, nudgeSteps: -1)
        guard case let .powerRange(d) = down else { return XCTFail("expected power") }
        // FTP 245: 222.95 to 257.25.
        assertRange(d, 222.95, 257.25)
    }

    func testRunResolvesToPaceAndNudgesFaster() {
        let b = Benchmarks(thresholdPaceSecondsPerKm: value(300))
        let plain = zones.resolveTarget(for: step(.run, level: 4), athlete: athlete(), benchmarks: b, nudgeSteps: 0)
        guard case let .pacePerKm(r) = plain else { return XCTFail("expected pace") }
        assertRange(r, 290, 310)
        // Two steps harder: threshold 300 times 0.96 is 288, band 278 to 298.
        let nudged = zones.resolveTarget(for: step(.run, level: 4), athlete: athlete(), benchmarks: b, nudgeSteps: 2)
        guard case let .pacePerKm(n) = nudged else { return XCTFail("expected pace") }
        assertRange(n, 278, 298)
    }

    func testRunEasyAndVO2Levels() {
        let b = Benchmarks(thresholdPaceSecondsPerKm: value(300))
        guard case let .pacePerKm(easy) = zones.resolveTarget(for: step(.run, level: 1), athlete: athlete(), benchmarks: b, nudgeSteps: 0),
              case let .pacePerKm(vo2) = zones.resolveTarget(for: step(.run, level: 5), athlete: athlete(), benchmarks: b, nudgeSteps: 0),
              case let .pacePerKm(steady) = zones.resolveTarget(for: step(.run, level: 3), athlete: athlete(), benchmarks: b, nudgeSteps: 0)
        else { return XCTFail("expected paces") }
        assertRange(easy, 345, 390)
        assertRange(steady, 320, 345)
        assertRange(vo2, 275, 285)
    }

    func testRunUsesRunHeartRateWhenNoPace() {
        let b = Benchmarks(lthrBpm: value(160), runLthrBpm: value(172))
        let target = zones.resolveTarget(for: step(.run, level: 4), athlete: athlete(), benchmarks: b, nudgeSteps: 0)
        guard case let .heartRateRange(r) = target else { return XCTFail("expected heart rate") }
        // 172 times 94 percent is 161.68, 172 times 102 percent is 175.44.
        assertRange(r, 161.68, 175.44)
        // Bike LTHR alone is not used for a run.
        let bikeOnly = zones.resolveTarget(for: step(.run, level: 4, target: .none), athlete: athlete(), benchmarks: Benchmarks(lthrBpm: value(160)), nudgeSteps: 0)
        XCTAssertEqual(bikeOnly, .rpe(ValueRange(7, 8)))
    }

    func testSwimResolvesToPaceFromLevelAndFromOffset() {
        let b = Benchmarks(cssSecondsPer100m: value(100))
        guard case let .pacePer100m(byLevel) = zones.resolveTarget(for: step(.swim, level: 3), athlete: athlete(), benchmarks: b, nudgeSteps: 0) else {
            return XCTFail("expected a swim pace")
        }
        // Steady is 104 to 107 per 100 m.
        assertRange(byLevel, 104, 107)

        guard case let .pacePer100m(byOffset) = zones.resolveTarget(for: step(.swim, level: 3, target: .cssOffset(ValueRange(2, 4))), athlete: athlete(), benchmarks: b, nudgeSteps: 0) else {
            return XCTFail("expected a swim pace")
        }
        assertRange(byOffset, 102, 104)

        // One step harder: CSS 100 times 0.98 is 98, so steady is 102 to 105.
        guard case let .pacePer100m(nudged) = zones.resolveTarget(for: step(.swim, level: 3), athlete: athlete(), benchmarks: b, nudgeSteps: 1) else {
            return XCTFail("expected a swim pace")
        }
        assertRange(nudged, 102, 105)
    }

    func testSwimWithoutCSSFallsBackToRPE() {
        let target = zones.resolveTarget(for: step(.swim, level: 4, target: .cssOffset(ValueRange(-3, 3))), athlete: athlete(), benchmarks: Benchmarks(), nudgeSteps: 0)
        XCTAssertEqual(target, .rpe(ValueRange(7, 8)))
    }

    func testEstimatedBenchmarksResolveNormally() {
        let b = Benchmarks(thresholdPaceSecondsPerKm: value(300, estimated: true))
        let target = zones.resolveTarget(for: step(.run, level: 4), athlete: athlete(), benchmarks: b, nudgeSteps: 0)
        guard case .pacePerKm = target else { return XCTFail("expected pace") }
    }

    func testConcreteTargetsPassThroughAndBadBenchmarksAreIgnored() {
        let fixed = StepTarget.powerRange(ValueRange(200, 220))
        XCTAssertEqual(
            zones.resolveTarget(for: step(.bike, level: 3, target: fixed), athlete: athlete(power: true), benchmarks: Benchmarks(ftpWatts: value(250)), nudgeSteps: 3),
            fixed)
        let bad = Benchmarks(ftpWatts: value(0), thresholdPaceSecondsPerKm: value(.nan))
        XCTAssertEqual(zones.resolveTarget(for: step(.bike, level: 5, target: .none), athlete: athlete(power: true), benchmarks: bad, nudgeSteps: 0), .rpe(ValueRange(9, 10)))
        XCTAssertEqual(zones.resolveTarget(for: step(.run, level: 1, target: .none), athlete: athlete(), benchmarks: bad, nudgeSteps: 0), .rpe(ValueRange(1, 2)))
    }

    func testHugeNudgeIsClamped() {
        let b = Benchmarks(thresholdPaceSecondsPerKm: value(300))
        guard case let .pacePerKm(r) = zones.resolveTarget(for: step(.run, level: 4), athlete: athlete(), benchmarks: b, nudgeSteps: 10_000) else {
            return XCTFail("expected pace")
        }
        // Clamped to 10 steps: 300 times 0.8 is 240, band 230 to 250.
        assertRange(r, 230, 250)
    }

    func testEveryLevelSportCombinationResolvesWithoutTrapping() {
        let b = Benchmarks(cssSecondsPer100m: value(100), ftpWatts: value(250), lthrBpm: value(170), thresholdPaceSecondsPerKm: value(300), runLthrBpm: value(175))
        for sport in Sport.allCases {
            for level in -2...8 {
                for power in [true, false] {
                    for nudge in [-12, -1, 0, 1, 12] {
                        let t = zones.resolveTarget(for: step(sport, level: level), athlete: athlete(power: power), benchmarks: b, nudgeSteps: nudge)
                        XCTAssertNotEqual(t, .none)
                    }
                }
            }
        }
    }

    // MARK: Seeding

    func testSeedFTPFromConstantPower() throws {
        let power = series([(1200, 200)])
        let ftp = try XCTUnwrap(zones.seedFTP(fromPower: power, on: start))
        XCTAssertEqual(ftp.value, 190, accuracy: accuracy)
        XCTAssertTrue(ftp.isEstimated)
        XCTAssertEqual(ftp.date, start)
    }

    func testSeedFTPFindsBestTwentyMinutes() throws {
        // 600 s at 100 W, 1200 s at 300 W, 600 s at 100 W. The best 20 minutes average 300 W.
        let power = series([(600, 100), (1200, 300), (600, 100)])
        let ftp = try XCTUnwrap(zones.seedFTP(fromPower: power, on: start))
        XCTAssertEqual(ftp.value, 285, accuracy: accuracy)
    }

    func testSeedFTPWindowNotAlignedToBlocks() throws {
        // 400 s at 100, 1000 s at 300, 400 s at 200, 400 s at 100. Best 1200 s starts at 400:
        // 1000 s at 300 plus 200 s at 200 gives (300000 + 40000) / 1200 = 283.333.
        let power = series([(400, 100), (1000, 300), (400, 200), (400, 100)])
        let ftp = try XCTUnwrap(zones.seedFTP(fromPower: power, on: start))
        XCTAssertEqual(ftp.value, 283.3333333 * 0.95, accuracy: 1e-4)
    }

    func testSeedFTPIgnoresSampleOrderAndSparseSampling() throws {
        let ordered = series([(600, 100), (1200, 300), (600, 100)], step: 5)
        let shuffled = ordered.reversed().map { $0 }
        let a = zones.seedFTP(fromPower: ordered, on: start)
        let b = zones.seedFTP(fromPower: shuffled, on: start)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a?.value ?? 0, 285, accuracy: accuracy)
    }

    func testSeedFTPNilWhenTooShortOrEmptyOrZero() {
        XCTAssertNil(zones.seedFTP(fromPower: series([(1100, 250)]), on: start))
        XCTAssertNil(zones.seedFTP(fromPower: [], on: start))
        XCTAssertNil(zones.seedFTP(fromPower: [SeriesSample(offsetSeconds: 0, value: 200)], on: start))
        XCTAssertNil(zones.seedFTP(fromPower: series([(1500, 0)]), on: start))
        XCTAssertNil(zones.seedFTP(fromPower: [SeriesSample(offsetSeconds: .nan, value: 200), SeriesSample(offsetSeconds: 1, value: .infinity)], on: start))
    }

    func testSeriesGapBreaksTheEffort() {
        // Two 900 s stretches separated by 120 s of nothing are not one 20 minute effort.
        let first = series([(900, 300)])
        let second = series([(900, 300)]).map { SeriesSample(offsetSeconds: $0.offsetSeconds + 1020, value: $0.value) }
        XCTAssertNil(zones.seedFTP(fromPower: first + second, on: start))
        // A 30 second dropout is bridged.
        let shortGap = series([(900, 300)]) + series([(900, 300)]).map { SeriesSample(offsetSeconds: $0.offsetSeconds + 930, value: $0.value) }
        XCTAssertNotNil(zones.seedFTP(fromPower: shortGap, on: start))
    }

    func testSeedBikeLTHRUsesFinalTwentyOfBestThirty() throws {
        // 600 s at 140, 600 s at 160, 1200 s at 170. Best 30 minutes starts at 600; its final 20 minutes average 170.
        let hr = series([(600, 140), (600, 160), (1200, 170)])
        let lthr = try XCTUnwrap(zones.seedBikeLTHR(fromHeartRate: hr, on: start))
        XCTAssertEqual(lthr.value, 170, accuracy: accuracy)
        XCTAssertTrue(lthr.isEstimated)
    }

    func testSeedBikeLTHRWithOnlyTwentyFiveMinutes() throws {
        // 1500 s at 150: the longest window the data allows is 1500 s, and its final 20 minutes average 150.
        let lthr = try XCTUnwrap(zones.seedBikeLTHR(fromHeartRate: series([(1500, 150)]), on: start))
        XCTAssertEqual(lthr.value, 150, accuracy: accuracy)
        XCTAssertNil(zones.seedBikeLTHR(fromHeartRate: series([(1100, 150)]), on: start))
        XCTAssertNil(zones.seedBikeLTHR(fromHeartRate: [], on: start))
    }

    func testSeedBikeLTHRIgnoresZeroDropouts() throws {
        let hr = series([(1000, 150), (5, 0), (1000, 150)])
        let lthr = try XCTUnwrap(zones.seedBikeLTHR(fromHeartRate: hr, on: start))
        XCTAssertEqual(lthr.value, 150, accuracy: accuracy)
    }

    func testSeedRunFromSpeedAndHeartRate() throws {
        // 600 s at 2.0 m/s, then 1800 s at 3.5 m/s. HR 140 for 1200 s then 172 for 1200 s.
        let speed = series([(600, 2.0), (1800, 3.5)])
        let hr = series([(1200, 140), (1200, 172)])
        let seeded = zones.seedRunBenchmarks(speed: speed, heartRate: hr, on: start)
        let pace = try XCTUnwrap(seeded.thresholdPaceSecondsPerKm)
        XCTAssertEqual(pace.value, 1000 / 3.5, accuracy: accuracy)
        XCTAssertTrue(pace.isEstimated)
        let lthr = try XCTUnwrap(seeded.runLthrBpm)
        // The best speed window is 600 to 2400; its final 20 minutes (1200 to 2400) average 172.
        XCTAssertEqual(lthr.value, 172, accuracy: accuracy)
        XCTAssertTrue(lthr.isEstimated)
        XCTAssertNil(seeded.cssSecondsPer100m)
        XCTAssertNil(seeded.ftpWatts)
        XCTAssertNil(seeded.lthrBpm)
    }

    func testSeedRunPaceMatchesThirtyMinuteTestFormula() throws {
        // 6 km in exactly 1800 s is 3.3333 m/s, so the seeded pace equals the test pace of 300 s per km.
        let speed = series([(1800, 6000.0 / 1800)])
        let seeded = zones.seedRunBenchmarks(speed: speed, heartRate: [], on: start)
        XCTAssertEqual(seeded.thresholdPaceSecondsPerKm?.value ?? 0, 300, accuracy: accuracy)
        XCTAssertNil(seeded.runLthrBpm)
    }

    func testSeedRunWithHeartRateOnlyAndWithNothing() {
        let seeded = zones.seedRunBenchmarks(speed: [], heartRate: series([(1500, 165)]), on: start)
        XCTAssertNil(seeded.thresholdPaceSecondsPerKm)
        XCTAssertEqual(seeded.runLthrBpm?.value ?? 0, 165, accuracy: accuracy)
        let empty = zones.seedRunBenchmarks(speed: series([(600, 3)]), heartRate: series([(600, 150)]), on: start)
        XCTAssertEqual(empty, Benchmarks())
    }

    func testSeedRunRejectsWalkingSpeed() {
        let seeded = zones.seedRunBenchmarks(speed: series([(1800, 0.2)]), heartRate: [], on: start)
        XCTAssertNil(seeded.thresholdPaceSecondsPerKm)
    }

    func testBikeSeedPrefersPowerThenHeartRate() {
        let power = series([(1300, 200)])
        let hr = series([(1800, 150)])
        let withPower = zones.seedBike(power: power, heartRate: hr, on: start)
        XCTAssertEqual(withPower.source, .power)
        XCTAssertEqual(withPower.benchmarks.ftpWatts?.value ?? 0, 190, accuracy: accuracy)
        XCTAssertNil(withPower.benchmarks.lthrBpm)
        XCTAssertFalse(withPower.suggestsTest)

        let hrOnly = zones.seedBike(power: [], heartRate: hr, on: start)
        XCTAssertEqual(hrOnly.source, .heartRate)
        XCTAssertNil(hrOnly.benchmarks.ftpWatts)
        XCTAssertEqual(hrOnly.benchmarks.lthrBpm?.value ?? 0, 150, accuracy: accuracy)
        XCTAssertTrue(hrOnly.suggestsTest)

        // Power samples that are too short fall back to heart rate.
        XCTAssertEqual(zones.seedBike(power: series([(300, 200)]), heartRate: hr, on: start).source, .heartRate)

        let none = zones.seedBike(power: [], heartRate: [], on: start)
        XCTAssertEqual(none.source, .none)
        XCTAssertEqual(none.benchmarks, Benchmarks())
    }

    func testSwimIsNeverSeeded() {
        XCTAssertFalse(DefaultZoneCalculator.supportsSeeding(for: .swim))
        XCTAssertTrue(DefaultZoneCalculator.supportsSeeding(for: .bike))
        XCTAssertTrue(DefaultZoneCalculator.supportsSeeding(for: .run))
        let seeded = zones.seedRunBenchmarks(speed: series([(1800, 3.5)]), heartRate: series([(1800, 160)]), on: start)
        XCTAssertNil(seeded.cssSecondsPer100m)
    }

    func testSeededValuesCountAsUntestedForRetestAndNudges() {
        let seeded = zones.seedRunBenchmarks(speed: series([(1800, 3.5)]), heartRate: series([(1800, 160)]), on: start)
        XCTAssertNil(seeded.lastTestDate(for: .run))
        XCTAssertTrue(seeded.isOnlyEstimated(for: .run))
    }

    func testSeedingIsDeterministic() throws {
        // Compared with a hand computed value, not with a second call, so a change between launches would show.
        let power = series([(600, 100), (1200, 300), (600, 100)], step: 3)
        let seeded = try XCTUnwrap(zones.seedFTP(fromPower: power, on: start))
        XCTAssertEqual(seeded.value, 300 * 0.95, accuracy: 0.0001)
        XCTAssertTrue(seeded.isEstimated)
    }

    func testLargeSeriesIsFast() throws {
        let long = series([(3 * 3600, 210)])
        let began = Date()
        let seeded = try XCTUnwrap(zones.seedFTP(fromPower: long, on: start))
        XCTAssertEqual(seeded.value, 210 * 0.95, accuracy: 0.001)
        XCTAssertLessThan(Date().timeIntervalSince(began), 2.0, "a three hour series must seed in well under two seconds")
    }
}
