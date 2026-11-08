import Foundation

// Internal helpers shared by the adaptation rules. Names are prefixed so they cannot collide with helpers in
// other modules of the package.

// MARK: - Plan editing

extension Plan {
    /// All sessions of one calendar day across the plan, in id order.
    func adaptSessions(on day: Date, calendar: Calendar) -> [Session] {
        guard let index = weekIndex(containing: day, calendar: calendar) else { return [] }
        let target = calendar.startOfDay(for: day)
        return weeks[index].days.values.flatMap { $0 }
            .filter { calendar.startOfDay(for: $0.scheduledDate) == target }
            .sorted { $0.id < $1.id }
    }

    /// Removes a session by id and returns it. Empty day lists are dropped.
    @discardableResult
    mutating func adaptRemove(id: String) -> Session? {
        for position in weeks.indices {
            for (key, list) in weeks[position].days {
                if let at = list.firstIndex(where: { $0.id == id }) {
                    let removed = list[at]
                    var copy = list
                    copy.remove(at: at)
                    if copy.isEmpty { weeks[position].days[key] = nil } else { weeks[position].days[key] = copy }
                    return removed
                }
            }
        }
        return nil
    }

    /// Adds a session to the week that contains its scheduled date. Returns false when the date is outside the plan.
    @discardableResult
    mutating func adaptInsert(_ session: Session, calendar: Calendar) -> Bool {
        guard let index = weekIndex(containing: session.scheduledDate, calendar: calendar) else { return false }
        let key = calendar.startOfDay(for: session.scheduledDate)
        weeks[index].days[key, default: []].append(session)
        return true
    }

    /// Recomputes `plannedHours` of one week from its sessions that are not dropped.
    mutating func adaptRefreshHours(weekIndex index: Int) {
        guard weeks.indices.contains(index) else { return }
        let hours = weeks[index].days.keys.sorted().flatMap { weeks[index].days[$0] ?? [] }
            .filter { $0.state != .skipped }
            .reduce(0.0) { $0 + $1.durationHours }
        weeks[index].plannedHours = hours
    }

    /// A deterministic id for a new session: the first free slot for that week, day and sport.
    func adaptNewSessionID(weekIndex index: Int, date: Date, sport: Sport, calendar: Calendar) -> String {
        var slot = 1
        while slot < 100 {
            let candidate = SessionID.make(weekIndex: index, date: date, sport: sport, slot: slot, calendar: calendar)
            if session(withID: candidate) == nil { return candidate }
            slot += 1
        }
        return SessionID.make(weekIndex: index, date: date, sport: sport, slot: slot, calendar: calendar)
    }

    /// The week with every dropped session removed, for Load comparisons.
    func adaptWeekWithoutSkipped(_ index: Int) -> PlannedWeek? {
        guard weeks.indices.contains(index) else { return nil }
        var week = weeks[index]
        for (key, list) in week.days {
            let kept = list.filter { $0.state != .skipped }
            week.days[key] = kept.isEmpty ? nil : kept
        }
        return week
    }
}

// MARK: - Session helpers

enum AdaptationSupport {
    static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// English weekday name. Fixed table so the copy never depends on the device locale.
    static func dayName(of date: Date, calendar: Calendar) -> String {
        let weekday = Weekday(date: date, calendar: calendar)
        return dayNames[min(max(weekday.rawValue - 1, 0), dayNames.count - 1)]
    }

    /// Quality for the weekly caps: a quality session or a maximal effort test.
    static func isHard(_ session: Session) -> Bool { session.isQuality || session.isTest }

    /// Sports a session touches (a brick touches two).
    static func sports(of session: Session) -> Set<Sport> {
        var result: Set<Sport> = [session.sport]
        if let second = session.brickSecondSport { result.insert(second) }
        return result
    }

    /// Whether a session still counts toward the plan (not dropped).
    static func isLive(_ session: Session) -> Bool { session.state != .skipped }

