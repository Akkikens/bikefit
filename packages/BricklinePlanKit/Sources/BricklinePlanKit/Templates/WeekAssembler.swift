import Foundation

/// Everything that stays fixed while a run of weeks is generated.
struct GenerationContext {
    /// Distance whose table drives session counts and caps (the race distance, or a reference for base plans).
    let distance: RaceDistance
    let athlete: AthleteProfile
    let benchmarks: Benchmarks
    let calendar: Calendar
    /// Origin of day numbering. Week specs may start anywhere on the same seven day grid.
    let sequenceStart: Date
    /// Days before this day are not used (the part of week 0 before the requested start date). Nil uses every day.
    let earliestDay: Date?
    /// Average weekly hours the volume curve multiplies (annex B, clipped to the athlete declared hours).
    let averageHours: Double
    /// Planned sessions per sport in an ordinary week (annex B "Sessions per week", "Swims per week").
    let counts: [Sport: Int]
    let available: Set<Weekday>
    let pool: Set<Weekday>
    /// CSS in seconds per 100 m, used only to turn swim distances into durations.
    let css: Double
}

/// One session before it has a day.
struct SessionPlan {
    var id: Int
    var kind: SessionKind
    var brickRunSeconds: Double

    var sport: Sport { kind.sport }
    var longRide: Bool { kind == .bikeLong || kind == .bikeBrick }
    var longRun: Bool { kind == .runLong }
    var brick: Bool { kind == .bikeBrick }
    var priority: Int {
        if longRide { return 0 }
        if longRun { return 1 }
        if kind.isTest { return 2 }
        if kind.isQuality { return 3 }
        if sport == .swim { return 4 }
        return 5
    }
}

/// Turns week specs into planned weeks: picks the quality and test sessions (annex B), places them on the
/// athlete's days, sizes them to the week's hours and builds the steps.
struct WeekAssembler {
    let ctx: GenerationContext

    /// A recovery week is trimmed until it sits at or under this multiple of the load week before it (annex B:
    /// recovery weeks sit 30 to 40 percent below average volume; 0.8 is the loosest the shape may reach). The
    /// trim aims at 0.78 because built step durations land a little off the sized lengths.
    static let recoveryCeilingFactor = 0.78
    /// Longest single session, in seconds, in the first two weeks of a gentle start.
    static let gentleOpeningCap = 2400.0
    /// Shortest session, in seconds, in those two weeks, so the week can shrink to the eased-in size.
    static let gentleOpeningFloor = 1500.0

    // MARK: Shape

    /// Sessions per sport for an ordinary week. Returns nil when the declared days cannot host even one session
    /// of each sport.
    static func weekShape(
        distance: RaceDistance,
        level: Level,
        averageHours: Double,
        dayCount: Int,
        poolDayCount: Int
    ) -> [Sport: Int]? {
        let params = distance.parameters
        let typical: Double
        switch distance {
        case .sprint: typical = 0.95
        case .olympic: typical = 1.1
        case .half: typical = 1.35
        }
        let delta: Int
        switch level {
        case .firstTimer: delta = -1
        case .intermediate: delta = 0
        case .experienced: delta = 1
        }
        var sessions = Intensity.whole(averageHours / typical) + delta
        sessions = min(max(sessions, params.sessionsPerWeek.lowerBound), params.sessionsPerWeek.upperBound)
        var swims: Int
        switch distance {
        case .sprint: swims = sessions <= 4 ? 1 : 2
        case .olympic: swims = 2
        case .half: swims = sessions >= 8 ? 3 : 2
        }
        swims = max(min(swims, poolDayCount), 1)
        sessions = max(sessions, swims + 2)
        sessions = min(sessions, 2 * dayCount)
        guard sessions >= swims + 2 else { return nil }
        let rest = sessions - swims
        return [.swim: swims, .bike: (rest + 1) / 2, .run: rest / 2]
    }

    // MARK: Limits and weights

