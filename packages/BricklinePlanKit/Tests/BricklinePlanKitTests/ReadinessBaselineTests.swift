import XCTest
@testable import BricklinePlanKit

/// Annex C rule 9 and the baseline method: log transform, 35 nights before the latest 7, validity, per source
/// separation, calibration and source choice.
final class ReadinessBaselineTests: XCTestCase {
    private typealias F = ReadinessFixtures
    private let today = ReadinessFixtures.thursday
    private var calendar: Calendar { F.calendar }

    private func baseline(_ source: ReadinessSource = .oura, _ nights: [ReadinessNight]) -> SourceBaseline {
        BaselineCalculator.baseline(for: source, nights: nights, today: today, calendar: calendar)
    }

    private func night(_ age: Int, _ source: ReadinessSource = .oura, hrv: Double? = 60) -> ReadinessNight {
        ReadinessNight(date: F.day(-age), source: source, hrvMilliseconds: hrv)
    }

    // MARK: Hand computed math

    func testLogMeanAndSDOfExponentialsIsExact() throws {
        // ln values 3, 4, 5: mean 4, sample SD = sqrt((1 + 0 + 1) / 2) = 1.
        let stats = try XCTUnwrap(BaselineCalculator.logMeanAndSD(of: [exp(3.0), exp(4.0), exp(5.0)]))
        XCTAssertEqual(stats.mean, 4.0, accuracy: 1e-12)
        XCTAssertEqual(stats.standardDeviation, 1.0, accuracy: 1e-12)
    }

    func testLogMeanAndSDMatchesSecondHandComputedCase() throws {
        // 40, 50, 60, 80 ms. ln: 3.688879, 3.912023, 4.094345, 4.382027. Mean 4.019318.
        // Squared deviations: 0.109190, 0.011512, 0.005629, 0.131557 -> sum 0.257888, over 3 -> 0.085963, root 0.293194.
        let stats = try XCTUnwrap(BaselineCalculator.logMeanAndSD(of: [40, 50, 60, 80]))
        XCTAssertEqual(stats.mean, 4.019318, accuracy: 1e-5)
        XCTAssertEqual(stats.standardDeviation, 0.293194, accuracy: 1e-5)
    }