    /// The sport when the session is that sport's long session of the week: a bike or run session that is not
    /// quality and lasts at least 80 percent of the longest live session of its sport. Nil otherwise.
    static func longKind(of session: Session, among week: [Session]) -> Sport? {
        guard session.sport == .bike || session.sport == .run, !session.isQuality, !session.isTest else { return nil }
        let longest = week.filter { $0.sport == session.sport }.map(\.durationSeconds).max() ?? 0
        guard longest > 0, session.durationSeconds >= 0.8 * longest else { return nil }
        return session.sport
    }

    static func sportNoun(_ sport: Sport) -> String {
        switch sport {
        case .swim: return "swim"
        case .bike: return "ride"
        case .run: return "run"
        }
    }

    static func sportPlural(_ sport: Sport) -> String { sportNoun(sport) + "s" }

    /// Copy of a step brought to at most `maxLevel`, with its target rewritten to match. Steps already at or
    /// below the level are returned unchanged.
    static func cap(_ step: Step, maxLevel: Int, zones: any ZoneCalculator) -> Step {
        guard step.level > maxLevel else { return step }
        var capped = step
        capped.level = IntensityLevel.clamped(maxLevel)
        switch step.target {
        case .none:
            break
        case .cssOffset:
            capped.target = .cssOffset(zones.swimOffsetRange(SwimZone(level: capped.level)))
        default:
            capped.target = .rpe(ZoneConstants.rpeRange(forLevel: capped.level))
        }
        if step.kind == .work, maxLevel <= AdaptationConstants.easyMaximumLevel { capped.name = "Easy" }
        if let note = step.note, !note.isEmpty { capped.note = nil }
        return capped
    }

    /// The session brought down to easy: every step at level 2 or lower, no quality or test flags.
    static func easy(_ session: Session, zones: any ZoneCalculator) -> Session {
        var easySession = session
        let cap = AdaptationConstants.easyMaximumLevel
        easySession.steps = session.steps.map { AdaptationSupport.cap($0, maxLevel: cap, zones: zones) }
        easySession.poolAlternativeSteps = session.poolAlternativeSteps.map { AdaptationSupport.cap($0, maxLevel: cap, zones: zones) }
        if session.isQuality || session.isTest {
            if session.brickSecondSport != nil {
                easySession.name = "Easy brick"
            } else {
                easySession.name = "Easy \(sportNoun(session.sport))"
            }
            easySession.purpose = "Keeps the day gentle. The usual hard effort comes back later."
        }
        easySession.isQuality = false
        easySession.isTest = false
        easySession.benchmarkKind = nil
        return easySession
    }

    /// True when any step sits above the easy ceiling.
    static func hasHardSteps(_ session: Session) -> Bool {
        session.isQuality || session.isTest || session.steps.contains { $0.level > AdaptationConstants.easyMaximumLevel }
    }

    /// Copy of the session with every duration and distance scaled by `factor`.
    static func scaled(_ session: Session, by factor: Double) -> Session {
        var result = session
        result.steps = session.steps.map { scale($0, by: factor) }
        result.poolAlternativeSteps = session.poolAlternativeSteps.map { scale($0, by: factor) }
        return result
    }

    private static func scale(_ step: Step, by factor: Double) -> Step {
        var result = step
        let raw = max(step.durationSeconds * factor, 0)
        if raw >= 60 {
            let grain = AdaptationConstants.shortenGranularitySeconds
            result.durationSeconds = max((raw / grain).rounded(.down) * grain, grain)
        } else {
            result.durationSeconds = raw
        }
        if let distance = step.distanceMeters {
            result.distanceMeters = max((distance * factor / 10).rounded(.down) * 10, 0)
        }
        return result
    }
}

// MARK: - Unwell periods

/// One stretch of the unwell toggle (annex C rule 4): easy sessions only up to 14 days, then quality returns
/// gradually over one week. Built from the athlete's toggle events, never from the clock.
struct AdaptationUnwellPeriod: Hashable {
    enum Mode { case none, easyOnly, limitedQuality }

