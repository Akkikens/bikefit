import Foundation

/// View models the screens draw, and `Demo`, the one place the screens read the plan from. Every number behind it comes
/// from BricklinePlanKit through `EngineAdapter`; nothing here is hand written plan data.
enum Sport: String, CaseIterable, Identifiable {
    case swim, bike, run
    var id: String { rawValue }
    var word: String { rawValue.capitalized }
    func symbol(openWater: Bool = false, indoor: Bool = false) -> String {
        switch self {
        case .swim: openWater ? "figure.open.water.swim" : "figure.pool.swim"
        case .bike: indoor ? "figure.indoor.cycle" : "figure.outdoor.cycle"
        case .run: "figure.run"
        }
    }
}

enum StepKind { case warm, work, recovery, cool }

struct PlanStep: Identifiable, Hashable {
    let id = UUID()
    var sport: Sport
    var kind: StepKind
    var name: String
    var seconds: TimeInterval
    /// 1 easy to 5 hardest; drives Profile block height.
    var level: Int
    var target: String?
    var distance: String?
    /// Distance covered by the step in meters, for swim distance readouts and the swim ruler. Rests carry nil.
    var meters: Int? = nil
    /// Steps sharing a group are one repeat set; `repeatCount` is shown on the first.
    var group: Int? = nil
    var repeatCount: Int? = nil

    /// How the step should feel, in plain words, so a target pace always comes with a feel.
    var feel: String {
        switch kind {
        case .warm, .cool: return "Easy. You could chat."
        case .recovery: return "Very easy. Let your breathing settle."
        case .work:
            switch level {
            case ...2: return "Easy. You could chat."
            case 3: return "Steady. You can say short sentences."
            case 4: return "Hard but controlled. A few words at a time."
            default: return "All out."
            }
        }
    }
}

enum SessionState { case planned, done, skipped }

struct Session: Identifiable, Hashable {
    var id = UUID()
    var sport: Sport
    var name: String
    var purpose: String
    var steps: [PlanStep]
    var state: SessionState = .planned
    var reason: String? = nil
    /// The written rule behind `reason`, for the expandable line. Nil uses the pace rule.
    var reasonRule: String? = nil
    var headlineTarget: (value: String, unit: String)? = nil
    var watchLine: String
    var doneMinutes: Int? = nil
    var isTest: Bool = false
    var brickSecond: Sport? = nil
    /// Open water swims offer a pool version; pool swims do not.
    var isOpenWater: Bool = false
    /// The one technical idea behind the session (brick, threshold, ...), shown as a tap to explain line under the title.
    var idea: Term? = nil
    /// Plain wording for that line, e.g. "This is a brick".
    var ideaLabel: String? = nil
    /// The engine's deterministic id, so the engine session behind this one can be found again. Nil for player tests.
    var engineID: String? = nil
    var scheduledDate: Date? = nil
    /// Load in points from the engine: planned Load for a session still to do, recorded Load once done.
    var loadPoints: Int = 0
    /// True when the engine marks the Load as an estimate (a swim without heart rate, a guessed power number, a plan).
    var loadEstimated: Bool = true
    /// True when the headline target rests on an estimated benchmark rather than a test or a number the athlete typed.
    var targetsEstimated: Bool = false
    /// Representative intensity level 1 to 5, kept for the Load history.
    var engineLevel: Int = 2

    var minutes: Int { Int((steps.reduce(0) { $0 + $1.seconds } / 60).rounded()) }

    /// True when the headline target is power in watts. Without a power meter bike sessions use how hard it feels.
    var usesPower: Bool { headlineTarget?.unit == "watts" }

    /// What the headline target is, in words: a pace, a power, a heart rate, or how it feels.
    var targetLabel: String {
        switch headlineTarget?.unit {
        case "watts": return "target power"
        case "effort": return "how it feels"
        case "beats per min": return "target heart rate"
        default: return sport == .bike ? "how it feels" : "target pace"
        }
    }

    /// How the main effort of the session should feel, from its hardest working step.
    var feel: String? {
        steps.filter { $0.kind == .work }.max(by: { $0.level < $1.level })?.feel
    }

