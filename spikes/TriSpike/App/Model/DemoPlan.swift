import Foundation

/// Demo plan data for the prototype: week 9 of 16 of an Olympic plan. Shapes match SampleSessions.
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
}

enum SessionState { case planned, done, skipped }

struct Session: Identifiable, Hashable {
    let id = UUID()
    var sport: Sport
    var name: String
    var purpose: String
    var steps: [PlanStep]
    var state: SessionState = .planned
    var reason: String? = nil
    var headlineTarget: (value: String, unit: String)? = nil
    var watchLine: String
    var doneMinutes: Int? = nil
    var isTest: Bool = false
    var brickSecond: Sport? = nil
    /// Open water swims offer a pool version; pool swims do not.
    var isOpenWater: Bool = false

    var minutes: Int { Int((steps.reduce(0) { $0 + $1.seconds } / 60).rounded()) }

    /// Total swim distance when every working step carries meters, else nil.
    var totalMeters: Int? {
        let m = steps.compactMap(\.meters)
        return m.isEmpty ? nil : m.reduce(0, +)
    }
    /// Swims lead with distance, the number a swimmer needs on the pool deck. Bricks and other sports lead with time.
    var showsDistance: Bool { sport == .swim && totalMeters != nil && brickSecond == nil }

    /// Placeholder load until real training load exists: 1.5 points per minute of what was done, else what is planned.
    /// Every place that shows it marks it as estimated.
    var estimatedLoad: Int { Session.loadEstimate(minutes: doneMinutes ?? minutes) }
    static func loadEstimate(minutes: Int) -> Int { minutes * 3 / 2 }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension Session {
    /// Rep context for a step inside a repeat set, the way an athlete counts it.
    /// Work step: "rep 3 of 8". Rest inside the set: "rest, then rep 4 of 8". Nil outside a set.
    func repLabel(at i: Int) -> String? {
        guard steps.indices.contains(i), let g = steps[i].group else { return nil }
        let works = steps.indices.filter { steps[$0].group == g && steps[$0].kind == .work }
        guard let first = works.first else { return nil }
        let total = steps[first].repeatCount ?? works.count
        let done = works.filter { $0 < i }.count
        switch steps[i].kind {
        case .work: return "rep \(done + 1) of \(total)"
        default: return done < total ? "rest, then rep \(done + 1) of \(total)" : nil
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

enum Demo {
    static let calendar = Calendar.current
    static let today = calendar.startOfDay(for: Date())

    // Season: 16 weeks, base 6, build 5, peak 3, taper 2; today is week 9.
    static let phases: [(Phase, Int)] = [(.base, 6), (.build, 5), (.peak, 3), (.taper, 2)]
    static let currentWeek = 9
    static let totalWeeks = 16
    static let recoveryWeeks: Set<Int> = [4, 8, 12]
    static let testWeeks: Set<Int> = [1, 5, 9, 13]
    static let daysToRace = 52
    static let raceName = "Harbor City Olympic"
    static let raceStart = "7:05"
    static let raceWake = "4:30"
    /// Time of day the watch schedules today's session.
    static let sessionTime = "6:30"

    /// Position of a season week inside its phase, derived from `phases`.
    static func phasePosition(of week: Int) -> (phase: Phase, index: Int, length: Int) {
        var start = 1
        for (phase, length) in phases {
            if week < start + length { return (phase, week - start + 1, length) }
            start += length
        }
        let last = phases[phases.count - 1]
        return (last.0, last.1, last.1)
    }
    static var currentPhase: Phase { phasePosition(of: currentWeek).phase }

    static let cssSwim: Session = {
        var steps = [PlanStep(sport: .swim, kind: .warm, name: "Easy 300", seconds: 360, level: 2, target: "easy", distance: "300 m", meters: 300)]
        for _ in 0..<8 {
            steps.append(PlanStep(sport: .swim, kind: .work, name: "100 on 2:00", seconds: 105, level: 4, target: "1:45 /100m", distance: "100 m", meters: 100, group: 1, repeatCount: 8))
            steps.append(PlanStep(sport: .swim, kind: .recovery, name: "Rest", seconds: 15, level: 1, target: nil, distance: nil, group: 1))
        }
        steps.append(PlanStep(sport: .swim, kind: .cool, name: "Easy 200", seconds: 240, level: 2, target: "easy", distance: "200 m", meters: 200))
        return Session(
            sport: .swim, name: "CSS 8 x 100",
            purpose: "Eight fast hundreds at threshold pace to lift the speed you can hold for 1500 m.",
            steps: steps,
            reason: "Target is 2 s per 100 m faster because your last three CSS swims beat it.",
            headlineTarget: ("1:45", "/100m"),
            watchLine: "Lands as 8 reps of 100 m on 2:00; the watch advances when distance and time are both met.")
    }()

    static let sweetSpotBike: Session = {
        var steps = [PlanStep(sport: .bike, kind: .warm, name: "Warm up", seconds: 600, level: 2, target: "150 to 170 W")]
        for _ in 0..<3 {
            steps.append(PlanStep(sport: .bike, kind: .work, name: "Sweet spot", seconds: 600, level: 4, target: "220 to 235 W", group: 2, repeatCount: 3))
            steps.append(PlanStep(sport: .bike, kind: .recovery, name: "Spin easy", seconds: 300, level: 1, target: "under 150 W", group: 2))
        }
        steps.append(PlanStep(sport: .bike, kind: .cool, name: "Cool down", seconds: 600, level: 2, target: "easy"))
        var s = Session(sport: .bike, name: "Sweet spot 3 x 10", purpose: "Three long efforts just under threshold to build the engine for the bike leg.",
                        steps: steps, headlineTarget: ("220", "W"), watchLine: "Power range alerts at 220 to 235 W, average power.")
        s.state = .done
        s.doneMinutes = 64
        return s
    }()

    static let thresholdRun: Session = {
        var steps = [PlanStep(sport: .run, kind: .warm, name: "Easy warm up", seconds: 600, level: 2, target: "5:40 /km")]
        for _ in 0..<2 {
            steps.append(PlanStep(sport: .run, kind: .work, name: "Threshold", seconds: 900, level: 4, target: "4:20 to 4:40 /km", group: 3, repeatCount: 2))
            steps.append(PlanStep(sport: .run, kind: .recovery, name: "Jog", seconds: 180, level: 1, target: "easy", group: 3))
        }
        steps.append(PlanStep(sport: .run, kind: .cool, name: "Easy cool down", seconds: 600, level: 2, target: "5:40 /km"))
        return Session(sport: .run, name: "Threshold 2 x 15", purpose: "Two long blocks at threshold pace, the speed you could hold for about an hour.",
                       steps: steps, headlineTarget: ("4:30", "/km"), watchLine: "Speed range alert 4:20 to 4:40 /km on each threshold block.")
    }()

    static let easySwim = Session(
        sport: .swim, name: "Easy 1500",
        purpose: "Steady aerobic swimming with long strokes. Keep it conversational.",
        steps: [PlanStep(sport: .swim, kind: .work, name: "Steady 1500", seconds: 1800, level: 2, target: "1:58 /100m", distance: "1500 m", meters: 1500)],
        headlineTarget: ("1:58", "/100m"), watchLine: "Lands as one 1500 m swim with a distance goal.")

    static let brick: Session = {
        let steps = [
            PlanStep(sport: .bike, kind: .warm, name: "Warm up", seconds: 900, level: 2, target: "easy"),
            PlanStep(sport: .bike, kind: .work, name: "Race pace", seconds: 2700, level: 3, target: "200 to 215 W"),
            PlanStep(sport: .run, kind: .work, name: "Run off the bike", seconds: 900, level: 3, target: "4:50 /km"),
        ]
        var s = Session(sport: .bike, name: "Brick 60 + 15", purpose: "A steady ride then straight into a run, to teach your legs the switch.",
                        steps: steps, headlineTarget: ("205", "W"), watchLine: "Lands as two workouts: the ride, then the run.")
        s.brickSecond = .run
        return s
    }()

    static let longRun = Session(
        sport: .run, name: "Long run 70",
        purpose: "Easy aerobic running, the foundation for a strong 10 k off the bike.",
        steps: [PlanStep(sport: .run, kind: .work, name: "Easy", seconds: 4200, level: 2, target: "5:30 to 5:50 /km")],
        headlineTarget: ("5:40", "/km"), watchLine: "Lands as one 70 minute run with a pace range alert.")

    static let skippedRun: Session = {
        var s = longRun
        s.name = "Easy run 40"
        s.steps = [PlanStep(sport: .run, kind: .work, name: "Easy", seconds: 2400, level: 2, target: "5:40 /km")]
        s.state = .skipped
        return s
    }()

    /// Sessions by offset from today, so the story always fits the real week: past days done or skipped,
    /// today the CSS swim, the rest planned.
    private static func sessions(at offset: Int) -> [Session] {
        func past(_ s: Session) -> Session { var c = s; c.state = .done; c.doneMinutes = s.minutes + 3; return c }
        func planned(_ s: Session) -> Session { var c = s; c.state = .planned; c.doneMinutes = nil; return c }
        switch offset {
        case -6: return [past(easySwim)]
        case -5: return [past(thresholdRun)]
        case -4: return []
        case -3: return [past(brick)]
        case -2: return [skippedRun]
        case -1: return [sweetSpotBike]
        case 0: return [cssSwim]
        case 1: return [planned(thresholdRun)]
        case 2: return []
        case 3: return [planned(brick)]
        case 4: return [easySwim, longRun]
        case 5: return [planned(sweetSpotBike)]
        default: return [planned(easySwim)]
        }
    }

    static var week: [PlanDay] {
        // Monday based week containing the real today.
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let monday = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i, to: monday)!
            let offset = cal.dateComponents([.day], from: today, to: date).day ?? 0
            return PlanDay(date: date, sessions: sessions(at: offset), isToday: offset == 0)
        }
    }

    static let raceLegs: [PlanStep] = [
        PlanStep(sport: .swim, kind: .work, name: "Swim 1500 m", seconds: 1680, level: 3, target: "1:52 /100m", distance: "1500 m", meters: 1500),
        PlanStep(sport: .bike, kind: .work, name: "Bike 40 km", seconds: 4200, level: 3, target: "205 to 220 W"),
        PlanStep(sport: .run, kind: .work, name: "Run 10 km", seconds: 2820, level: 4, target: "4:35 to 4:50 /km"),
    ]

    /// Transition estimates in seconds. 2:25 of legs plus 3 minutes of transitions is the 2:28 prediction.
    static let transitions: (t1: TimeInterval, t2: TimeInterval) = (120, 60)
    static var racePredicted: TimeInterval { raceLegs.reduce(0) { $0 + $1.seconds } + transitions.t1 + transitions.t2 }
    static var raceDate: Date { calendar.date(byAdding: .day, value: daysToRace, to: today) ?? today }

    struct TimelineItem: Identifiable { let id = UUID(); var tMinus: String; var symbol: String; var text: String; var done: Bool }
    static let timeline: [TimelineItem] = [
        .init(tMinus: "T minus 14", symbol: "wrench.and.screwdriver", text: "Bike service: tires, chain, brake pads", done: true),
        .init(tMinus: "T minus 2", symbol: "fork.knife", text: "Start carb loading", done: false),
        .init(tMinus: "T minus 1", symbol: "shippingbox", text: "Pack tonight", done: false),
        .init(tMinus: "Race day", symbol: "alarm", text: "Wake 4:30, breakfast 4:45, leave 5:30", done: false),
    ]

    struct Checklist: Identifiable { let id = UUID(); var title: String; var items: [String] }
    static let checklists: [Checklist] = [
        .init(title: "Pack by discipline", items: ["Wetsuit", "Goggles, spare pair", "Swim cap from packet", "Bike, helmet, shoes", "Bottles and gels", "Run shoes with elastic laces", "Race belt and number", "Cap and sunglasses"]),
        .init(title: "Transition bag", items: ["Towel to mark your spot", "Bike shoes clipped or ready", "Helmet unbuckled on the bars", "Run shoes, socks rolled", "Gels taped to top tube", "Spare tube and CO2"]),
        .init(title: "Race morning", items: ["Breakfast 3 hours before", "Body marking", "Tire pressure", "Walk swim exit to your rack", "Walk bike out and in", "Warm up swim if allowed"]),
    ]
}