    /// First easy day.
    var start: Date
    /// First day after the easy only stretch.
    var easyEnd: Date
    /// First day after the gradual return.
    var restrictedEnd: Date

    /// First day on which quality may come back.
    func qualityReturnDate(calendar: Calendar) -> Date {
        calendar.addDays(AdaptationConstants.unwellReturnEasyDays, to: easyEnd)
    }

    func mode(on day: Date, calendar: Calendar) -> Mode {
        let d = calendar.startOfDay(for: day)
        if d < start { return .none }
        if d < easyEnd { return .easyOnly }
        if d < restrictedEnd {
            let offset = calendar.daysBetween(easyEnd, d)
            return offset < AdaptationConstants.unwellReturnEasyDays ? .easyOnly : .limitedQuality
        }
        return .none
    }

    func contains(_ day: Date, calendar: Calendar) -> Bool { mode(on: day, calendar: calendar) != .none }

    /// Builds the periods that started on or before `today` from the toggle events.
    static func periods(from events: [AthleteEvent], today: Date, calendar: Calendar) -> [AdaptationUnwellPeriod] {
        var toggles: [(day: Date, started: Bool)] = []
        for event in events {
            switch event {
            case let .unwellStarted(on): toggles.append((calendar.startOfDay(for: on), true))
            case let .unwellEnded(on): toggles.append((calendar.startOfDay(for: on), false))
            default: break
            }
        }
        // Stable order: by day, and a start before an end on the same day.
        toggles = toggles.enumerated().sorted { a, b in
            if a.element.day != b.element.day { return a.element.day < b.element.day }
            if a.element.started != b.element.started { return a.element.started }
            return a.offset < b.offset
        }.map(\.element)

        var result: [AdaptationUnwellPeriod] = []
        var openStart: Date?
        var openEnd: Date?
        func close() {
            guard let start = openStart else { return }
            let cap = calendar.addDays(AdaptationConstants.unwellMaximumDays, to: start)
            let rawEnd = openEnd ?? cap
            let easyEnd = max(min(rawEnd, cap), start)
            let restrictedEnd = calendar.addDays(AdaptationConstants.unwellReturnDays, to: easyEnd)
            result.append(AdaptationUnwellPeriod(start: start, easyEnd: easyEnd, restrictedEnd: restrictedEnd))
            openStart = nil
            openEnd = nil
        }
        for toggle in toggles where toggle.day <= today {
            if toggle.started {
                if openStart != nil, openEnd != nil { close() }
                if openStart == nil { openStart = toggle.day }
            } else if openStart != nil, openEnd == nil {
                openEnd = max(toggle.day, openStart ?? toggle.day)
            }
        }
        close()
        return result
    }
}

// MARK: - Move rules

/// The placement rules a session must keep when it changes day (annex B microcycle assembly, annex C rule 1, annex
/// A test spacing). Shared by rule 1 and by `PlanKit.moveSession`, so a drag to a new day and an automatic move
/// follow the same rules.
enum PlanMoveRules {
    /// The first day from `firstDay` through `lastDay` that `session` may move to, empty days before occupied ones
    /// (annex C rules 1 and 10: "next free day"). Days for which `isExcluded` is true are skipped. Nil when none
    /// fits. Shared by rule 1 and rule 10 so both land a session on the same day.
    static func firstAllowedDay(
        for session: Session, from firstDay: Date, through lastDay: Date, in plan: Plan, calendar: Calendar,
        isExcluded: (Date) -> Bool = { _ in false }
    ) -> Date? {
        guard firstDay <= lastDay else { return nil }
        for emptyOnly in [true, false] {
            var day = firstDay
            while day <= lastDay {
                if !isExcluded(day), problem(for: session, on: day, in: plan, calendar: calendar, emptyOnly: emptyOnly) == nil {
                    return day
                }
                day = calendar.addDays(1, to: day)
            }
        }
        return nil
    }

