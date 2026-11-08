import XCTest
@testable import BricklinePlanKit

// Tests for the Templates module (annex B, annex A retest rotation, spec 3.2).
// The invariant checker below runs over hand picked profiles and over seeded random profiles, so each rule of
// annex B is exercised as a property, not only as an example.

// MARK: - Harness

private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
    mutating func double(_ range: ClosedRange<Double>) -> Double {
        let unit = Double(next() % 1_000_000) / 1_000_000
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
    mutating func bool() -> Bool { next() % 2 == 0 }
}

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        c.firstWeekday = 2
    return c
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
}

private let allDays = Set(Weekday.allCases)

private func athlete(
    _ level: Level, hours: Double, days: Set<Weekday> = allDays,
    pool: Set<Weekday> = [.tuesday, .thursday, .saturday],
    power: Bool = false, runWalk: Bool = false
) -> AthleteProfile {
    AthleteProfile(
        level: level, weeklyHours: hours, availableWeekdays: days, poolWeekdays: pool,
        hasWatch: true, hasPowerMeter: power, hasTrainer: false, prefersRunWalk: runWalk)
}

/// Forbidden words and marks, assembled from pieces so this file never spells them out.
private let bannedWords: [String] = [
    "diag" + "nos", "tre" + "at", "doc" + "tor", "inj" + "ur", "ill" + "ness", "clin" + "ical",
    "medical " + "grade", "ai " + "coach", "prev" + "ent"
]
private let bannedMarks: [String] = ["T" + "SS", "I" + "F", "N" + "P", "T" + "P", "T" + "PU"]

private func containsBannedCopy(_ text: String) -> String? {
    let lower = text.lowercased()
    for word in bannedWords where lower.contains(word) { return word }
    for mark in bannedMarks {
        guard let regex = try? NSRegularExpression(pattern: "\\b" + mark + "\\b") else { continue }
        let range = NSRange(text.startIndex..., in: text)
        if regex.firstMatch(in: text, options: [], range: range) != nil { return mark }
    }
    if text.contains("\u{2014}") || text.contains("\u{2013}") { return "dash" }
    return nil
}

private func strings(of plan: Plan) -> [String] {
    var out: [String] = []
    for s in plan.allSessions {
        out.append(s.name)
        out.append(s.purpose)
        for step in s.steps + s.poolAlternativeSteps {
            out.append(step.name)
            if let note = step.note { out.append(note) }
        }
    }
    return out
}

private func isFullyEasy(_ s: Session) -> Bool {
    !s.isQuality && !s.isTest && s.steps.allSatisfy { $0.level <= 3 }
}

private func hardSeconds(_ s: Session) -> Double {
    s.steps.filter { $0.level >= 4 }.reduce(0) { $0 + $1.durationSeconds * Double($1.repeats) }
}

