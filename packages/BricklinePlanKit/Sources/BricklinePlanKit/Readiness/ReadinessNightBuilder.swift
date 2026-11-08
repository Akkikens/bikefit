import Foundation

/// One timestamped reading from a health store: an HRV sample or a resting heart rate sample.
public struct ReadinessSample: Codable, Hashable, Sendable {
    public var date: Date
    /// Milliseconds for HRV, beats per minute for resting heart rate.
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// One block of time asleep from a health store.
public struct SleepInterval: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// Turns raw health store readings into `ReadinessNight`s (annex C rules 9 to 13), so the day bucketing and the
/// sleep arithmetic live in tested package code and not in the app. Foundation only and deterministic.
///
/// Attribution is the caller's job and must follow the data source, not the sample type. Oura and WHOOP write their
/// rMSSD into the same Health HRV type that Apple Watch fills with SDNN, so a host splits the samples by the
/// source that wrote them (for example the Health sample's source) and calls this once per source with that
/// source's `ReadinessSource`. Never pass the readings of two sources in one call.
///
/// Rules of the road:
/// - A night is dated by the day the athlete woke up: the calendar day of the end of the sleep block.
/// - Sleep blocks that overlap or touch are merged, so a re-synced or overlapping record is not counted twice. The
///   minutes of all blocks that end on one day are summed (a night recorded in fragments is one night).
/// - HRV counts only when the sample falls inside a sleep block, and is dated to that block's wake day. Apple Watch
///   HRV is sporadic through the day, and a daytime reading says nothing about the night. Several samples in one night
///   are averaged.
/// - Resting heart rate is one reading per day in Health. It is dated by the calendar day of the sample, and
///   several in one day are averaged.
/// - Values that are not finite, intervals that end before they start and anything else unusable are dropped.
public enum ReadinessNightBuilder {
    public static func nights(
        hrvSamples: [ReadinessSample],
        restingHeartRate: [ReadinessSample],
        sleepIntervals: [SleepInterval],
        source: ReadinessSource,
        calendar: Calendar
    ) -> [ReadinessNight] {
        let blocks = mergedBlocks(sleepIntervals)

        var sleepByDay: [Date: Double] = [:]
        for block in blocks {
            let day = calendar.startOfDay(for: block.end)
            sleepByDay[day, default: 0] += block.end.timeIntervalSince(block.start) / 60
        }

        var hrvByDay: [Date: [Double]] = [:]
        for sample in hrvSamples where sample.value.isFinite && sample.date.timeIntervalSinceReferenceDate.isFinite {
            guard let block = blocks.first(where: { $0.start <= sample.date && sample.date <= $0.end }) else { continue }
            hrvByDay[calendar.startOfDay(for: block.end), default: []].append(sample.value)
        }

        var rhrByDay: [Date: [Double]] = [:]
        for sample in restingHeartRate where sample.value.isFinite && sample.date.timeIntervalSinceReferenceDate.isFinite {
            rhrByDay[calendar.startOfDay(for: sample.date), default: []].append(sample.value)
        }

        let days = Set(sleepByDay.keys).union(hrvByDay.keys).union(rhrByDay.keys).sorted()
        return days.map { day in
            ReadinessNight(
                date: day, source: source,
                hrvMilliseconds: mean(hrvByDay[day]),
                restingHeartRate: mean(rhrByDay[day]),
                sleepMinutes: sleepByDay[day])
        }
    }

    /// Valid blocks sorted by start, with overlapping or touching blocks merged.
    static func mergedBlocks(_ intervals: [SleepInterval]) -> [SleepInterval] {
        let valid = intervals.filter {
            $0.start.timeIntervalSinceReferenceDate.isFinite && $0.end.timeIntervalSinceReferenceDate.isFinite && $0.end > $0.start
        }.sorted { a, b in a.start != b.start ? a.start < b.start : a.end < b.end }
        var merged: [SleepInterval] = []
        for interval in valid {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1].end = max(last.end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private static func mean(_ values: [Double]?) -> Double? {
        guard let values, !values.isEmpty else { return nil }
        return values.sorted().reduce(0, +) / Double(values.count)
    }
}
