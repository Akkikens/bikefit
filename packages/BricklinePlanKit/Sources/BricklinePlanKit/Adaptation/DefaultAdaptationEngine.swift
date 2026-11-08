import Foundation

/// Applies the eight ordered rules of annex C.
///
/// The engine is a pure function of (plan, context, calendar): it never reads the clock, uses no randomness and
/// never traps. Every fired rule returns an `AdaptationEvent` with a non empty reason line.
///
/// Contract with the host:
/// - `context.events` is the athlete's event log. Unwell toggles must stay in it for as long as they matter, so the
///   engine can rebuild the unwell state on any day. Skip events are consumed once.
/// - `context.history` holds every event the engine returned earlier. The host appends the returned events to it.
///   It carries the once per 2 weeks nudge gap, the realignment floor and the one structural change per day budget.
/// - Annex C: at most one structural change per day. The budget is shared by rules 1, 4, 5, 6, 8 and by a
///   confirmed rule 2 realignment. While a rule 2 prompt is pending, the day's structural change is reserved
///   for it, so no other structural rule runs in that pass.
public struct DefaultAdaptationEngine: AdaptationEngine {
    public let loadModel: any LoadModel
    public let zones: any ZoneCalculator

    public init(
        loadModel: any LoadModel = DefaultLoadModel(),
        zones: any ZoneCalculator = DefaultZoneCalculator()
    ) {
        self.loadModel = loadModel
        self.zones = zones
    }

    // MARK: AdaptationEngine

    /// Evaluates annex C rules 1 to 8 in order for `context.today`.
    public func apply(to plan: Plan, context: AdaptationContext, calendar: Calendar) -> AdaptationResult {
        // Days are read in the plan's own time zone, and a nudge measured against an older benchmark than the
        // current tested one is dropped first (annex C rule 3: a retest already holds the improvement).
        let calendar = plan.resolvedCalendar(calendar)
        let run = AdaptationRun(context: context, calendar: calendar)
        var plan = plan.normalizingNudges(benchmarks: context.benchmarks)
        if let nowWeek = plan.weekIndex(containing: run.today, calendar: calendar) {
            for index in 0..<nowWeek where plan.weeks[index].cautionFlag { plan.weeks[index].cautionFlag = false }
        }
        var current = plan
        var events: [AdaptationEvent] = []
        var pending: RealignmentPrompt?

        var structuralOpen = !run.structuralUsedToday(includingChosenEvents: true)

        // Rule 2 is detected first and read only. When it fires it reserves the day's structural change.
        if let trigger = detectRealignment(plan: plan, run: run) {
            if structuralOpen {
                pending = RealignmentPrompt(reasonLine: trigger.reasonLine, date: run.today, canShiftPlan: trigger.canShiftPlan)
                let alreadyLogged = context.history.contains {
                    $0.rule == .realignmentPrompt && !$0.isStructural && run.calendar.isDate($0.date, inSameDayAs: run.today)
                }
                if !alreadyLogged {
                    events.append(AdaptationEvent(
                        rule: .realignmentPrompt, reasonLine: trigger.reasonLine, date: run.today,
                        isStructural: false, sessionIDs: trigger.missedIDs))
                }
                structuralOpen = false
            }
        }

        let lock = run.taperLockActive(plan: plan)
        var lockSuppressedSomething = false

        // Rule 1: skipped session.
        let rule1Result = rule1(plan: current, run: run, allowMove: structuralOpen)
        current = rule1Result.plan
        var touchedWeeks = Set<Int>()
        if let event = rule1Result.event {
            events.append(event)
            structuralOpen = false
            touchedWeeks.formUnion(weekIndices(of: event.sessionIDs, in: current, calendar: calendar))
        }

        // Rule 3: zone nudge (not structural). Suspended by the taper lock.
        let rule3Result = rule3(plan: current, run: run)
        if lock {
            if !rule3Result.events.isEmpty { lockSuppressedSomething = true }
        } else {
            current = rule3Result.plan
            events.append(contentsOf: rule3Result.events)
        }

        // Rule 4: unwell mode.
        if structuralOpen, let outcome = rule4(plan: current, run: run) {
            current = outcome.plan
            events.append(outcome.event)
            structuralOpen = false
            touchedWeeks.formUnion(weekIndices(of: outcome.event.sessionIDs, in: current, calendar: calendar))
        }

        // Rule 5: ramp clamp. Suspended by the taper lock. Weeks that rules 1 and 4 just changed are re checked
        // together with the weeks the athlete edited.
        if lock {
            if rule5(plan: current, run: run, extraWeeks: touchedWeeks) != nil { lockSuppressedSomething = true }
        } else if structuralOpen, let outcome = rule5(plan: current, run: run, extraWeeks: touchedWeeks) {
            current = outcome.plan
            events.append(outcome.event)
            structuralOpen = false
        }

        // Rule 6: load spike caution.
        if structuralOpen, let outcome = rule6(plan: current, run: run) {
            current = outcome.plan
            events.append(outcome.event)
            structuralOpen = false
        }

        // Rule 8: retest. No added intensity in the taper lock, none while the athlete is recovering.
        if lock {
            if !staleSports(plan: current, run: run).isEmpty { lockSuppressedSomething = true }
        } else if structuralOpen, !run.isRestricted(run.today), let outcome = rule8(plan: current, run: run) {
            current = outcome.plan
            events.append(outcome.event)
            structuralOpen = false
        }

        // Rule 7: taper lock. Reported when it held something back.
        if lockSuppressedSomething {
            let alreadyLogged = context.history.contains {
                $0.rule == .taperLock && run.calendar.isDate($0.date, inSameDayAs: run.today)
            }
            if !alreadyLogged {
                events.append(AdaptationEvent(
                    rule: .taperLock, reasonLine: AdaptationConstants.taperLockReason, date: run.today, isStructural: false))
            }
        }

        let ordered = events.enumerated().sorted { a, b in
            if a.element.rule.rawValue != b.element.rule.rawValue { return a.element.rule.rawValue < b.element.rule.rawValue }
            return a.offset < b.offset
        }.map(\.element)
        return AdaptationResult(plan: current, events: ordered, pendingRealignment: pending)
    }

