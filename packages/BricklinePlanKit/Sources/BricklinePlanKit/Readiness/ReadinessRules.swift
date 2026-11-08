import Foundation

/// Annex C rules 9 to 13: readiness. Pure functions of (plan, inputs, today, calendar, history). The rules only
/// ever defer or soften a hard session; they never add load, never prescribe rest and never name a cause.
///
/// - Rule 9, calibration gate: no rule before 14 valid nights, off with fewer than 3 valid nights in the latest 7,
///   and a different recovery source starts calibration again from the day it changed.
/// - Rule 10, defer a hard session: the 7 night HRV mean sits below baseline minus 0.5 SD (Apple Watch HRV alone
///   cannot trigger it). Today's quality session moves to the next free day, empty days first, else becomes easy.
///   A session already deferred in the last 7 days becomes easy instead of moving again.
/// - Rule 11, swap to easy: two consecutive mornings below baseline minus 1 SD plus a second signal (resting heart
///   rate 1 SD or more above baseline, or today's check-in of 2 or lower); with no device, or a source with no HRV,
///   two check-ins of 2 or lower. Today's quality session becomes easy at about 80 percent duration. Rule 11 is
///   checked before rule 10 because it is the narrower, stronger trigger, and only one structural change fits in
///   a day.
/// - Rule 12, sleep note: 6 hours or less and 1 hour or more under the median. A note only; the plan is untouched.
/// - Rule 13, guardrails: at most 2 plan changes in a rolling 7 days across rules 10 to 12, every change advisory
///   with a one tap Keep planned session, 3 overrides in 14 days leaves notes only, no sync for 48 hours is
///   silence, and the taper lock still wins.
///
/// The one structural change per day budget of annex C is shared with the adaptation rules: pass the adaptation
/// `history` (including the events of the same day) and readiness does nothing on a day that already used it. A
/// pending rule 2 realignment prompt reserves that change as well (`structuralReserved`): its prompt event is not
/// logged as structural, so the caller says so.
public struct ReadinessRules: Sendable {
    public let zones: any ZoneCalculator

    public init(zones: any ZoneCalculator = DefaultZoneCalculator()) {
        self.zones = zones
    }

    // MARK: Entry point

    /// Evaluates rules 9 to 13 for `today`.
    ///
    /// - Parameters:
    ///   - history: every event the engines fired so far. Counts the plan changes of the last 7 days and today's
    ///     structural change. Append `result.events` to it.
    ///   - athleteEvents: the athlete's event log, read for the unwell toggle (annex C rule 4 owns those days, and
    ///     the nights inside them stay out of the baseline) and the confirmed realignments.
    ///   - structuralReserved: true while a rule 2 realignment prompt awaits the athlete. The prompt reserves the
    ///     day's one structural change (annex C), so rules 10 and 11 stay out. Rule 12 still writes its note.
    public func apply(
        to plan: Plan,
        inputs: ReadinessInputs,
        today: Date,
        calendar: Calendar,
        history: [AdaptationEvent] = [],
        athleteEvents: [AthleteEvent] = [],
        structuralReserved: Bool = false
    ) -> ReadinessResult {
        let calendar = plan.resolvedCalendar(calendar)
        let run = AdaptationRun(
            context: AdaptationContext(today: today, events: athleteEvents, history: history), calendar: calendar)
        let picture = Picture.make(
            plan: plan, inputs: inputs, run: run, history: history, structuralReserved: structuralReserved)

        var edited = plan
        var events: [AdaptationEvent] = []
        var fired = false

        if picture.canChangePlan {
            let hard = edited.adaptSessions(on: run.today, calendar: calendar)
                .filter { $0.state == .planned && AdaptationSupport.isHard($0) }
            if !hard.isEmpty {
                if let trigger = easyTrigger(picture) {
                    let outcome = soften(hard, trigger: trigger, plan: edited, run: run)
                    edited = outcome.plan
                    events.append(outcome.event)
                    fired = true
                } else if deferTrigger(picture) {
                    let outcome = deferHard(hard, plan: edited, run: run, history: history)
                    edited = outcome.plan
                    events.append(outcome.event)
                    fired = true
                }
            }
        }

        var note: String?
        if let sleepNote = sleepNote(picture) {
            note = sleepNote
            let logged = history.contains { $0.rule == .sleepNote && calendar.isDate($0.date, inSameDayAs: run.today) }
            if !logged {
                // A note changes nothing, so it carries no advisory data: there is nothing to keep.
                events.append(AdaptationEvent(rule: .sleepNote, reasonLine: sleepNote, date: run.today, isStructural: false))
            }
        }

        let ordered = events.enumerated().sorted { a, b in
            if a.element.rule.rawValue != b.element.rule.rawValue { return a.element.rule.rawValue < b.element.rule.rawValue }
            return a.offset < b.offset
        }.map(\.element)
        let assessment = Assessor.make(picture: picture, note: note, firedToday: fired)
        return ReadinessResult(plan: edited, events: ordered, assessment: assessment)
    }

