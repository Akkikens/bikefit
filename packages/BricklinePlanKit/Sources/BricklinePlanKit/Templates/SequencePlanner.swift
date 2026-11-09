import Foundation

/// The plan for one week before any session exists: phase, recovery, tests and the volume factor.
struct WeekSpec {
    /// Position in the generated sequence (day numbers are relative to the sequence start).
    var index: Int
    /// Week index written into the plan and into session ids.
    var outputIndex: Int
    var start: Date
    var phase: Phase
    var isRecovery: Bool
    /// Sports whose maximal effort test is scheduled this week (annex A retest rotation).
    var testSports: [Sport]
    /// Opening or overflow test weeks carry no other quality session.
    var noOtherQuality: Bool
    /// Weekly volume as a multiple of the average weekly hours (annex B).
    var hoursFactor: Double
    /// Race day, set only on the final week of a race plan.
    var raceDate: Date?
    var isFinal: Bool
}

/// Phases, recovery weeks, volume curve and test rotation for a whole plan (annex A and annex B).
enum SequencePlanner {
    /// Recovery weeks sit 30 to 40 percent below average volume (annex B). The midpoint, 35 percent.
    static let recoveryFactor = 0.65
    /// Largest week over week step in hours between load weeks inside the template. Planned Load grows a little
    /// faster than hours (later weeks carry more quality), so the hours step stays well under the 10 percent of
    /// annex C rule 5; the property test checks the designed Load ratio stays within 12 percent.
    static let maxTemplateRamp = 1.05
    /// First peak week as a multiple of the average hours (annex B: peak weeks 20 to 30 percent above).
    static let firstPeakFactor = 1.22
    /// Days a fresh test keeps a sport out of the next test week.
    static let freshTestDays = 28

    /// Taper weeks per distance, inside the published span of annex B.
    static func taperWeeks(distance: RaceDistance, weekCount n: Int) -> Int {
        switch distance {
        case .sprint: return 1
        case .olympic: return n >= 13 ? 2 : 1
        case .half: return n >= 22 ? 3 : 2
        }
    }

    /// Volume factors for the taper weeks, first to last.
    static func taperFactors(_ count: Int) -> [Double] {
        switch count {
        case 1: return [0.50]
        case 2: return [0.75, 0.45]
        case 3: return [0.85, 0.65, 0.40]
        default:
            return (0..<count).map { max(0.4, 0.9 - 0.15 * Double($0)) }
        }
    }