    /// Short sport words for a chip or a list: "Swim", or "Bike then run" for a brick.
    var chipWord: String { brickSecond.map { "\(sport.word) then \($0.word.lowercased())" } ?? sport.word }

    /// Total swim distance when every working step carries meters, else nil.
    var totalMeters: Int? {
        let m = steps.compactMap(\.meters)
        return m.isEmpty ? nil : m.reduce(0, +)
    }
    /// Swims lead with distance, the number a swimmer needs on the pool deck. Bricks and other sports lead with time.
    var showsDistance: Bool { sport == .swim && totalMeters != nil && brickSecond == nil }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension Session {
    /// Rep context for a step inside a repeat set, the way an athlete counts it.
    /// Work step: "repeat 3 of 8". Rest inside the set: "rest, then repeat 4 of 8". Nil outside a set.
    func repLabel(at i: Int) -> String? {
        guard steps.indices.contains(i), let g = steps[i].group else { return nil }
        let works = steps.indices.filter { steps[$0].group == g && steps[$0].kind == .work }
        guard let first = works.first else { return nil }
        let total = steps[first].repeatCount ?? works.count
        let done = works.filter { $0 < i }.count
        switch steps[i].kind {
        case .work: return "repeat \(done + 1) of \(total)"
        default: return done < total ? "rest, then repeat \(done + 1) of \(total)" : nil
        }
    }
}

struct PlanDay: Identifiable {
    let id = UUID()
    var date: Date
    var sessions: [Session]
    var isToday: Bool
}

enum Phase: String, CaseIterable { case base, build, peak, taper }

extension Phase {
    /// The glossary entry that explains this part of the plan.
    var glossaryTerm: Term {
        switch self { case .base: .base; case .build: .build; case .peak: .peak; case .taper: .taper }
    }
    /// One plain line on what the phase is for.
    var plainLine: String {
        switch self {
        case .base: "easy building"
        case .build: "harder sessions added"
        case .peak: "your biggest weeks"
        case .taper: "lighter weeks so you arrive fresh"
        }
    }
    /// Capitalised word for headings: "Build".
    var displayName: String { rawValue.capitalized }
}


/// What the screens read. Every value forwards to the engine model for the saved setup and today's date.
@MainActor
enum Demo {
    static let calendar = EngineBuilder.calendar()
    static var today: Date { EngineBuilder.calendar().startOfDay(for: Date()) }

    private static let planStartKey = "brickline.demo.planStart"

    /// The day the athlete started the plan. Set when onboarding finishes, today when it was never set.
    static var planStart: Date {
        (UserDefaults.standard.object(forKey: planStartKey) as? Date) ?? today
    }
    static func startPlan() { UserDefaults.standard.set(today, forKey: planStartKey) }
    static func clearPlanStart() { UserDefaults.standard.removeObject(forKey: planStartKey) }

    static var setup: SetupData { UserSetup.shared.data }
    static var model: EngineModel { EngineAdapter.shared.model }

    static var phases: [(Phase, Int)] { model.phases }
    static var currentWeek: Int { model.currentWeek }
    static var totalWeeks: Int { model.totalWeeks }
    /// "Week 3 of 12", or a base weeks line while the race plan has not started.
    static var weekLabel: String {
        if let begins = model.planBeginsOn { return "Base weeks until \(begins.formatted(.dateTime.day().month(.abbreviated)))" }
        return "Week \(currentWeek) of \(totalWeeks)"
    }
    static var planHasStarted: Bool { model.planBeginsOn == nil }
    static var recoveryWeeks: Set<Int> { model.recoveryWeeks }
    static var testWeeks: Set<Int> { model.testWeeks }
    static var hasRace: Bool { model.hasRace }
    static var daysToRace: Int { model.daysToRace }
    static var hasPowerMeter: Bool { setup.hasPowerMeter }
    /// A calm line when the engine could not build exactly the plan asked for, else nil.
    static var planProblem: String? { model.problem }

    /// "Olympic triathlon" or the name the athlete typed.
    static var raceName: String {
        let typed = setup.raceName.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        return setup.raceChoice == .half ? setup.raceChoice.title : "\(setup.raceChoice.title) triathlon"
    }
    /// Start time of the race as "7:05" (24 hour clock), and the wake time the engine works out from it.
    static var raceStart: String { EngineBuilder.clock(model.race.startMinutes) }
    static var raceWake: String { EngineBuilder.clock(model.race.wakeMinutes) }
    /// Time of day the session is scheduled on the watch. Scheduling is not wired yet, so this is a fixed morning time.
    static let sessionTime = "6:30"