    private static func sportFraction(_ sport: Sport, _ distance: RaceDistance) -> Double {
        switch (distance, sport) {
        case (.sprint, .swim): return 0.20
        case (.sprint, .bike): return 0.42
        case (.sprint, .run): return 0.38
        case (.olympic, .swim): return 0.18
        case (.olympic, .bike): return 0.46
        case (.olympic, .run): return 0.36
        case (.half, .swim): return 0.15
        case (.half, .bike): return 0.50
        case (.half, .run): return 0.35
        }
    }

    private static func roleWeight(_ kind: SessionKind) -> Double {
        switch kind {
        case .swimEndurance: return 1.4
        case .swimTechnique: return 1.0
        case .swimThreshold: return 1.2
        case .swimSpeed: return 1.1
        case .bikeLong, .bikeBrick: return 2.5
        case .bikeEasy: return 1.0
        case .bikeThreshold: return 1.4
        case .bikeVO2: return 1.2
        case .bikeOpeners, .runOpeners: return 0.6
        case .runLong: return 2.0
        case .runEasy: return 1.0
        case .runThreshold: return 1.2
        case .runVO2: return 1.1
        case .swimTest, .bikeTestFTP, .bikeTestLTHR, .runTest: return 1.0
        }
    }

    /// Smallest and largest duration of a session kind, in seconds.
    private static func limits(_ kind: SessionKind, distance: RaceDistance, level: Level) -> (lo: Double, hi: Double) {
        let scale: Double
        switch level {
        case .firstTimer: scale = 0.8
        case .intermediate: scale = 1.0
        case .experienced: scale = 1.15
        }
        let longRide: Double
        let longRun: Double
        switch distance {
        case .sprint: longRide = 7200; longRun = 4800
        case .olympic: longRide = 12600; longRun = 6600
        case .half: longRide = 18000; longRun = 9000
        }
        switch kind {
        case .swimTechnique: return (1500, 5400)
        case .swimEndurance: return (1500, 6300)
        case .swimThreshold: return (2100, 5400)
        case .swimSpeed: return (2100, 4800)
        case .bikeEasy: return (1800, 7200 * scale)
        case .bikeLong, .bikeBrick: return (2700, longRide * scale)
        case .bikeThreshold, .bikeVO2: return (2700, 6300 * scale)
        case .bikeOpeners, .runOpeners: return (1500, 2400)
        case .runEasy: return (1500, 5400 * scale)
        case .runLong: return (2100, longRun * scale)
        case .runThreshold, .runVO2: return (2400, 5400 * scale)
        case .swimTest, .bikeTestFTP, .bikeTestLTHR, .runTest: return (0, 0)
        }
    }

    private static func brickRunSeconds(distance: RaceDistance, phase: Phase) -> Double {
        let peak = phase == .peak
        switch distance {
        case .sprint: return peak ? 720 : 600
        case .olympic: return peak ? 900 : 720
        case .half: return peak ? 1200 : 900
        }
    }

    // MARK: Quality

    private struct QualitySlot {
        var sport: Sport
        var ordinal: Int
    }

    private func qualitySlots(spec: WeekSpec, counts: [Sport: Int], tests: [Sport]) -> [QualitySlot] {
        if spec.isRecovery || spec.noOtherQuality { return [] }
        let level = ctx.athlete.level
        let gentle = ctx.athlete.gentleStart
        // A gentle start has no hard efforts at all: every session stays easy or steady (level 3 at most).
        if gentle { return [] }
        var capTotal = level.maxQualityPerWeek - tests.count
        if spec.phase == .taper { capTotal = min(capTotal, spec.isFinal ? 1 : 2) }
        if capTotal <= 0 { return [] }
        var wishes: [QualitySlot]
        switch spec.phase {
        case .base:
            wishes = [QualitySlot(sport: .bike, ordinal: 1), QualitySlot(sport: .run, ordinal: 1),
                      QualitySlot(sport: .swim, ordinal: 1)]
        case .build, .peak:
            let second: Sport = spec.index % 2 == 0 ? .bike : .run
            let other: Sport = second == .bike ? .run : .bike
            wishes = [QualitySlot(sport: .run, ordinal: 1), QualitySlot(sport: .bike, ordinal: 1),
                      QualitySlot(sport: .swim, ordinal: 1), QualitySlot(sport: second, ordinal: 2),
                      QualitySlot(sport: other, ordinal: 2), QualitySlot(sport: .swim, ordinal: 2)]
        case .taper:
            wishes = [QualitySlot(sport: .bike, ordinal: 1), QualitySlot(sport: .run, ordinal: 1)]
        }
        let perSportCap = (level == .firstTimer || spec.phase == .base || spec.phase == .taper)
            ? 1 : Level.maxQualityPerSport
        var taken: [Sport: Int] = [:]
        for s in tests { taken[s, default: 0] += 1 }
        var out: [QualitySlot] = []
        for wish in wishes {
            if out.count >= capTotal { break }
            if level == .firstTimer && wish.sport == .swim { continue }
            let have = taken[wish.sport, default: 0]
            if wish.ordinal != have + 1 { continue }
            if have + 1 > perSportCap { continue }
            // Keep at least one fully easy session in the sport (annex B).
            if counts[wish.sport, default: 0] - 1 < have + 1 { continue }
            taken[wish.sport] = have + 1
            out.append(wish)
        }
        return out
    }

