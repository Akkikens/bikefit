import Foundation

/// Demo plan data for the prototype. The plan clock (weeks, phases, days to race) is worked out from the athlete's setup,
/// so every screen agrees with onboarding. Session content is demo data. Shapes match SampleSessions.
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
    /// The one technical idea behind the session (brick, threshold, ...), shown as a tap to explain line under the title.
    var idea: Term? = nil
    /// Plain wording for that line, e.g. "This is a brick".
    var ideaLabel: String? = nil

    var minutes: Int { Int((steps.reduce(0) { $0 + $1.seconds } / 60).rounded()) }

    /// True when the bike target is power in watts. Without a power meter bike sessions use how hard it feels.
    var usesPower: Bool = false

    /// What the headline target is, in words: swims and runs give a pace, rides give power or how it feels.
    var targetLabel: String {
        guard sport == .bike else { return "target pace" }
        return usesPower ? "target power" : "how it feels"
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

    /// Placeholder load until real training load exists: 1.5 points per minute of what was done, else what is planned.
    /// Every place that shows it marks it as estimated.
    var estimatedLoad: Int { Session.loadEstimate(minutes: doneMinutes ?? minutes) }
    static func loadEstimate(minutes: Int) -> Int { minutes * 3 / 2 }

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

/// Where the athlete is in the plan, worked out from setup. Pure, so it can be tested without the UI.
struct PlanClock {
    var totalWeeks: Int
    var currentWeek: Int
    /// Nil when the athlete has no race yet.
    var daysToRace: Int?
    var phases: [(Phase, Int)]
    /// Every fourth week is lighter, except the last two weeks before the race.
    var recoveryWeeks: Set<Int>
    /// A short test week about every 6 weeks, starting with the first.
    var testWeeks: Set<Int>

    init(setup d: SetupData, planStart: Date, today: Date, calendar: Calendar = .current) {
        let t = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: planStart)
        let race = calendar.startOfDay(for: d.raceDate)
        func days(_ a: Date, _ b: Date) -> Int { calendar.dateComponents([.day], from: a, to: b).day ?? 0 }
        let fromStart = days(start, race)
        let total = d.noRaceYet ? OBPlan.noRaceWeeks : min(max(max(0, fromStart) / 7, 8), 24)
        // The plan covers the last `total` weeks before the race. Before that window, the athlete is in week 1.
        let windowStart = d.noRaceYet ? start : max(start, calendar.date(byAdding: .day, value: -total * 7, to: race) ?? start)
        totalWeeks = total
        currentWeek = min(max(max(0, days(windowStart, t)) / 7 + 1, 1), total)
        daysToRace = d.noRaceYet ? nil : max(0, days(t, race))
        phases = OBPlan.phaseWeeks(total: total, noRace: d.noRaceYet)
        let recovery = Set((1...total).filter { $0 % 4 == 0 && $0 <= total - 2 })
        recoveryWeeks = recovery
        testWeeks = Set(stride(from: 1, through: max(1, total - 2), by: 6).filter { !recovery.contains($0) })
    }
}

@MainActor
enum Demo {
    static let calendar = Calendar.current
    static var today: Date { calendar.startOfDay(for: Date()) }

    private static let planStartKey = "brickline.demo.planStart"

    /// The day the athlete started the plan. Set when onboarding finishes, today when it was never set.
    static var planStart: Date {
        (UserDefaults.standard.object(forKey: planStartKey) as? Date) ?? today
    }
    static func startPlan() { UserDefaults.standard.set(today, forKey: planStartKey) }
    static func clearPlanStart() { UserDefaults.standard.removeObject(forKey: planStartKey) }

    static var setup: SetupData { UserSetup.shared.data }
    static var clock: PlanClock { PlanClock(setup: setup, planStart: planStart, today: today) }

    static var phases: [(Phase, Int)] { clock.phases }
    static var currentWeek: Int { clock.currentWeek }
    static var totalWeeks: Int { clock.totalWeeks }
    static var recoveryWeeks: Set<Int> { clock.recoveryWeeks }
    static var testWeeks: Set<Int> { clock.testWeeks }
    static var hasRace: Bool { clock.daysToRace != nil }
    static var daysToRace: Int { clock.daysToRace ?? 0 }
    static var hasPowerMeter: Bool { setup.hasPowerMeter }

    /// "Olympic triathlon" or the name the athlete typed.
    static var raceName: String {
        let typed = setup.raceName.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        return setup.raceChoice == .half ? setup.raceChoice.title : "\(setup.raceChoice.title) triathlon"
    }
    static let raceStart = "7:05"
    static let raceWake = "4:30"
    /// Time of day the session is scheduled (the watch, if the athlete uses one).
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
    static var currentPhase: Phase { phasePosition(of: currentWeek).phase }

    // Plain titles with units. Technical ideas (brick, threshold, sweet spot, critical swim speed) live in `idea`,
    // which the screens show as a tap to explain line, never inside a name.