    /// Applies the athlete's confirmed rule 2 choice. The realignment is that day's single structural change.
    ///
    /// - `.compress`: resume at today with the arc compressed. Missed sessions are set aside and the next weeks
    ///   build back in steps of at most 110 percent until they rejoin the plan (peak and taper weeks are never
    ///   touched, so the race date holds).
    /// - `.shiftPlan`: the planned sessions from the first missed one onward move later by whole weeks, so weekdays
    ///   hold. With a race date, the same number of base or build weeks is trimmed so the peak, taper and race week
    ///   keep their dates, and the shorter arc must still reach the distance's minimum plan length.
    ///
    /// Throws `PlanKitError.realignmentUnavailable` when a structural change already happened today, when today is
    /// outside the plan or at or after race day, or when shifting does not fit.
    public func applyRealignment(
        _ option: RealignmentOption,
        to plan: Plan,
        context: AdaptationContext,
        calendar: Calendar
    ) throws -> AdaptationResult {
        let calendar = plan.resolvedCalendar(calendar)
        let run = AdaptationRun(context: context, calendar: calendar)
        let plan = plan.normalizingNudges(benchmarks: context.benchmarks)
        guard !run.structuralUsedToday(includingChosenEvents: false),
              let currentWeek = plan.weekIndex(containing: run.today, calendar: calendar) else {
            throw PlanKitError.realignmentUnavailable
        }
        if let raceDay = run.raceDay(plan: plan), run.today >= raceDay {
            throw PlanKitError.realignmentUnavailable
        }
        let summary = missSummary(plan: plan, run: run)

        switch option {
        case .compress:
            var edited = plan
            var changed: [String] = []
            for id in summary.missedIDs {
                if let session = edited.session(withID: id), session.state == .planned {
                    edited.updateSession(id: id) { $0.state = .skipped }
                    changed.append(id)
                }
            }
            let anchorWeek = edited.weekIndex(containing: summary.anchorDate ?? run.today, calendar: calendar) ?? currentWeek
            let gap = gapDays(plan: plan, anchor: summary.anchorDate, run: run)
            let ramp = reenterRamp(
                plan: &edited, anchorWeek: anchorWeek, currentWeek: currentWeek, run: run, gapDays: gap)
            changed.append(contentsOf: ramp.changed)
            // The "builds back in steps" wording is only true when sessions were actually shortened.
            let line = ramp.shortened
                ? "Plan compressed from today. Missed sessions are set aside and the load builds back in steps"
                : "Plan resumed from today. Missed sessions are set aside"
            let event = AdaptationEvent(
                rule: .realignmentPrompt,
                reasonLine: line,
                date: run.today, isStructural: true, sessionIDs: changed)
            return AdaptationResult(plan: edited, events: [event], pendingRealignment: nil)

        case .shiftPlan:
            guard let shift = shiftPlan(plan: plan, anchor: summary.anchorDate ?? run.today, run: run,
                                        gapDays: gapDays(plan: plan, anchor: summary.anchorDate, run: run)) else {
                throw PlanKitError.realignmentUnavailable
            }
            let weeksWord = shift.weeks == 1 ? "week" : "weeks"
            let line = shift.reentryAdded
                ? "Plan shifted \(shift.weeks) \(weeksWord) later, with an easier week first, so you can pick up where you left off"
                : "Plan shifted \(shift.weeks) \(weeksWord) later so you can pick up where you left off"
            let event = AdaptationEvent(
                rule: .realignmentPrompt,
                reasonLine: line,
                date: run.today, isStructural: true, sessionIDs: shift.changedIDs)
            return AdaptationResult(plan: shift.plan, events: [event], pendingRealignment: nil)
        }
    }