    /// Why `session` cannot go to `day`, in a calm sentence, or nil when it can. With `emptyOnly` the day must
    /// hold no other live session.
    static func problem(
        for session: Session, on rawDay: Date, in plan: Plan, calendar: Calendar, emptyOnly: Bool
    ) -> String? {
        let day = calendar.startOfDay(for: rawDay)
        guard let weekIndex = plan.weekIndex(containing: day, calendar: calendar) else {
            return "That day is outside your plan."
        }
        if let raceDate = plan.raceDate {
            let raceDay = calendar.startOfDay(for: raceDate)
            if day > raceDay { return "That day is after your race." }
            if day == raceDay { return "That is race day." }
        }
        let athlete = plan.athlete
        let week = plan.weeks[weekIndex]
        let weekday = Weekday(date: day, calendar: calendar)
        guard athlete.availableWeekdays.contains(weekday) else { return "That is not one of your training days." }
        if session.sport == .swim, !session.isOpenWater, !athlete.poolWeekdays.contains(weekday) {
            return "Swims need a pool day, and that is not one."
        }

        let live = week.sessions.filter { $0.id != session.id && AdaptationSupport.isLive($0) }
        // Neighbouring days can sit in the next or the previous week (Sunday and Monday), so the day checks read
        // every week. Each neighbour's long ride or long run status is judged against its own week.
        let everyLive = plan.weeks.flatMap(\.sessions).filter { $0.id != session.id && AdaptationSupport.isLive($0) }
        func sessions(on target: Date) -> [Session] {
            everyLive.filter { calendar.startOfDay(for: $0.scheduledDate) == target }
        }
        let hard = AdaptationSupport.isHard(session)
        let sports = AdaptationSupport.sports(of: session)
        let isBrick = session.brickSecondSport != nil
        let allLive = live + [session]
        let longKind = AdaptationSupport.longKind(of: session, among: allLive)
        func longKindOfNeighbour(_ other: Session) -> Sport? {
            guard let otherWeek = plan.weekIndex(containing: other.scheduledDate, calendar: calendar),
                  otherWeek != weekIndex else { return AdaptationSupport.longKind(of: other, among: allLive) }
            let peers = plan.weeks[otherWeek].sessions.filter { AdaptationSupport.isLive($0) }
            return AdaptationSupport.longKind(of: other, among: peers)
        }

        let present = sessions(on: day)
        if present.contains(where: AdaptationSupport.isHard) { return "That day already has a hard session." }
        if isBrick && !present.isEmpty { return "A brick needs a day to itself." }
        if present.contains(where: { $0.brickSecondSport != nil }) { return "That day holds a brick, which needs the day to itself." }
        if emptyOnly {
            if !present.isEmpty { return "That day already has a session." }
        } else if present.contains(where: { !AdaptationSupport.sports(of: $0).isDisjoint(with: sports) }) {
            return "That day already has a session in the same sport."
        }
        if let longKind {
            let other: Sport = longKind == .bike ? .run : .bike
            for offset in [-1, 0, 1] {
                let nearby = sessions(on: calendar.addDays(offset, to: day))
                if nearby.contains(where: { longKindOfNeighbour($0) == other }) {
                    return "Keep the long ride and the long run at least a day apart."
                }
            }
        }
        if hard {
            for offset in [-1, 1] {
                let neighbour = sessions(on: calendar.addDays(offset, to: day))
                if neighbour.contains(where: {
                    AdaptationSupport.isHard($0) && !AdaptationSupport.sports(of: $0).isDisjoint(with: sports)
                }) {
                    return "Hard days in the same sport need a day between them."
                }
            }
        }
        if session.isTest {
            for other in everyLive where other.isTest {
                let gap = abs(calendar.daysBetween(calendar.startOfDay(for: other.scheduledDate), day))
                if gap < AdaptationConstants.testSpacingDays { return "Tests need at least 48 hours between them." }
            }
        }
        if let raceDate = plan.raceDate,
           calendar.addDays(-1, to: calendar.startOfDay(for: raceDate)) == day,
           hard || isBrick || longKind != nil {
            return "Keep the day before the race easy."
        }
        return nil
    }
}