    static let cssSwim: Session = {
        var steps = [PlanStep(sport: .swim, kind: .warm, name: "Easy warm up", seconds: 360, level: 2, target: "easy", distance: "300 m", meters: 300)]
        for _ in 0..<8 {
            steps.append(PlanStep(sport: .swim, kind: .work, name: "Fast 100 m, start every 2 min", seconds: 105, level: 4, target: "1:45 per 100 m", distance: "100 m", meters: 100, group: 1, repeatCount: 8))
            steps.append(PlanStep(sport: .swim, kind: .recovery, name: "Rest 15 s", seconds: 15, level: 1, target: nil, distance: nil, group: 1))
        }
        steps.append(PlanStep(sport: .swim, kind: .cool, name: "Easy cool down", seconds: 240, level: 2, target: "easy", distance: "200 m", meters: 200))
        var s = Session(
            sport: .swim, name: "Swim: 8 fast swims of 100 m",
            purpose: "Eight fast swims of 100 m, which is 4 lengths of a 25 m pool. You start one every 2 min, so you rest about 15 s between them. They train the steady hard pace you will need over 1500 m.",
            steps: steps,
            reason: "Your pace target is 2 s per 100 m faster than last time, because your last three swims like this beat it.",
            headlineTarget: ("1:45", "per 100 m"),
            watchLine: "Arrives as 8 swims of 100 m, each starting every 2 min. Your watch moves to the next step once you have swum the distance and the time is up.")
        s.idea = .css
        s.ideaLabel = "Pace is set from your steady hard swim speed"
        return s
    }()

    private static func makeSweetSpotBike(power: Bool) -> Session {
        func t(_ watts: String, _ feel: String) -> String { power ? watts : feel }
        var steps = [PlanStep(sport: .bike, kind: .warm, name: "Easy warm up", seconds: 600, level: 2, target: t("150 to 170 watts", "easy"))]
        for _ in 0..<3 {
            steps.append(PlanStep(sport: .bike, kind: .work, name: "Strong steady ride, 10 min", seconds: 600, level: 4, target: t("220 to 235 watts", "strong and steady"), group: 2, repeatCount: 3))
            steps.append(PlanStep(sport: .bike, kind: .recovery, name: "Spin easy, 5 min", seconds: 300, level: 1, target: t("under 150 watts", "very easy"), group: 2))
        }
        steps.append(PlanStep(sport: .bike, kind: .cool, name: "Easy cool down", seconds: 600, level: 2, target: "easy"))
        var s = Session(sport: .bike, name: "Strong steady ride, 3 times 10 min",
                        purpose: "Three 10 min efforts at a strong, steady pace, with 5 min of easy spinning between them. They build the strength you need for the 40 km bike leg.",
                        steps: steps, headlineTarget: power ? ("220", "watts") : ("Strong", "steady"),
                        watchLine: power ? "Your watch alerts you when your power leaves 220 to 235 watts during each effort."
                                         : "Your watch alerts you at the start and end of each effort.")
        s.usesPower = power
        s.state = .done
        s.doneMinutes = 64
        s.idea = .sweetSpot
        s.ideaLabel = "Known as a sweet spot ride"
        return s
    }
    private static let sweetSpotBikePower = makeSweetSpotBike(power: true)
    private static let sweetSpotBikeFeel = makeSweetSpotBike(power: false)
    static var sweetSpotBike: Session { hasPowerMeter ? sweetSpotBikePower : sweetSpotBikeFeel }

    static let thresholdRun: Session = {
        var steps = [PlanStep(sport: .run, kind: .warm, name: "Easy warm up", seconds: 600, level: 2, target: "5:40 per km")]
        for _ in 0..<2 {
            steps.append(PlanStep(sport: .run, kind: .work, name: "Steady hard run, 15 min", seconds: 900, level: 4, target: "4:20 to 4:40 per km", group: 3, repeatCount: 2))
            steps.append(PlanStep(sport: .run, kind: .recovery, name: "Easy jog, 3 min", seconds: 180, level: 1, target: "easy", group: 3))
        }
        steps.append(PlanStep(sport: .run, kind: .cool, name: "Easy cool down", seconds: 600, level: 2, target: "5:40 per km"))
        var s = Session(sport: .run, name: "Steady hard run, 2 times 15 min",
                        purpose: "Two 15 min runs at a hard, steady pace, with 3 min of easy jogging between them. They teach you to hold a strong pace for the 10 km run.",
                        steps: steps, headlineTarget: ("4:30", "per km"), watchLine: "Your watch alerts you when your pace leaves 4:20 to 4:40 per km during each hard run.")
        s.idea = .threshold
        s.ideaLabel = "Known as a threshold run"
        return s
    }()

    static let easySwim = Session(
        sport: .swim, name: "Easy swim, 1500 m",
        purpose: "Steady, relaxed swimming with long smooth strokes. It should feel comfortable enough to chat between lengths.",
        steps: [PlanStep(sport: .swim, kind: .work, name: "Steady easy swim", seconds: 1800, level: 2, target: "1:58 per 100 m", distance: "1500 m", meters: 1500)],
        headlineTarget: ("1:58", "per 100 m"), watchLine: "Arrives as one 1500 m swim with a distance goal.")