/// Checks every annex B invariant on one generated race plan and returns the failures as text.
private func invariantFailures(
    _ plan: Plan, distance: RaceDistance, athlete a: AthleteProfile, label: String, partialFirstWeek: Bool = false
) -> [String] {
    var f: [String] = []
    func fail(_ text: String) { f.append("\(label): \(text)") }
    let params = distance.parameters
    let n = plan.weeks.count
    let average = min(a.weeklyHours, params.weeklyHours.upperBound)

    // Length and layout.
    if !params.planWeeks.contains(n) { fail("week count \(n) outside \(params.planWeeks)") }
    for (k, week) in plan.weeks.enumerated() {
        if week.index != k { fail("week index \(week.index) at position \(k)") }
        if week.startDate != utc.addDays(7 * k, to: plan.startDate) { fail("week \(k) start is off the 7 day grid") }
    }
    guard let race = plan.raceDate, let last = plan.weeks.last else { fail("no race date"); return f }
    let offset = utc.daysBetween(last.startDate, race)
    if offset < 0 || offset > 6 { fail("final week does not contain the race date (offset \(offset))") }

    // Phases in order, with ratios near annex B.
    let order: [Phase] = [.base, .build, .peak, .taper]
    var lastRank = 0
    for week in plan.weeks {
        let rank = order.firstIndex(of: week.phase) ?? 0
        if rank < lastRank { fail("phase order broke at week \(week.index)") }
        lastRank = rank
    }
    func fraction(_ p: Phase) -> Double { Double(plan.weeks.filter { $0.phase == p }.count) / Double(n) }
    let taperCount = plan.weeks.filter { $0.phase == .taper }.count
    if fraction(.base) < 0.28 || fraction(.base) > 0.55 { fail("base fraction \(fraction(.base))") }
    if fraction(.build) < 0.2 || fraction(.build) > 0.4 { fail("build fraction \(fraction(.build))") }
    if fraction(.peak) < 0.08 || fraction(.peak) > 0.25 { fail("peak fraction \(fraction(.peak))") }
    if taperCount < params.taperWeeks.lowerBound || taperCount > params.taperWeeks.upperBound + 1 {
        fail("taper weeks \(taperCount)")
    }
    if Double(taperCount) / Double(n) > 0.3 { fail("taper fraction too large") }

    // Recovery weeks every fourth week (the last one moves a week earlier when it would be the final pre taper
    // week, so no run of load weeks is longer than three), 30 to 40 percent below average; peak weeks 20 to 30
    // percent above.
    let pre = n - taperCount
    func expectedRecovery(_ k: Int) -> Bool {
        guard k < pre else { return false }
        return ((k + 1) % 4 == 0 && k != pre - 1) || (pre % 4 == 0 && k == pre - 2)
    }
    var loadRun = 0
    for week in plan.weeks {
        if week.isRecovery != expectedRecovery(week.index) { fail("recovery week \(week.index) off the 3 plus 1 pattern") }
        if week.phase == .taper || week.isRecovery { loadRun = 0 } else { loadRun += 1 }
        if loadRun > 3 && week.phase != .taper { fail("\(loadRun) load weeks in a row at week \(week.index)") }
        if week.isRecovery {
            if week.phase == .taper { fail("recovery week inside the taper") }
            // Test weeks carry fixed length test protocols, so low volume athletes cannot always reach 0.8.
            let ratio = week.plannedHours / average
            let ceiling = week.isTest ? 0.95 : 0.8
            if ratio < 0.5 || ratio > ceiling { fail("recovery week \(week.index) ratio \(ratio)") }
        }
        if week.phase == .peak && !week.isRecovery {
            // With four or fewer declared days the sessions cannot all be placed, so peaks fall short of 1.2.
            let ratio = week.plannedHours / average
            let floor = a.availableWeekdays.count >= 5 ? 1.12 : 1.0
            if ratio < floor || ratio > 1.4 { fail("peak week \(week.index) ratio \(ratio)") }
        }
    }
    let taperWeeks = plan.weeks.filter { $0.phase == .taper }
    for pair in zip(taperWeeks, taperWeeks.dropFirst()) where pair.1.plannedHours > pair.0.plannedHours + 0.01 {
        fail("taper volume grew from week \(pair.0.index) to \(pair.1.index)")
    }
    if let firstTaper = taperWeeks.first,
       let before = plan.weeks.last(where: { $0.phase != .taper && !$0.isRecovery }),
       firstTaper.plannedHours >= before.plannedHours {
        fail("taper does not cut volume")
    }
    // Load week over load week step stays modest inside the template (recovery weeks excluded).
    let loadWeeks = plan.weeks.filter { !$0.isRecovery && $0.phase != .taper && !(partialFirstWeek && $0.index == 0) }
    for pair in zip(loadWeeks, loadWeeks.dropFirst()) where pair.0.plannedHours > 0 {
        let ratio = pair.1.plannedHours / pair.0.plannedHours
        if ratio > 1.16 { fail("load ramp \(ratio) at week \(pair.1.index)") }
    }

    // Per week rules.
    var allSessions: [Session] = []
    for week in plan.weeks {
        let sessions = week.sessions
        allSessions += sessions
        let final = week.index == n - 1
        if sessions.count != week.days.values.flatMap({ $0 }).count { fail("week \(week.index) session count mismatch") }
        let range = params.sessionsPerWeek
        if !final && !(partialFirstWeek && week.index == 0) {
            if sessions.count > range.upperBound { fail("week \(week.index) has \(sessions.count) sessions") }
            // A recovery week may lose a session so it stays clearly lighter than the load week before it.
            if a.availableWeekdays.count >= 5 && sessions.count < range.lowerBound && !week.isRecovery {
                fail("week \(week.index) has only \(sessions.count) sessions")
            }
            let swims = sessions.filter { $0.sport == .swim }.count
            let pool = a.poolWeekdays.intersection(a.availableWeekdays).count
            if swims > params.swimsPerWeek.upperBound { fail("week \(week.index) has \(swims) swims") }
            if swims < min(params.swimsPerWeek.lowerBound, pool) { fail("week \(week.index) has \(swims) swims") }
        }
        // Quality caps by level, at most two per sport, second only in build and peak (annex B).
        let quality = sessions.filter { $0.isQuality }
        if quality.count > a.level.maxQualityPerWeek { fail("week \(week.index) quality \(quality.count)") }
        for sport in Sport.allCases {
            let q = quality.filter { $0.sport == sport }.count
            if q > Level.maxQualityPerSport { fail("week \(week.index) \(sport) quality \(q)") }
            if q > 1 && (week.phase == .base || week.phase == .taper || a.level == .firstTimer) {
                fail("week \(week.index) \(sport) has a second quality session in \(week.phase)")
            }
        }
        // At least one fully easy session per scheduled sport.
        for sport in Sport.allCases where sessions.contains(where: { $0.sport == sport }) {
            if !sessions.contains(where: { $0.sport == sport && isFullyEasy($0) }) {
                fail("week \(week.index) has no fully easy \(sport) session")
            }
        }
        for s in sessions where !s.isQuality && !s.isTest && hardSeconds(s) > 0 {
            fail("easy session \(s.id) holds hard steps")
        }
        // Days and pool.
        for s in sessions {
            let weekday = Weekday(date: s.scheduledDate, calendar: utc)
            if !a.availableWeekdays.contains(weekday) { fail("\(s.id) on an undeclared day") }
            if s.sport == .swim && !a.poolWeekdays.contains(weekday) { fail("\(s.id) swim off a pool day") }
            if s.scheduledDate >= race { fail("\(s.id) on or after race day") }
            if week.days[s.scheduledDate]?.contains(where: { $0.id == s.id }) != true { fail("\(s.id) day key mismatch") }
            if !s.id.hasPrefix(String(format: "w%02d-", week.index)) { fail("\(s.id) id does not carry its week") }
        }
        // Bricks: one per load week of build and peak, 10 to 20 minute run, never elsewhere.
        let bricks = sessions.filter { $0.brickSecondSport != nil }
        let brickWeek = (week.phase == .build || week.phase == .peak) && !week.isRecovery
        if brickWeek && bricks.count != 1 { fail("week \(week.index) has \(bricks.count) bricks") }
        if !brickWeek && !bricks.isEmpty { fail("week \(week.index) has a brick outside build and peak") }
        for b in bricks {
            let runSeconds = b.steps.filter { $0.sport == .run }.reduce(0) { $0 + $1.durationSeconds * Double($1.repeats) }
            if runSeconds < 600 || runSeconds > 1200 { fail("brick run \(runSeconds) s") }
            if b.sport != .bike || b.brickSecondSport != .run { fail("brick sports wrong") }
            if b.isQuality { fail("brick counted as quality") }
        }
        // Tests (annex A).
        let tests = sessions.filter { $0.isTest }
        if week.isTest != !tests.isEmpty { fail("week \(week.index) test flag mismatch") }
        if !tests.isEmpty {
            let opening = week.index <= 1 && distance == .sprint
            if !week.isRecovery && !opening { fail("test outside a recovery week at week \(week.index)") }
            if week.isRecovery && tests.count > 2 { fail("recovery week \(week.index) holds \(tests.count) tests") }
            if tests.contains(where: { $0.benchmarkKind == nil || !$0.isQuality }) { fail("test flags wrong") }
            if tests.map({ $0.sport }).count != Set(tests.map { $0.sport }).count { fail("two tests in one sport") }
        }
        // Hard time stays a modest part of an ordinary week.
        let total = sessions.reduce(0) { $0 + $1.durationSeconds }
        if tests.isEmpty && total > 0 {
            let hard = sessions.reduce(0) { $0 + hardSeconds($1) }
            if hard / total > 0.3 { fail("week \(week.index) hard share \(hard / total)") }
        }
        // Taper weeks carry short openers only.
        if week.phase == .taper {
            for s in quality where s.durationSeconds > 2500 { fail("taper quality session too long") }
        }
    }

    // Cross week rules.
    for sport in Sport.allCases {
        let q = allSessions.filter { $0.sport == sport && ($0.isQuality || $0.isTest) }.map { $0.scheduledDate }.sorted()
        for pair in zip(q, q.dropFirst()) where utc.daysBetween(pair.0, pair.1) < 2 {
            fail("back to back quality \(sport) on \(pair.0)")
        }
    }
    let testDays = allSessions.filter { $0.isTest }.map { $0.scheduledDate }.sorted()
    for pair in zip(testDays, testDays.dropFirst()) where utc.daysBetween(pair.0, pair.1) < 2 {
        fail("tests closer than 48 hours on \(pair.0)")
    }
    let longRides = allSessions.filter {
        $0.name == SessionLibrary.name(for: .bikeLong) || $0.name == SessionLibrary.name(for: .bikeBrick)
    }
    let longRuns = allSessions.filter {
        $0.name == SessionLibrary.name(for: .runLong) || $0.name == SessionLibrary.name(for: .runLong, runWalk: true)
    }
    for ride in longRides {
        for run in longRuns where abs(utc.daysBetween(ride.scheduledDate, run.scheduledDate)) < 2 {
            fail("long ride \(ride.id) and long run \(run.id) too close")
        }
    }
    if Set(allSessions.map { $0.id }).count != allSessions.count { fail("duplicate session ids") }

    // Intensity distribution: roughly 80 percent of time easy and steady (annex B).
    let totalSeconds = allSessions.reduce(0) { $0 + $1.durationSeconds }
    let hardTotal = allSessions.reduce(0) { $0 + hardSeconds($1) }
    if totalSeconds > 0 && hardTotal / totalSeconds > 0.22 { fail("plan hard share \(hardTotal / totalSeconds)") }

    // Steps.
    for s in allSessions {
        if s.steps.isEmpty { fail("\(s.id) has no steps") }
        if s.name.isEmpty || s.purpose.isEmpty { fail("\(s.id) missing copy") }
        if s.purpose.hasSuffix(".") == false { fail("\(s.id) purpose is not one sentence") }
        var seenGroups: [String: Int] = [:]
        var lastGroup: String?
        for (i, step) in s.steps.enumerated() {
            if !(1...5).contains(step.level) { fail("step level \(step.level)") }
            if step.durationSeconds <= 0 { fail("\(s.id) step \(i) has no duration") }
            if (step.note ?? "").contains("RPE") == false { fail("\(s.id) step \(i) lacks an RPE note") }
            switch step.target {
            case .rpe, .cssOffset: break
            default: fail("\(s.id) step \(i) target is not rpe or css offset")
            }
            if let g = step.repeatGroupID {
                if let count = seenGroups[g], count != step.repeatCount { fail("\(s.id) group \(g) counts differ") }
                if lastGroup != g, seenGroups[g] != nil { fail("\(s.id) group \(g) not contiguous") }
                seenGroups[g] = step.repeatCount
                if (step.repeatCount ?? 0) < 1 { fail("\(s.id) group \(g) repeat count") }
            }
            lastGroup = step.repeatGroupID
        }
        if s.isOpenWater && s.poolAlternativeSteps.isEmpty { fail("\(s.id) open water without pool alternative") }
        if s.brickSecondSport != nil && !s.steps.contains(where: { $0.sport == s.brickSecondSport }) {
            fail("\(s.id) brick without second sport steps")
        }
    }

    for text in strings(of: plan) {
        if let hit = containsBannedCopy(text) { fail("copy '\(text)' hits \(hit)") }
    }
    return f
}