    func testStandardFixtureBaseline() {
        let b = baseline(.oura, F.nights(recentLnHRV: { _ in 3.95 }))
        XCTAssertEqual(b.hrv.mean ?? 0, 4.0, accuracy: 1e-12)
        XCTAssertEqual(b.hrv.standardDeviation ?? 0, (0.175 / 34).squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(b.hrv.recentMean ?? 0, 3.95, accuracy: 1e-12)
        XCTAssertEqual(b.hrv.baselineNights, 35)
        XCTAssertEqual(b.hrv.recentNights, 7)
        XCTAssertEqual(b.recentHRVMilliseconds ?? 0, exp(3.95), accuracy: 1e-9)
        XCTAssertEqual(b.baselineHRVMilliseconds ?? 0, exp(4.0), accuracy: 1e-9)
    }

    func testLimitsAreMeanMinusSDs() throws {
        let b = baseline(.oura, F.nights())
        let sd = (0.175 / 34).squareRoot()
        XCTAssertEqual(try XCTUnwrap(b.hrv.lowerLimit(sds: 0.5)), 4.0 - 0.5 * sd, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(b.hrv.lowerLimit(sds: 1)), 4.0 - sd, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(b.hrv.upperLimit(sds: 1)), 4.0 + sd, accuracy: 1e-12)
    }

    func testResultIsAMeanOfLogsNotALogOfMeans() throws {
        // Recent nights 20 ms and 80 ms and 40 ms: geometric mean 40, arithmetic mean 46.67.
        let nights = F.nights(recentLnHRV: { [log(20.0), log(80.0), log(40.0)][$0 % 3] })
        let b = baseline(.oura, nights)
        let expectedMean = (log(20.0) * 3 + log(80.0) * 2 + log(40.0) * 2) / 7
        XCTAssertEqual(b.hrv.recentMean ?? 0, expectedMean, accuracy: 1e-12)
    }

    func testSleepMedianAndRestingHeartRateStatistics() throws {
        let b = baseline(.oura, F.nights())
        XCTAssertEqual(b.sleepMedianMinutes ?? 0, 420, accuracy: 1e-9)
        // Resting heart rate 52 + (-2, 2, 0, 2, -2): sample SD of the logs, computed independently here.
        let values = (0..<35).map { 52 + F.rhrCycle[$0 % 5] }
        let logs = values.map { log($0) }
        let mean = logs.reduce(0, +) / 35
        let sd = (logs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / 34).squareRoot()
        XCTAssertEqual(b.restingHeartRate.mean ?? 0, mean, accuracy: 1e-12)
        XCTAssertEqual(b.restingHeartRate.standardDeviation ?? 0, sd, accuracy: 1e-12)
        XCTAssertGreaterThan(sd, ReadinessConstants.minimumRestingHeartRateLogSD)
    }

    func testMedianOddEvenEmpty() {
        XCTAssertEqual(BaselineCalculator.median(of: [3, 1, 2]), 2)
        XCTAssertEqual(BaselineCalculator.median(of: [4, 1, 3, 2]), 2.5)
        XCTAssertNil(BaselineCalculator.median(of: []))
        XCTAssertNil(BaselineCalculator.median(of: [.nan]))
    }

    func testLogMeanAndSDSkipsUnusableValuesAndNeedsTwo() {
        XCTAssertNil(BaselineCalculator.logMeanAndSD(of: []))
        XCTAssertNil(BaselineCalculator.logMeanAndSD(of: [50]))
        XCTAssertNil(BaselineCalculator.logMeanAndSD(of: [0, -5, .nan, .infinity, 50]))
        XCTAssertNotNil(BaselineCalculator.logMeanAndSD(of: [0, -5, 40, 50]))
    }

    func testEffectiveSDHasAFloor() throws {
        // A flat baseline: every night identical, SD zero. The floor keeps thresholds finite and modest.
        let nights = (0...41).map {
            ReadinessNight(date: F.day(-$0), source: .oura, hrvMilliseconds: 60, restingHeartRate: 52)
        }
        let b = baseline(.oura, nights)
        XCTAssertEqual(b.hrv.standardDeviation ?? 1, 0, accuracy: 1e-12)
        XCTAssertEqual(b.hrv.effectiveSD ?? 0, ReadinessConstants.minimumHRVLogSD, accuracy: 1e-12)
        // Resting heart rate has its own, smaller floor, set from its smaller device error.
        XCTAssertEqual(b.restingHeartRate.effectiveSD ?? 0, ReadinessConstants.minimumRestingHeartRateLogSD, accuracy: 1e-12)
        XCTAssertLessThan(ReadinessConstants.minimumRestingHeartRateLogSD, ReadinessConstants.minimumHRVLogSD)
    }

    // MARK: Windows and validity

    func testWindowsSplitLatestSevenFromThirtyFiveBefore() {
        // Day 6 is the oldest recent night, day 7 the newest baseline night, day 41 the oldest baseline night.
        let nights = [night(6), night(7), night(41), night(42), night(-1)]
        let b = baseline(.oura, nights)
        XCTAssertEqual(b.hrv.recentNights, 1)
        XCTAssertEqual(b.hrv.baselineNights, 2)
        XCTAssertEqual(b.calibration.validNights, 3)
        XCTAssertNil(b.hrvByDaysAgo[42])
        XCTAssertNil(b.hrvByDaysAgo[-1])
    }

    func testBaselineNeedsTenNights() {
        XCTAssertEqual(ReadinessConstants.minimumBaselineNights, 10)
        let nine = (7...15).map { night($0) }
        let ten = (7...16).map { night($0) }
        XCTAssertNil(baseline(.oura, nine).hrv.mean)
        XCTAssertNil(baseline(.oura, nine).hrv.standardDeviation)
        XCTAssertFalse(baseline(.oura, nine).hrv.hasBaseline)
        XCTAssertNotNil(baseline(.oura, ten).hrv.mean)
        XCTAssertTrue(baseline(.oura, ten).hrv.hasBaseline)
    }

    func testRecentMeanNeedsThreeValidNights() {
        let two = (0..<2).map { night($0) }
        let three = (0..<3).map { night($0) }
        XCTAssertNil(baseline(.oura, two).hrv.recentMean)
        XCTAssertNotNil(baseline(.oura, three).hrv.recentMean)
    }

    func testImplausibleValuesAreNotValidNights() {
        let junk: [Double?] = [0, -4, 1, 4.9, 400.1, 5000, nil, .nan, .infinity]
        let nights = junk.enumerated().map { night($0.offset, hrv: $0.element) }
        XCTAssertEqual(baseline(.oura, nights).calibration.validNights, 0)
        let edges = [night(0, hrv: 5), night(1, hrv: 400)]
        XCTAssertEqual(baseline(.oura, edges).calibration.validNights, 2)
    }

    func testSeveralRecordsOnOneDayCountOnceAndAreAveraged() {
        let records = [night(3, hrv: 40), night(3, hrv: 60), night(4, hrv: 50)]
        let b = baseline(.oura, records)
        XCTAssertEqual(b.calibration.validNights, 2)
        XCTAssertEqual(b.hrvByDaysAgo[3] ?? 0, 50, accuracy: 1e-12)
    }

    func testInputOrderDoesNotChangeTheResult() {
        let original = F.nights(recentLnHRV: { 3.9 + 0.01 * Double($0) })
        var reversed = Array(original.reversed())
        XCTAssertEqual(baseline(.oura, original), baseline(.oura, reversed))
        var rotated = original
        rotated.append(contentsOf: rotated.prefix(11))
        rotated.removeFirst(11)
        XCTAssertEqual(baseline(.oura, original), baseline(.oura, rotated))
        reversed.append(night(3, hrv: 61))
        reversed.append(night(3, hrv: 59))
        let a = baseline(.oura, reversed)
        let b = baseline(.oura, reversed.reversed())
        XCTAssertEqual(a, b)
    }

    func testTimeOfDayDoesNotMatter() {
        let late = ReadinessNight(date: F.date(2026, 11, 4, hour: 23), source: .oura, hrvMilliseconds: 60)
        let early = ReadinessNight(date: F.date(2026, 11, 4, hour: 1), source: .oura, hrvMilliseconds: 60)
        let b = BaselineCalculator.baseline(
            for: .oura, nights: [late, early], today: F.date(2026, 11, 5, hour: 15), calendar: calendar)
        XCTAssertEqual(b.calibration.validNights, 1)
        XCTAssertEqual(b.hrvByDaysAgo.keys.sorted(), [1])
    }

    // MARK: Source separation

    func testHRVKindsPerSource() {
        XCTAssertEqual(ReadinessSource.appleWatch.hrvKind, .sdnn)
        XCTAssertEqual(ReadinessSource.whoop.hrvKind, .rmssd)
        XCTAssertEqual(ReadinessSource.oura.hrvKind, .rmssd)
        XCTAssertNil(ReadinessSource.garmin.hrvKind, "Garmin writes no HRV to Health, so none is read")
        XCTAssertFalse(ReadinessSource.garmin.canTriggerDeferral)
        XCTAssertTrue(ReadinessSource.garmin.isDevice)
        XCTAssertFalse(ReadinessSource.manual.isDevice)
        XCTAssertNil(ReadinessSource.manual.hrvKind)
        XCTAssertFalse(ReadinessSource.appleWatch.canTriggerDeferral)
        XCTAssertTrue(ReadinessSource.oura.canTriggerDeferral)
        XCTAssertFalse(ReadinessSource.manual.canTriggerDeferral)
    }

    func testHRVIsNeverPooledAcrossSources() {
        let ouraOnly = F.nights(source: .oura, recentLnHRV: { _ in 3.95 })
        // Apple Watch SDNN nights on the same days with very different values (about half the size).
        let apple = F.nights(source: .appleWatch, recentLnHRV: { _ in 3.0 }).map { n -> ReadinessNight in
            var copy = n
            if copy.date <= F.day(-7) { copy.hrvMilliseconds = (copy.hrvMilliseconds ?? 0) * 0.5 }
            return copy
        }
        let alone = baseline(.oura, ouraOnly)
        let mixed = baseline(.oura, ouraOnly + apple)
        XCTAssertEqual(alone, mixed)
        XCTAssertEqual(mixed.hrv.mean ?? 0, 4.0, accuracy: 1e-12)
        XCTAssertEqual(mixed.hrv.recentMean ?? 0, 3.95, accuracy: 1e-12)
        XCTAssertEqual(mixed.calibration.validNights, 42)
        // And the Apple Watch baseline is its own.
        let appleBaseline = baseline(.appleWatch, ouraOnly + apple)
        XCTAssertEqual(appleBaseline.hrv.recentMean ?? 0, 3.0, accuracy: 1e-9)
        XCTAssertEqual(appleBaseline.hrv.mean ?? 0, 4.0 + log(0.5), accuracy: 1e-9)
        XCTAssertNotEqual(appleBaseline.hrv.mean, mixed.hrv.mean)
    }

    func testManualNightsCarryNoHRV() {
        let manual = (0..<20).map { night($0, .manual, hrv: 60) }
        let b = baseline(.manual, manual)
        XCTAssertEqual(b.calibration.validNights, 0)
        XCTAssertTrue(b.hrvByDaysAgo.isEmpty)
        XCTAssertEqual(BaselineCalculator.validNightCount(for: .manual, nights: manual, today: today, calendar: calendar), 0)
    }

    func testRestingHeartRateAndSleepAlsoStaySeparate() {
        let oura = ReadinessNight(date: F.day(-1), source: .oura, hrvMilliseconds: 60, restingHeartRate: 50, sleepMinutes: 450)
        let apple = ReadinessNight(date: F.day(-1), source: .appleWatch, hrvMilliseconds: 40, restingHeartRate: 60, sleepMinutes: 380)
        let b = baseline(.oura, [oura, apple])
        XCTAssertEqual(b.restingHeartRateByDaysAgo[1], 50)
        XCTAssertEqual(b.sleepByDaysAgo[1], 450)
    }

    // MARK: Calibration

    func testCalibrationCountsAndTransitions() {
        // Fourteen valid nights are needed, ten of them in the baseline: 7 recent + 10 baseline is 17 nights.
        for count in [0, 1, 9, 13, 14, 16, 17, 20] {
            let nights = (0..<count).map { night($0) }
            let state = baseline(.oura, nights).calibration
            XCTAssertEqual(state.validNights, count)
            XCTAssertEqual(state.isCalibrated, count >= 17, "count \(count)")
            // The line never reads "night 14 of 14" while the baseline is still short.
            XCTAssertEqual(state.night, count >= 17 ? 14 : min(count, 13), "count \(count)")
            XCTAssertEqual(state.required, 14)
        }
    }

    func testCalibrationCountIsPerSource() {
        let oura = (0..<9).map { night($0, .oura) }
        let apple = (0..<30).map { night($0, .appleWatch) }
        XCTAssertEqual(baseline(.oura, oura + apple).calibration.validNights, 9)
        XCTAssertEqual(baseline(.appleWatch, oura + apple).calibration.validNights, 30)
    }

    func testRecentValidNightsForTheWeekGate() {
        let nights = (0..<2).map { night($0) } + (10..<30).map { night($0) }
        let state = baseline(.oura, nights).calibration
        XCTAssertEqual(state.validNights, 22)
        XCTAssertEqual(state.recentValidNights, 2)
        XCTAssertFalse(state.hasEnoughRecentNights)
        XCTAssertTrue(baseline(.oura, nights + [night(2)]).calibration.hasEnoughRecentNights)
    }

    func testNightsOlderThanFortyTwoDaysDoNotCalibrate() {
        let nights = (42...80).map { night($0) }
        XCTAssertEqual(baseline(.oura, nights).calibration.validNights, 0)
    }

    // MARK: Source choice

    private func choose(_ nights: [ReadinessNight], preferred: ReadinessSource? = nil) -> SourceChoice? {
        BaselineCalculator.chooseSource(nights: nights, preferred: preferred, today: today, calendar: calendar)
    }

    func testNoNightsMeansNoSource() {
        XCTAssertNil(choose([]))
    }

    func testOnlySource() {
        let choice = choose((0..<10).map { night($0, .whoop) })
        XCTAssertEqual(choice?.source, .whoop)
        XCTAssertEqual(choice?.reason, .onlySource)
    }

    func testDefaultOrderIsOuraWhoopAppleWatchGarmin() {
        XCTAssertEqual(ReadinessSource.defaultOrder, [.oura, .whoop, .appleWatch, .garmin])
        let all = ReadinessSource.defaultOrder.flatMap { source in
            (0..<7).map {
                ReadinessNight(date: F.day(-$0), source: source, hrvMilliseconds: 60, restingHeartRate: 52, sleepMinutes: 420)
            }
        }
        XCTAssertEqual(choose(all)?.source, .oura)
        XCTAssertEqual(choose(all)?.reason, .defaultOrder)
        XCTAssertEqual(choose(all.filter { $0.source != .oura })?.source, .whoop)
        XCTAssertEqual(choose(all.filter { $0.source != .oura && $0.source != .whoop })?.source, .appleWatch)
        XCTAssertEqual(choose(all.filter { $0.source == .garmin || $0.source == .appleWatch })?.source, .appleWatch)
    }

    func testASourceNeedsThreeRecentNightsToWinTheDefaultOrder() {
        let oura = (0..<2).map { night($0, .oura) } + (10..<40).map { night($0, .oura) }
        let apple = (0..<7).map { night($0, .appleWatch) }
        XCTAssertEqual(choose(oura + apple)?.source, .appleWatch)
        XCTAssertEqual(choose(oura + apple + [night(2, .oura)])?.source, .oura)
    }

    func testWhenNoSourceHasRecentNightsTheLatestDataWins() {
        let oura = (10..<20).map { night($0, .oura) }
        let apple = (5..<8).map { night($0, .appleWatch) } // two recent (5, 6): not enough, but latest
        let choice = choose(oura + apple)
        XCTAssertEqual(choice?.source, .appleWatch)
        XCTAssertEqual(choice?.reason, .latestData)
    }

    func testTiesOnLatestDataFollowTheDefaultOrder() {
        let nights = [night(10, .appleWatch), night(10, .whoop)]
        XCTAssertEqual(choose(nights)?.source, .whoop)
    }

    func testAthletePreferenceWins() {
        let nights = (0..<7).map { night($0, .oura) } + (0..<7).map { night($0, .appleWatch) }
        let choice = choose(nights, preferred: .appleWatch)
        XCTAssertEqual(choice?.source, .appleWatch)
        XCTAssertEqual(choice?.reason, .chosenByAthlete)
        XCTAssertEqual(choice?.explanation, "Using Apple Watch, the source you chose.")
    }

    func testPreferenceIsHonouredEvenWithoutNights() {
        XCTAssertEqual(choose((0..<7).map { night($0, .oura) }, preferred: .whoop)?.source, .whoop)
    }

    func testManualPreferenceMeansCheckInsOnly() {
        XCTAssertNil(choose((0..<7).map { night($0, .oura) }, preferred: .manual))
    }

    func testChoiceExplanationsAreCalm() {
        XCTAssertEqual(SourceChoice(source: .oura, reason: .defaultOrder).explanation,
                       "Using Oura, the first of your sources with enough recent nights.")
        XCTAssertEqual(SourceChoice(source: .whoop, reason: .onlySource).explanation,
                       "Using WHOOP, your only source with recent nights.")
        XCTAssertEqual(SourceChoice(source: .garmin, reason: .latestData).explanation,
                       "Using Garmin, the source with your latest data.")
    }

    // MARK: Source change restarts calibration

    func testSwitchingToANewSourceRestartsCalibration() {
        // Forty two nights of Apple Watch, then an Oura ring appears for the last five nights.
        let apple = F.nights(source: .appleWatch)
        let oura = (0..<5).map { night($0, .oura) }
        let before = BaselineCalculator.chooseSource(nights: apple, preferred: nil, today: today, calendar: calendar)
        XCTAssertEqual(before?.source, .appleWatch)
        XCTAssertTrue(baseline(.appleWatch, apple).calibration.isCalibrated)

        let after = BaselineCalculator.chooseSource(nights: apple + oura, preferred: nil, today: today, calendar: calendar)
        XCTAssertEqual(after?.source, .oura)
        let state = baseline(.oura, apple + oura).calibration
        XCTAssertEqual(state.validNights, 5)
        XCTAssertFalse(state.isCalibrated)
    }
}