    private static func makeBrick(power: Bool) -> Session {
        let steps = [
            PlanStep(sport: .bike, kind: .warm, name: "Easy warm up", seconds: 900, level: 2, target: "easy"),
            PlanStep(sport: .bike, kind: .work, name: "Steady ride at race effort", seconds: 2700, level: 3, target: power ? "200 to 215 watts" : "steady, not hard"),
            PlanStep(sport: .run, kind: .work, name: "Run straight off the bike", seconds: 900, level: 3, target: "4:50 per km"),
        ]
        var s = Session(sport: .bike, name: "Ride 60 min, then run 15 min",
                        purpose: "A steady ride, then straight into a run, to teach your legs the switch from cycling to running.",
                        steps: steps, headlineTarget: power ? ("205", "watts") : ("Steady", "effort"),
                        watchLine: "Arrives as two workouts: the ride, then the run.")
        s.usesPower = power
        s.brickSecond = .run
        s.idea = .brick
        s.ideaLabel = "Known as a brick session"
        return s
    }
    private static let brickPower = makeBrick(power: true)
    private static let brickFeel = makeBrick(power: false)
    static var brick: Session { hasPowerMeter ? brickPower : brickFeel }

    static let longRun = Session(
        sport: .run, name: "Long run, 70 min",
        purpose: "Easy running that builds the stamina for a strong 10 km run after the bike.",
        steps: [PlanStep(sport: .run, kind: .work, name: "Easy run", seconds: 4200, level: 2, target: "5:30 to 5:50 per km")],
        headlineTarget: ("5:40", "per km"), watchLine: "Arrives as one 70 min run with a pace range alert.")

    static let skippedRun: Session = {
        var s = Session(
            sport: .run, name: "Easy run, 40 min",
            purpose: "A short, easy run to keep your legs moving between harder days. It should feel comfortable enough to chat.",
            steps: [PlanStep(sport: .run, kind: .work, name: "Easy run", seconds: 2400, level: 2, target: "5:40 per km")],
            headlineTarget: ("5:40", "per km"), watchLine: "Arrives as one 40 min run with a pace range alert.")
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

    /// Race legs for the distance the athlete chose. Times come from steady paces: 1:52 per 100 m, about 34 km/h, 4:42 per km.
    static var raceLegs: [PlanStep] {
        let r = setup.raceChoice
        let swimM = r.swimMeters, bikeKm = r.bikeKm
        let runKm = r.runKm
        let runText = runKm == runKm.rounded() ? String(Int(runKm)) : String(runKm)
        let bikeTarget = hasPowerMeter ? (r == .half ? "190 to 205 watts" : "205 to 220 watts") : "strong and steady"
        return [
            PlanStep(sport: .swim, kind: .work, name: "Swim \(swimM) m", seconds: Double(swimM) / 100 * 112, level: 3, target: "1:52 per 100 m", distance: "\(swimM) m", meters: swimM),
            PlanStep(sport: .bike, kind: .work, name: "Bike \(bikeKm) km", seconds: Double(bikeKm) * 105, level: 3, target: bikeTarget),
            PlanStep(sport: .run, kind: .work, name: "Run \(runText) km", seconds: runKm * 282, level: 4, target: "4:35 to 4:50 per km"),
        ]
    }

    /// Transition estimates in seconds. 2:25 of legs plus 3 minutes of transitions is the 2:28 prediction.
    static let transitions: (t1: TimeInterval, t2: TimeInterval) = (120, 60)
    static var racePredicted: TimeInterval { raceLegs.reduce(0) { $0 + $1.seconds } + transitions.t1 + transitions.t2 }
    static var raceDate: Date { calendar.date(byAdding: .day, value: daysToRace, to: today) ?? today }

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
    static let timeline: [TimelineItem] = [
        .init(daysBefore: 14, symbol: "wrench.and.screwdriver", text: "Bike service: tires, chain, brake pads", done: true),
        .init(daysBefore: 2, symbol: "fork.knife", text: "Start eating a little more carbohydrate than usual, such as rice, pasta and bread", done: false),
        .init(daysBefore: 1, symbol: "shippingbox", text: "Pack your bags tonight", done: false),
        .init(daysBefore: nil, symbol: "alarm", text: "Wake at 4:30 am, breakfast at 4:45 am, leave at 5:30 am", done: false),
    ]

    struct Checklist: Identifiable { let id = UUID(); var title: String; var items: [String] }
    static let checklists: [Checklist] = [
        .init(title: "Pack for swim, bike and run", items: ["Wetsuit", "Goggles, spare pair", "Swim cap from your race packet", "Bike, helmet, shoes", "Bottles and gels", "Run shoes with elastic laces", "Race belt and number", "Cap and sunglasses"]),
        .init(title: "Bag for the changing area", items: ["Towel to mark your spot", "Bike shoes clipped or ready", "Helmet unbuckled on the bars", "Run shoes, socks rolled", "Gels taped to the top tube", "Spare inner tube and CO2 inflator"]),
        .init(title: "Race morning", items: ["Breakfast 3 hours before the start", "Get your race number marked on your arms and leg", "Check tire pressure", "Walk from the swim exit to your bike", "Walk your bike out and back in", "Warm up with a short swim if allowed"]),
    ]
}
