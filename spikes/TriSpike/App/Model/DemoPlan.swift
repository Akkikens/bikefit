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

    var minutes: Int { Int((steps.reduce(0) { $0 + $1.seconds } / 60).rounded()) }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
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

    static let cssSwim: Session = {
        var steps = [PlanStep(sport: .swim, kind: .warm, name: "Easy 300", seconds: 360, level: 2, target: "easy", distance: "300 m")]
        for _ in 0..<8 {
            steps.append(PlanStep(sport: .swim, kind: .work, name: "100 on 2:00", seconds: 105, level: 4, target: "1:45 /100m", distance: "100 m", group: 1, repeatCount: 8))
            steps.append(PlanStep(sport: .swim, kind: .recovery, name: "Rest", seconds: 15, level: 1, target: nil, distance: nil, group: 1))
        }
        steps.append(PlanStep(sport: .swim, kind: .cool, name: "Easy 200", seconds: 240, level: 2, target: "easy", distance: "200 m"))
        return Session(
            sport: .swim, name: "CSS 8 x 100",
            purpose: "Eight fast hundreds at threshold pace to lift the speed you can hold for 1500 m.",
            steps: steps,
            reason: "Paces moved up 2 s per 100 m. Your last three CSS swims came in faster than target.",
            headlineTarget: ("1:45", "/100m"),
            watchLine: "Lands as 8 reps of 100 m on 2:00; the watch advances when distance and time are both met.")
    }()

    static let sweetSpotBike: Session = {
        var steps = [PlanStep(sport: .bike, kind: .warm, name: "Warm up", seconds: 600, level: 2, target: "150 to 170 w")]
        for _ in 0..<3 {
            steps.append(PlanStep(sport: .bike, kind: .work, name: "Sweet spot", seconds: 600, level: 4, target: "220 to 235 w", group: 2, repeatCount: 3))
            steps.append(PlanStep(sport: .bike, kind: .recovery, name: "Spin easy", seconds: 300, level: 1, target: "under 150 w", group: 2))
        }
        steps.append(PlanStep(sport: .bike, kind: .cool, name: "Cool down", seconds: 600, level: 2, target: "easy"))
        var s = Session(sport: .bike, name: "Sweet spot 3 x 10", purpose: "Three long efforts just under threshold to build the engine for the bike leg.",
                        steps: steps, headlineTarget: ("220", "w"), watchLine: "Power range alerts at 220 to 235 w, average power.")
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
        steps: [PlanStep(sport: .swim, kind: .work, name: "Steady 1500", seconds: 1800, level: 2, target: "1:58 /100m", distance: "1500 m")],
        headlineTarget: ("1:58", "/100m"), watchLine: "Lands as one 1500 m swim with a distance goal.")

    static let brick: Session = {
        let steps = [
            PlanStep(sport: .bike, kind: .warm, name: "Warm up", seconds: 900, level: 2, target: "easy"),
            PlanStep(sport: .bike, kind: .work, name: "Race pace", seconds: 2700, level: 3, target: "200 to 215 w"),
            PlanStep(sport: .run, kind: .work, name: "Run off the bike", seconds: 900, level: 3, target: "4:50 /km"),
        ]
        var s = Session(sport: .bike, name: "Brick 60 + 15", purpose: "A steady ride then straight into a run, to teach your legs the switch.",
                        steps: steps, headlineTarget: ("205", "w"), watchLine: "Lands as two workouts: the ride, then the run.")
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
        PlanStep(sport: .swim, kind: .work, name: "Swim 1500 m", seconds: 1680, level: 3, target: "1:52 /100m"),
        PlanStep(sport: .bike, kind: .work, name: "Bike 40 km", seconds: 4200, level: 3, target: "205 to 220 w"),
        PlanStep(sport: .run, kind: .work, name: "Run 10 km", seconds: 2820, level: 4, target: "4:35 to 4:50 /km"),
    ]

    struct TimelineItem: Identifiable { let id = UUID(); var tMinus: String; var symbol: String; var text: String; var done: Bool }
    static let timeline: [TimelineItem] = [
        .init(tMinus: "T minus 14", symbol: "wrench.and.screwdriver", text: "Bike service: tires, chain, brake pads", done: false),
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