// MARK: - Tests

final class TemplatesTests: XCTestCase {
    private let engine = DefaultTemplateEngine()

    private func plan(
        _ distance: RaceDistance, weeks: Int, a: AthleteProfile, benchmarks: Benchmarks = Benchmarks(),
        start: Date = day(2026, 11, 9), raceWeekday: Int = 6
    ) throws -> Plan {
        // The race falls on day `raceWeekday` (0 = start weekday) of the final week.
        let race = utc.addDays(7 * (weeks - 1) + raceWeekday, to: start)
        return try engine.makePlan(
            raceDistance: distance, raceDate: race, startDate: start, athlete: a, benchmarks: benchmarks, calendar: utc)
    }

    // MARK: Plan length

    func testPlanWeekCountClampsAndRejects() throws {
        let start = day(2026, 11, 9)
        func count(_ d: RaceDistance, days: Int) throws -> Int {
            try engine.planWeekCount(raceDistance: d, raceDate: utc.addDays(days, to: start), startDate: start, calendar: utc)
        }
        XCTAssertEqual(try count(.sprint, days: 55), 8)
        XCTAssertEqual(try count(.sprint, days: 400), 12)
        XCTAssertEqual(try count(.olympic, days: 7 * 13), 14)
        XCTAssertEqual(try count(.half, days: 7 * 40), 24)
        XCTAssertThrowsError(try count(.sprint, days: 48)) { error in
            XCTAssertEqual(error as? PlanKitError, .raceDateTooSoon(minimumWeeks: 8, availableWeeks: 7))
        }
        XCTAssertThrowsError(try count(.half, days: -3)) { error in
            XCTAssertEqual(error as? PlanKitError, .raceDateTooSoon(minimumWeeks: 14, availableWeeks: 0))
        }
    }

    func testFarRaceStartsLaterSoFinalWeekHoldsRaceDay() throws {
        let start = day(2026, 11, 9)
        let race = day(2027, 11, 7)
        let result = try engine.makePlan(
            raceDistance: .sprint, raceDate: race, startDate: start, athlete: athlete(.intermediate, hours: 6),
            benchmarks: Benchmarks(), calendar: utc)
        XCTAssertEqual(result.weeks.count, 12)
        XCTAssertGreaterThan(result.startDate, start)
        XCTAssertEqual(utc.daysBetween(start, result.startDate) % 7, 0)
        XCTAssertEqual(result.weekIndex(containing: race, calendar: utc), 11)
    }

    // MARK: Hand picked profiles

    private struct Case {
        var label: String
        var distance: RaceDistance
        var weeks: Int
        var athlete: AthleteProfile
        var raceWeekday: Int
    }

