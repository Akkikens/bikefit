import Foundation

/// One continuous stretch of a recorded series, read as a step function: each sample holds its value until the
/// next sample, and the last sample holds for the length of the final interval. Used for the "best sustained
/// segment" searches of annex A "Seeding without tests".
struct HoldRun {
    let times: [Double]
    let values: [Double]
    let end: Double
    /// `cumulative[i]` is the area under the step function from `times[0]` to `times[i]`.
    private let cumulative: [Double]

    init?(times: [Double], values: [Double]) {
        guard times.count >= 2, times.count == values.count,
              let last = times.last else { return nil }
        let finalInterval = times[times.count - 1] - times[times.count - 2]
        guard finalInterval > 0 else { return nil }
        self.times = times
        self.values = values
        self.end = last + finalInterval
        var running: [Double] = [0]
        running.reserveCapacity(times.count)
        for i in 0..<(times.count - 1) {
            running.append(running[i] + values[i] * (times[i + 1] - times[i]))
        }
        self.cumulative = running
    }

    var start: Double { times[0] }
    var coverage: Double { end - times[0] }

    /// Area under the step function from the start of the run to `x` (clamped into the run).
    func integral(to x: Double) -> Double {
        let c = min(max(x, start), end)
        var low = 0
        var high = times.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if times[mid] <= c { low = mid } else { high = mid - 1 }
        }
        return cumulative[low] + values[low] * (c - times[low])
    }
}

/// Pure helpers over `SeriesSample` arrays. Nothing here reads the clock or traps.
enum SeriesAnalysis {
    static let epsilon = 1e-6

    /// Splits a series into continuous runs. Samples that are not finite, are negative, or are zero when
    /// `allowZero` is false are dropped. Samples are sorted by offset, and a repeated offset keeps its last value.
    static func runs(
        from samples: [SeriesSample],
        allowZero: Bool,
        maximumGap: Double = ZoneConstants.seriesMaximumGapSeconds
    ) -> [HoldRun] {
        var cleaned = samples.filter {
            $0.offsetSeconds.isFinite && $0.value.isFinite && ($0.value > 0 || (allowZero && $0.value == 0))
        }
        cleaned.sort {
            $0.offsetSeconds != $1.offsetSeconds ? $0.offsetSeconds < $1.offsetSeconds : $0.value < $1.value
        }
        var deduped: [SeriesSample] = []
        for sample in cleaned {
            if let last = deduped.last, last.offsetSeconds == sample.offsetSeconds {
                deduped[deduped.count - 1] = sample
            } else {
                deduped.append(sample)
            }
        }

        var result: [HoldRun] = []
        var times: [Double] = []
        var values: [Double] = []
        func flush() {
            if let run = HoldRun(times: times, values: values) { result.append(run) }
            times.removeAll(keepingCapacity: true)
            values.removeAll(keepingCapacity: true)
        }
        for sample in deduped {
            if let last = times.last, sample.offsetSeconds - last > maximumGap { flush() }
            times.append(sample.offsetSeconds)
            values.append(sample.value)
        }
        flush()
        return result
    }

    /// The longest continuous coverage in seconds across all runs.
    static func longestCoverage(of runs: [HoldRun]) -> Double {
        runs.map(\.coverage).max() ?? 0
    }

    /// The window of `length` seconds with the highest time weighted average inside one continuous run.
    /// The optimum of a step function always starts or ends on a sample boundary, so only those are tried.
    /// Ties keep the earliest window.
    static func bestWindow(in runs: [HoldRun], length: Double) -> (average: Double, start: Double)? {
        guard length > 0, length.isFinite else { return nil }
        var best: (average: Double, start: Double)?
        for run in runs where run.coverage + epsilon >= length {
            var starts: [Double] = []
            for t in run.times where t + length <= run.end + epsilon { starts.append(t) }
            for index in 1..<run.times.count {
                let s = run.times[index] - length
                if s >= run.start - epsilon { starts.append(s) }
            }
            let s = run.end - length
            if s >= run.start - epsilon { starts.append(s) }
            starts.sort()
            let latestStart = run.end - length
            for raw in starts {
                let candidate = min(max(raw, run.start), latestStart)
                let average = (run.integral(to: candidate + length) - run.integral(to: candidate)) / length
                if let current = best, average <= current.average + 1e-12 { continue }
                best = (average, candidate)
            }
        }
        return best
    }

    /// Time weighted average over `[from, to]` across the runs, with the number of seconds actually covered.
    static func average(in runs: [HoldRun], from: Double, to: Double) -> (average: Double, covered: Double)? {
        var area = 0.0
        var covered = 0.0
        for run in runs {
            let low = max(from, run.start)
            let high = min(to, run.end)
            if high > low {
                area += run.integral(to: high) - run.integral(to: low)
                covered += high - low
            }
        }
        guard covered > 0 else { return nil }
        return (area / covered, covered)
    }
}
