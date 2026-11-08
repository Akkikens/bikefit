import Foundation

/// Benchmark seeding from recorded series (annex A "Seeding without tests"). Seeded values are always
/// labelled estimated, so they never drive pace nudges (annex C rule 3). Swim is never seeded in 1.0.
extension DefaultZoneCalculator {
    /// Whether 1.0 seeds a sport from recorded data: bike and run yes, swim never (annex A, swim).
    public static func supportsSeeding(for sport: Sport) -> Bool {
        sport != .swim
    }

    /// Annex A, bike: FTP is 0.95 times the best 20 minute average of the power samples. Nil when no continuous
    /// stretch of power data covers 20 minutes, or when the result is not above zero.
    public func seedFTP(fromPower samples: [SeriesSample], on date: Date) -> BenchmarkValue? {
        let runs = SeriesAnalysis.runs(from: samples, allowZero: true)
        guard let best = SeriesAnalysis.bestWindow(in: runs, length: ZoneConstants.ftpSeedWindowSeconds) else {
            return nil
        }
        let ftp = best.average * ZoneConstants.ftpFractionOfTwentyMinutePower
        guard ftp.isFinite, ftp > 0 else { return nil }
        return BenchmarkValue(value: ftp, isEstimated: true, date: date)
    }

    /// Annex A, bike: LTHR from the best sustained 20 to 30 minute heart rate segment. The search takes the
    /// highest average 30 minute window (or the longest window of at least 20 minutes that the data allows) and
    /// reports the average of its final 20 minutes, mirroring the test protocol. Nil when the data is too short.
    public func seedBikeLTHR(fromHeartRate samples: [SeriesSample], on date: Date) -> BenchmarkValue? {
        guard let bpm = Self.seededLTHR(fromHeartRate: samples) else { return nil }
        return BenchmarkValue(value: bpm, isEstimated: true, date: date)
    }

    /// Annex A, run: threshold pace from the best sustained 20 to 30 minute segment of the speed series
    /// (1000 divided by the average speed in metres per second), plus LTHR from the final 20 minutes of the same
    /// segment when heart rate covers it, else from the best heart rate segment. Only the run fields are set.
    /// Returns empty benchmarks when the data is too short.
    public func seedRunBenchmarks(
        speed: [SeriesSample],
        heartRate: [SeriesSample],
        on date: Date
    ) -> Benchmarks {
        var result = Benchmarks()
        let heartRuns = SeriesAnalysis.runs(from: heartRate, allowZero: false)
        let speedRuns = SeriesAnalysis.runs(from: speed, allowZero: true)

        var segment: (start: Double, length: Double)?
        if let length = Self.seedWindowLength(coverage: SeriesAnalysis.longestCoverage(of: speedRuns)),
           let best = SeriesAnalysis.bestWindow(in: speedRuns, length: length),
           let rawPace = PaceConversion.pacePerKm(fromSpeed: best.average),
           case let pace = rawPace * Self.shortWindowPaceFactor(windowSeconds: length),
           pace >= Self.fastestPlausibleRunPace,
           best.average >= Self.slowestPlausibleRunSpeed {
            result.thresholdPaceSecondsPerKm = BenchmarkValue(value: pace, isEstimated: true, date: date)
            segment = (best.start, length)
        }

        var lthr: Double?
        if let segment {
            let finalStart = segment.start + segment.length - ZoneConstants.lthrWindowSeconds
            let finalEnd = segment.start + segment.length
            if let stretch = SeriesAnalysis.average(in: heartRuns, from: finalStart, to: finalEnd),
               stretch.covered >= ZoneConstants.lthrWindowSeconds * Self.minimumHeartRateCoverage,
               Self.isPlausibleHeartRate(stretch.average) {
                lthr = stretch.average
            }
        }
        if lthr == nil {
            lthr = Self.seededLTHR(fromHeartRate: heartRate)
        }
        if let lthr {
            result.runLthrBpm = BenchmarkValue(value: lthr, isEstimated: true, date: date)
        }
        return result
    }

    /// Annex A, bike: seeds from power only when the ride has power samples that yield a result, otherwise falls
    /// back to LTHR from heart rate. The source tells the benchmarks screen to say bike zones were estimated from
    /// heart rate and to suggest a test.
    public func seedBike(power: [SeriesSample], heartRate: [SeriesSample], on date: Date) -> BikeSeed {
        if let ftp = seedFTP(fromPower: power, on: date) {
            return BikeSeed(benchmarks: Benchmarks(ftpWatts: ftp), source: .power)
        }
        if let lthr = seedBikeLTHR(fromHeartRate: heartRate, on: date) {
            return BikeSeed(benchmarks: Benchmarks(lthrBpm: lthr), source: .heartRate)
        }
        return BikeSeed(benchmarks: Benchmarks(), source: .none)
    }

    // MARK: Helpers

    /// Slows a pace taken from a window under 30 minutes: about 4 percent at 20 minutes, none at 30 (the best
    /// shorter effort runs a little faster than a 30 minute test pace).
    static func shortWindowPaceFactor(windowSeconds: Double) -> Double {
        let missing = max(ZoneConstants.seedMaximumWindowSeconds - windowSeconds, 0)
        let span = ZoneConstants.seedMaximumWindowSeconds - ZoneConstants.seedMinimumWindowSeconds
        return 1 + ZoneConstants.seedShortWindowPaceAdjustment * min(missing / span, 1)
    }

    /// A heart rate stretch must cover at least this share of the final 20 minutes to be trusted.
    static let minimumHeartRateCoverage: Double = 0.75

    /// Slower than 0.5 m/s on average over 20 minutes is a walk with stops, not a run effort.
    static let slowestPlausibleRunSpeed: Double = 0.5

    /// Window length for a 20 to 30 minute search: 30 minutes when the data allows it, else the longest
    /// stretch of at least 20 minutes. Nil when under 20 minutes.
    static func seedWindowLength(coverage: Double) -> Double? {
        guard coverage + SeriesAnalysis.epsilon >= ZoneConstants.seedMinimumWindowSeconds else { return nil }
        return min(coverage, ZoneConstants.seedMaximumWindowSeconds)
    }

    static func seededLTHR(fromHeartRate samples: [SeriesSample]) -> Double? {
        let runs = SeriesAnalysis.runs(from: samples, allowZero: false)
        guard let length = seedWindowLength(coverage: SeriesAnalysis.longestCoverage(of: runs)),
              let best = SeriesAnalysis.bestWindow(in: runs, length: length) else { return nil }
        let finalEnd = best.start + length
        let finalStart = finalEnd - ZoneConstants.lthrWindowSeconds
        guard let stretch = SeriesAnalysis.average(in: runs, from: finalStart, to: finalEnd),
              isPlausibleHeartRate(stretch.average) else { return nil }
        return stretch.average
    }
}