    /// Plan week indices holding the given sessions.
    func weekIndices(of ids: [String], in plan: Plan, calendar: Calendar) -> Set<Int> {
        var result = Set<Int>()
        for id in ids {
            if let session = plan.session(withID: id),
               let index = plan.weekIndex(containing: session.scheduledDate, calendar: calendar) {
                result.insert(index)
            }
        }
        return result
    }

    // MARK: Rule 2 detection

    struct RealignmentTrigger {
        var reasonLine: String
        var canShiftPlan: Bool
        var missedIDs: [String]
    }

    /// Annex C rule 2: 3 or more misses in 14 days, or an entire week missed. Read only.
    func detectRealignment(plan: Plan, run: AdaptationRun) -> RealignmentTrigger? {
        guard plan.weekIndex(containing: run.today, calendar: run.calendar) != nil else { return nil }
        if let raceDay = run.raceDay(plan: plan), run.today >= raceDay { return nil }
        if run.isRestricted(run.today) { return nil }
        let summary = missSummary(plan: plan, run: run)
        let triggered = summary.missedIDs.count >= AdaptationConstants.missesToPrompt || summary.wholeWeekMissed
        guard triggered else { return nil }
        let line: String
        if summary.wholeWeekMissed {
            line = "You missed a week; here are two honest ways forward"
        } else {
            line = "You missed \(summary.missedIDs.count) sessions in \(AdaptationConstants.missWindowDays) days; here are two honest ways forward"
        }
        let canShift = shiftFeasibility(
            plan: plan, anchor: summary.anchorDate ?? run.today, run: run,
            gapDays: gapDays(plan: plan, anchor: summary.anchorDate, run: run)) != nil
        return RealignmentTrigger(reasonLine: line, canShiftPlan: canShift, missedIDs: summary.missedIDs)
    }

    struct MissSummary {
        var missedIDs: [String]
        var anchorDate: Date?
        var wholeWeekMissed: Bool
    }

