import Foundation

/// The plain race day explainer and the beginner gear list. Pure data, so the copy can be tested for dashes and for
/// unexplained jargon. Any section that touches a glossary word carries the `term`, and the screen puts a
/// JargonText link on it. The words themselves never appear in the body text.
enum RaceDayGuide {
    struct Section: Identifiable, Equatable {
        var id: String
        var symbol: String
        var title: String
        var lines: [String]
        /// The glossary entry to link from this section, if the section touches one.
        var term: Term? = nil
        var termLabel: String? = nil
    }

    struct Gear: Identifiable, Equatable {
        var id: String { name }
        var name: String
        var note: String? = nil
    }

    static let gearIntro = "You do not need a power meter, a watch or a special bike to race. Any bike that is safe to ride is fine."

    static let requiredGear: [Gear] = [
        Gear(name: "Swimsuit or swim shorts", note: "You can wear them under your other clothes for the whole race."),
        Gear(name: "Goggles", note: "Bring a spare pair if you can."),
        Gear(name: "Swim cap", note: "Most races give you one with your race number."),
        Gear(name: "A bike that works", note: "A road bike, a hybrid or a mountain bike are all fine."),
        Gear(name: "Helmet that fits", note: "It is required, and it must be buckled before you touch your bike."),
        Gear(name: "Running shoes"),
        Gear(name: "Water bottle on your bike"),
        Gear(name: "Race number and a belt or pins to hold it"),
        Gear(name: "Towel", note: "Lay it next to your bike to find your spot."),
    ]

    static let niceToHaveGear: [Gear] = [
        Gear(name: "Tri suit", note: "One piece that works for swim, bike and run."),
        Gear(name: "Padded cycling shorts"),
        Gear(name: "Elastic laces", note: "Slip your running shoes on without tying them."),
        Gear(name: "Sunglasses and sunscreen"),
        Gear(name: "Spare inner tube and a small pump", note: "Learn to fix a flat tire in training first."),
        Gear(name: "Anti-chafe balm"),
        Gear(name: "Bike shoes and clip pedals", note: "Not needed. Flat pedals and running shoes are fine."),
        Gear(name: "Wetsuit", note: "Only for a cold swim in a lake or the sea. Many races rent them."),
    ]

    static func sections(for race: RaceChoice) -> [Section] {
        var out: [Section] = [
            Section(id: "before", symbol: "clock", title: "Before the start", lines: [
                "Arrive 60 to 90 minutes early. Pick up your race number and swim cap if you have not already.",
                "Find your spot in the changing area, where bikes hang on a rack. Lay out a towel, your shoes, your helmet and your sunglasses.",
                "Walk from the swim exit to your bike, and from your bike to the run exit, so you know the way when you are tired.",
            ]),
            Section(id: "swim", symbol: "figure.pool.swim", title: "The swim start", lines: [
                "Some races start in a pool, one person every 10 seconds. Others start in a lake or the sea, with swimmers going in small groups a few minutes apart.",
                "If you are nervous, start at the back or the side. Nobody minds, and you will have more space.",
                "You can rest at any time. Float on your back, hold the lane rope or a buoy, or switch to breaststroke. Races have safety crews in the water. If you need help, raise an arm and stay where you are.",
            ]),
            Section(id: "swimToBike", symbol: "arrow.triangle.swap", title: "From swim to bike", lines: [
                "Run to your spot. Take off your cap and goggles.",
                "Put your helmet on and fasten the strap before you touch your bike. This is a rule.",
                "Put on your shoes and sunglasses. Walk or run your bike to the line at the exit, and get on after the line, not before.",
            ], term: .transition, termLabel: "What are T1 and T2?"),
            Section(id: "bike", symbol: "figure.outdoor.cycle", title: "The bike", lines: [
                "Keep to the right side of the road, and pass on the left.",
                "Stay a few bike lengths behind the rider ahead. Riding right behind someone is against the rules in most races.",
                "Most races do not allow headphones. Ride at an easy, steady effort where you could still talk.",
                "Take a few sips of water about every 10 minutes. If you get a flat tire, move off the course and fix it, or ask a marshal for help.",
            ]),
            Section(id: "bikeToRun", symbol: "arrow.triangle.swap", title: "From bike to run", lines: [
                "Hang your bike on your rack the way the race tells you, then take your helmet off.",
                "Change into your running shoes and go. Your legs will feel heavy for the first few minutes. That is normal.",
            ], term: .transition, termLabel: "What are T1 and T2?"),
            Section(id: "run", symbol: "figure.run", title: "The run", lines: [
                "Start easy. The first kilometer is for settling in.",
                "Walk through the water stations if you like. Many first timers do.",
                "At the finish line someone gives you water and a medal. Keep walking for a few minutes before you sit down.",
            ]),
            Section(id: "eat", symbol: "fork.knife", title: "What to eat and drink", lines: eatLines(for: race)),
            Section(id: "wear", symbol: "tshirt", title: "What to wear", lines: [
                "Wear a swimsuit, or a tri suit, as your race clothes. It works for the swim, the bike and the run, so you do not need to change clothes.",
                "A wetsuit is only needed for a cold swim in a lake or the sea. A pool swim never needs one.",
                "Do not try anything new on race day: shoes, clothes or food. Test all of it in training.",
                "Bring sunscreen, and a cap for the run if it is sunny.",
            ]),
        ]
        if race.isBeginnerRace {
            out.insert(Section(id: "welcome", symbol: "hand.wave", title: "What this race is", lines: [
                "A super sprint is the gentlest triathlon: a short swim, a short ride and a short run, one after the other. Finishing is the goal.",
                "You will be among people who are also doing their first one. It is normal to walk parts of the run, to rest during the swim, and to be last in your group.",
            ]), at: 0)
        }
        return out
    }