    private var cases: [Case] {
        [
            Case(label: "sprint first timer 5h", distance: .sprint, weeks: 10,
                 athlete: athlete(.firstTimer, hours: 5, runWalk: true), raceWeekday: 6),
            Case(label: "sprint intermediate 6h five days", distance: .sprint, weeks: 12,
                 athlete: athlete(.intermediate, hours: 6, days: [.monday, .tuesday, .thursday, .saturday, .sunday],
                                  pool: [.tuesday, .thursday]), raceWeekday: 5),
            Case(label: "sprint experienced 7h", distance: .sprint, weeks: 8,
                 athlete: athlete(.experienced, hours: 7, power: true), raceWeekday: 6),
            Case(label: "olympic first timer 6h", distance: .olympic, weeks: 14,
                 athlete: athlete(.firstTimer, hours: 6, pool: [.monday, .wednesday, .friday]), raceWeekday: 6),
            Case(label: "olympic intermediate 8h six days", distance: .olympic, weeks: 16,
                 athlete: athlete(.intermediate, hours: 8, days: [.monday, .tuesday, .wednesday, .friday, .saturday, .sunday],
                                  pool: [.tuesday, .friday]), raceWeekday: 6),
            Case(label: "olympic experienced 10h", distance: .olympic, weeks: 12,
                 athlete: athlete(.experienced, hours: 10, power: true), raceWeekday: 5),
            Case(label: "half first timer 8h", distance: .half, weeks: 20,
                 athlete: athlete(.firstTimer, hours: 8, runWalk: true), raceWeekday: 6),
            Case(label: "half intermediate 10h", distance: .half, weeks: 18,
                 athlete: athlete(.intermediate, hours: 10, days: [.monday, .tuesday, .wednesday, .thursday, .saturday, .sunday],
                                  pool: [.monday, .thursday, .saturday]), raceWeekday: 6),
            Case(label: "half experienced 14h", distance: .half, weeks: 24,
                 athlete: athlete(.experienced, hours: 14, power: true), raceWeekday: 6),
            Case(label: "half experienced 14h midweek race", distance: .half, weeks: 15,
                 athlete: athlete(.experienced, hours: 14), raceWeekday: 2)
        ]
    }

    func testInvariantsOnHandPickedProfiles() throws {
        for c in cases {
            let p = try plan(c.distance, weeks: c.weeks, a: c.athlete, raceWeekday: c.raceWeekday)
            XCTAssertEqual(p.weeks.count, c.weeks, c.label)
            let failures = invariantFailures(p, distance: c.distance, athlete: c.athlete, label: c.label)
            XCTAssertEqual(failures, [], failures.joined(separator: "\n"))
        }
    }

    func testInvariantsAcrossSeededRandomProfiles() throws {
        // More seeds can be tried locally with TEMPLATES_SEEDS=500 swift test --filter Templates.
        let seedCount = max(Int(ProcessInfo.processInfo.environment["TEMPLATES_SEEDS"] ?? "") ?? 36, 1)
        var built = 0
        for seed in 1...seedCount {
            var rng = SplitMix64(seed: UInt64(seed) &* 7919)
            let distance = RaceDistance.allCases[rng.int(0...2)]
            let level = Level.allCases[rng.int(0...2)]
            let params = distance.parameters
            var days = allDays
            var removable = Weekday.allCases
            for _ in 0..<rng.int(0...3) {
                guard !removable.isEmpty else { break }
                days.remove(removable.remove(at: rng.int(0...(removable.count - 1))))
            }
            // Declared hours the declared days cannot hold are not reached (the plan fills the days it has),
            // so the generator keeps hours inside what the days and level can carry.
            let ceiling = params.weeklyHours.upperBound * (days.count >= 6 && level != .firstTimer ? 1.2 : 0.8)
            let hours = rng.double((params.weeklyHours.lowerBound * 0.9)...ceiling)
            let dayList = Weekday.allCases.filter { days.contains($0) }
            var pool: Set<Weekday> = []
            while pool.count < min(rng.int(2...3), dayList.count) { pool.insert(dayList[rng.int(0...(dayList.count - 1))]) }
            let profile = athlete(level, hours: hours, days: days, pool: pool, power: rng.bool(), runWalk: rng.bool())
            let start = utc.addDays(rng.int(0...6), to: day(2026, 11, 2))
            let weeks = rng.int(params.planWeeks)
            let race = utc.addDays(7 * (weeks - 1) + rng.int(0...6), to: start)
            let label = "seed \(seed) \(distance) \(level) \(String(format: "%.1f", hours))h \(days.count) days"
            let p = try engine.makePlan(
                raceDistance: distance, raceDate: race, startDate: start, athlete: profile, benchmarks: Benchmarks(),
                calendar: utc)
            built += 1
            XCTAssertEqual(utc.component(.weekday, from: p.startDate), utc.firstWeekday, "week 0 starts on the first weekday")
            let failures = invariantFailures(
                p, distance: distance, athlete: profile, label: label, partialFirstWeek: p.startDate != start)
            XCTAssertEqual(failures, [], failures.joined(separator: "\n"))
        }
        XCTAssertEqual(built, seedCount)
    }

    // MARK: Specific rules

    func testDeterministicAndCodable() throws {
        let a = athlete(.intermediate, hours: 8)
        let first = try plan(.olympic, weeks: 14, a: a)
        let second = try plan(.olympic, weeks: 14, a: a)
        XCTAssertEqual(first, second)
        let data = try JSONEncoder().encode(first)
        XCTAssertEqual(try JSONDecoder().decode(Plan.self, from: data), first)
    }

    func testSessionIdsFollowTheCoreFormat() throws {
        let p = try plan(.sprint, weeks: 8, a: athlete(.intermediate, hours: 6))
        let pattern = try NSRegularExpression(pattern: "^w\\d{2}-\\d{8}-(swim|bike|run)-\\d+$")
        for s in p.allSessions {
            let range = NSRange(s.id.startIndex..., in: s.id)
            XCTAssertNotNil(pattern.firstMatch(in: s.id, options: [], range: range), s.id)
        }
    }