    /// Order in which sports sit out test weeks: the most recently tested sits out first, ties run, bike, swim.
    static func sitOutOrder(_ benchmarks: Benchmarks) -> [Sport] {
        func rank(_ s: Sport) -> Int {
            switch s {
            case .run: return 0
            case .bike: return 1
            case .swim: return 2
            }
        }
        return Sport.allCases.sorted { a, b in
            let da = benchmarks.lastTestDate(for: a)
            let db = benchmarks.lastTestDate(for: b)
            switch (da, db) {
            case let (x?, y?):
                if x != y { return x > y }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return rank(a) < rank(b)
        }
    }

    /// Sports to test in the `t`th rotation test week starting on `weekStart`: all but the sport sitting out,
    /// minus any sport tested inside the last 28 days.
    static func rotationTests(
        t: Int,
        weekStart: Date,
        benchmarks: Benchmarks,
        order: [Sport],
        calendar: Calendar
    ) -> [Sport] {
        guard !order.isEmpty else { return [] }
        let sitOut = order[t % order.count]
        return Sport.allCases.filter { sport in
            guard sport != sitOut else { return false }
            if let last = benchmarks.lastTestDate(for: sport), calendar.daysBetween(last, weekStart) < freshTestDays {
                return false
            }
            return true
        }
    }

    /// Sports that need a test at the opening of a short sprint plan (never tested, estimated only, or stale).
    static func openingTests(start: Date, benchmarks: Benchmarks, calendar: Calendar) -> [Sport] {
        Sport.allCases.filter { sport in
            guard let last = benchmarks.lastTestDate(for: sport) else { return true }
            return calendar.daysBetween(last, start) >= freshTestDays
        }
    }

    // MARK: Race plan

    /// Builds the week specs of a race plan of `n` weeks whose last week contains `raceDate`.
    static func raceSequence(
        distance: RaceDistance,
        weekCount n: Int,
        start: Date,
        outputOffset: Int,
        raceDate: Date,
        level: Level,
        gentle: Bool = false,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) -> [WeekSpec] {
        guard n > 0 else { return [] }
        let finalStart = calendar.addDays(7 * (n - 1), to: start)
        let trainingDaysInFinalWeek = max(calendar.daysBetween(finalStart, raceDate), 0)
        var taper = taperWeeks(distance: distance, weekCount: n)
        if trainingDaysInFinalWeek < 3 { taper += 1 }
        taper = min(taper, max(n - 3, 1))
        let pre = n - taper

        // Phase sizes (annex B): about 15 percent peak, 30 build, the rest of the pre taper weeks base,
        // which lands near 40 to 50 percent for typical lengths.
        var peakCount = max(1, Intensity.whole(Double(n) * 0.15))
        var buildCount = max(1, Intensity.whole(Double(n) * 0.30))
        while pre - peakCount - buildCount < 2 && (peakCount > 1 || buildCount > 1) {
            if buildCount > 1 { buildCount -= 1 } else { peakCount -= 1 }
        }
        let baseCount = max(pre - peakCount - buildCount, 1)

        var phases: [Phase] = []
        for k in 0..<n {
            if k < baseCount { phases.append(.base) }
            else if k < baseCount + buildCount { phases.append(.build) }
            else if k < pre { phases.append(.peak) }
            else { phases.append(.taper) }
        }

        // 3 plus 1 blocks: every fourth week recovers. The last week before the taper stays a load week, so when
        // the fourth week of a block would land exactly there, the recovery moves one week earlier. That keeps
        // every run of load weeks at three or fewer (annex B).
        // A gentle start recovers after every second load week instead (2 plus 1), so first timers get more easy weeks.
        let blockLength = gentle ? 3 : 4
        var recovery = [Bool](repeating: false, count: n)
        for k in 0..<pre where (k + 1) % blockLength == 0 {
            if k == pre - 1 {
                if k >= 1, !recovery[k - 1] { recovery[k - 1] = true }
            } else {
                recovery[k] = true
            }
        }

        // Volume curve (annex B): load weeks ramp, peak weeks sit 20 to 30 percent above average.
        var factors = [Double](repeating: 1, count: n)
        let peakLoad = (0..<pre).filter { phases[$0] == .peak && !recovery[$0] }
        let preLoad = (0..<pre).filter { phases[$0] != .peak && !recovery[$0] }
        for (j, k) in peakLoad.enumerated() {
            factors[k] = peakLoad.count == 1 ? firstPeakFactor : firstPeakFactor + 0.06 * Double(j) / Double(peakLoad.count - 1)
        }
        let firstPeak = peakLoad.first.map { factors[$0] } ?? 1.2
        var next = firstPeak
        var linear: [Double] = []
        if preLoad.count == 1 {
            linear = [1.0]
        } else {
            for i in 0..<preLoad.count {
                linear.append(0.85 + 0.27 * Double(i) / Double(max(preLoad.count - 1, 1)))
            }
        }
        for i in stride(from: preLoad.count - 1, through: 0, by: -1) {
            let value = max(linear[i], next / maxTemplateRamp)
            factors[preLoad[i]] = value
            next = value
        }
        for k in 0..<pre where recovery[k] { factors[k] = recoveryFactor }
        let taperValues = taperFactors(taper)
        for (i, k) in (pre..<n).enumerated() { factors[k] = taperValues[min(i, taperValues.count - 1)] }

        // Tests (annex A): sprint plans open with a full test week, then every recovery week on a block boundary
        // rotates which sport sits out.
        var tests = [[Sport]](repeating: [], count: n)
        var noOther = [Bool](repeating: false, count: n)
        var rotationWeeks: [Int] = (0..<pre).filter { recovery[$0] && phases[$0] != .taper }
        // A gentle start never tests: maximal efforts wait until the athlete has a base. Estimates stand in.
        if gentle { rotationWeeks = [] }
        if distance == .sprint && !gentle {
            let needed = openingTests(start: start, benchmarks: benchmarks, calendar: calendar)
            if !needed.isEmpty {
                let cap = level.maxQualityPerWeek
                let ordered = [Sport.swim, .bike, .run].filter { needed.contains($0) }
                tests[0] = Array(ordered.prefix(cap))
                noOther[0] = true
                if ordered.count > cap, n > 1 {
                    tests[1] = Array(ordered.dropFirst(cap))
                    noOther[1] = true
                }
                rotationWeeks = rotationWeeks.filter { $0 >= 7 }
            }
        }
        let order = sitOutOrder(benchmarks)
        var t = 0
        for k in rotationWeeks {
            let weekStart = calendar.addDays(7 * k, to: start)
            let picked = rotationTests(t: t, weekStart: weekStart, benchmarks: benchmarks, order: order, calendar: calendar)
            t += 1
            tests[k] = picked
        }

        return (0..<n).map { k in
            WeekSpec(
                index: k,
                outputIndex: outputOffset + k,
                start: calendar.addDays(7 * k, to: start),
                phase: phases[k],
                isRecovery: recovery[k],
                testSports: tests[k],
                noOtherQuality: noOther[k],
                hoursFactor: factors[k],
                raceDate: k == n - 1 ? raceDate : nil,
                isFinal: k == n - 1
            )
        }
    }

    // MARK: Base plan

    /// A rolling base block of `count` weeks (default 4): load weeks, then a recovery week that is also the
    /// test week (annex B "No race yet mode").
    static func baseSequence(
        count: Int,
        start: Date,
        outputOffset: Int,
        gentle: Bool = false,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) -> [WeekSpec] {
        guard count > 0 else { return [] }
        let order = sitOutOrder(benchmarks)
        var t = 0
        var out: [WeekSpec] = []
        // A gentle start recovers after every second load week (2 plus 1), the same as the race plan path.
        let blockLength = gentle ? 3 : 4
        for k in 0..<count {
            let isRecovery = (k + 1) % blockLength == 0
            let weekStart = calendar.addDays(7 * k, to: start)
            var tests: [Sport] = []
            if isRecovery && !gentle {
                tests = rotationTests(t: t, weekStart: weekStart, benchmarks: benchmarks, order: order, calendar: calendar)
                t += 1
            }
            let position = k % blockLength
            let factor: Double
            if isRecovery {
                factor = recoveryFactor
            } else {
                factor = [0.85, 0.93, 1.0, 1.0][position]
            }
            out.append(WeekSpec(
                index: k,
                outputIndex: outputOffset + k,
                start: weekStart,
                phase: .base,
                isRecovery: isRecovery,
                testSports: tests,
                noOtherQuality: false,
                hoursFactor: factor,
                raceDate: nil,
                isFinal: false
            ))
        }
        return out
    }
}