    // MARK: Keep planned session

    /// The one tap undo (annex C rule 13). Puts the sessions of a rule 10 or 11 event back as they were planned.
    /// It is valid on the day of the change only, since the sessions were planned for that day, and only while the
    /// original day still takes them under the placement rules (a hard session added there in the meantime blocks
    /// it). Throws `PlanKitError.invalidInput` for an event with nothing to undo, one that was already kept, one
    /// from an earlier day, a session that is no longer planned or a day that no longer fits, and
    /// `PlanKitError.sessionNotFound` for a session that left the plan. The plan is unchanged on a throw. Use
    /// `AdaptationState.keepPlannedSession` to also record the tap in the log.
    public func keepPlannedSession(
        _ event: AdaptationEvent, in plan: Plan, today: Date, calendar: Calendar
    ) throws -> KeepPlannedSessionResult {
        let calendar = plan.resolvedCalendar(calendar)
        guard let advisory = event.advisory, advisory.canKeepPlannedSession else {
            throw PlanKitError.invalidInput("That change has nothing to put back.")
        }
        guard calendar.startOfDay(for: event.date) == calendar.startOfDay(for: today) else {
            throw PlanKitError.invalidInput("That change is from an earlier day.")
        }
        for original in advisory.originalSessions {
            guard let current = plan.session(withID: original.id) else { throw PlanKitError.sessionNotFound(original.id) }
            guard current.state == .planned else {
                throw PlanKitError.invalidInput("Only a session that is still planned can go back.")
            }
        }
        var without = plan
        for original in advisory.originalSessions { without.adaptRemove(id: original.id) }
        for original in advisory.originalSessions {
            let day = calendar.startOfDay(for: original.scheduledDate)
            if let reason = PlanMoveRules.problem(for: original, on: day, in: without, calendar: calendar, emptyOnly: false) {
                throw PlanKitError.invalidInput(reason)
            }
        }
        var edited = plan
        var weeks = Set<Int>()
        for original in advisory.originalSessions {
            if let current = edited.session(withID: original.id),
               let index = edited.weekIndex(containing: current.scheduledDate, calendar: calendar) {
                weeks.insert(index)
            }
            edited.adaptRemove(id: original.id)
            guard edited.adaptInsert(original, calendar: calendar) else {
                throw PlanKitError.invalidInput("That day is outside your plan.")
            }
            if let index = edited.weekIndex(containing: original.scheduledDate, calendar: calendar) { weeks.insert(index) }
        }
        for index in weeks.sorted() { edited.adaptRefreshHours(weekIndex: index) }
        return KeepPlannedSessionResult(plan: edited, overrideDay: calendar.startOfDay(for: today))
    }

    // MARK: Triggers

    /// What backs a rule 11 swap.
    enum EasyTrigger {
        case restingHeartRateUp
        case lowCheckIn
        case checkInsOnly
    }