    /// Counts misses inside the window, after the last confirmed realignment, ignoring unwell days.
    func missSummary(plan: Plan, run: AdaptationRun) -> MissSummary {
        let calendar = run.calendar
        let today = run.today
        let windowStart = calendar.addDays(-AdaptationConstants.missWindowDays, to: today)
        let floorDay = run.lastRealignmentDay()
        func counts(_ day: Date) -> Bool {
            guard day >= windowStart, day <= today else { return false }
            if let floorDay, day <= floorDay { return false }
            return !run.isRestricted(day)
        }
        let completed = Set(run.context.completedWorkouts.compactMap(\.plannedSessionID))
        func isUndone(_ session: Session) -> Bool { session.state != .done && !completed.contains(session.id) }

        var ids = Set<String>()
        for session in plan.allSessions {
            let day = calendar.startOfDay(for: session.scheduledDate)
            if day < today, counts(day), isUndone(session) { ids.insert(session.id) }
        }
        for event in run.context.events {
            if case let .sessionSkipped(id, on) = event, counts(calendar.startOfDay(for: on)),
               let session = plan.session(withID: id), isUndone(session) {
                ids.insert(id)
            }
        }
        for entry in run.context.history where entry.rule == .skippedMove && counts(calendar.startOfDay(for: entry.date)) {
            for id in entry.sessionIDs {
                if let session = plan.session(withID: id), isUndone(session) { ids.insert(id) }
            }
        }

        var whole = false
        if let currentWeek = plan.weekIndex(containing: today, calendar: calendar), currentWeek >= 1 {
            let week = plan.weeks[currentWeek - 1]
            let sessions = week.sessions
            let weekEnd = calendar.addDays(6, to: week.startDate)
            let afterFloor = floorDay.map { calendar.startOfDay(for: week.startDate) > $0 } ?? true
            if afterFloor, weekEnd < today,
               sessions.count >= AdaptationConstants.wholeWeekMinimumSessions,
               sessions.allSatisfy({ isUndone($0) && !run.isRestricted(calendar.startOfDay(for: $0.scheduledDate)) }) {
                whole = true
                for session in sessions { ids.insert(session.id) }
            }
        }

        let anchor = ids.compactMap { plan.session(withID: $0) }
            .map { calendar.startOfDay(for: $0.scheduledDate) }.min()
        return MissSummary(missedIDs: ids.sorted(), anchorDate: anchor, wholeWeekMissed: whole)
    }

    // MARK: Realignment: compress

    /// Days since the last recorded training: the latest completed workout or done session on or before today,
    /// else the day before the first missed session. Never negative.
    func gapDays(plan: Plan, anchor: Date?, run: AdaptationRun) -> Int {
        let calendar = run.calendar
        var lastDone: Date?
        func consider(_ date: Date) {
            let day = calendar.startOfDay(for: date)
            guard day <= run.today else { return }
            if lastDone.map({ day > $0 }) ?? true { lastDone = day }
        }
        for workout in run.context.completedWorkouts { consider(workout.start) }
        for session in plan.allSessions where session.state == .done { consider(session.scheduledDate) }
        let fallback = calendar.addDays(-1, to: calendar.startOfDay(for: anchor ?? run.today))
        return max(calendar.daysBetween(lastDone ?? fallback, run.today), 0)
    }

    /// First week back factor for a gap (annex C rule 2 re-entry; the gap table is in `AdaptationConstants`).
    func reentryFactor(gapDays: Int) -> Double {
        if gapDays <= AdaptationConstants.reentryShortGapDays { return AdaptationConstants.reentryFactorShortGap }
        if gapDays <= AdaptationConstants.reentryMediumGapDays { return AdaptationConstants.reentryFactorMediumGap }
        if gapDays <= AdaptationConstants.reentryLongGapDays { return AdaptationConstants.reentryFactorLongGap }
        return AdaptationConstants.reentryFactorRestart
    }

    /// Mean weekly Load over the 28 days before today, from the context. Nil when the context does not cover the
    /// window, so the planned reference is used instead.
    func recentWeeklyLoad(run: AdaptationRun) -> Double? {
        let calendar = run.calendar
        let windowStart = calendar.addDays(-AdaptationConstants.reentryActualWindowDays, to: run.today)
        var loads = run.context.dailyLoads
        if loads.isEmpty, !run.context.completedWorkouts.isEmpty {
            loads = loadModel.dailyLoads(
                workouts: run.context.completedWorkouts, benchmarks: run.context.benchmarks,
                from: windowStart, through: calendar.addDays(-1, to: run.today), calendar: calendar)
        }
        guard !loads.isEmpty else { return nil }
        let days = loads.map { calendar.startOfDay(for: $0.date) }
        guard let earliest = days.min(), earliest <= calendar.addDays(6, to: windowStart) else { return nil }
        var sum = 0.0
        for sample in loads {
            let day = calendar.startOfDay(for: sample.date)
            if day >= windowStart, day < run.today, sample.load.isFinite, sample.load > 0 { sum += sample.load }
        }
        return sum / (Double(AdaptationConstants.reentryActualWindowDays) / 7)
    }