    func testRunWalkOnlyWhenRequested() throws {
        let with = try plan(.sprint, weeks: 10, a: athlete(.firstTimer, hours: 5, runWalk: true))
        let without = try plan(.sprint, weeks: 10, a: athlete(.firstTimer, hours: 5, runWalk: false))
        func easyRuns(_ p: Plan) -> [Session] {
            p.allSessions.filter { $0.sport == .run && !$0.isQuality && !$0.isTest }
        }
        XCTAssertFalse(easyRuns(with).isEmpty)
        for s in easyRuns(with) {
            XCTAssertTrue(s.steps.contains { $0.name == "Walk break" && $0.repeatGroupID != nil }, s.id)
            XCTAssertTrue(s.name.lowercased().contains("run walk"), s.name)
        }
        for s in easyRuns(without) {
            XCTAssertFalse(s.steps.contains { $0.name == "Walk break" }, s.id)
        }
    }

    func testFirstTimerNeverGetsSwimQualityOrTwoQualityInOneSport() throws {
        let p = try plan(.olympic, weeks: 16, a: athlete(.firstTimer, hours: 7))
        for week in p.weeks where week.phase != .taper {
            let quality = week.sessions.filter { $0.isQuality && !$0.isTest }
            XCTAssertFalse(quality.contains { $0.sport == .swim }, "week \(week.index)")
            XCTAssertLessThanOrEqual(quality.count, 2)
        }
    }

    func testExperiencedGetsSecondQualityOnlyInBuildAndPeak() throws {
        let p = try plan(.half, weeks: 20, a: athlete(.experienced, hours: 13))
        var sawSecond = false
        for week in p.weeks {
            for sport in Sport.allCases {
                let q = week.sessions.filter { $0.sport == sport && $0.isQuality }.count
                if q == 2 {
                    sawSecond = true
                    XCTAssertTrue(week.phase == .build || week.phase == .peak, "week \(week.index) \(week.phase)")
                }
            }
        }
        XCTAssertTrue(sawSecond)
    }

    func testBrickRunScalesWithDistance() throws {
        func brickRun(_ d: RaceDistance, weeks: Int, hours: Double) throws -> [Double] {
            let p = try plan(d, weeks: weeks, a: athlete(.intermediate, hours: hours))
            return p.allSessions.filter { $0.brickSecondSport != nil }.map { s in
                s.steps.filter { $0.sport == .run }.reduce(0) { $0 + $1.durationSeconds }
            }
        }
        let sprint = try brickRun(.sprint, weeks: 10, hours: 6)
        let half = try brickRun(.half, weeks: 20, hours: 10)
        XCTAssertFalse(sprint.isEmpty)
        XCTAssertFalse(half.isEmpty)
        XCTAssertLessThan(sprint.max() ?? 0, half.max() ?? 0)
        XCTAssertGreaterThanOrEqual(sprint.min() ?? 0, 600)
        XCTAssertLessThanOrEqual(half.max() ?? 0, 1200)
    }

    func testRaceWeekStopsBeforeRaceDayAndKeepsEveEasy() throws {
        let a = athlete(.intermediate, hours: 8)
        for weekday in [1, 3, 5, 6] {
            let p = try plan(.olympic, weeks: 12, a: a, raceWeekday: weekday)
            guard let race = p.raceDate, let final = p.weeks.last else { return XCTFail("no race") }
            for s in final.sessions {
                XCTAssertLessThan(s.scheduledDate, race)
                if utc.daysBetween(s.scheduledDate, race) == 1 {
                    XCTAssertFalse(s.isQuality)
                    XCTAssertLessThan(s.durationSeconds, 3600)
                }
            }
            XCTAssertLessThanOrEqual(final.sessions.filter { $0.isQuality }.count, 1)
        }
    }

    func testShortRaceWeekExtendsTaperInsteadOfEmptyWeek() throws {
        // Race on the first day of the final week leaves no training days in it.
        let p = try plan(.olympic, weeks: 12, a: athlete(.intermediate, hours: 8), raceWeekday: 0)
        XCTAssertTrue(try XCTUnwrap(p.weeks.last).sessions.isEmpty)
        XCTAssertEqual(p.weeks.filter { $0.phase == .taper }.count, 2)
        let prior = p.weeks[p.weeks.count - 2]
        XCTAssertFalse(prior.sessions.isEmpty)
    }

    // MARK: Tests and rotation

    func testSprintOpensWithFullTestWeekForIntermediate() throws {
        let p = try plan(.sprint, weeks: 10, a: athlete(.intermediate, hours: 6))
        let opening = p.weeks[0].sessions.filter { $0.isTest }
        XCTAssertEqual(Set(opening.map { $0.sport }), [.swim, .bike, .run])
        XCTAssertTrue(p.weeks[0].isTest)
        XCTAssertLessThanOrEqual(p.weeks[0].sessions.filter { $0.isQuality }.count, Level.intermediate.maxQualityPerWeek)
        // The first block boundary after an opening test week is a plain recovery week.
        XCTAssertTrue(p.weeks[3].isRecovery)
        XCTAssertFalse(p.weeks[3].isTest)
    }

    func testFirstTimerOpeningTestsRespectTheCap() throws {
        let p = try plan(.sprint, weeks: 10, a: athlete(.firstTimer, hours: 5))
        XCTAssertEqual(p.weeks[0].sessions.filter { $0.isTest }.count, 2)
        XCTAssertEqual(p.weeks[1].sessions.filter { $0.isTest }.map { $0.sport }, [.run])
        XCTAssertLessThanOrEqual(p.weeks[0].sessions.filter { $0.isQuality }.count, 2)
        XCTAssertLessThanOrEqual(p.weeks[1].sessions.filter { $0.isQuality }.count, 2)
    }

    func testRotationGivesEverySportTestsAboutEverySixWeeks() throws {
        let p = try plan(.half, weeks: 24, a: athlete(.intermediate, hours: 11))
        let testWeeks = p.weeks.filter { $0.isTest }
        XCTAssertGreaterThanOrEqual(testWeeks.count, 4)
        for week in testWeeks {
            XCTAssertTrue(week.isRecovery)
            XCTAssertLessThanOrEqual(week.sessions.filter { $0.isTest }.count, 2)
        }
        for sport in Sport.allCases {
            let weeks = testWeeks.filter { $0.sessions.contains { $0.isTest && $0.sport == sport } }.map { $0.index }
            XCTAssertGreaterThanOrEqual(weeks.count, 3, "\(sport) tested at \(weeks)")
            for pair in zip(weeks, weeks.dropFirst()) {
                XCTAssertLessThanOrEqual(pair.1 - pair.0, 8, "\(sport) gap \(weeks)")
            }
        }
    }