    /// Rule 11. Nil when it does not fire.
    func easyTrigger(_ p: Picture) -> EasyTrigger? {
        switch p.gate {
        case .checkInOnly:
            let n = ReadinessConstants.consecutiveMornings
            let lows = (0..<n).filter { (p.checkIns[$0] ?? Int.max) <= ReadinessConstants.lowCheckIn }
            return lows.count == n ? .checkInsOnly : nil
        case .ready:
            guard let b = p.baseline else { return nil }
            guard let limit = b.hrv.lowerLimit(sds: ReadinessConstants.easySDMultiple) else {
                // A source with no HRV baseline (Garmin, or too few HRV nights) gets the check-in form only.
                let n = ReadinessConstants.consecutiveMornings
                let lows = (0..<n).filter { (p.checkIns[$0] ?? Int.max) <= ReadinessConstants.lowCheckIn }
                return lows.count == n ? .checkInsOnly : nil
            }
            for day in 0..<ReadinessConstants.consecutiveMornings {
                guard let value = b.hrvByDaysAgo[day], log(value) < limit else { return nil }
            }
            if let upper = b.restingHeartRate.upperLimit(sds: ReadinessConstants.restingHeartRateSDMultiple),
               let rhr = b.restingHeartRateByDaysAgo[0], log(rhr) >= upper {
                return .restingHeartRateUp
            }
            // Today's check-in only: the reason line says it was low, so it has to be today's.
            let low = (p.checkIns[0] ?? Int.max) <= ReadinessConstants.lowCheckIn
            return low ? .lowCheckIn : nil
        default:
            return nil
        }
    }

    /// Rule 10. The source must be able to trigger it (not Apple Watch alone) and its 7 night mean must sit below
    /// baseline minus 0.5 SD.
    func deferTrigger(_ p: Picture) -> Bool {
        guard p.gate == .ready, let b = p.baseline, b.source.canTriggerDeferral,
              let recent = b.hrv.recentMean,
              let limit = b.hrv.lowerLimit(sds: ReadinessConstants.deferralSDMultiple) else { return false }
        return recent < limit
    }

    /// Rule 12. Needs the gates open, last night's sleep and a trusted median.
    func sleepNote(_ p: Picture) -> String? {
        guard p.gate == .ready, let b = p.baseline, let slept = b.sleepByDaysAgo[0],
              let median = b.sleepMedianMinutes else { return nil }
        guard slept <= ReadinessConstants.shortSleepMinutes,
              median - slept >= ReadinessConstants.sleepUnderMedianMinutes else { return nil }
        return ReadinessCopy.sleepNote(sleepMinutes: slept, medianMinutes: median)
    }

    // MARK: Actions

    /// Rule 11 action: today's hard sessions become easy at about 80 percent duration.
    private func soften(
        _ sessions: [Session], trigger: EasyTrigger, plan: Plan, run: AdaptationRun
    ) -> (plan: Plan, event: AdaptationEvent) {
        var edited = plan
        var names: [String] = []
        for session in sessions {
            let eased = AdaptationSupport.scaled(
                AdaptationSupport.easy(session, zones: zones), by: ReadinessConstants.easyDurationFactor)
            edited.updateSession(id: session.id) { $0 = eased }
            names.append(eased.name.lowercased())
        }
        refreshHours(&edited, for: sessions, calendar: run.calendar)

        let change: String
        if sessions.count == 1 {
            change = "Today's \(ReadinessCopy.descriptor(sessions[0])) became \(ReadinessCopy.article(before: names[0])) \(names[0])."
        } else {
            change = "Today's \(sessions.count) hard sessions became easy sessions."
        }
        let facts: String
        switch trigger {
        case .restingHeartRateUp:
            facts = "Your HRV has been below your usual range two mornings running and resting heart rate is up."
        case .lowCheckIn:
            facts = "Your HRV has been below your usual range two mornings running and your check-in was low."
        case .checkInsOnly:
            facts = "Your last two check-ins were low."
        }
        let keep = sessions.count == 1 ? ReadinessCopy.keepOriginal : ReadinessCopy.keepOriginals
        let event = AdaptationEvent(
            rule: .readinessEasy, reasonLine: "\(change) \(facts) \(keep)", date: run.today, isStructural: true,
            sessionIDs: sessions.map(\.id), sport: sessions.count == 1 ? sessions[0].sport : nil,
            advisory: AdvisoryChange(originalSessions: sessions))
        return (edited, event)
    }

