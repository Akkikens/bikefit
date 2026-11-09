import Foundation

/// How an answer to a starting point question reads. Plain words, one scale for all three sports.
enum StartAbility: String, Codable, CaseIterable, Identifiable {
    case comfortably, withEffort, notYet
    var id: String { rawValue }

    /// Points toward the starting point score: 2, 1 and 0.
    var points: Int {
        switch self { case .comfortably: 2; case .withEffort: 1; case .notYet: 0 }
    }
}

/// The three starting point questions: can you swim 200 m, ride 30 minutes, run or walk-run 20 minutes.
/// Each has plain answers and no wrong one. The answers set the plan's starting level and whether the first weeks are
/// gentle. They can only lower the level the athlete picked, never raise it.
enum StartQuestion: String, CaseIterable, Identifiable {
    case swim, bike, run
    var id: String { rawValue }

    var title: String {
        switch self {
        case .swim: "Swim 200 m without stopping"
        case .bike: "Ride a bike for 30 minutes"
        case .run: "Run or walk-run for 20 minutes"
        }
    }

    /// The question in a sentence, with the distance in lengths so nobody has to convert.
    var prompt: String {
        switch self {
        case .swim: "Could you swim 200 m without stopping to rest? That is 8 lengths of a 25 m pool. Any stroke counts."
        case .bike: "Could you ride a bike for 30 minutes at an easy pace, on the road, a path or an indoor bike?"
        case .run: "Could you run, or mix running and walking, for 20 minutes without stopping?"
        }
    }

    func answer(_ ability: StartAbility) -> String {
        switch (self, ability) {
        case (.swim, .comfortably): "Yes, and I would feel fine"
        case (.swim, .withEffort): "Yes, but I would be tired"
        case (.swim, .notYet): "Not yet, I need to rest on the way"
        case (.bike, .comfortably): "Yes, and I would feel fine"
        case (.bike, .withEffort): "Yes, but my legs would be tired"
        case (.bike, .notYet): "Not yet, or I do not have a bike yet"
        case (.run, .comfortably): "Yes, running the whole time"
        case (.run, .withEffort): "Yes, mixing running and walking"
        case (.run, .notYet): "Not yet, I would walk most of it"
        }
    }

    var symbol: String {
        switch self { case .swim: "figure.pool.swim"; case .bike: "figure.outdoor.cycle"; case .run: "figure.run" }
    }
}

/// The three answers together, and what they mean for the plan. Pure, so it can be tested without the UI.
struct StartingPoint: Equatable {
    var swim: StartAbility?
    var bike: StartAbility?
    var run: StartAbility?

    func ability(_ q: StartQuestion) -> StartAbility? {
        switch q { case .swim: swim; case .bike: bike; case .run: run }
    }

    /// True once at least one question has an answer. With none, the plan follows the experience the athlete picked.
    var anyAnswered: Bool { swim != nil || bike != nil || run != nil }
    var allAnswered: Bool { swim != nil && bike != nil && run != nil }

    /// An unanswered question counts as "yes, with effort", the middle answer, so one skipped question never decides.
    private var answers: [StartAbility] { [swim ?? .withEffort, bike ?? .withEffort, run ?? .withEffort] }
    var score: Int { answers.reduce(0) { $0 + $1.points } }
    var notYetCount: Int { answers.filter { $0 == .notYet }.count }

    /// Brand new, or close to it: the first weeks hold no hard efforts and no all out tests.
    var needsGentleStart: Bool {
        guard anyAnswered else { return false }
        return score <= 3 || notYetCount >= 2
    }

    /// The experience the plan is built for. Answers can lower the picked level, never raise it.
    func resolvedLevel(experience: ExperienceChoice) -> ExperienceChoice {
        guard anyAnswered else { return experience }
        if needsGentleStart { return .firstTimer }
        if score == 6 { return experience }
        // Some answers were not an easy yes: stay below the top level.
        return experience == .experienced ? .intermediate : experience
    }