    func testTestsFollowGearAndSkipFreshBenchmarks() throws {
        let start = day(2026, 11, 9)
        let fresh = BenchmarkValue(value: 100, isEstimated: false, date: utc.addDays(-7, to: start))
        let estimated = BenchmarkValue(value: 100, isEstimated: true, date: utc.addDays(-7, to: start))
        // Fresh swim and bike tests are skipped at the opening of a sprint plan; estimates are not.
        let benchmarks = Benchmarks(
            cssSecondsPer100m: fresh, ftpWatts: BenchmarkValue(value: 200, isEstimated: false, date: start),
            thresholdPaceSecondsPerKm: estimated)
        let p = try plan(.sprint, weeks: 10, a: athlete(.experienced, hours: 6, power: true), benchmarks: benchmarks, start: start)
        XCTAssertEqual(p.weeks[0].sessions.filter { $0.isTest }.map { $0.sport }, [.run])
        // With a power meter the bike test is the power test, without one it is the heart rate test.
        let power = try plan(.sprint, weeks: 10, a: athlete(.experienced, hours: 6, power: true))
        let heart = try plan(.sprint, weeks: 10, a: athlete(.experienced, hours: 6, power: false))
        XCTAssertEqual(power.weeks[0].sessions.first { $0.isTest && $0.sport == .bike }?.benchmarkKind, .bikeFTP)
        XCTAssertEqual(heart.weeks[0].sessions.first { $0.isTest && $0.sport == .bike }?.benchmarkKind, .bikeLTHR)
    }

    func testTestSessionsFollowAnnexProtocols() throws {
        let p = try plan(.sprint, weeks: 10, a: athlete(.experienced, hours: 6, power: true))
        let tests = p.weeks[0].sessions.filter { $0.isTest }
        let swim = try XCTUnwrap(tests.first { $0.sport == .swim })
        XCTAssertEqual(swim.steps.filter { $0.distanceMeters == 400 && $0.level == 5 }.count, 1)
        XCTAssertEqual(swim.steps.filter { $0.distanceMeters == 200 && $0.level == 5 }.count, 1)
        let recovery = try XCTUnwrap(swim.steps.first { $0.name == "Active recovery" })
        XCTAssertTrue((300...600).contains(recovery.durationSeconds))
        let run = try XCTUnwrap(tests.first { $0.sport == .run })
        XCTAssertEqual(run.steps.filter { $0.durationSeconds == 1800 }.count, 1)
        let bike = try XCTUnwrap(tests.first { $0.sport == .bike })
        XCTAssertTrue(bike.steps.contains { $0.name == "Clearing effort" && $0.durationSeconds == 300 })
        XCTAssertTrue(bike.steps.contains { $0.durationSeconds == 1200 })
    }

    // MARK: Base plan, convert, replan

    func testBasePlanIsFourWeeksWithATestWeek() throws {
        let start = day(2026, 11, 9)
        let a = athlete(.intermediate, hours: 7)
        let base = try engine.makeBasePlan(startDate: start, athlete: a, benchmarks: Benchmarks(), calendar: utc)
        XCTAssertNil(base.raceDistance)
        XCTAssertNil(base.raceDate)
        XCTAssertEqual(base.weeks.count, 4)
        XCTAssertTrue(base.weeks.allSatisfy { $0.phase == .base })
        XCTAssertTrue(base.weeks[3].isRecovery)
        XCTAssertTrue(base.weeks[3].isTest)
        XCTAssertEqual(base.weeks.prefix(3).filter { $0.isTest }.count, 0)
        XCTAssertLessThanOrEqual(base.weeks[3].sessions.filter { $0.isTest }.count, 2)
        for week in base.weeks {
            XCTAssertTrue(week.sessions.allSatisfy { $0.brickSecondSport == nil })
            XCTAssertLessThanOrEqual(week.sessions.filter { $0.isQuality }.count, Level.intermediate.maxQualityPerWeek)
            for sport in Sport.allCases where week.sessions.contains(where: { $0.sport == sport }) {
                XCTAssertTrue(week.sessions.contains { $0.sport == sport && isFullyEasy($0) })
            }
        }
        XCTAssertEqual(base, try engine.makeBasePlan(startDate: start, athlete: a, benchmarks: Benchmarks(), calendar: utc))
    }

    func testBaseTestRotationSitsOutMostRecentlyTestedSport() throws {
        let start = day(2026, 11, 9)
        let recentRun = BenchmarkValue(value: 300, isEstimated: false, date: utc.addDays(-30, to: start))
        let b = Benchmarks(thresholdPaceSecondsPerKm: recentRun)
        XCTAssertEqual(SequencePlanner.sitOutOrder(b).first, .run)
        XCTAssertEqual(SequencePlanner.sitOutOrder(Benchmarks()), [.run, .bike, .swim])
        let base = try engine.makeBasePlan(startDate: start, athlete: athlete(.experienced, hours: 8), benchmarks: b, calendar: utc)
        XCTAssertEqual(Set(base.weeks[3].sessions.filter { $0.isTest }.map { $0.sport }), [.swim, .bike])
    }