    /// Position of a season week inside its phase, derived from `phases`.
    static func phasePosition(of week: Int) -> (phase: Phase, index: Int, length: Int) {
        let list = phases
        var start = 1
        for (phase, length) in list {
            if week < start + length { return (phase, week - start + 1, length) }
            start += length
        }
        let last = list[list.count - 1]
        return (last.0, last.1, last.1)
    }
    static var currentPhase: Phase { model.planBeginsOn != nil ? .base : phasePosition(of: currentWeek).phase }

    // MARK: Sessions

    /// The seven days of this week, Monday first, with the engine's sessions.
    static var week: [PlanDay] { model.week }
    static var todaySessions: [Session] { week.first(where: { $0.isToday })?.sessions ?? [] }
    /// The first session after today, or the first of the week when none follows. Nil only for an empty plan.
    static var nextSession: Session? {
        let days = week
        if let i = days.firstIndex(where: { $0.isToday }),
           let next = days[(i + 1)...].first(where: { !$0.sessions.isEmpty }) { return next.sessions.first }
        return days.flatMap(\.sessions).first
    }
    static func dayName(of session: Session) -> String? {
        guard let day = week.first(where: { $0.sessions.contains(session) }) else { return nil }
        return day.isToday ? "today" : day.date.formatted(.dateTime.weekday(.wide))
    }
    /// A session with intervals for `-screenPlayer` and `-screenDetail`: today's, else the first with repeats, else any.
    static var smokeSession: Session? {
        let all = week.flatMap(\.sessions)
        return todaySessions.first ?? all.first { $0.steps.contains { $0.group != nil } } ?? all.first
    }
    static var fitness: FitnessSummary? { model.fitness }

    // MARK: Race

    static var raceLegs: [PlanStep] { model.race.legs }
    /// Transition estimates in seconds.
    static let transitions: (t1: TimeInterval, t2: TimeInterval) = (120, 60)
    static var racePredicted: TimeInterval { raceLegs.reduce(0) { $0 + $1.seconds } + transitions.t1 + transitions.t2 }
    static var raceDate: Date { calendar.date(byAdding: .day, value: daysToRace, to: today) ?? today }
    static var raceModel: RaceModel { model.race }

    /// Clock times as the athlete reads them. The bare strings above stay machine readable ("7:05").
    static var raceStartLabel: String { raceStart + " am" }
    static var raceWakeLabel: String { raceWake + " am" }
    static var sessionTimeLabel: String { sessionTime + " am" }

    /// One line of the race plan. `daysBefore` is nil on race day.
    struct TimelineItem: Identifiable {
        let id = UUID()
        var daysBefore: Int?
        var symbol: String
        var text: String
        var done: Bool

        /// Plain wording: "14 days before the race", "Race day".
        var when: String {
            switch daysBefore {
            case nil: return "Race day"
            case 1?: return "1 day before the race"
            case let n?: return "\(n) days before the race"
            }
        }
    }
    static var timeline: [TimelineItem] { model.race.timeline }

    struct Checklist: Identifiable { let id = UUID(); var title: String; var items: [String] }
    static let checklists: [Checklist] = [
        .init(title: "Pack for swim, bike and run", items: ["Wetsuit", "Goggles, spare pair", "Swim cap from your race packet", "Bike, helmet, shoes", "Bottles and gels", "Run shoes with elastic laces", "Race belt and number", "Cap and sunglasses"]),
        .init(title: "Bag for the changing area", items: ["Towel to mark your spot", "Bike shoes clipped or ready", "Helmet unbuckled on the bars", "Run shoes, socks rolled", "Gels taped to the top tube", "Spare inner tube and CO2 inflator"]),
        .init(title: "Race morning", items: ["Breakfast 3 hours before the start", "Get your race number marked on your arms and leg", "Check tire pressure", "Walk from the swim exit to your bike", "Walk your bike out and back in", "Warm up with a short swim if allowed"]),
    ]
}