    /// Run and walk intervals are offered to anyone who is not a comfortable runner yet.
    func prefersRunWalk(experience: ExperienceChoice) -> Bool {
        if anyAnswered, let run, run != .comfortably { return true }
        return resolvedLevel(experience: experience) == .firstTimer
    }

    /// Weekly hours for a gentle start stop at 5. More than that is more than a body new to training should add.
    static let gentleHoursCap = 5

    // MARK: Plain feedback

    /// A headline for the result card.
    var headline: String {
        if !anyAnswered { return "Not answered yet" }
        return needsGentleStart ? "You will start gently" : "You are ready for a regular start"
    }

    /// What the plan will do, in plain words.
    var detail: String {
        if !anyAnswered {
            return "Answer the questions above, or skip. Without them the plan follows the experience you picked."
        }
        if needsGentleStart {
            return "Your plan is easy and steady: no hard efforts, no all out tests, small first weeks, and a lighter week after every second week of training. Up to \(Self.gentleHoursCap) hours a week."
        }
        return "You can handle the plan as it comes. The first weeks are mostly easy with a few steady efforts, and the plan builds from there."
    }

    /// Practical help for the sport that is not there yet. Empty when every answer is a yes.
    var helpLines: [String] {
        var out: [String] = []
        if swim == .notYet {
            out.append("Swim: your swims are short sets with a rest at the wall. Resting is part of the plan. A lesson or a friend at the pool can help a lot.")
        }
        if bike == .notYet {
            out.append("Bike: any bike you can ride safely works, including a hybrid, a mountain bike or an indoor bike. Start with easy rides on flat ground.")
        }
        if run != .comfortably, run != nil {
            out.append("Run: your runs mix running and walking. Walking is part of the plan, not a step back.")
        }
        return out
    }
}

extension SetupData {
    var startingPoint: StartingPoint {
        get { StartingPoint(swim: swimAbility, bike: bikeAbility, run: runAbility) }
        set { swimAbility = newValue.swim; bikeAbility = newValue.bike; runAbility = newValue.run }
    }

    /// True when the plan should start gently: the answers say so, or the athlete picked a first triathlon and
    /// skipped the questions (a skipped step must never produce the unsafe plan the questions exist to prevent).
    var isGentleStart: Bool {
        let point = startingPoint
        return point.needsGentleStart || (!point.anyAnswered && experience == .firstTimer)
    }

    /// Weekly hours the plan is built for: the athlete's number, held to the gentle cap for a gentle start.
    var effectiveHours: Int {
        isGentleStart ? min(hoursPerWeek, StartingPoint.gentleHoursCap) : hoursPerWeek
    }

    /// Fewest weekly hours the engine accepts for the chosen race, rounded up to a whole hour.
    var raceMinimumHours: Int {
        Int((EngineBuilder.distance(raceChoice).parameters.weeklyHours.lowerBound * 0.75).rounded(.up))
    }

    /// A plain note when a gentle start cannot reach the race picked, for example a half iron on 5 hours. Nil otherwise.
    var gentleRaceNote: String? {
        guard isGentleStart, raceMinimumHours > StartingPoint.gentleHoursCap else { return nil }
        return "\(raceChoice.title) needs at least \(raceMinimumHours) hours a week, and a gentle start stops at \(StartingPoint.gentleHoursCap). For a first race, a super sprint, sprint or olympic is a better fit. Choose another race below, or on the Your race step."
    }

    /// Races a gentle start can reach, shortest first, offered when `gentleRaceNote` shows.
    var gentleRaceAlternatives: [RaceChoice] {
        RaceChoice.allCases.filter { race in
            Int((EngineBuilder.distance(race).parameters.weeklyHours.lowerBound * 0.75).rounded(.up)) <= StartingPoint.gentleHoursCap
        }
    }
}