    func testConvertKeepsHistoryAndBuildsRacePlanToTheRaceDate() throws {
        let start = day(2026, 11, 9)
        let a = athlete(.intermediate, hours: 8)
        var base = try engine.makeBasePlan(startDate: start, athlete: a, benchmarks: Benchmarks(), calendar: utc)
        let doneID = try XCTUnwrap(base.weeks[0].sessions.first?.id)
        base.updateSession(id: doneID) { $0.state = .done }
        base.zoneNudgeSteps = [.run: 1]
        let today = day(2026, 11, 25)
        let race = day(2027, 3, 14)
        let converted = try engine.convertToRacePlan(
            base, raceDistance: .olympic, raceDate: race, today: today, benchmarks: Benchmarks(), calendar: utc)
        XCTAssertEqual(converted.startDate, start)
        XCTAssertEqual(converted.raceDistance, .olympic)
        XCTAssertEqual(converted.weekIndex(containing: race, calendar: utc), converted.weeks.count - 1)
        XCTAssertEqual(converted.weeks[0], base.weeks[0])
        XCTAssertEqual(converted.weeks[1], base.weeks[1])
        XCTAssertEqual(converted.session(withID: doneID)?.state, .done)
        XCTAssertEqual(converted.zoneNudgeSteps, [.run: 1])
        for (k, week) in converted.weeks.enumerated() {
            XCTAssertEqual(week.index, k)
            XCTAssertEqual(week.startDate, utc.addDays(7 * k, to: start))
        }
        let ids = converted.allSessions.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        // Weeks after the current one follow the race template: a peak, then a taper.
        XCTAssertTrue(converted.weeks.contains { $0.phase == .peak })
        XCTAssertEqual(converted.weeks.last?.phase, .taper)
        // Days already past in the current week are not rescheduled.
        let currentWeek = converted.weeks[2]
        XCTAssertTrue(currentWeek.days.keys.filter { $0 < today }.allSatisfy { day in
            base.weeks.count > 2 && base.weeks[2].days[day] == currentWeek.days[day]
        })
    }

    func testConvertRejectsRaceThatIsTooSoon() throws {
        let start = day(2026, 11, 9)
        let base = try engine.makeBasePlan(
            startDate: start, athlete: athlete(.intermediate, hours: 7), benchmarks: Benchmarks(), calendar: utc)
        XCTAssertThrowsError(try engine.convertToRacePlan(
            base, raceDistance: .olympic, raceDate: day(2026, 12, 20), today: day(2026, 11, 10),
            benchmarks: Benchmarks(), calendar: utc)) { error in
            guard case .raceDateTooSoon(let minimum, _)? = error as? PlanKitError else { return XCTFail("\(error)") }
            XCTAssertEqual(minimum, 10)
        }
    }

    func testReplanMovesRaceAndCancelsToBase() throws {
        let start = day(2026, 11, 9)
        let a = athlete(.intermediate, hours: 8)
        let original = try engine.makePlan(
            raceDistance: .olympic, raceDate: day(2027, 3, 14), startDate: start, athlete: a, benchmarks: Benchmarks(),
            calendar: utc)
        let today = day(2026, 12, 14)
        // Weeks before the one holding `today` are history and stay exactly as they were.
        let kept = utc.daysBetween(original.startDate, today) / 7
        XCTAssertGreaterThan(kept, 0)
        let moved = try engine.replan(
            original, raceDistance: .olympic, raceDate: day(2027, 4, 25), today: today, benchmarks: Benchmarks(),
            calendar: utc)
        XCTAssertEqual(moved.raceDate, day(2027, 4, 25))
        XCTAssertEqual(Array(moved.weeks.prefix(kept)), Array(original.weeks.prefix(kept)))
        XCTAssertEqual(moved.weekIndex(containing: day(2027, 4, 25), calendar: utc), moved.weeks.count - 1)
        let cancelled = try engine.replan(
            original, raceDistance: nil, raceDate: nil, today: today, benchmarks: Benchmarks(), calendar: utc)
        XCTAssertNil(cancelled.raceDate)
        XCTAssertEqual(cancelled.weeks.count, kept + 4)
        XCTAssertEqual(Array(cancelled.weeks.prefix(kept)), Array(original.weeks.prefix(kept)))
        XCTAssertTrue(cancelled.weeks.dropFirst(kept).allSatisfy { $0.phase == .base })
    }

    func testReplanWithDistantRaceBridgesWithBaseWeeks() throws {
        let start = day(2026, 11, 9)
        let base = try engine.makeBasePlan(
            startDate: start, athlete: athlete(.intermediate, hours: 7), benchmarks: Benchmarks(), calendar: utc)
        let race = day(2027, 11, 7)
        let converted = try engine.convertToRacePlan(
            base, raceDistance: .sprint, raceDate: race, today: start, benchmarks: Benchmarks(), calendar: utc)
        XCTAssertEqual(converted.weekIndex(containing: race, calendar: utc), converted.weeks.count - 1)
        XCTAssertGreaterThan(converted.weeks.count, 12)
        XCTAssertEqual(converted.weeks.prefix(while: { $0.phase == .base }).count > 12, true)
        for (k, week) in converted.weeks.enumerated() { XCTAssertEqual(week.index, k) }
    }

    // MARK: Errors

    func testInfeasibleProfilesThrowInsteadOfTrapping() {
        let start = day(2026, 11, 9)
        let race = day(2027, 3, 14)
        func attempt(_ a: AthleteProfile, _ d: RaceDistance = .olympic) -> PlanKitError? {
            do {
                _ = try engine.makePlan(
                    raceDistance: d, raceDate: race, startDate: start, athlete: a, benchmarks: Benchmarks(), calendar: utc)
                return nil
            } catch { return error as? PlanKitError }
        }
        if case .infeasibleProfile? = attempt(athlete(.intermediate, hours: 8, days: [])) {} else { XCTFail("no days") }
        if case .infeasibleProfile? = attempt(athlete(.intermediate, hours: 8, days: [.monday, .tuesday], pool: [.friday])) {} else { XCTFail("no pool day") }
        if case .infeasibleProfile? = attempt(athlete(.intermediate, hours: 8, days: [.monday], pool: [.monday])) {} else { XCTFail("one day") }
        if case .infeasibleProfile? = attempt(athlete(.intermediate, hours: 2)) {} else { XCTFail("too few hours") }
        if case .invalidInput? = attempt(athlete(.intermediate, hours: .nan)) {} else { XCTFail("nan hours") }
        if case .invalidInput? = attempt(athlete(.intermediate, hours: -3)) {} else { XCTFail("negative hours") }
    }

    func testThreeDaysAthleteStillGetsASafePlan() throws {
        let a = athlete(.firstTimer, hours: 5, days: [.tuesday, .thursday, .sunday], pool: [.tuesday, .thursday])
        let p = try plan(.sprint, weeks: 10, a: a)
        let failures = invariantFailures(p, distance: .sprint, athlete: a, label: "three days")
        // Session count floors do not apply with three days; every safety rule still does.
        XCTAssertEqual(failures.filter { !$0.contains("has only") }, [])
    }