    /// Re entry ramp for `.compress` (annex C rule 2). The reference is the lower of the last load week's planned
    /// Load before the miss and the mean weekly Load actually done in the last 28 days, so a missed week never
    /// returns the athlete to full volume. The first week back runs at a gap based fraction of that reference
    /// (`reentryFactor`, over 28 days restarts from base with quality made easy). Each following load week may
    /// grow 10 percent. The first week is always held to its cap, never skipped because it already looks small.
    /// Peak and taper weeks end the ramp, so the race arc is untouched. `shortened` is true when any session
    /// became shorter or easier.
    func reenterRamp(
        plan: inout Plan, anchorWeek: Int, currentWeek: Int, run: AdaptationRun, gapDays: Int
    ) -> (changed: [String], shortened: Bool) {
        guard let reference = referenceLoad(plan: plan, before: anchorWeek, run: run) else { return ([], false) }
        var base = reference.load
        if let actual = recentWeeklyLoad(run: run), actual > 0 { base = min(base, actual) }
        var cap = base * reentryFactor(gapDays: gapDays)
        let restart = gapDays > AdaptationConstants.reentryLongGapDays
        var changed: [String] = []
        var index = currentWeek
        var first = true
        while plan.weeks.indices.contains(index) {
            let week = plan.weeks[index]
            if AdaptationConstants.rampExemptPhases.contains(week.phase) { break }
            if week.isRecovery && !first {
                index += 1
                continue
            }
            if first && restart {
                for session in week.sessions where session.state == .planned
                    && run.calendar.startOfDay(for: session.scheduledDate) >= run.today
                    && AdaptationSupport.hasHardSteps(session) {
                    plan.updateSession(id: session.id) { $0 = AdaptationSupport.easy(session, zones: zones) }
                    changed.append(session.id)
                }
            }
            guard let trimmed = plan.adaptWeekWithoutSkipped(index) else { break }
            let load = loadModel.plannedLoad(for: trimmed, benchmarks: run.context.benchmarks)
            if load > cap + AdaptationConstants.loadTolerance {
                for id in shortenWeek(
                    plan: &plan, weekIndex: index, cap: cap, run: run,
                    minimum: AdaptationConstants.reentryMinimumShortenFactor) where !changed.contains(id) {
                    changed.append(id)
                }
            } else if !first {
                break
            }
            first = false
            cap *= AdaptationConstants.rampCapFactor
            index += 1
        }
        return (changed, !changed.isEmpty)
    }

    /// The most recent load week before `index`: not a recovery week, with some planned Load. Skipped sessions
    /// do not count, the same way the edited week is measured.
    func referenceLoad(plan: Plan, before index: Int, run: AdaptationRun) -> (week: Int, load: Double)? {
        var cursor = min(index, plan.weeks.count) - 1
        while cursor >= 0 {
            let week = plan.weeks[cursor]
            if !week.isRecovery, let trimmed = plan.adaptWeekWithoutSkipped(cursor) {
                let load = loadModel.plannedLoad(for: trimmed, benchmarks: run.context.benchmarks)
                if load > 0 { return (cursor, load) }
            }
            cursor -= 1
        }
        return nil
    }

