import XCTest
@testable import BricklinePlanKit

final class LoadTests: XCTestCase {
    private let model = DefaultLoadModel()

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? Date(timeIntervalSince1970: 0)
    }

    private func benchmarks(ftp: Double? = nil, ftpEstimated: Bool = false, bikeLTHR: Double? = nil, runLTHR: Double? = nil) -> Benchmarks {
        let d = date(2026, 10, 1)
        return Benchmarks(
            ftpWatts: ftp.map { BenchmarkValue(value: $0, isEstimated: ftpEstimated, date: d) },
            lthrBpm: bikeLTHR.map { BenchmarkValue(value: $0, isEstimated: false, date: d) },
            runLthrBpm: runLTHR.map { BenchmarkValue(value: $0, isEstimated: false, date: d) }
        )
    }

    private func workout(
        _ sport: Sport, seconds: Double, day: Date? = nil, power: Double? = nil, adjusted: Double? = nil,
        heartRate: Double? = nil, zones: [Double]? = nil, rpe: Int? = nil, planned: String? = nil
    ) -> CompletedWorkout {
        CompletedWorkout(
            id: UUID().uuidString, sport: sport, start: day ?? date(2026, 11, 2, hour: 7), durationSeconds: seconds,
            averagePower: power, adjustedPower: adjusted, averageHeartRate: heartRate,
            secondsInHeartRateZones: zones, rpe: rpe, plannedSessionID: planned, source: .healthKit)
    }

    // MARK: Power path

    func testPowerLoadHandComputed() {
        let b = benchmarks(ftp: 250)
        // (200 / 250)^2 * 1 h * 100 = 64
        XCTAssertEqual(model.load(for: workout(.bike, seconds: 3600, power: 200), benchmarks: b).load, 64, accuracy: 1e-9)
        // threshold hour is 100
        XCTAssertEqual(model.load(for: workout(.bike, seconds: 3600, power: 250), benchmarks: b).load, 100, accuracy: 1e-9)
        // 90 minutes at FTP is 150
        XCTAssertEqual(model.load(for: workout(.bike, seconds: 5400, power: 250), benchmarks: b).load, 150, accuracy: 1e-9)
    }

    func testAdjustedPowerWinsOverAverage() {
        let b = benchmarks(ftp: 250)
        // (225 / 250)^2 * 0.5 h * 100 = 40.5
        let result = model.load(for: workout(.bike, seconds: 1800, power: 200, adjusted: 225), benchmarks: b)
        XCTAssertEqual(result.load, 40.5, accuracy: 1e-9)
        XCTAssertFalse(result.isEstimated)
    }

    func testEstimatedFTPFlagsTheLoad() {
        let b = benchmarks(ftp: 250, ftpEstimated: true)
        XCTAssertTrue(model.load(for: workout(.bike, seconds: 3600, power: 250), benchmarks: b).isEstimated)
    }

    func testPowerPathIgnoredForOtherSportsAndMissingFTP() {
        let b = benchmarks(ftp: 250)
        // A run with power does not use the bike FTP; with no heart rate or feel rating it scores zero, estimated.
        let run = model.load(for: workout(.run, seconds: 3600, power: 250), benchmarks: b)
        XCTAssertEqual(run.load, 0)
        XCTAssertTrue(run.isEstimated)
        // A bike with power but no FTP falls through to zone time.
        let noFTP = model.load(for: workout(.bike, seconds: 3600, power: 250, zones: [0, 0, 0, 3600, 0]), benchmarks: Benchmarks())
        XCTAssertEqual(noFTP.load, 100, accuracy: 1e-9)
    }

    // MARK: Heart rate path

    func testZoneTimeLoadHandComputed() {
        // 10 min Z1, 20 min Z2, 30 min Z3, 10 min Z4:
        // 20/6 + 40/3 + 65/2 + 100/6 = 3.3333 + 13.3333 + 32.5 + 16.6667 = 65.8333
        let w = workout(.run, seconds: 4200, zones: [600, 1200, 1800, 600, 0])
        let result = model.load(for: w, benchmarks: Benchmarks())
        XCTAssertEqual(result.load, 65.833333333, accuracy: 1e-6)
        XCTAssertFalse(result.isEstimated)
    }

    func testEveryZoneFactorForOneHour() {
        let expected = [20.0, 40, 65, 100, 135]
        for index in 0..<5 {
            var zones = [Double](repeating: 0, count: 5)
            zones[index] = 3600
            let result = model.load(for: workout(.run, seconds: 3600, zones: zones), benchmarks: Benchmarks())
            XCTAssertEqual(result.load, expected[index], accuracy: 1e-9)
        }
    }

    func testZoneTimeBeatsAverageHeartRate() {
        let w = workout(.run, seconds: 3600, heartRate: 120, zones: [0, 0, 0, 3600, 0])
        XCTAssertEqual(model.load(for: w, benchmarks: benchmarks(runLTHR: 170)).load, 100, accuracy: 1e-9)
    }

    func testAverageHeartRateFallbackIsEstimated() {
        // 150 / 170 = 0.882 which is zone 2, factor 40.
        let b = benchmarks(bikeLTHR: 170, runLTHR: 170)
        let run = model.load(for: workout(.run, seconds: 3600, heartRate: 150), benchmarks: b)
        XCTAssertEqual(run.load, 40, accuracy: 1e-9)
        XCTAssertTrue(run.isEstimated)
        // 175 / 170 = 1.03 which is zone 5.
        XCTAssertEqual(model.load(for: workout(.run, seconds: 1800, heartRate: 175), benchmarks: b).load, 67.5, accuracy: 1e-9)
    }

    func testRunUsesRunLTHRNotBikeLTHR() {
        // Only a bike LTHR exists, so the run average heart rate cannot be anchored.
        let b = benchmarks(bikeLTHR: 170)
        let run = model.load(for: workout(.run, seconds: 3600, heartRate: 150), benchmarks: b)
        XCTAssertEqual(run.load, 0)
        XCTAssertTrue(run.isEstimated)
    }

    func testHeartRateBandBoundaries() {
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.50), 1)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.809), 1)
        // A value exactly on a band edge belongs to the lower zone, the same rule the zone calculator uses.
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.81), 1)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.811), 2)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.89), 2)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.891), 3)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.94), 3)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 0.941), 4)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 1.02), 4)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 1.021), 5)
        XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: 1.4), 5)
    }

    // MARK: Swim and feel fallbacks

    func testSwimWithHeartRateZonesIsNotEstimated() {
        let w = workout(.swim, seconds: 2700, zones: [0, 2700, 0, 0, 0])
        let result = model.load(for: w, benchmarks: Benchmarks())
        XCTAssertEqual(result.load, 30, accuracy: 1e-9) // 0.75 h * 40
        XCTAssertFalse(result.isEstimated)
    }

    func testSwimWithoutHeartRateUsesPlannedLevelAndIsEstimated() {
        let w = workout(.swim, seconds: 3600)
        let planned = model.load(for: w, benchmarks: Benchmarks(), plannedLevel: 4)
        XCTAssertEqual(planned.load, 100, accuracy: 1e-9)
        XCTAssertTrue(planned.isEstimated)
        // Nothing at all: an easy swim.
        let fallback = model.load(for: w, benchmarks: Benchmarks())
        XCTAssertEqual(fallback.load, 40, accuracy: 1e-9)
        XCTAssertTrue(fallback.isEstimated)
    }

    func testFeelRatingMapsToLevel() {
        XCTAssertEqual(LoadConstants.level(forRPE: 1), 1)
        XCTAssertEqual(LoadConstants.level(forRPE: 2), 1)
        XCTAssertEqual(LoadConstants.level(forRPE: 3), 2)
        XCTAssertEqual(LoadConstants.level(forRPE: 5), 3)
        XCTAssertEqual(LoadConstants.level(forRPE: 7), 4)
        XCTAssertEqual(LoadConstants.level(forRPE: 10), 5)
        XCTAssertEqual(LoadConstants.level(forRPE: 99), 5)
        XCTAssertEqual(LoadConstants.level(forRPE: -4), 1)
        let result = model.load(for: workout(.run, seconds: 3600, rpe: 7), benchmarks: Benchmarks())
        XCTAssertEqual(result.load, 100, accuracy: 1e-9)
        XCTAssertTrue(result.isEstimated)
    }

    func testNoUsableDataIsZeroAndEstimated() {
        let result = model.load(for: workout(.bike, seconds: 3600), benchmarks: Benchmarks())
        XCTAssertEqual(result.load, 0)
        XCTAssertTrue(result.isEstimated)
    }

    func testMalformedInputNeverTraps() {
        let b = benchmarks(ftp: 250, bikeLTHR: 170)
        XCTAssertEqual(model.load(for: workout(.bike, seconds: 3600, power: .nan), benchmarks: b).load, 0)
        XCTAssertEqual(model.load(for: workout(.bike, seconds: -50, power: 200), benchmarks: b).load, 0)
        // Four zone entries is treated as missing data.
        XCTAssertEqual(model.load(for: workout(.run, seconds: 3600, zones: [3600, 0, 0, 0]), benchmarks: Benchmarks()).load, 0)
        // Negative or infinite zone time is rejected.
        XCTAssertEqual(model.load(for: workout(.run, seconds: 3600, zones: [-1, 0, 0, 0, 3600]), benchmarks: Benchmarks()).load, 0)
        XCTAssertEqual(model.load(for: workout(.run, seconds: 3600, zones: [.infinity, 0, 0, 0, 0]), benchmarks: Benchmarks()).load, 0)
        // All zero zone times is treated as missing data.
        XCTAssertEqual(model.load(for: workout(.run, seconds: 3600, zones: [0, 0, 0, 0, 0]), benchmarks: Benchmarks()).load, 0)
        var zeroFTP = benchmarks(ftp: 0)
        zeroFTP.ftpWatts = BenchmarkValue(value: 0, isEstimated: false, date: date(2026, 10, 1))
        XCTAssertEqual(model.load(for: workout(.bike, seconds: 3600, power: 200), benchmarks: zeroFTP).load, 0)
    }

    // MARK: Parity between the two paths

    func testSteadyHourParityAtEachZoneMidpoint() {
        let b = benchmarks(ftp: 250)
        for level in 1...5 {
            let watts = 250 * LoadConstants.powerMidpointFraction(level: level)
            let power = model.load(for: workout(.bike, seconds: 3600, power: watts), benchmarks: b).load
            var zones = [Double](repeating: 0, count: 5)
            zones[level - 1] = 3600
            let heartRate = model.load(for: workout(.bike, seconds: 3600, zones: zones), benchmarks: Benchmarks()).load
            XCTAssertEqual(heartRate, power, accuracy: power * 0.08, "level \(level): heart rate \(heartRate) vs power \(power)")
        }
    }

    func testMidpointHeartRatesLandInTheirOwnZone() {
        // Middle of each band as a fraction of LTHR (Z1 and Z5 are open ended, so a typical value is used).
        let midpoints = [0.70, 0.85, 0.915, 0.98, 1.06]
        for (index, fraction) in midpoints.enumerated() {
            XCTAssertEqual(LoadConstants.heartRateLevel(fractionOfLTHR: fraction), index + 1)
        }
    }

    func testThresholdHourScoresOneHundredOnBothPaths() {
        let power = model.load(for: workout(.bike, seconds: 3600, power: 300), benchmarks: benchmarks(ftp: 300)).load
        let heartRate = model.load(for: workout(.bike, seconds: 3600, zones: [0, 0, 0, 3600, 0]), benchmarks: Benchmarks()).load
        XCTAssertEqual(power, 100, accuracy: 1e-9)
        XCTAssertEqual(heartRate, 100, accuracy: 1e-9)
    }

    // MARK: Planned Load

    private func step(_ sport: Sport, _ kind: StepKind, _ seconds: Double, level: Int, group: String? = nil, count: Int? = nil) -> Step {
        Step(sport: sport, kind: kind, durationSeconds: seconds, level: level, repeatGroupID: group, repeatCount: count, name: "s")
    }

    private func session(_ sport: Sport, _ steps: [Step], id: String = "w00-20261109-x-1", brick: Sport? = nil) -> Session {
        Session(id: id, sport: sport, name: "n", purpose: "p", steps: steps, scheduledDate: date(2026, 11, 9), brickSecondSport: brick)
    }

    func testPlannedLoadBikeWithAndWithoutFTP() {
        let s = session(.bike, [step(.bike, .work, 3600, level: 4)])
        let withFTP = model.plannedLoad(for: s, benchmarks: benchmarks(ftp: 250))
        XCTAssertEqual(withFTP.load, 96.04, accuracy: 1e-9) // 0.98^2 * 100
        XCTAssertFalse(withFTP.isEstimated)
        let without = model.plannedLoad(for: s, benchmarks: Benchmarks())
        XCTAssertEqual(without.load, 100, accuracy: 1e-9)
        let estimatedFTP = model.plannedLoad(for: s, benchmarks: benchmarks(ftp: 250, ftpEstimated: true))
        XCTAssertTrue(estimatedFTP.isEstimated)
    }

    func testPlannedLoadExpandsRepeats() {
        let steps = [
            step(.run, .warmUp, 600, level: 2),
            step(.run, .work, 300, level: 5, group: "g", count: 4),
            step(.run, .recovery, 120, level: 1, group: "g", count: 4),
            step(.run, .coolDown, 600, level: 1)
        ]
        // warm up 10/60 h * 40 = 6.6667; work 4 * 5/60 h * 135 = 45; recovery 4 * 2/60 h * 20 = 2.6667; cool down 10/60 h * 20 = 3.3333
        let result = model.plannedLoad(for: session(.run, steps), benchmarks: Benchmarks())
        XCTAssertEqual(result.load, 57.6666666667, accuracy: 1e-6)
        XCTAssertFalse(result.isEstimated)
    }

    func testPlannedLoadSwimIsEstimatedAndBrickMixesPaths() {
        let swim = session(.swim, [step(.swim, .work, 1800, level: 3)])
        let swimLoad = model.plannedLoad(for: swim, benchmarks: Benchmarks())
        XCTAssertEqual(swimLoad.load, 32.5, accuracy: 1e-9)
        XCTAssertTrue(swimLoad.isEstimated)

        let brick = session(.bike, [step(.bike, .work, 3600, level: 3), step(.run, .work, 900, level: 3)], brick: .run)
        // bike on the power path: 0.83^2 * 100 = 68.89; run on the heart rate path: 0.25 h * 65 = 16.25
        let result = model.plannedLoad(for: brick, benchmarks: benchmarks(ftp: 250))
        XCTAssertEqual(result.load, 85.14, accuracy: 1e-9)
    }

    func testPlannedLoadEmptyAndZeroDurationAreZero() {
        XCTAssertEqual(model.plannedLoad(for: session(.run, []), benchmarks: Benchmarks()).load, 0)
        XCTAssertEqual(model.plannedLoad(for: session(.run, [step(.run, .work, 0, level: 5)]), benchmarks: Benchmarks()).load, 0)
    }

    func testPlannedLoadForWeekSumsSessions() {
        let d1 = date(2026, 11, 9)
        let d2 = date(2026, 11, 11)
        let a = Session(id: "a", sport: .run, name: "n", purpose: "p", steps: [step(.run, .work, 3600, level: 4)], scheduledDate: d1)
        let b = Session(id: "b", sport: .run, name: "n", purpose: "p", steps: [step(.run, .work, 1800, level: 2)], scheduledDate: d2)
        let week = PlannedWeek(index: 0, startDate: d1, phase: .base, days: [d1: [a], d2: [b]])
        XCTAssertEqual(model.plannedLoad(for: week, benchmarks: Benchmarks()), 100 + 20, accuracy: 1e-9)
        XCTAssertEqual(model.plannedLoad(for: PlannedWeek(index: 1, startDate: d1, phase: .base), benchmarks: Benchmarks()), 0)
    }

    func testRepresentativeLevelIsDurationWeighted() {
        // 600 s at level 1 and 1800 s at level 4: (600 + 7200) / 2400 = 3.25 which rounds to 3.
        let s = session(.run, [step(.run, .warmUp, 600, level: 1), step(.run, .work, 1800, level: 4)])
        XCTAssertEqual(model.representativeLevel(for: s), 3)
        XCTAssertEqual(model.representativeLevel(for: session(.run, [])), LoadConstants.defaultSwimLevel)
        XCTAssertEqual(model.plannedLevels(for: [s]), [s.id: 3])
    }

    // MARK: Daily series

    func testDailyLoadsFillGapsWithZero() {
        let b = Benchmarks()
        let workouts = [
            workout(.run, seconds: 3600, day: date(2026, 11, 2, hour: 7), zones: [0, 0, 0, 3600, 0]),
            workout(.run, seconds: 1800, day: date(2026, 11, 2, hour: 18), zones: [0, 0, 1800, 0, 0]),
            workout(.run, seconds: 3600, day: date(2026, 11, 5, hour: 12), zones: [0, 3600, 0, 0, 0]),
            workout(.run, seconds: 3600, day: date(2026, 10, 30), zones: [0, 0, 0, 3600, 0]), // before range
            workout(.run, seconds: 3600, day: date(2026, 11, 9), zones: [0, 0, 0, 3600, 0])  // after range
        ]
        let series = model.dailyLoads(workouts: workouts, benchmarks: b, from: date(2026, 11, 1, hour: 15), through: date(2026, 11, 6), calendar: calendar)
        XCTAssertEqual(series.count, 6)
        XCTAssertEqual(series.map(\.date), (1...6).map { date(2026, 11, $0) })
        XCTAssertEqual(series.map(\.load), [0, 100 + 32.5, 0, 0, 40, 0])
    }

    func testDailyLoadsUsesPlannedLevelsForUnmeasuredSwims() {
        let swim = workout(.swim, seconds: 3600, day: date(2026, 11, 3), planned: "swim-a")
        let day = date(2026, 11, 3)
        let withLevel = model.dailyLoads(workouts: [swim], benchmarks: Benchmarks(), plannedLevels: ["swim-a": 4], from: day, through: day, calendar: calendar)
        XCTAssertEqual(withLevel.first?.load ?? -1, 100, accuracy: 1e-9)
        let without = model.dailyLoads(workouts: [swim], benchmarks: Benchmarks(), from: day, through: day, calendar: calendar)
        XCTAssertEqual(without.first?.load ?? -1, 40, accuracy: 1e-9)
    }

    func testDailyLoadsEdgeCases() {
        let day = date(2026, 11, 3)
        XCTAssertTrue(model.dailyLoads(workouts: [], benchmarks: Benchmarks(), from: day, through: date(2026, 11, 2), calendar: calendar).isEmpty)
        let single = model.dailyLoads(workouts: [], benchmarks: Benchmarks(), from: day, through: day, calendar: calendar)
        XCTAssertEqual(single, [LoadSample(date: day, load: 0)])
        let huge = model.dailyLoads(workouts: [], benchmarks: Benchmarks(), from: date(1900, 1, 1), through: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(huge.count, LoadConstants.maximumSeriesDays)
    }

    // MARK: Fitness and Form

    func testFitnessFormAgainstHandComputedSeries() {
        // Loads 100, 0, 50. Smoothing factors: 1 - e^(-1/42) = 0.0235283133, 1 - e^(-1/7) = 0.1331221002.
        // Day 1: fitness 2.3528313, fatigue 13.3122100, form 0 (yesterday is zero).
        // Day 2: fitness 2.2974732, fatigue 11.5400607, form 2.3528313 - 13.3122100 = -10.9593787.
        // Day 3: fitness 3.4198332, fatigue 16.6599286, form 2.2974732 - 11.5400607 = -9.2425875.
        let loads = [100.0, 0, 50]
        let samples = loads.enumerated().map { LoadSample(date: date(2026, 11, 2 + $0.offset), load: $0.element) }
        let series = model.fitnessForm(dailyLoads: samples, calendar: calendar)
        XCTAssertEqual(series.count, 3)
        let expected: [(Double, Double, Double)] = [
            (2.3528313347756735, 13.312210024981841, 0),
            (2.2974731818766507, 11.54006066748957, -10.959378690206167),
            (3.419833180333226, 16.65992856691396, -9.242587485612919)
        ]
        for (index, row) in expected.enumerated() {
            XCTAssertEqual(series[index].fitness, row.0, accuracy: 1e-6)
            XCTAssertEqual(series[index].fatigue, row.1, accuracy: 1e-6)
            XCTAssertEqual(series[index].form, row.2, accuracy: 1e-6)
            XCTAssertEqual(series[index].date, samples[index].date)
        }
    }

    func testFormIsYesterdaysFitnessMinusFatigue() {
        let samples = (0..<20).map { LoadSample(date: date(2026, 11, 1 + $0), load: $0 % 3 == 0 ? 80 : 20) }
        let series = model.fitnessForm(dailyLoads: samples, calendar: calendar)
        XCTAssertEqual(series[0].form, 0)
        for index in 1..<series.count {
            XCTAssertEqual(series[index].form, series[index - 1].fitness - series[index - 1].fatigue, accuracy: 1e-12)
        }
    }

    func testFitnessFormConvergesToSteadyLoad() {
        let samples = (0..<600).map { LoadSample(date: calendar.addDays($0, to: date(2025, 1, 1)), load: 100) }
        let last = model.fitnessForm(dailyLoads: samples, calendar: calendar).last
        XCTAssertEqual(last?.fitness ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(last?.fatigue ?? 0, 100, accuracy: 1e-6)
        XCTAssertEqual(last?.form ?? 1, 0, accuracy: 0.01)
    }

    func testFitnessFormTreatsMissingDaysAsZeroLoadDays() {
        // 100 on day 1, nothing on days 2 and 3, 50 on day 4. Same as the dense series 100, 0, 0, 50.
        let sparse = [LoadSample(date: date(2026, 11, 2), load: 100), LoadSample(date: date(2026, 11, 5), load: 50)]
        let dense = [100.0, 0, 0, 50].enumerated().map { LoadSample(date: date(2026, 11, 2 + $0.offset), load: $0.element) }
        let a = model.fitnessForm(dailyLoads: sparse, calendar: calendar)
        let b = model.fitnessForm(dailyLoads: dense, calendar: calendar)
        XCTAssertEqual(a.count, 2)
        XCTAssertEqual(a[1].fitness, b[3].fitness, accuracy: 1e-9)
        XCTAssertEqual(a[1].fatigue, b[3].fatigue, accuracy: 1e-9)
        XCTAssertEqual(a[1].form, b[3].form, accuracy: 1e-9)
        // Hand computed: fitness 3.3670494, fatigue 15.3281986, form -7.7604060.
        XCTAssertEqual(a[1].fitness, 3.3670493501188017, accuracy: 1e-6)
        XCTAssertEqual(a[1].form, -7.760406041477649, accuracy: 1e-6)
    }

    func testFitnessFormSortsAndMergesAndSanitizes() {
        let day = date(2026, 11, 2)
        let samples = [
            LoadSample(date: calendar.addDays(1, to: day), load: -5),
            LoadSample(date: day, load: 60),
            LoadSample(date: calendar.addDays(0, to: day), load: 40),
            LoadSample(date: calendar.addDays(2, to: day), load: .nan)
        ]
        let series = model.fitnessForm(dailyLoads: samples, calendar: calendar)
        XCTAssertEqual(series.map(\.date), (0...2).map { calendar.addDays($0, to: day) })
        XCTAssertEqual(series[0].fitness, 100 * LoadConstants.smoothingFactor(timeConstantDays: 42), accuracy: 1e-9)
        XCTAssertTrue(series.allSatisfy { $0.fitness.isFinite && $0.fatigue.isFinite && $0.form.isFinite })
        XCTAssertTrue(model.fitnessForm(dailyLoads: [], calendar: calendar).isEmpty)
    }

    // MARK: Acute to chronic ratio

    func testAcuteChronicRatioHandComputed() {
        // 28 days ending 2026-11-28: days 1 to 21 score 10, days 22 to 28 score 40.
        // Acute average 40, chronic average (210 + 280) / 28 = 17.5, ratio 2.2857142857.
        let samples = (1...28).map { LoadSample(date: date(2026, 11, $0), load: $0 <= 21 ? 10 : 40) }
        let ratio = model.acuteChronicRatio(dailyLoads: samples, asOf: date(2026, 11, 28), calendar: calendar)
        XCTAssertEqual(ratio ?? 0, 40 / 17.5, accuracy: 1e-9)
    }

    func testAcuteChronicRatioSteadyLoadIsOne() {
        let samples = (1...30).map { LoadSample(date: date(2026, 11, $0), load: 55) }
        XCTAssertEqual(model.acuteChronicRatio(dailyLoads: samples, asOf: date(2026, 11, 30), calendar: calendar) ?? 0, 1, accuracy: 1e-9)
    }

    func testAcuteChronicRatioNilCases() {
        // History of 27 days is too short.
        let short = (2...28).map { LoadSample(date: date(2026, 11, $0), load: 50) }
        XCTAssertNil(model.acuteChronicRatio(dailyLoads: short, asOf: date(2026, 11, 28), calendar: calendar))
        // Chronic average of zero.
        let zeros = (1...28).map { LoadSample(date: date(2026, 11, $0), load: 0) }
        XCTAssertNil(model.acuteChronicRatio(dailyLoads: zeros, asOf: date(2026, 11, 28), calendar: calendar))
        XCTAssertNil(model.acuteChronicRatio(dailyLoads: [], asOf: date(2026, 11, 28), calendar: calendar))
    }

    func testAcuteChronicRatioIgnoresLaterDaysAndCountsMissingAsZero() {
        // Series covers 1 to 40 Nov but we ask as of 28 Nov; days after are ignored.
        var samples = (1...40).map { LoadSample(date: date(2026, 11, $0), load: 20) }
        samples[35] = LoadSample(date: samples[35].date, load: 9999)
        XCTAssertEqual(model.acuteChronicRatio(dailyLoads: samples, asOf: date(2026, 11, 28), calendar: calendar) ?? 0, 1, accuracy: 1e-9)
        // Only day 1 and day 28 present: chronic (60 + 70) / 28, acute 70 / 7.
        let sparse = [LoadSample(date: date(2026, 11, 1), load: 60), LoadSample(date: date(2026, 11, 28), load: 70)]
        let ratio = model.acuteChronicRatio(dailyLoads: sparse, asOf: date(2026, 11, 28), calendar: calendar)
        XCTAssertEqual(ratio ?? 0, (70.0 / 7) / (130.0 / 28), accuracy: 1e-9)
    }

    // MARK: Hygiene

    func testSeriesBuilderFeedsFitnessForm() {
        let workouts = (0..<10).map { workout(.run, seconds: 3600, day: date(2026, 11, 1 + $0, hour: 6), zones: [0, 0, 0, 3600, 0]) }
        let daily = model.dailyLoads(workouts: workouts, benchmarks: Benchmarks(), from: date(2026, 11, 1), through: date(2026, 11, 12), calendar: calendar)
        let series = model.fitnessForm(dailyLoads: daily, calendar: calendar)
        XCTAssertEqual(series.count, 12)
        XCTAssertGreaterThan(series[9].fitness, series[0].fitness)
        XCTAssertLessThan(series[11].fatigue, series[9].fatigue) // two rest days
    }
}