    private func qualityKind(_ slot: QualitySlot, phase: Phase) -> SessionKind {
        if phase == .taper { return slot.sport == .bike ? .bikeOpeners : .runOpeners }
        switch (slot.sport, slot.ordinal) {
        case (.swim, 1): return .swimThreshold
        case (.swim, _): return .swimSpeed
        case (.bike, 1): return .bikeThreshold
        case (.bike, _): return .bikeVO2
        case (.run, 1): return .runThreshold
        case (.run, _): return .runVO2
        }
    }

    private func testKind(_ sport: Sport) -> SessionKind {
        switch sport {
        case .swim: return .swimTest
        case .bike: return ctx.athlete.hasPowerMeter ? .bikeTestFTP : .bikeTestLTHR
        case .run: return .runTest
        }
    }

    // MARK: Week assembly

    /// - Parameters:
    ///   - previousLoadHours: planned hours of the load week before this one. A recovery week that would exceed
    ///     0.8 times that (fixed length tests plus minimum session lengths can do it at low declared hours)
    ///     drops its lowest priority sessions, never a test and never the last session of a sport.
    ///   - warnings: receives a note for every session that was eased, dropped or trimmed.
    func assemble(
        _ spec: WeekSpec,
        history: inout [PlacedRecord],
        previousLoadHours: Double? = nil,
        warnings: inout [PlanWarning]
    ) -> PlannedWeek {
        let cal = ctx.calendar
        let weekStart = cal.startOfDay(for: spec.start)

        var weekdayOfDay: [Int: Weekday] = [:]
        var dateOfDay: [Int: Date] = [:]
        var allowedDays: [Int] = []
        var poolDays: [Int] = []
        let raceDay = spec.raceDate.map { cal.daysBetween(ctx.sequenceStart, $0) }
        for offset in 0..<7 {
            let date = cal.startOfDay(for: cal.addDays(offset, to: weekStart))
            let number = cal.daysBetween(ctx.sequenceStart, date)
            let weekday = Weekday(date: date, calendar: cal)
            weekdayOfDay[number] = weekday
            dateOfDay[number] = date
            if let earliest = ctx.earliestDay, date < earliest { continue }
            if let race = raceDay, number >= race { continue }
            if ctx.available.contains(weekday) {
                allowedDays.append(number)
                if ctx.pool.contains(weekday) { poolDays.append(number) }
            }
        }

        // Counts and tests (annex A: a tested sport also keeps an easy session).
        var counts = ctx.counts
        if spec.isFinal {
            // Race week keeps a light touch: one swim, at most two rides and two runs.
            counts[.swim] = min(counts[.swim, default: 1], 1)
            counts[.bike] = min(counts[.bike, default: 1], 2)
            counts[.run] = min(counts[.run, default: 1], 2)
        }
        var tests: [Sport] = []
        let sessionCap = min(ctx.distance.parameters.sessionsPerWeek.upperBound, 2 * allowedDays.count)
        for sport in spec.testSports where !spec.isFinal {
            if counts[sport, default: 0] >= 2 {
                tests.append(sport)
                continue
            }
            if sport == .swim && poolDays.count < 2 { continue }
            let total = counts.values.reduce(0, +)
            let donor = [Sport.bike, .run, .swim].filter { $0 != sport && counts[$0, default: 0] >= 3 }
                .max { counts[$0, default: 0] < counts[$1, default: 0] }
            if let donor = donor {
                counts[donor, default: 0] -= 1
                counts[sport, default: 0] += 1
                tests.append(sport)
            } else if total < sessionCap {
                counts[sport, default: 0] += 1
                tests.append(sport)
            }
        }

        let slots = qualitySlots(spec: spec, counts: counts, tests: tests)
        let wantBrick = (spec.phase == .build || spec.phase == .peak) && !spec.isRecovery && !spec.isFinal
        let brickSeconds = WeekAssembler.brickRunSeconds(distance: ctx.distance, phase: spec.phase)
        let longRoles = !spec.isFinal

        var plans: [SessionPlan] = []
        var nextID = 0
        func add(_ kind: SessionKind, brick: Double = 0) {
            plans.append(SessionPlan(id: nextID, kind: kind, brickRunSeconds: brick))
            nextID += 1
        }
        for sport in Sport.allCases {
            let count = counts[sport, default: 0]
            var qualityKinds: [SessionKind] = []
            if tests.contains(sport) { qualityKinds.append(testKind(sport)) }
            for slot in slots where slot.sport == sport { qualityKinds.append(qualityKind(slot, phase: spec.phase)) }
            for kind in qualityKinds { add(kind) }
            let easyCount = max(count - qualityKinds.count, 0)
            for i in 0..<easyCount {
                switch sport {
                case .swim:
                    add(i == 0 && longRoles ? .swimEndurance : .swimTechnique)
                case .bike:
                    if i == 0 && longRoles {
                        if wantBrick { add(.bikeBrick, brick: brickSeconds) } else { add(.bikeLong) }
                    } else {
                        add(.bikeEasy)
                    }
                case .run:
                    add(i == 0 && longRoles ? .runLong : .runEasy)
                }
            }
        }
        let plannedCount = plans.count

        // Place with relaxation: demote quality, then drop the lowest priority sessions.
        var placer = WeekPlacer(history: history, weekdayOfDay: weekdayOfDay, raceEve: raceDay.map { $0 - 1 })
        var solution: [Int: Int] = [:]
        while !plans.isEmpty {
            let items = plans.map { plan in
                PlacementItem(
                    id: plan.id, sport: plan.sport, quality: plan.kind.isQuality, test: plan.kind.isTest,
                    longRide: plan.longRide, longRun: plan.longRun, brick: plan.brick, priority: plan.priority,
                    allowed: plan.sport == .swim ? poolDays : allowedDays)
            }
            if let found = placer.solve(items) {
                solution = found
                break
            }
            if let i = plans.lastIndex(where: { $0.kind.isQuality && !$0.kind.isTest }) {
                warnings.append(.qualityEased(
                    weekIndex: spec.outputIndex, name: SessionLibrary.name(for: plans[i].kind, runWalk: ctx.athlete.prefersRunWalk)))
                plans[i].kind = plans[i].kind.easyCounterpart
                continue
            }
            if let i = plans.lastIndex(where: { $0.kind.isTest }) {
                warnings.append(.qualityEased(
                    weekIndex: spec.outputIndex, name: SessionLibrary.name(for: plans[i].kind, runWalk: ctx.athlete.prefersRunWalk)))
                plans[i].kind = plans[i].kind.easyCounterpart
                continue
            }
            var worst = 0
            for i in plans.indices where plans[i].priority >= plans[worst].priority { worst = i }
            warnings.append(.sessionDropped(
                weekIndex: spec.outputIndex, name: SessionLibrary.name(for: plans[worst].kind, runWalk: ctx.athlete.prefersRunWalk)))
            plans.remove(at: worst)
        }

        // Size sessions to the week's hours.
        let runWalk = ctx.athlete.prefersRunWalk
        let buildContext = { (brickRun: Double) -> BuildContext in
            BuildContext(
                level: ctx.athlete.level, phase: spec.phase, distance: ctx.distance, runWalk: runWalk, css: ctx.css,
                allowSteady: !spec.isRecovery && spec.phase != .taper && !(ctx.athlete.gentleStart && spec.phase == .base),
                brickRunSeconds: brickRun)
        }
        /// Sizes the variable sessions for the plans that remain, and totals the whole week in seconds.
        // A gentle start eases in: the first two weeks carry a fraction of the volume and no session over 40 minutes.
        let gentleRamp: (factor: Double, cap: Double)? = {
            guard ctx.athlete.gentleStart, !spec.isRecovery else { return nil }
            switch spec.outputIndex {
            case 0: return (0.70, WeekAssembler.gentleOpeningCap)
            case 1: return (0.85, WeekAssembler.gentleOpeningCap)
            default: return nil
            }
        }()
        func sizeSessions(_ current: [SessionPlan]) -> (sizes: [Int: Double], total: Double) {
            var fixedTotal = 0.0
            var fixedIDs = Set<Int>()
            for plan in current {
                if plan.kind.isTest {
                    fixedTotal += StepFactory.total(StepFactory.build(plan.kind, seconds: 0, ctx: buildContext(0)).steps)
                    fixedIDs.insert(plan.id)
                } else if plan.brick {
                    fixedTotal += plan.brickRunSeconds
                }
            }
            var share = plannedCount > 0 ? Double(current.count) / Double(plannedCount) : 1
            if share.isNaN { share = 1 }
            let target = spec.hoursFactor * (gentleRamp?.factor ?? 1) * ctx.averageHours * 3600 * share
            let variable = current.filter { !fixedIDs.contains($0.id) }
            let presentSports = Set(variable.map { $0.sport })
            let fractionSum = presentSports.map { WeekAssembler.sportFraction($0, ctx.distance) }.reduce(0, +)
            var roleSum: [Sport: Double] = [:]
            for plan in variable { roleSum[plan.sport, default: 0] += WeekAssembler.roleWeight(plan.kind) }
            var weights: [Double] = []
            var lows: [Double] = []
            var highs: [Double] = []
            for plan in variable {
                let sportShare = fractionSum > 0 ? WeekAssembler.sportFraction(plan.sport, ctx.distance) / fractionSum : 1
                let denominator = roleSum[plan.sport, default: 1]
                weights.append(sportShare * WeekAssembler.roleWeight(plan.kind) / max(denominator, 0.001))
                let lim = WeekAssembler.limits(plan.kind, distance: ctx.distance, level: ctx.athlete.level)
                // Recovery and taper weeks shrink the long sessions too, not just the short ones.
                var low = lim.lo
                var high = lim.hi * min(1.0, spec.hoursFactor)
                if let ramp = gentleRamp {
                    low = min(low, WeekAssembler.gentleOpeningFloor)
                    high = min(high, ramp.cap)
                }
                lows.append(low)
                // Race week sessions stay short so the legs arrive fresh.
                if spec.isFinal { high = min(high, 3000) }
                highs.append(max(low, high))
            }
            let allocated = WeekAssembler.allocate(weights: weights, lows: lows, highs: highs, total: max(target - fixedTotal, 0))
            var byID: [Int: Double] = [:]
            for (i, plan) in variable.enumerated() { byID[plan.id] = allocated[i] }
            return (byID, fixedTotal + allocated.reduce(0, +))
        }

        var (sizeByID, weekSeconds) = sizeSessions(plans)
        if spec.isRecovery, let previous = previousLoadHours, previous > 0 {
            let ceiling = WeekAssembler.recoveryCeilingFactor * previous * 3600
            while weekSeconds > ceiling {
                var perSport: [Sport: Int] = [:]
                for plan in plans { perSport[plan.sport, default: 0] += 1 }
                let droppable = plans.indices.filter { !plans[$0].kind.isTest && perSport[plans[$0].sport, default: 0] > 1 }
                guard let victim = droppable.max(by: { a, b in
                    if plans[a].priority != plans[b].priority { return plans[a].priority < plans[b].priority }
                    return (sizeByID[plans[a].id] ?? 0) < (sizeByID[plans[b].id] ?? 0)
                }) else { break }
                warnings.append(.recoveryWeekTrimmed(
                    weekIndex: spec.outputIndex,
                    name: SessionLibrary.name(for: plans[victim].kind, runWalk: ctx.athlete.prefersRunWalk)))
                plans.remove(at: victim)
                (sizeByID, weekSeconds) = sizeSessions(plans)
            }
        }

        // Build the sessions.
        var days: [Date: [Session]] = [:]
        var hours = 0.0
        var anyTest = false
        var records: [PlacedRecord] = []
        let ordered = plans.sorted {
            let da = solution[$0.id] ?? 0
            let db = solution[$1.id] ?? 0
            if da != db { return da < db }
            return $0.sport.sortRank < $1.sport.sortRank
        }
        for plan in ordered {
            guard let dayNumber = solution[plan.id], let date = dateOfDay[dayNumber] else { continue }
            let seconds = sizeByID[plan.id] ?? 0
            let built = StepFactory.build(plan.kind, seconds: seconds, ctx: buildContext(plan.brickRunSeconds))
            let existing = days[date] ?? []
            let slot = existing.filter { $0.sport == plan.sport }.count + 1
            let session = Session(
                id: SessionID.make(weekIndex: spec.outputIndex, date: date, sport: plan.sport, slot: slot, calendar: cal),
                sport: plan.sport,
                name: SessionLibrary.name(for: plan.kind, runWalk: runWalk),
                purpose: SessionLibrary.purpose(for: plan.kind, runWalk: runWalk),
                steps: built.steps,
                state: .planned,
                scheduledDate: date,
                brickSecondSport: built.brickSecondSport,
                isQuality: plan.kind.isQuality,
                isTest: plan.kind.isTest,
                benchmarkKind: plan.kind.benchmarkKind,
                isOpenWater: false,
                poolAlternativeSteps: []
            )
            days[date, default: []].append(session)
            hours += session.durationHours
            if plan.kind.isTest { anyTest = true }
            records.append(PlacedRecord(
                day: dayNumber, sport: plan.sport, quality: plan.kind.isQuality, test: plan.kind.isTest,
                longRide: plan.longRide, longRun: plan.longRun, brick: plan.brick))
        }
        history.append(contentsOf: records)
        let plannedHours = (hours * 100).rounded() / 100
        return PlannedWeek(
            index: spec.outputIndex,
            startDate: weekStart,
            phase: spec.phase,
            isRecovery: spec.isRecovery,
            isTest: anyTest,
            days: days,
            plannedHours: plannedHours,
            designedHours: plannedHours
        )
    }

    /// Water filling: scales the weights until the clamped durations add up to `total`, then rounds each to
    /// five minutes inside its own limits.
    static func allocate(weights: [Double], lows: [Double], highs: [Double], total: Double) -> [Double] {
        guard !weights.isEmpty else { return [] }
        func at(_ scale: Double) -> [Double] {
            weights.indices.map { min(max(weights[$0] * scale, lows[$0]), highs[$0]) }
        }
        let sumLow = lows.reduce(0, +)
        let sumHigh = highs.reduce(0, +)
        var raw: [Double]
        if total <= sumLow {
            raw = lows
        } else if total >= sumHigh {
            raw = highs
        } else {
            var a = 0.0
            var b = 1.0e8
            for _ in 0..<80 {
                let mid = (a + b) / 2
                if at(mid).reduce(0, +) < total { a = mid } else { b = mid }
            }
            raw = at(b)
        }
        return raw.indices.map { i in
            let rounded = (raw[i] / 300).rounded() * 300
            return min(max(rounded, lows[i]), highs[i])
        }
    }
}

extension Sport {
    /// Stable order for same day sessions: swim, bike, run.
    var sortRank: Int {
        switch self {
        case .swim: return 0
        case .bike: return 1
        case .run: return 2
        }
    }
}