    /// Shortens future planned sessions of one week until its Load is at or under `cap`. Easy sessions go first,
    /// the biggest first, and no session loses more than 40 percent. Tests are never shortened.
    func shortenWeek(
        plan: inout Plan, weekIndex: Int, cap: Double, run: AdaptationRun,
        minimum: Double = AdaptationConstants.minimumShortenFactor
    ) -> [String] {
        let calendar = run.calendar
        var changed: [String] = []
        var factors: [String: Double] = [:]
        func load(of session: Session) -> Double {
            loadModel.plannedLoad(for: session, benchmarks: run.context.benchmarks).load
        }

        var pass = 0
        while pass < 4 {
            pass += 1
            guard let week = plan.adaptWeekWithoutSkipped(weekIndex) else { break }
            var excess = loadModel.plannedLoad(for: week, benchmarks: run.context.benchmarks) - cap
            if excess <= AdaptationConstants.loadTolerance { break }
            let candidates = week.sessions
                .filter { $0.state == .planned && !$0.isTest && calendar.startOfDay(for: $0.scheduledDate) >= run.today }
                .map { (session: $0, load: load(of: $0)) }
                .sorted { a, b in
                    let ah = AdaptationSupport.isHard(a.session), bh = AdaptationSupport.isHard(b.session)
                    if ah != bh { return !ah }
                    if a.load != b.load { return a.load > b.load }
                    return a.session.id < b.session.id
                }
            var progressed = false
            for candidate in candidates {
                if excess <= AdaptationConstants.loadTolerance { break }
                guard candidate.load > 0 else { continue }
                let used = factors[candidate.session.id] ?? 1
                let room = used - minimum
                guard room > 0.001 else { continue }
                let removable = candidate.load * room / used
                let cut = min(excess, removable)
                let relative = (candidate.load - cut) / candidate.load
                let shortened = AdaptationSupport.scaled(candidate.session, by: relative)
                let newLoad = load(of: shortened)
                guard newLoad < candidate.load - 0.0001 else { continue }
                plan.updateSession(id: candidate.session.id) { $0 = shortened }
                factors[candidate.session.id] = used * relative
                excess -= (candidate.load - newLoad)
                if !changed.contains(candidate.session.id) { changed.append(candidate.session.id) }
                progressed = true
            }
            if !progressed { break }
        }
        plan.adaptRefreshHours(weekIndex: weekIndex)
        return changed
    }

    // MARK: Realignment: shift

    struct ShiftPlanResult {
        var plan: Plan
        var weeks: Int
        var changedIDs: [String]
        var reentryAdded: Bool
    }

    struct ShiftFeasibility {
        var weeks: Int
        var trimmedWeeks: [Int]
        var anchorDay: Date
        /// True when a gap of two weeks or more adds one easier re-entry week before the shifted arc.
        var reentryWeek: Bool
    }

    /// Works out whether the plan can shift, and by how many weeks, without changing anything. A gap of
    /// `shiftReentryWeekGapDays` or more adds one re-entry week, so the shift grows by one week.
    func shiftFeasibility(plan: Plan, anchor: Date, run: AdaptationRun, gapDays: Int) -> ShiftFeasibility? {
        let calendar = run.calendar
        let anchorDay = calendar.startOfDay(for: anchor)
        guard plan.weekIndex(containing: run.today, calendar: calendar) != nil else { return nil }
        let behind = max(calendar.daysBetween(anchorDay, run.today), 0)
        let reentry = gapDays >= AdaptationConstants.shiftReentryWeekGapDays
        let weeks = max(1, (behind + 6) / 7) + (reentry ? 1 : 0)
        guard let raceDistance = plan.raceDistance, plan.raceDate != nil else {
            return ShiftFeasibility(weeks: weeks, trimmedWeeks: [], anchorDay: anchorDay, reentryWeek: reentry)
        }
        let firstWeek = plan.weekIndex(containing: anchorDay, calendar: calendar) ?? 0
        let firstExempt = plan.weeks.firstIndex { AdaptationConstants.rampExemptPhases.contains($0.phase) } ?? plan.weeks.count
        let upper = max(min(firstExempt, plan.weeks.count), firstWeek)
        let candidates = (firstWeek..<upper).filter { index in
            let week = plan.weeks[index]
            return (week.phase == .base || week.phase == .build) && !week.isRecovery && !week.isTest
        }
        guard candidates.count >= weeks else { return nil }
        guard plan.weeks.count - weeks >= raceDistance.parameters.planWeeks.lowerBound else { return nil }
        return ShiftFeasibility(
            weeks: weeks, trimmedWeeks: Array(candidates.suffix(weeks)), anchorDay: anchorDay, reentryWeek: reentry)
    }

