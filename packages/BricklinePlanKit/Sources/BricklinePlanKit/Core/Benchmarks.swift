import Foundation

/// Which field test a benchmark or test session refers to (annex A).
public enum BenchmarkKind: String, Codable, Hashable, Sendable, CaseIterable {
    /// Swim CSS from the 400 m and 200 m test.
    case swimCSS
    /// Bike FTP from the guided 20 minute test.
    case bikeFTP
    /// Bike LTHR from the 30 minute solo time trial (no power source).
    case bikeLTHR
    /// Run threshold pace and LTHR from the 30 minute time trial.
    case runThreshold

    /// The sport this test belongs to.
    public var sport: Sport {
        switch self {
        case .swimCSS: return .swim
        case .bikeFTP, .bikeLTHR: return .bike
        case .runThreshold: return .run
        }
    }
}

/// One benchmark number with provenance. `isEstimated` values are labelled Estimated everywhere and never
/// drive pace nudges (annex A "Seeding without tests", annex C rule 3).
public struct BenchmarkValue: Codable, Hashable, Sendable {
    public var value: Double
    public var isEstimated: Bool
    /// Date of the test or of the seeding activity.
    public var date: Date

    public init(value: Double, isEstimated: Bool, date: Date) {
        self.value = value
        self.isEstimated = isEstimated
        self.date = date
    }
}

/// The athlete's benchmark set (annex A). Every field is optional because plans must run on RPE alone.
public struct Benchmarks: Codable, Hashable, Sendable {
    /// Critical swim speed, seconds per 100 m.
    public var cssSecondsPer100m: BenchmarkValue?
    /// Functional threshold power, watts.
    public var ftpWatts: BenchmarkValue?
    /// Bike lactate threshold heart rate, bpm.
    public var lthrBpm: BenchmarkValue?
    /// Run threshold pace, seconds per km.
    public var thresholdPaceSecondsPerKm: BenchmarkValue?
    /// Run lactate threshold heart rate, bpm. Kept separate from the bike value because the two tests differ.
    public var runLthrBpm: BenchmarkValue?

    public init(
        cssSecondsPer100m: BenchmarkValue? = nil,
        ftpWatts: BenchmarkValue? = nil,
        lthrBpm: BenchmarkValue? = nil,
        thresholdPaceSecondsPerKm: BenchmarkValue? = nil,
        runLthrBpm: BenchmarkValue? = nil
    ) {
        self.cssSecondsPer100m = cssSecondsPer100m
        self.ftpWatts = ftpWatts
        self.lthrBpm = lthrBpm
        self.thresholdPaceSecondsPerKm = thresholdPaceSecondsPerKm
        self.runLthrBpm = runLthrBpm
    }

    /// Merges an incoming set (a test result, a seed) into this one, field by field. A tested value always beats an
    /// estimated one, so a seed can never overwrite a test; between two values of the same kind the newer wins,
    /// and a tie goes to the incoming value.
    public func merged(with incoming: Benchmarks) -> Benchmarks {
        func pick(_ current: BenchmarkValue?, _ new: BenchmarkValue?) -> BenchmarkValue? {
            guard let current else { return new }
            guard let new else { return current }
            if current.isEstimated != new.isEstimated { return current.isEstimated ? new : current }
            return new.date >= current.date ? new : current
        }
        return Benchmarks(
            cssSecondsPer100m: pick(cssSecondsPer100m, incoming.cssSecondsPer100m),
            ftpWatts: pick(ftpWatts, incoming.ftpWatts),
            lthrBpm: pick(lthrBpm, incoming.lthrBpm),
            thresholdPaceSecondsPerKm: pick(thresholdPaceSecondsPerKm, incoming.thresholdPaceSecondsPerKm),
            runLthrBpm: pick(runLthrBpm, incoming.runLthrBpm))
    }

    /// Date of the most recent non estimated (tested) benchmark for a sport, or nil when the sport was never
    /// tested. Used by annex C rule 8 (a test older than 8 weeks) and by retest rotation (annex A).
    public func lastTestDate(for sport: Sport) -> Date? {
        let candidates: [BenchmarkValue?]
        switch sport {
        case .swim: candidates = [cssSecondsPer100m]
        case .bike: candidates = [ftpWatts, lthrBpm]
        case .run: candidates = [thresholdPaceSecondsPerKm, runLthrBpm]
        }
        return candidates.compactMap { $0 }.filter { !$0.isEstimated }.map(\.date).max()
    }

    /// True when every benchmark that exists for the sport is an estimate (or none exists). Rule 3 pace nudges
    /// must not fire in that case (annex C rule 3).
    public func isOnlyEstimated(for sport: Sport) -> Bool {
        lastTestDate(for: sport) == nil
    }
}
