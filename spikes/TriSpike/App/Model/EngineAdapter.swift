import Foundation
import SwiftUI
import Combine
import BricklinePlanKit
#if canImport(WorkoutKit)
import WorkoutKit
#endif

// The bridge between BricklinePlanKit (the engine) and the screens.
//
// Every number the screens print comes from the engine through this file: week x of y, phase, session titles and
// durations, pace, power and heart rate ranges, Load, Fitness and Form, the race pacing card and the race timeline.
// The engine types are written with their module name (`BricklinePlanKit.Session`) because the app has view models
// with the same names (Sport, Session, Phase). The screens keep reading `Demo`, which forwards here.

typealias EnginePlan = BricklinePlanKit.Plan

// MARK: Completions

/// A session the athlete finished, kept on this phone so Today and Week can show it done and the engine can count
/// its Load. Keyed by the engine's deterministic session id.
struct CompletionRecord: Codable, Equatable {
    var sessionID: String
    var minutes: Int
    /// The day the session was scheduled for.
    var date: Date
    var sport: String
    var level: Int
}

enum CompletionStore {
    private static let key = "brickline.completions.v1"

    static func load() -> [String: CompletionRecord] {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([CompletionRecord].self, from: raw) else { return [:] }
        return Dictionary(list.map { ($0.sessionID, $0) }, uniquingKeysWith: { _, new in new })
    }