    /// Shifts planned sessions from the anchor onward by whole weeks (see `applyRealignment`). Week flags follow
    /// the content: a week that now holds the sessions of a recovery week is a recovery week, and a week is a test
    /// week only while it holds a test. With a gap of two weeks or more, the current week first holds a copy of
    /// the nearest recovery week as a re-entry week.
    func shiftPlan(plan: Plan, anchor: Date, run: AdaptationRun, gapDays: Int) -> ShiftPlanResult? {
        guard let feasibility = shiftFeasibility(plan: plan, anchor: anchor, run: run, gapDays: gapDays) else { return nil }
        let calendar = run.calendar
        var edited = plan
        let movable = plan.allSessions.filter {
            $0.state == .planned && calendar.startOfDay(for: $0.scheduledDate) >= feasibility.anchorDay
        }
        var changed: [String] = []
        var moves: [(session: Session, weeks: Int, sourceRecovery: Bool)] = []
        for session in movable {
            guard let week = plan.weekIndex(containing: session.scheduledDate, calendar: calendar) else { continue }
            edited.adaptRemove(id: session.id)
            changed.append(session.id)
            if feasibility.trimmedWeeks.contains(week) { continue }
            let shift = feasibility.weeks - feasibility.trimmedWeeks.filter { $0 < week }.count
            if shift > 0 {
                moves.append((session, shift, plan.weeks[week].isRecovery))
            } else {
                edited.adaptInsert(session, calendar: calendar)
                changed.removeAll { $0 == session.id }
            }
        }
        var newIDs: [String] = []
        var movedIn: [Int: (recovery: Int, total: Int)] = [:]
        for move in moves {
            let newDate = calendar.addDays(7 * move.weeks, to: calendar.startOfDay(for: move.session.scheduledDate))
            let newWeek = max(calendar.daysBetween(plan.startDate, newDate), 0) / 7
            while edited.weeks.count <= newWeek {
                let position = edited.weeks.count
                let source = position >= 4 ? edited.weeks[position - 4] : edited.weeks[edited.weeks.count - 1]
                edited.weeks.append(PlannedWeek(
                    index: position,
                    startDate: calendar.addDays(7 * position, to: plan.startDate),
                    phase: source.phase, isRecovery: source.isRecovery, isTest: source.isTest))
            }
            var shifted = move.session
            shifted.scheduledDate = newDate
            shifted.id = edited.adaptNewSessionID(weekIndex: newWeek, date: newDate, sport: shifted.sport, calendar: calendar)
            edited.adaptInsert(shifted, calendar: calendar)
            newIDs.append(shifted.id)
            var tally = movedIn[newWeek] ?? (0, 0)
            tally.total += 1
            if move.sourceRecovery { tally.recovery += 1 }
            movedIn[newWeek] = tally
        }

        var reentryAdded = false
        if feasibility.reentryWeek, let weekIndex = edited.weekIndex(containing: run.today, calendar: calendar) {
            let added = insertReentryWeek(
                plan: &edited, original: plan, targetWeek: weekIndex, anchor: feasibility.anchorDay, run: run)
            if !added.isEmpty {
                newIDs.append(contentsOf: added)
                reentryAdded = true
                movedIn[weekIndex] = (1, 1)
            }
        }

        // Flags follow the content (annex C rule 5 and rule 8 read them).
        for index in edited.weeks.indices {
            let live = edited.weeks[index].days.values.flatMap { $0 }.filter { AdaptationSupport.isLive($0) }
            if index >= (edited.weekIndex(containing: feasibility.anchorDay, calendar: calendar) ?? 0) {
                edited.weeks[index].isTest = live.contains { $0.isTest }
                if let tally = movedIn[index] {
                    edited.weeks[index].isRecovery = tally.recovery * 2 > tally.total
                }
            }
            edited.adaptRefreshHours(weekIndex: index)
        }
        return ShiftPlanResult(plan: edited, weeks: feasibility.weeks, changedIDs: changed + newIDs, reentryAdded: reentryAdded)
    }