    /// Rule 10 action: each hard session moves to the next free day of its week (empty days first), else becomes
    /// easy at its full length. A session that rule 10 already moved in the last 7 days is not moved again: it
    /// becomes easy, so one visible change settles it. A move adds no load: the same session lands on a later day.
    private func deferHard(
        _ sessions: [Session], plan: Plan, run: AdaptationRun, history: [AdaptationEvent]
    ) -> (plan: Plan, event: AdaptationEvent) {
        let calendar = run.calendar
        let recentlyDeferred = Set(history.filter { event in
            guard event.rule == .readinessDefer else { return false }
            let age = calendar.daysBetween(calendar.startOfDay(for: event.date), run.today)
            return age >= 0 && age < ReadinessConstants.redeferWindowDays
        }.flatMap(\.sessionIDs))
        var edited = plan
        var moved: [(from: Session, to: Date)] = []
        var eased: [Session] = []
        var easyNames: [String] = []
        for session in sessions {
            let target = recentlyDeferred.contains(session.id) ? nil : nextFreeDay(for: session, in: edited, run: run)
            if let target {
                edited.adaptRemove(id: session.id)
                var relocated = session
                relocated.scheduledDate = target
                edited.adaptInsert(relocated, calendar: calendar)
                moved.append((session, target))
            } else {
                let easy = AdaptationSupport.easy(session, zones: zones)
                edited.updateSession(id: session.id) { $0 = easy }
                eased.append(session)
                easyNames.append(easy.name.lowercased())
            }
        }
        refreshHours(&edited, for: sessions + moved.map { moveItem -> Session in
            var s = moveItem.from
            s.scheduledDate = moveItem.to
            return s
        }, calendar: calendar)

        let fact = ReadinessCopy.hrvBelowFact
        let line: String
        if sessions.count == 1, let move = moved.first {
            let from = AdaptationSupport.dayName(of: run.today, calendar: calendar)
            let to = AdaptationSupport.dayName(of: move.to, calendar: calendar)
            line = "Moved \(from)'s \(ReadinessCopy.descriptor(move.from)) to \(to). \(fact)"
        } else if sessions.count == 1 {
            line = "Today's \(ReadinessCopy.descriptor(sessions[0])) became \(ReadinessCopy.article(before: easyNames[0])) \(easyNames[0]). \(fact) \(ReadinessCopy.keepOriginal)"
        } else {
            let count = sessions.count
            let change: String
            if eased.isEmpty {
                change = "Moved today's \(count) hard sessions to later days."
            } else if moved.isEmpty {
                change = "Today's \(count) hard sessions became easy sessions."
            } else {
                change = "Moved \(moved.count) of today's \(count) hard sessions to later days and made \(eased.count) easy."
            }
            line = "\(change) \(fact) \(ReadinessCopy.keepOriginals)"
        }
        let event = AdaptationEvent(
            rule: .readinessDefer, reasonLine: line, date: run.today, isStructural: true,
            sessionIDs: sessions.map(\.id), sport: sessions.count == 1 ? sessions[0].sport : nil,
            advisory: AdvisoryChange(originalSessions: sessions))
        return (edited, event)
    }

    /// The nearest later day of the session's week that the placement rules allow (annex B and annex C rules 1 and
    /// 10: the athlete's days, pool days, hard days apart, long ride and long run apart, easy race eve), empty days
    /// before occupied ones, the same order rule 1 uses. Days under the unwell rule are skipped, since rule 4 owns
    /// them. The day before a race is the last candidate; the taper lock normally keeps readiness out of that week
    /// anyway, so the limit is defence in depth.
    func nextFreeDay(for session: Session, in plan: Plan, run: AdaptationRun) -> Date? {
        let calendar = run.calendar
        guard let weekIndex = plan.weekIndex(containing: session.scheduledDate, calendar: calendar) else { return nil }
        var last = calendar.addDays(6, to: calendar.startOfDay(for: plan.weeks[weekIndex].startDate))
        if let raceDay = run.raceDay(plan: plan) {
            let eve = calendar.addDays(-1, to: raceDay)
            if eve < last { last = eve }
        }
        return PlanMoveRules.firstAllowedDay(
            for: session, from: calendar.addDays(1, to: run.today), through: last, in: plan, calendar: calendar,
            isExcluded: { run.isRestricted($0) })
    }

    private func refreshHours(_ plan: inout Plan, for sessions: [Session], calendar: Calendar) {
        var weeks = Set<Int>()
        for session in sessions {
            if let index = plan.weekIndex(containing: session.scheduledDate, calendar: calendar) { weeks.insert(index) }
        }
        for index in weeks.sorted() { plan.adaptRefreshHours(weekIndex: index) }
    }
}