    static func save(_ records: [String: CompletionRecord]) {
        let list = records.values.sorted { $0.sessionID < $1.sessionID }
        guard let raw = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: Model

/// Fitness, Fatigue and Form as of today, from the engine's load model.
struct FitnessSummary: Equatable {
    var fitness: Double
    var fatigue: Double
    var form: Double
    /// False until 42 days of history exist. The UI says "building" until then.
    var hasFullHistory: Bool
}

/// The race card: legs, timeline, fueling.
struct RaceModel {
    struct Fuel: Identifiable {
        let id = UUID()
        var sport: Sport
        var seconds: TimeInterval
        var text: String
    }
    var legs: [PlanStep]
    var startMinutes: Int
    var wakeMinutes: Int
    var timeline: [Demo.TimelineItem]
    var fueling: [Fuel]
    var caveat: String
    var stomachLine: String
    /// Legs whose time is a typical value for the athlete's level, not a prediction.
    var typicalLegs: Set<Sport>
}

/// Everything the screens read, computed once from the engine for one setup and one day.
struct EngineModel {
    /// The plan the screens show: the race plan, or the base plan when the race plan could not be built.
    var plan: EnginePlan?
    /// The plan the Today and Week screens read days from (the race plan, or a base plan that bridges the gap
    /// before a far away race plan begins).
    var weekPlan: EnginePlan?
    var benchmarks: Benchmarks
    var calendar: Calendar
    var today: Date
    var hasRace: Bool
    var daysToRace: Int
    var totalWeeks: Int
    /// 1 based.
    var currentWeek: Int
    var phases: [(Phase, Int)]
    var recoveryWeeks: Set<Int>
    var testWeeks: Set<Int>
    /// The seven days of the current week, Monday first.
    var week: [PlanDay]
    /// Calm text when the engine could not build the plan asked for.
    var problem: String?
    /// Engine warnings for the plan preview (hours clipped, days too few, and so on).
    var warnings: [String]
    var fitness: FitnessSummary?
    var race: RaceModel
    /// Average planned sessions and hours per full week, for the plan preview.
    var sessionsPerWeek: Int
    var hoursPerWeek: Double
    /// Sessions of the first week with at least three sessions (week 1 when none), for the preview.
    var firstWeekSessions: [Session]
    var firstWeekIsPartial: Bool
    /// Every session of the plan by engine id, so a tap can find the engine session again.
    var engineSessions: [String: BricklinePlanKit.Session]
    /// The readiness picture for today. Nil when no connected device can supply recovery data.
    var readiness: ReadinessAssessment? = nil
    /// The readiness change made to today that the athlete can still undo with Keep my planned session.
    var readinessEvent: AdaptationEvent? = nil
    /// True when the athlete kept the planned session today, so readiness left it alone.
    var readinessKept = false
    /// Set while the race plan has not started yet and base weeks bridge the gap. Week x of y does not apply then.
    var planBeginsOn: Date? = nil
    /// True when the athlete used "This feels too hard" for the week on screen.
    var weekEased = false
}

// MARK: Building

enum EngineBuilder {
    static let kit = PlanKit.standard

    static func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = .current
        return c
    }

    // MARK: Inputs

    static func level(_ e: ExperienceChoice) -> Level {
        switch e { case .firstTimer: .firstTimer; case .intermediate: .intermediate; case .experienced: .experienced }
    }

    static func distance(_ r: RaceChoice) -> RaceDistance {
        switch r { case .superSprint, .sprint: .sprint; case .olympic: .olympic; case .half: .half }
    }

    /// The engine level for the answers: the starting point questions can lower the level the athlete picked, never raise it.
    static func level(_ d: SetupData) -> Level { level(d.startingPoint.resolvedLevel(experience: d.experience)) }

    static func athlete(_ d: SetupData, poolOverride: Set<Weekday>? = nil) -> AthleteProfile {
        AthleteProfile(
            level: level(d),
            weeklyHours: Double(d.effectiveHours),
            availableWeekdays: Set(d.trainingDays.compactMap { Weekday(rawValue: $0) }),
            poolWeekdays: poolOverride ?? Set(d.poolDays.compactMap { Weekday(rawValue: $0) }),
            hasWatch: d.canSendToWatch,
            hasPowerMeter: d.hasPowerMeter,
            hasTrainer: d.hasTrainer,
            prefersRunWalk: d.startingPoint.prefersRunWalk(experience: d.experience),
            gentleStart: d.isGentleStart)
    }

    /// Typical starting numbers by level, used only when the athlete has no test yet. They are marked estimated
    /// everywhere, and an estimate never drives a pace change.
    static func typicalCSS(_ l: Level) -> Double {
        switch l { case .firstTimer: 130; case .intermediate: 110; case .experienced: 95 }
    }
    static func typicalThresholdPace(_ l: Level) -> Double {
        switch l { case .firstTimer: 390; case .intermediate: 345; case .experienced: 300 }
    }
    static func typicalFTP(_ l: Level) -> Double {
        switch l { case .firstTimer: 140; case .intermediate: 190; case .experienced: 240 }
    }

    /// Benchmarks from setup. Numbers the athlete typed count as theirs; anything missing is an estimate for their
    /// level. A bike power number exists only with a power meter, so without one the bike runs on feel.
    static func benchmarks(_ d: SetupData, today: Date) -> Benchmarks {
        let l = level(d)
        func value(_ entered: Double?, typical: Double) -> BenchmarkValue {
            if !d.useEstimates, let entered, entered > 0 {
                return BenchmarkValue(value: entered, isEstimated: false, date: today)
            }
            return BenchmarkValue(value: typical, isEstimated: true, date: today)
        }
        return Benchmarks(
            cssSecondsPer100m: value(d.cssSecondsPer100, typical: typicalCSS(l)),
            ftpWatts: d.hasPowerMeter ? value(d.ftpWatts.map(Double.init), typical: typicalFTP(l)) : nil,
            thresholdPaceSecondsPerKm: value(d.thresholdPaceSecondsPerKm, typical: typicalThresholdPace(l)))
    }

    // MARK: Text for numbers

    static func mmss(_ seconds: Double) -> String {
        let t = Int(seconds.isFinite ? seconds.rounded() : 0)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    static func effortWord(level: Int) -> String {
        switch level {
        case ...1: "very easy"
        case 2: "easy"
        case 3: "steady"
        case 4: "strong and steady"
        default: "very hard"
        }
    }

    static func effortWord(rpe: ValueRange) -> String {
        switch rpe.midpoint {
        case ..<4.5: "easy"
        case ..<6: "steady"
        case ..<7.5: "strong and steady"
        default: "hard"
        }
    }

    /// A range as text with its unit, for example "4:20 to 4:40 per km", "220 to 235 watts", "1:45 per 100 m".
    static func text(_ target: StepTarget, level: Int, css: Double? = nil) -> String? {
        switch target {
        case .pacePerKm(let r):
            let a = mmss(r.lower), b = mmss(r.upper)
            return a == b ? "\(a) per km" : "\(a) to \(b) per km"
        case .pacePer100m(let r):
            return r.width <= 3 ? "\(mmss(r.midpoint)) per 100 m" : "\(mmss(r.lower)) to \(mmss(r.upper)) per 100 m"
        case .cssOffset(let r):
            guard let css else { return nil }
            return text(.pacePer100m(ValueRange(css + r.lower, css + r.upper)), level: level)
        case .powerRange(let r):
            let a = Int(r.lower.rounded()), b = Int(r.upper.rounded())
            return a == b ? "\(a) watts" : "\(a) to \(b) watts"
        case .heartRateRange(let r):
            return "\(Int(r.lower.rounded())) to \(Int(r.upper.rounded())) beats per minute"
        case .speedRange(let r):
            // Metres per second to a pace per km.
            guard r.lower > 0, r.upper > 0 else { return nil }
            return text(.pacePerKm(ValueRange(1000 / r.upper, 1000 / r.lower)), level: level)
        case .rpe(let r):
            return effortWord(rpe: r)
        case .none:
            return nil
        }
    }

    /// The one big number for a session: the middle of the main target.
    static func headline(_ target: StepTarget, level: Int, css: Double? = nil) -> (value: String, unit: String) {
        switch target {
        case .pacePerKm(let r): return (mmss(r.midpoint), "per km")
        case .pacePer100m(let r): return (mmss(r.midpoint), "per 100 m")
        case .cssOffset(let r):
            guard let css else { return effort(level) }
            return (mmss(css + r.midpoint), "per 100 m")
        case .powerRange(let r): return ("\(Int(r.midpoint.rounded()))", "watts")
        case .heartRateRange(let r): return ("\(Int(r.midpoint.rounded()))", "beats per min")
        case .speedRange(let r):
            guard r.midpoint > 0 else { return effort(level) }
            return (mmss(1000 / r.midpoint), "per km")
        case .rpe, .none: return effort(level)
        }
    }

    static func effort(_ level: Int) -> (value: String, unit: String) {
        switch level {
        case ...1: ("Very easy", "effort")
        case 2: ("Easy", "effort")
        case 3: ("Steady", "effort")
        case 4: ("Strong", "effort")
        default: ("Very hard", "effort")
        }
    }

    // MARK: Sport and step mapping

    static func sport(_ s: BricklinePlanKit.Sport) -> Sport {
        switch s { case .swim: .swim; case .bike: .bike; case .run: .run }
    }

    static func kind(_ k: BricklinePlanKit.StepKind) -> StepKind {
        switch k { case .warmUp: .warm; case .work: .work; case .recovery: .recovery; case .coolDown: .cool }
    }

    /// A stable UUID for an engine id, so the same session keeps the same identity every time the model is built.
    static func stableUUID(_ text: String) -> UUID {
        func fnv(_ seed: UInt64) -> UInt64 {
            var h: UInt64 = 0xcbf29ce484222325 ^ seed
            for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            return h
        }
        let a = fnv(0), b = fnv(0x9e3779b97f4a7c15)
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: a >> (UInt64(i) * 8))
            bytes[8 + i] = UInt8(truncatingIfNeeded: b >> (UInt64(i) * 8))
        }
        let t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: t)
    }

    // MARK: One session

    /// The engine's resolved target for a step, honouring the plan's zone nudges.
    static func resolved(_ step: BricklinePlanKit.Step, plan: EnginePlan, benchmarks: Benchmarks) -> StepTarget {
        let nudge = plan.effectiveZoneNudgeSteps(benchmarks: benchmarks)[step.sport] ?? 0
        return kit.zones.resolveTarget(for: step, athlete: plan.athlete, benchmarks: benchmarks, nudgeSteps: nudge)
    }

    static func planSteps(for s: BricklinePlanKit.Session, plan: EnginePlan, benchmarks: Benchmarks) -> [PlanStep] {
        let css = benchmarks.cssSecondsPer100m?.value
        func make(_ m: BricklinePlanKit.Step, group: Int?, count: Int?) -> PlanStep {
            let target = resolved(m, plan: plan, benchmarks: benchmarks)
            var targetText = text(target, level: m.level, css: css)
            if targetText == nil, m.kind != .recovery { targetText = effortWord(level: m.level) }
            let meters: Int? = {
                guard m.sport == .swim, let d = m.distanceMeters, d > 0 else { return nil }
                return Int(d.rounded())
            }()
            return PlanStep(
                sport: sport(m.sport), kind: kind(m.kind), name: PlainCopy.stepName(m), seconds: m.durationSeconds,
                level: m.level, target: targetText, distance: meters.map { "\($0) m" }, meters: meters,
                group: group, repeatCount: count)
        }
        var out: [PlanStep] = []
        var groups = 0
        var i = 0
        while i < s.steps.count {
            let step = s.steps[i]
            guard let gid = step.repeatGroupID else {
                out.append(make(step, group: nil, count: nil))
                i += 1
                continue
            }
            var members: [BricklinePlanKit.Step] = []
            var j = i
            while j < s.steps.count, s.steps[j].repeatGroupID == gid { members.append(s.steps[j]); j += 1 }
            groups += 1
            let n = max(step.repeatCount ?? 1, 1)
            for _ in 0..<n {
                for m in members { out.append(make(m, group: groups, count: m.kind == .work ? n : nil)) }
            }
            i = j
        }
        return out
    }

    /// The step the session is about: the hardest work step of the first sport, longest first on a tie.
    static func mainStep(of s: BricklinePlanKit.Session) -> BricklinePlanKit.Step? {
        let work = s.steps.filter { $0.kind == .work && $0.sport == s.sport }
        let pool = work.isEmpty ? s.steps.filter { $0.kind == .work } : work
        return pool.max {
            if $0.level != $1.level { return $0.level < $1.level }
            return $0.durationSeconds * Double($0.repeats) < $1.durationSeconds * Double($1.repeats)
        } ?? s.steps.first
    }

    private static func steps(of w: CompiledWorkout) -> [CompiledStep] {
        switch w {
        case .custom(let c): return [c.warmUp].compactMap { $0 } + c.blocks.flatMap(\.steps) + [c.coolDown].compactMap { $0 }
        case .singleGoal, .swimBikeRun: return []
        }
    }

    /// What the watch gets, in plain words, from what the engine actually compiled.
    static func watchLine(for s: BricklinePlanKit.Session, plan: EnginePlan, benchmarks: Benchmarks) -> String {
        guard let compiled = try? kit.compile(s, in: plan, benchmarks: benchmarks, capabilities: .standard, indoor: false) else {
            return "This session runs on your phone."
        }
        var parts: [String] = []
        parts.append(compiled.workouts.count == 2
                     ? "Arrives as two workouts: the ride, then the run."
                     : "Arrives as one workout.")
        let all = compiled.workouts.flatMap(steps(of:))
        var alerts: [String] = []
        if all.contains(where: { if case .speedRange = $0.alert { return true } else { return false } }) { alerts.append("pace") }
        if all.contains(where: { if case .powerRange = $0.alert { return true } else { return false } }) { alerts.append("power") }
        if all.contains(where: { if case .heartRateRange = $0.alert { return true } else { return false } }) { alerts.append("heart rate") }
        if let first = alerts.first {
            parts.append("Your watch alerts you when your \(first) leaves the target range during each hard step.")
        }
        if all.contains(where: { if case .distanceWithTime = $0.goal { return true } else { return false } }) {
            parts.append("Your watch moves to the next step once you have swum the distance and the time is up.")
        }
        if compiled.usesPhoneSetCard { parts.append("This one is easiest to follow from the set card on your phone.") }
        return PlainCopy.sanitize(parts.joined(separator: " "))
    }

    static func makeSession(
        _ s: BricklinePlanKit.Session, plan: EnginePlan, benchmarks: Benchmarks, completion: CompletionRecord?,
        reason: String? = nil, reasonRule: String? = nil
    ) -> Session {
        let steps = planSteps(for: s, plan: plan, benchmarks: benchmarks)
        let css = benchmarks.cssSecondsPer100m?.value
        let main = mainStep(of: s)
        var headline: (value: String, unit: String)? = nil
        var estimated = false
        if let main {
            let target = resolved(main, plan: plan, benchmarks: benchmarks)
            headline = Self.headline(target, level: main.level, css: css)
            switch (headline?.unit, main.sport) {
            case ("per 100 m"?, _): estimated = benchmarks.cssSecondsPer100m?.isEstimated ?? false
            case ("per km"?, _): estimated = benchmarks.thresholdPaceSecondsPerKm?.isEstimated ?? false
            case ("watts"?, _): estimated = benchmarks.ftpWatts?.isEstimated ?? false
            default: estimated = false
            }
        }
        let idea = PlainCopy.idea(for: s)
        let model = DefaultLoadModel()
        let planned = model.plannedLoad(for: s, benchmarks: benchmarks)
        var loadPoints = Int(planned.load.rounded())
        var loadEstimated = true
        var state: SessionState = s.state == .skipped ? .skipped : .planned
        var doneMinutes: Int? = nil
        if let completion {
            state = .done
            doneMinutes = completion.minutes
            let workout = CompletedWorkout(
                id: completion.sessionID, sport: s.sport, start: completion.date,
                durationSeconds: Double(completion.minutes) * 60, plannedSessionID: s.id, source: .phonePlayer)
            let done = model.load(for: workout, benchmarks: benchmarks, plannedLevel: model.representativeLevel(for: s))
            loadPoints = Int(done.load.rounded())
            loadEstimated = done.isEstimated
        }
        var out = Session(
            id: stableUUID(s.id), sport: sport(s.sport), name: PlainCopy.title(for: s),
            purpose: PlainCopy.purpose(for: s), steps: steps, state: state, reason: reason,
            headlineTarget: headline, watchLine: watchLine(for: s, plan: plan, benchmarks: benchmarks),
            doneMinutes: doneMinutes, isTest: s.isTest,
            brickSecond: s.brickSecondSport.map(sport), isOpenWater: s.isOpenWater,
            idea: idea?.term, ideaLabel: idea?.label)
        out.engineID = s.id
        if reason != nil { out.reasonRule = reasonRule ?? ReadinessPlainCopy.ruleExplanation }
        out.scheduledDate = s.scheduledDate
        out.loadPoints = loadPoints
        out.loadEstimated = loadEstimated
        out.targetsEstimated = estimated
        out.engineLevel = model.representativeLevel(for: s)
        return out
    }

    // MARK: Plan

    struct PlanResult {
        var plan: EnginePlan?
        var problem: String?
    }

    /// Collapses the engine's per week warnings into a few plain lines, one per kind, so the preview does not repeat itself.
    static func summarizeWarnings(_ list: [PlanWarning], trainingDays: Int) -> [String] {
        var eased = 0, dropped = 0, trimmed = 0
        var others: [String] = []
        for w in list {
            switch w {
            case .qualityEased: eased += 1
            case .sessionDropped: dropped += 1
            case .recoveryWeekTrimmed: trimmed += 1
            default: others.append(PlainCopy.sanitize(w.message))
            }
        }
        let days = trainingDays == 1 ? "1 training day" : "\(trainingDays) training days"
        var out: [String] = []
        if eased > 0 {
            out.append("With \(days), some hard sessions become easy so hard days stay apart. Add a day for the full plan.")
        }
        if dropped > 0 {
            out.append("With \(days), some sessions are left out because they do not fit. Add a day for the full plan.")
        }
        if trimmed > 0 {
            out.append("Recovery weeks drop a session so they stay light.")
        }
        var seen = Set<String>()
        return (out + others).filter { seen.insert($0).inserted }
    }

    /// Start of the rolling 28 day block that contains `today`, counted from the day the athlete started.
    static func rollingBlockStart(planStart: Date, today: Date, calendar cal: Calendar) -> Date {
        let days = max(0, cal.daysBetween(planStart, today))
        return cal.addDays(days / 28 * 28, to: planStart)
    }

    /// The engine's refusal in words for the screen. Never shows the engine's own reason text, which is for developers.
    static func plainProblem(_ error: PlanKitError, setup d: SetupData) -> String {
        switch error {
        case .infeasibleProfile:
            if let note = d.gentleRaceNote { return note }
            return "The plan cannot fit your answers yet. Try more training days or more hours."
        default:
            return error.errorDescription ?? "The plan could not be built from your answers yet."
        }
    }

    /// Builds the plan the setup asks for. When the engine refuses, falls back to a base plan with a calm reason.
    static func buildPlan(_ d: SetupData, planStart: Date, today: Date, benchmarks: Benchmarks, calendar cal: Calendar) -> PlanResult {
        var athlete = athlete(d)
        var note: String? = nil
        if athlete.poolWeekdays.intersection(athlete.availableWeekdays).isEmpty, !athlete.availableWeekdays.isEmpty {
            // The engine places swims on pool days that are also training days. Without one, swims can go on any training day.
            athlete.poolWeekdays = athlete.availableWeekdays
            note = "None of your pool days is a training day, so swims can fall on any training day."
        }
        func basePlan(from start: Date) -> EnginePlan? {
            try? kit.makeBasePlan(startDate: start, athlete: athlete, benchmarks: benchmarks, calendar: cal)
        }
        // A rolling four week block anchored on the day the athlete started: the block that contains today.
        // Anchoring on planStart keeps session ids, week counts and completions stable from day to day.
        let blockStart = rollingBlockStart(planStart: planStart, today: today, calendar: cal)
        if d.noRaceYet {
            if let plan = basePlan(from: blockStart) { return PlanResult(plan: plan, problem: note) }
            return PlanResult(plan: nil, problem: "The plan cannot fit your answers yet. Try more training days or more hours.")
        }
        let raceDate = cal.startOfDay(for: d.raceDate)
        if raceDate < today {
            return PlanResult(plan: basePlan(from: blockStart), problem: "Your race date has passed. Choose Redo setup under Learn and setup to add a new date.")
        }
        do {
            let plan = try kit.makePlan(
                raceDistance: distance(d.raceChoice), raceDate: raceDate, startDate: planStart,
                athlete: athlete, benchmarks: benchmarks, calendar: cal)
            return PlanResult(plan: plan, problem: note)
        } catch let error as PlanKitError {
            return PlanResult(plan: basePlan(from: blockStart), problem: plainProblem(error, setup: d))
        } catch {
            return PlanResult(plan: basePlan(from: blockStart), problem: "The plan could not be built from your answers yet. Try more training days or more hours.")
        }
    }

    /// Contiguous phase lengths in plan order, for example base 5, build 4, peak 2, taper 1.
    static func phaseCounts(_ plan: EnginePlan) -> [(Phase, Int)] {
        var counts: [BricklinePlanKit.Phase: Int] = [:]
        for w in plan.weeks { counts[w.phase, default: 0] += 1 }
        let order: [BricklinePlanKit.Phase] = [.base, .build, .peak, .taper]
        let mapped: [(Phase, Int)] = order.compactMap { p in
            guard let n = counts[p], n > 0 else { return nil }
            switch p {
            case .base: return (Phase.base, n)
            case .build: return (Phase.build, n)
            case .peak: return (Phase.peak, n)
            case .taper: return (Phase.taper, n)
            }
        }
        return mapped.isEmpty ? [(.base, 1)] : mapped
    }

    static func build(
        setup d: SetupData, planStart: Date, today rawToday: Date, completions: [String: CompletionRecord],
        readiness: ReadinessInputs? = nil, easedWeeks: Set<String> = [], calendar cal: Calendar = EngineBuilder.calendar()
    ) -> EngineModel {
        let today = cal.startOfDay(for: rawToday)
        let start = cal.startOfDay(for: planStart)
        let bench = benchmarks(d, today: today)
        let built = buildPlan(d, planStart: start, today: today, benchmarks: bench, calendar: cal)
        let hasRace = !d.noRaceYet
        let raceDay = cal.startOfDay(for: d.raceDate)
        let daysToRace = hasRace ? max(0, cal.daysBetween(today, raceDay)) : 0

        // Which plan supplies the week on screen.
        var weekPlan = built.plan
        var weekIndex = 0
        var planBeginsOn: Date? = nil
        if let plan = built.plan {
            let c = plan.resolvedCalendar(cal)
            if let idx = plan.weekIndex(containing: today, calendar: c) {
                weekIndex = idx
            } else if today < plan.startDate {
                // A race further out than its plan: easy base weeks bridge the gap until the plan begins.
                // The block is anchored on the day the athlete started, so ids and completions stay put.
                let blockStart = rollingBlockStart(planStart: start, today: today, calendar: cal)
                weekPlan = (try? kit.makeBasePlan(startDate: blockStart, athlete: plan.athlete, benchmarks: bench, calendar: cal))
                weekIndex = weekPlan?.weekIndex(containing: today, calendar: weekPlan?.resolvedCalendar(cal) ?? cal) ?? 0
                planBeginsOn = plan.startDate
            } else {
                weekIndex = max(0, plan.weeks.count - 1)
            }
        }

        // Readiness (annex C rules 9 to 13): sleep, resting heart rate and heart rate variability from the connected
        // devices. It can only ease or move one hard session, and the athlete can put it back with one tap.
        var assessment: ReadinessAssessment? = nil
        var pendingEvent: AdaptationEvent? = nil
        var kept = false
        var reasons: [String: String] = [:]
        if let inputs = readiness, let wp = weekPlan {
            let ran = kit.readiness(plan: wp, inputs: inputs, today: today, calendar: cal)
            var plan = ran.plan
            assessment = ran.assessment
            let keptToday = inputs.overrides.contains { cal.isDate($0, inSameDayAs: today) }
            if let event = ran.events.first(where: { $0.canKeepPlannedSession }) {
                if keptToday,
                   let restored = try? kit.keepPlannedSession(event, in: plan, today: today, calendar: cal) {
                    plan = restored.plan
                    kept = true
                } else {
                    pendingEvent = event
                    for id in event.sessionIDs { reasons[id] = ReadinessPlainCopy.sessionReason(from: event.reasonLine) }
                }
            }
            weekPlan = plan
        }

        var engineSessions: [String: BricklinePlanKit.Session] = {
            var all: [String: BricklinePlanKit.Session] = [:]
            for p in [built.plan, weekPlan].compactMap({ $0 }) { for s in p.allSessions { all[s.id] = s } }
            return all
        }()
        var easedThisWeek = false

        // The seven days of the current week.
        var days: [PlanDay] = []
        if let wp = weekPlan, wp.weeks.indices.contains(weekIndex) {
            let c = wp.resolvedCalendar(cal)
            let week = wp.weeks[weekIndex]
            // "This feels too hard": the sessions still to do this week come down to easy and a quarter shorter.
            easedThisWeek = easedWeeks.contains(EaseStore.weekKey(week.startDate, calendar: c))
            for i in 0..<7 {
                let date = c.startOfDay(for: c.addDays(i, to: week.startDate))
                let list = (week.days[date] ?? []).sorted { $0.id < $1.id }
                let sessions: [Session] = list.map { original in
                    var source = original
                    var why = reasons[original.id]
                    var rule: String? = nil
                    if easedThisWeek, EaseWeek.shouldEase(original, today: today, hasCompletion: completions[original.id] != nil, calendar: c) {
                        source = EaseWeek.eased(original, kit: kit)
                        engineSessions[original.id] = source
                        why = EaseWeek.reason
                        rule = EaseWeek.rule
                    }
                    return makeSession(source, plan: wp, benchmarks: bench, completion: completions[original.id], reason: why, reasonRule: rule)
                }
                days.append(PlanDay(date: date, sessions: sessions, isToday: c.isDate(date, inSameDayAs: today)))
            }
        } else {
            var monday = today
            while cal.component(.weekday, from: monday) != cal.firstWeekday { monday = cal.addDays(-1, to: monday) }
            days = (0..<7).map { i in
                let date = cal.addDays(i, to: monday)
                return PlanDay(date: date, sessions: [], isToday: date == today)
            }
        }

        let shown = built.plan
        let total = max(1, shown?.weeks.count ?? 1)
        let current = min(max(weekIndex + 1, 1), total)
        let phases = shown.map(phaseCounts) ?? [(.base, 1)]
        let recovery = Set((shown?.weeks ?? []).filter(\.isRecovery).map { $0.index + 1 })
        let tests = Set((shown?.weeks ?? []).filter(\.isTest).map { $0.index + 1 })

        // Preview numbers: full weeks only, because the first week can start mid week.
        let fullWeeks = (shown?.weeks ?? []).dropFirst()
        let counted = fullWeeks.isEmpty ? (shown?.weeks ?? []) : Array(fullWeeks)
        let sessionsPerWeek = counted.isEmpty ? 0 : Int((Double(counted.map { $0.sessions.count }.reduce(0, +)) / Double(counted.count)).rounded())
        let hoursPerWeek = counted.isEmpty ? 0 : counted.map(\.plannedHours).reduce(0, +) / Double(counted.count)
        let previewWeek = (shown?.weeks ?? []).first { $0.sessions.count >= 3 } ?? shown?.weeks.first
        let firstWeek = (previewWeek.map { w in w.sessions.map { makeSession($0, plan: shown ?? EnginePlan(raceDistance: nil, raceDate: nil, startDate: today, weeks: [], athlete: athlete(d)), benchmarks: bench, completion: nil) } }) ?? []

        // Fitness, Fatigue and Form from what was completed.
        var fitness: FitnessSummary? = nil
        if let wp = weekPlan {
            fitness = fitnessSummary(completions: completions, plan: wp, benchmarks: bench, today: today, calendar: cal)
        }

        return EngineModel(
            plan: shown, weekPlan: weekPlan, benchmarks: bench, calendar: cal, today: today,
            hasRace: hasRace, daysToRace: daysToRace, totalWeeks: total, currentWeek: current,
            phases: phases, recoveryWeeks: recovery, testWeeks: tests, week: days,
            problem: built.problem, warnings: summarizeWarnings(shown?.warnings ?? [], trainingDays: d.trainingDays.count),
            fitness: fitness,
            race: raceModel(setup: d, benchmarks: bench, today: today, daysToRace: daysToRace, calendar: cal),
            sessionsPerWeek: sessionsPerWeek, hoursPerWeek: hoursPerWeek,
            firstWeekSessions: firstWeek, firstWeekIsPartial: previewWeek?.index == 0 && (previewWeek?.sessions.count ?? 0) < 3,
            engineSessions: engineSessions, readiness: assessment, readinessEvent: pendingEvent, readinessKept: kept,
            planBeginsOn: planBeginsOn, weekEased: easedThisWeek)
    }

    // MARK: Fitness

    static func fitnessSummary(
        completions: [String: CompletionRecord], plan: EnginePlan, benchmarks: Benchmarks, today: Date, calendar cal: Calendar
    ) -> FitnessSummary? {
        guard !completions.isEmpty else { return nil }
        let model = DefaultLoadModel()
        var levels: [String: Int] = [:]
        let workouts: [CompletedWorkout] = completions.values.sorted { $0.sessionID < $1.sessionID }.map { r in
            levels[r.sessionID] = r.level
            return CompletedWorkout(
                id: r.sessionID, sport: BricklinePlanKit.Sport(rawValue: r.sport) ?? .run, start: r.date,
                durationSeconds: Double(r.minutes) * 60, plannedSessionID: r.sessionID, source: .phonePlayer)
        }
        // The range starts at the first completed session, so `hasFullHistory` is true only once the athlete's own
        // history spans 42 days. Before that the series is seeded at zero and the UI says "building".
        let earliest = workouts.map(\.start).min() ?? today
        let from = cal.startOfDay(for: earliest)
        let daily = model.dailyLoads(workouts: workouts, benchmarks: benchmarks, plannedLevels: levels, from: from, through: today, calendar: cal)
        let series = model.fitnessForm(dailyLoads: daily, calendar: cal)
        guard let last = series.last else { return nil }
        return FitnessSummary(fitness: last.fitness, fatigue: last.fatigue, form: last.form,
                              hasFullHistory: daily.count >= LoadConstants.fullHistoryDays)
    }

    // MARK: Race

    static let defaultStartMinutes = 7 * 60 + 5

    static func raceModel(setup d: SetupData, benchmarks: Benchmarks, today: Date, daysToRace: Int, calendar cal: Calendar) -> RaceModel {
        let dist = distance(d.raceChoice)
        let athlete = athlete(d)
        let (card, fuel) = kit.racePlan(distance: dist, athlete: athlete, benchmarks: benchmarks)
        let css = benchmarks.cssSecondsPer100m?.value
        var typical: Set<Sport> = []
        var legs: [PlanStep] = []
        for t in card.targets {
            let sp = sport(t.leg.sport)
            if t.durationBasis == .typicalForLevel { typical.insert(sp) }
            let seconds = t.expectedDurationSeconds.midpoint
            let targetText = text(t.target, level: 3, css: css)
            switch t.leg.sport {
            case .swim:
                let m = Int((t.leg.distanceKm * 1000).rounded())
                legs.append(PlanStep(sport: .swim, kind: .work, name: "Swim \(m) m", seconds: seconds, level: 3,
                                     target: targetText, distance: "\(m) m", meters: m))
            case .bike:
                let km = t.leg.distanceKm == t.leg.distanceKm.rounded() ? String(Int(t.leg.distanceKm)) : String(t.leg.distanceKm)
                legs.append(PlanStep(sport: .bike, kind: .work, name: "Bike \(km) km", seconds: seconds, level: 3, target: targetText))
            case .run:
                let km = t.leg.distanceKm == t.leg.distanceKm.rounded() ? String(Int(t.leg.distanceKm)) : String(t.leg.distanceKm)
                legs.append(PlanStep(sport: .run, kind: .work, name: "Run \(km) km", seconds: seconds, level: 4, target: targetText))
            }
        }
        // The engine plans a sprint for a super sprint. The race card shows the shorter legs, scaled from the sprint times.
        if d.raceChoice == .superSprint {
            let sprint = RaceChoice.sprint
            legs = legs.map { leg in
                var out = leg
                switch leg.sport {
                case .swim:
                    out.seconds = leg.seconds * Double(d.raceChoice.swimMeters) / Double(sprint.swimMeters)
                    out.name = "Swim \(d.raceChoice.swimMeters) m"
                    out.distance = "\(d.raceChoice.swimMeters) m"
                    out.meters = d.raceChoice.swimMeters
                case .bike:
                    out.seconds = leg.seconds * Double(d.raceChoice.bikeKm) / Double(sprint.bikeKm)
                    out.name = "Bike \(d.raceChoice.bikeKm) km"
                case .run:
                    out.seconds = leg.seconds * d.raceChoice.runKm / sprint.runKm
                    out.name = "Run 2.5 km"
                }
                return out
            }
        }
        let raceDay = d.noRaceYet ? cal.addDays(84, to: today) : cal.startOfDay(for: d.raceDate)
        let details = RaceDetails(distance: dist, raceDate: raceDay, startMinutesAfterMidnight: defaultStartMinutes)
        let entries = kit.raceWindow(for: details, calendar: cal)
        let timeline: [Demo.TimelineItem] = entries.map { e in
            Demo.TimelineItem(daysBefore: e.tMinusDays == 0 ? nil : e.tMinusDays, symbol: symbol(e.kind),
                              text: PlainCopy.sanitize(e.text), done: e.tMinusDays > daysToRace && !d.noRaceYet)
        }
        let wake = entries.first { $0.kind == .wakeUp }?.minutesAfterMidnight ?? DefaultRaceWindow().wakeUpMinutes(for: details)
        let fuelRows: [RaceModel.Fuel] = fuel.map { f in
            let sp = sport(f.leg.sport)
            let seconds = legs.first { $0.sport == sp }?.seconds ?? 0
            var line = ""
            if let carbs = f.carbsGramsPerHour {
                line = "About \(Int(carbs.lower.rounded())) to \(Int(carbs.upper.rounded())) g of carbohydrate per hour. "
            } else {
                line = "Fluids to thirst. "
            }
            return RaceModel.Fuel(sport: sp, seconds: seconds, text: PlainCopy.sanitize(line + f.practiceLine))
        }
        return RaceModel(
            legs: legs, startMinutes: defaultStartMinutes, wakeMinutes: wake, timeline: timeline, fueling: fuelRows,
            caveat: card.caveat, stomachLine: fuel.first?.stomachLine ?? RaceWindowCopy.stomachLine, typicalLegs: typical)
    }

    static func symbol(_ k: RaceWindowEntryKind) -> String {
        switch k {
        case .bikeService: "wrench.and.screwdriver"
        case .travel: "airplane"
        case .pack: "suitcase"
        case .carbLoad: "fork.knife"
        case .packTonight: "shippingbox"
        case .wakeUp: "alarm"
        }
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

// MARK: Shared instance

/// Holds the engine model for the current setup and day, and rebuilds it only when something it depends on changes.
@MainActor
final class EngineAdapter: ObservableObject {
    static let shared = EngineAdapter()

    private struct Key: Equatable {
        var setup: SetupData
        var planStart: Date
        var today: Date
        var completions: [String: CompletionRecord]
        var readiness: ReadinessInputs?
        var eased: Set<String>
    }

    @Published private(set) var completions: [String: CompletionRecord]
    @Published private(set) var easedWeeks: Set<String> = EaseStore.load()
    private var cached: (key: Key, model: EngineModel)?
    private var readinessWatch: AnyCancellable?

    private init() {
        completions = CompletionStore.load()
        // A new night, a different source or a Keep tap changes the plan on screen.
        readinessWatch = ReadinessCoordinator.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }

    /// The model for the saved setup and today's date.
    var model: EngineModel {
        let calendar = EngineBuilder.calendar()
        let key = Key(setup: UserSetup.shared.data, planStart: Demo.planStart,
                      today: calendar.startOfDay(for: Date()), completions: completions,
                      readiness: ReadinessCoordinator.shared.inputs(for: UserSetup.shared.data),
                      eased: easedWeeks)
        if let cached, cached.key == key { return cached.model }
        let built = EngineBuilder.build(setup: key.setup, planStart: key.planStart, today: key.today,
                                        completions: key.completions, readiness: key.readiness, easedWeeks: key.eased, calendar: calendar)
        cached = (key, built)
        return built
    }

    private var previewCached: (setup: SetupData, day: Date, model: EngineModel)?

    /// A model for answers that are not saved yet, for the onboarding preview. Remembers the last one asked for.
    func preview(for setup: SetupData) -> EngineModel {
        let calendar = EngineBuilder.calendar()
        let day = calendar.startOfDay(for: Date())
        if let c = previewCached, c.setup == setup, c.day == day { return c.model }
        let built = EngineBuilder.build(setup: setup, planStart: day, today: day, completions: [:], calendar: calendar)
        previewCached = (setup, day, built)
        return built
    }

    /// Remembers a finished session so it shows as done and counts toward Load, Fitness and Form.
    func recordCompletion(of session: Session, minutes: Int) {
        guard let id = session.engineID else { return }
        completions[id] = CompletionRecord(
            sessionID: id, minutes: max(1, minutes), date: session.scheduledDate ?? Date(),
            sport: session.sport.rawValue, level: session.engineLevel)
        CompletionStore.save(completions)
    }

    /// Records a completion for the session with this engine id, found in the current week.
    func recordCompletion(engineID: String, minutes: Int) {
        guard let session = model.week.flatMap(\.sessions).first(where: { $0.engineID == engineID }) else { return }
        recordCompletion(of: session, minutes: minutes)
    }

    func clearCompletions() {
        completions = [:]
        CompletionStore.clear()
        easedWeeks = []
        EaseStore.clear()
    }

    /// "This feels too hard": eases what is left of the week on screen.
    func easeCurrentWeek() {
        guard let wp = model.weekPlan else { return }
        let c = wp.resolvedCalendar(EngineBuilder.calendar())
        guard let index = wp.weekIndex(containing: Demo.today, calendar: c), wp.weeks.indices.contains(index) else { return }
        easedWeeks.insert(EaseStore.weekKey(wp.weeks[index].startDate, calendar: c))
        EaseStore.save(easedWeeks)
    }

    /// Puts the week back as planned.
    func undoEaseCurrentWeek() {
        easedWeeks = []
        EaseStore.clear()
    }

    // MARK: Compiled workouts

    /// The engine session behind a screen session.
    func engineSession(for session: Session) -> BricklinePlanKit.Session? {
        guard let id = session.engineID else { return nil }
        return model.engineSessions[id]
    }

    /// The full fidelity workouts the phone player runs, compiled by the engine for this session.
    func phoneWorkouts(for session: Session) -> [CompiledWorkout] {
        let m = model
        guard let s = engineSession(for: session), let plan = m.weekPlan else { return [] }
        return (try? EngineBuilder.kit.compilePhoneWorkouts(s, in: plan, benchmarks: m.benchmarks)) ?? []
    }

    /// The engine's compile result for the watch, with its plain notes.
    func compiled(for session: Session, capabilities: DeviceCapabilities = .standard) -> CompiledSession? {
        let m = model
        guard let s = engineSession(for: session), let plan = m.weekPlan else { return nil }
        return try? EngineBuilder.kit.compile(s, in: plan, benchmarks: m.benchmarks, capabilities: capabilities, indoor: false)
    }

#if canImport(WorkoutKit)
    /// WorkoutKit plans for the session, one per compiled workout (a brick gives the ride, then the run).
    @available(iOS 18, *)
    func workoutPlans(for session: Session) -> [WorkoutPlan] {
        guard let c = compiled(for: session) else { return [] }
        return WorkoutKitBridge.makePlans(from: c, capabilities: .standard) { _ in UUID() }
    }
#endif
}