    /// Fills the vacated week with a copy of the nearest recovery week before the miss (else the last load week
    /// scaled down), from today on. Tests in the copy become easy sessions. Returns the new session ids.
    private func insertReentryWeek(
        plan: inout Plan, original: Plan, targetWeek: Int, anchor: Date, run: AdaptationRun
    ) -> [String] {
        let calendar = run.calendar
        let anchorWeek = original.weekIndex(containing: anchor, calendar: calendar) ?? 0
        var sourceIndex: Int?
        var cursor = min(anchorWeek, original.weeks.count) - 1
        while cursor >= 0 {
            if original.weeks[cursor].isRecovery && !original.weeks[cursor].days.isEmpty { sourceIndex = cursor; break }
            cursor -= 1
        }
        var scale = 1.0
        if sourceIndex == nil {
            cursor = min(anchorWeek, original.weeks.count) - 1
            while cursor >= 0 {
                if !original.weeks[cursor].days.isEmpty { sourceIndex = cursor; break }
                cursor -= 1
            }
            scale = AdaptationConstants.reentryWeekFallbackFactor
        }
        guard let source = sourceIndex else { return [] }
        let sourceStart = calendar.startOfDay(for: original.weeks[source].startDate)
        let targetStart = calendar.startOfDay(for: plan.weeks[targetWeek].startDate)
        var added: [String] = []
        for template in original.weeks[source].sessions {
            let offset = calendar.daysBetween(sourceStart, calendar.startOfDay(for: template.scheduledDate))
            let date = calendar.addDays(offset, to: targetStart)
            if date < run.today { continue }
            if let raceDay = run.raceDay(plan: plan), date >= raceDay { continue }
            if plan.adaptSessions(on: date, calendar: calendar).contains(where: { $0.sport == template.sport }) { continue }
            var copy = template
            if AdaptationSupport.hasHardSteps(copy) { copy = AdaptationSupport.easy(copy, zones: zones) }
            if scale != 1 { copy = AdaptationSupport.scaled(copy, by: scale) }
            copy.state = .planned
            copy.scheduledDate = date
            copy.id = plan.adaptNewSessionID(weekIndex: targetWeek, date: date, sport: copy.sport, calendar: calendar)
            if plan.adaptInsert(copy, calendar: calendar) { added.append(copy.id) }
        }
        return added
    }
}

// MARK: - Run state

/// Everything a single pass needs besides the plan: the normalized day, the calendar, the context and the
/// unwell periods rebuilt from the toggle events.
struct AdaptationRun {
    let context: AdaptationContext
    let calendar: Calendar
    let today: Date
    let periods: [AdaptationUnwellPeriod]

    init(context: AdaptationContext, calendar: Calendar) {
        self.context = context
        self.calendar = calendar
        self.today = calendar.startOfDay(for: context.today)
        self.periods = AdaptationUnwellPeriod.periods(from: context.events, today: calendar.startOfDay(for: context.today), calendar: calendar)
    }

    /// True when the day falls inside an easy only stretch or the gradual return (annex C rule 4).
    func isRestricted(_ day: Date) -> Bool {
        periods.contains { $0.contains(day, calendar: calendar) }
    }

    /// Start of the race day, when the plan has a race.
    func raceDay(plan: Plan) -> Date? {
        plan.raceDate.map { calendar.startOfDay(for: $0) }
    }

    /// Annex C rule 7: the race window is active from T minus 21 days (T minus 10 for Sprint) through race day.
    func taperLockActive(plan: Plan) -> Bool {
        guard let distance = plan.raceDistance, let raceDay = raceDay(plan: plan) else { return false }
        let opens = calendar.addDays(-distance.parameters.windowOpensTMinusDays, to: raceDay)
        return today >= opens && today <= raceDay
    }

    /// Whether today's single structural change is already spent (annex C: one per day, a confirmed rule 2
    /// realignment counts as that change).
    func structuralUsedToday(includingChosenEvents: Bool) -> Bool {
        if context.history.contains(where: { $0.isStructural && calendar.isDate($0.date, inSameDayAs: today) }) {
            return true
        }
        if includingChosenEvents {
            for event in context.events {
                if case let .realignmentChosen(_, on) = event, calendar.isDate(on, inSameDayAs: today) { return true }
            }
        }
        return false
    }

    /// Day of the latest confirmed realignment, the floor for counting misses.
    func lastRealignmentDay() -> Date? {
        context.history.filter { $0.rule == .realignmentPrompt && $0.isStructural }
            .map { calendar.startOfDay(for: $0.date) }.max()
    }
}

/// A rule that changed the plan.
struct AdaptationOutcome {
    var plan: Plan
    var event: AdaptationEvent
}