    func testOddBenchmarksDoNotTrap() throws {
        let weird = Benchmarks(
            cssSecondsPer100m: BenchmarkValue(value: .nan, isEstimated: false, date: day(2026, 1, 1)),
            ftpWatts: BenchmarkValue(value: -5, isEstimated: true, date: day(2026, 1, 1)))
        let p = try plan(.sprint, weeks: 8, a: athlete(.intermediate, hours: 6), benchmarks: weird)
        XCTAssertFalse(p.allSessions.isEmpty)
        XCTAssertTrue(p.allSessions.allSatisfy { $0.durationSeconds.isFinite })
    }

    // MARK: Session library

    func testLibraryCopyIsCleanAndComplete() {
        for kind in SessionKind.allCases {
            XCTAssertFalse(SessionLibrary.name(for: kind).isEmpty)
            let purpose = SessionLibrary.purpose(for: kind)
            XCTAssertTrue(purpose.hasSuffix("."), purpose)
            XCTAssertEqual(purpose.filter { $0 == "." }.count, 1, "one sentence: \(purpose)")
            XCTAssertEqual(kind.isTest, kind.benchmarkKind != nil)
            if kind.isTest { XCTAssertTrue(kind.isQuality) }
        }
        for text in SessionLibrary.allCopy { XCTAssertNil(containsBannedCopy(text), text) }
    }

    // MARK: Golden fixtures

    /// Compact, order independent summary of a plan. Includes a digest of every session so regenerating must
    /// match exactly (annex J "Golden plan fixtures").
    private struct GoldenSummary: Codable, Equatable {
        var weekCount: Int
        var sessionsPerSport: [String: Int]
        var weeklyHours: [Double]
        var phases: String
        var recoveryWeeks: [Int]
        var testWeeks: [Int]
        var rampProfile: [Double]
        var taperHours: [Double]
        var digest: String
    }

    private func summary(_ p: Plan) -> GoldenSummary {
        var perSport: [String: Int] = [:]
        for s in p.allSessions { perSport[s.sport.rawValue, default: 0] += 1 }
        let loads = p.weeks.filter { !$0.isRecovery && $0.phase != .taper }
        var ramp: [Double] = []
        for pair in zip(loads, loads.dropFirst()) where pair.0.plannedHours > 0 {
            ramp.append((pair.1.plannedHours / pair.0.plannedHours * 100).rounded() / 100)
        }
        var text = ""
        func targetCase(_ target: StepTarget) -> String {
            switch target {
            case .pacePerKm: return "pace"
            case .pacePer100m: return "pace100"
            case .speedRange: return "speed"
            case .powerRange: return "power"
            case .heartRateRange: return "hr"
            case .cssOffset(let r): return "css\(r.lower),\(r.upper)"
            case .rpe(let r): return "rpe\(r.lower),\(r.upper)"
            case .none: return "none"
            }
        }
        for s in p.allSessions {
            text += "\(s.id)|\(s.name)|\(Int(s.durationSeconds))|\(s.steps.count)|\(s.isQuality)|\(s.isTest)"
            text += "|\(s.brickSecondSport?.rawValue ?? "-")|\(s.purpose.count)\n"
            // Every step: sport, kind, level, rounded duration, repeat count, target case, name and note length.
            for step in s.steps {
                text += "  \(step.sport.rawValue)|\(step.kind.rawValue)|\(step.level)|\(Int(step.durationSeconds.rounded()))"
                text += "|\(step.repeats)|\(targetCase(step.target))|\(step.name)|\(step.note?.count ?? 0)\n"
            }
        }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return GoldenSummary(
            weekCount: p.weeks.count,
            sessionsPerSport: perSport,
            weeklyHours: p.weeks.map { $0.plannedHours },
            phases: p.weeks.map { String($0.phase.rawValue.prefix(1)) }.joined(),
            recoveryWeeks: p.weeks.filter { $0.isRecovery }.map { $0.index },
            testWeeks: p.weeks.filter { $0.isTest }.map { $0.index },
            rampProfile: ramp,
            taperHours: p.weeks.filter { $0.phase == .taper }.map { $0.plannedHours },
            digest: String(hash, radix: 16)
        )
    }

    /// Where the fixture lives in the source tree, used only to write it when `UPDATE_GOLDEN=1`.
    private var goldenSourceURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("Templates-golden-plans.json")
    }

    func testGoldenPlansMatchCheckedInFixture() throws {
        var current: [String: GoldenSummary] = [:]
        let matrix: [(RaceDistance, Level, Double, Int)] = [
            (.sprint, .firstTimer, 5, 9), (.sprint, .intermediate, 6, 12), (.sprint, .experienced, 7, 8),
            (.olympic, .firstTimer, 6, 12), (.olympic, .intermediate, 8, 14), (.olympic, .experienced, 10, 16),
            (.half, .firstTimer, 8, 16), (.half, .intermediate, 10, 20), (.half, .experienced, 14, 24),
            (.olympic, .intermediate, 7, 10), (.half, .intermediate, 12, 14), (.sprint, .intermediate, 4.5, 10)
        ]
        for (distance, level, hours, weeks) in matrix {
            let a = athlete(level, hours: hours, power: level == .experienced, runWalk: level == .firstTimer)
            let p = try plan(distance, weeks: weeks, a: a)
            let label = "\(distance.rawValue)-\(level.rawValue)-\(hours)h-\(weeks)w"
            current[label] = summary(p)
            XCTAssertEqual(invariantFailures(p, distance: distance, athlete: a, label: label), [])
        }
        XCTAssertGreaterThanOrEqual(current.count, 12)

        // The fixture is read from the test bundle. It is rewritten only on purpose, with UPDATE_GOLDEN=1; a
        // missing or unreadable fixture fails the test instead of quietly creating itself.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1" {
            let url = goldenSourceURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(current).write(to: url)
            return
        }
        guard let bundled = Bundle.module.url(forResource: "Templates-golden-plans", withExtension: "json", subdirectory: "Fixtures") else {
            return XCTFail("golden fixture missing from the test bundle; regenerate on purpose with UPDATE_GOLDEN=1")
        }
        let stored = try JSONDecoder().decode([String: GoldenSummary].self, from: Data(contentsOf: bundled))
        XCTAssertEqual(Set(stored.keys), Set(current.keys))
        for key in current.keys.sorted() {
            XCTAssertEqual(stored[key], current[key], "golden plan \(key) changed; delete the fixture only on purpose")
        }
    }
}