    private static func eatLines(for race: RaceChoice) -> [String] {
        var lines = [
            "Eat a normal breakfast you know well, 2 to 3 hours before the start. For example toast with peanut butter and a banana, or oatmeal.",
            "Drink water in the morning. On the bike, sip as you go: about one bottle (500 ml) in an hour is a good rule.",
        ]
        switch race {
        case .superSprint, .sprint:
            lines.append("A race under about 75 minutes does not need gels or sports drink. Water is enough. If you want a gel, try it in training first.")
        case .olympic, .half:
            lines.append("A longer race needs fuel on the bike and the run. The Fueling card on the Race screen gives numbers for your race. Practise them in training.")
        }
        lines.append("Afterwards, eat something with carbohydrate and protein within an hour.")
        return lines
    }

    /// Every sentence on the guide, for the copy tests.
    static func allText(for race: RaceChoice) -> [String] {
        var out: [String] = [gearIntro]
        for s in sections(for: race) { out.append(s.title); out += s.lines; if let l = s.termLabel { out.append(l) } }
        for g in requiredGear + niceToHaveGear { out.append(g.name); if let n = g.note { out.append(n) } }
        return out
    }
}

/// Short in-session coaching, in plain words. Used by the phone player and the session detail.
enum Coaching {
    /// One line for a step, by its kind and level. Never uses a zone name or a number the athlete has to look up.
    static func line(kind: StepKind, level: Int) -> String {
        switch kind {
        case .warm: return "This is meant to feel easy. Let your body wake up."
        case .cool: return "This is meant to feel easy. Let your breathing settle."
        case .recovery: return "Very easy. Walk or go slow if you want to."
        case .work:
            switch level {
            case ...2: return "You should be able to talk in full sentences. If you cannot, slow down."
            case 3: return "Steady. You can say a short sentence, but you would not want to chat."
            case 4: return "Hard but controlled. A few words at a time. If it feels sharp or wrong, ease off."
            default: return "Very hard, and short. It is fine to stop early if you need to."
            }
        }
    }

    /// Two or three lines for the whole session, shown on the session detail screen.
    static func sessionLines(sport: Sport, topLevel: Int, isRunWalk: Bool) -> [String] {
        var lines: [String] = []
        if topLevel <= 2 {
            lines.append("This whole session is meant to feel easy. You should be able to talk the whole time.")
        } else if topLevel == 3 {
            lines.append("Most of this is easy. The steady parts should feel like a firm pace you could keep up for a while.")
        } else {
            lines.append("The easy parts are really easy, so the hard parts have room. Rest properly between the hard efforts.")
        }
        if isRunWalk {
            lines.append("Walking is part of the plan. Walk when it says walk, even if you feel good.")
        }
        switch sport {
        case .swim: lines.append("Rest at the wall whenever you need to. A rest is not a failure.")
        case .bike: lines.append("Sip water as you ride. Spin your legs easily instead of pushing a heavy gear.")
        case .run: lines.append("Run so that your breathing stays calm. If it does not, walk until it does.")
        }
        lines.append("If it feels too hard, slow down. You can also ease the whole week from the Today screen.")
        return lines
    }
}
