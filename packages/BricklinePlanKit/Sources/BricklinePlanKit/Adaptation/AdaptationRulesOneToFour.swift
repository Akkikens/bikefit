import Foundation

// Annex C rules 1, 3 and 4.

extension DefaultAdaptationEngine {
    // MARK: Rule 1: skipped session

    struct Rule1Result {
        var plan: Plan
        var event: AdaptationEvent?
    }

    /// Annex C rule 1. A skipped session moves to a later free day in the same week, except a day already holding a
    /// quality session, and never creates a second quality day; with no slot it drops (state `skipped`).
    ///
    /// A later day means after the session's own day, after the skip day and not before today. A quality session also
    /// avoids a day next to a quality session of the same sport (annex B: never back to back hard days in one sport).
    /// While the athlete is unwell, a skip only marks the session as skipped, since rule 4 owns those days.
    /// With `allowMove` false (the day's structural change is spent or reserved) nothing runs and every skip
    /// event waits for the next pass.
    func rule1(plan: Plan, run: AdaptationRun, allowMove: Bool) -> Rule1Result {
        let calendar = run.calendar
        var edited = plan
        var moved: [Session] = []
        var movedTo: [Date] = []
        var dropped: [Session] = []

        var seen = Set<String>()
        var skips: [(id: String, day: Date)] = []
        for event in run.context.events {
            if case let .sessionSkipped(id, on) = event {
                let day = calendar.startOfDay(for: on)
                // One entry per session and day: a second skip of the same session on a later day is a new skip.
                let key = "\(id)|\(day.timeIntervalSinceReferenceDate)"
                if day <= run.today, seen.insert(key).inserted { skips.append((id, day)) }
            }
        }
        skips.sort { a, b in a.day != b.day ? a.day < b.day : a.id < b.id }

        for skip in skips {
            guard let session = edited.session(withID: skip.id), session.state == .planned else { continue }
            let sessionDay = calendar.startOfDay(for: session.scheduledDate)
            let consumed = run.context.history.contains {
                $0.rule == .skippedMove && $0.sessionIDs.contains(skip.id) && calendar.startOfDay(for: $0.date) >= skip.day
            }
            if consumed { continue }
            // An older skip whose session already sits after the skip day was handled by an earlier pass.
            if sessionDay > skip.day, skip.day < run.today { continue }

            guard allowMove else { continue }
            if run.isRestricted(skip.day) {
                edited.updateSession(id: skip.id) { $0.state = .skipped }
                continue
            }

            if let weekIndex = edited.weekIndex(containing: sessionDay, calendar: calendar),
               let target = moveTarget(for: session, plan: edited, weekIndex: weekIndex, skipDay: skip.day, run: run) {
                edited.adaptRemove(id: session.id)
                var relocated = session
                relocated.scheduledDate = target
                edited.adaptInsert(relocated, calendar: calendar)
                moved.append(relocated)
                movedTo.append(target)
            } else {
                edited.updateSession(id: skip.id) { $0.state = .skipped }
                dropped.append(session)
            }
        }

        let touched = moved + dropped
        guard !touched.isEmpty else { return Rule1Result(plan: edited, event: nil) }
        for session in touched {
            if let index = edited.weekIndex(containing: session.scheduledDate, calendar: calendar) {
                edited.adaptRefreshHours(weekIndex: index)
            }
        }

        // The annex wording talks about hard days, so it is used only when hard work is involved.
        let involvesHard = moved.contains { relocated in
            AdaptationSupport.isHard(relocated) || [-1, 1].contains { offset in
                let next = calendar.addDays(offset, to: calendar.startOfDay(for: relocated.scheduledDate))
                return edited.adaptSessions(on: next, calendar: calendar).contains {
                    $0.id != relocated.id && AdaptationSupport.isLive($0) && AdaptationSupport.isHard($0)
                }
            }
        }
        let line: String
        switch (moved.count, dropped.count) {
        case (1, 0):
            let day = AdaptationSupport.dayName(of: movedTo[0], calendar: calendar)
            line = involvesHard
                ? "Moved to \(day) so your hard days stay separated"
                : "Moved to \(day) to keep your week balanced"
        case (_, 0):
            line = involvesHard
                ? "Moved \(moved.count) sessions to later days so your hard days stay separated"
                : "Moved \(moved.count) sessions to later days to keep your week balanced"
        case (0, 1):
            line = "No free day left this week, so \(dropped[0].name) was dropped"
        case (0, _):
            line = "No free day left this week, so \(dropped.count) sessions were dropped"
        default:
            line = involvesHard
                ? "Moved \(moved.count) and dropped \(dropped.count) so your hard days stay separated"
                : "Moved \(moved.count) and dropped \(dropped.count) to keep your week balanced"
        }
        let sport: Sport? = touched.count == 1 ? touched[0].sport : nil
        let event = AdaptationEvent(
            rule: .skippedMove, reasonLine: line, date: run.today, isStructural: true,
            sessionIDs: touched.map(\.id), sport: sport)
        return Rule1Result(plan: edited, event: event)
    }

    /// The first later free day that satisfies the rule 1 constraints, or nil when the week has no slot.
    func moveTarget(for session: Session, plan: Plan, weekIndex: Int, skipDay: Date, run: AdaptationRun) -> Date? {
        let calendar = run.calendar
        let week = plan.weeks[weekIndex]
        let weekEnd = calendar.addDays(6, to: calendar.startOfDay(for: week.startDate))
        let sessionDay = calendar.startOfDay(for: session.scheduledDate)
        var firstDay = calendar.addDays(1, to: max(sessionDay, skipDay))
        if firstDay < run.today { firstDay = run.today }
        var lastDay = weekEnd
        if let raceDay = run.raceDay(plan: plan), calendar.addDays(-1, to: raceDay) < lastDay {
            lastDay = calendar.addDays(-1, to: raceDay)
        }
        return PlanMoveRules.firstAllowedDay(for: session, from: firstDay, through: lastDay, in: plan, calendar: calendar)
    }

    // MARK: Rule 3: zone nudge

    struct Rule3Result {
        var plan: Plan
        var events: [AdaptationEvent]
    }

    /// Annex C rule 3. Looks at the last 3 comparable quality sessions of each sport (same sport, same key level,
    /// tests excluded). Each is compared with the plan's own target, outliers beyond 20 percent are dropped, and if
    /// the median is at least one step (about 2 percent) off with all three on the same side, that sport's zones
    /// move one step. Never on Estimated benchmarks, at most once per 2 weeks per sport, never while unwell.
    /// Non structural.
    func rule3(plan: Plan, run: AdaptationRun) -> Rule3Result {
        var edited = plan
        var events: [AdaptationEvent] = []
        guard !run.isRestricted(run.today) else { return Rule3Result(plan: plan, events: []) }
        let calendar = run.calendar

        for sport in Sport.allCases {
            guard nudgeBenchmarkIsTested(sport: sport, plan: plan, run: run) else { continue }

            let lastNudge = run.context.history
                .filter { $0.rule == .zoneNudge && $0.sport == sport }
                .map { calendar.startOfDay(for: $0.date) }.max()
            if let lastNudge, calendar.daysBetween(lastNudge, run.today) < AdaptationConstants.nudgeMinimumGapDays { continue }

            struct Sample { var id: String; var deviation: Double; var level: Int; var start: Date }
            var samples: [Sample] = []
            for workout in run.context.completedWorkouts where workout.sport == sport {
                let day = calendar.startOfDay(for: workout.start)
                if day > run.today || run.isRestricted(day) { continue }
                if let lastNudge, day <= lastNudge { continue }
                guard let id = workout.plannedSessionID, let session = plan.session(withID: id),
                      session.isQuality, !session.isTest,
                      let measured = nudgeDeviation(workout: workout, session: session, plan: plan, run: run) else { continue }
                if abs(measured.deviation) > AdaptationConstants.nudgeOutlierFraction { continue }
                samples.append(Sample(id: id, deviation: measured.deviation, level: measured.level, start: workout.start))
            }
            samples.sort { a, b in a.start != b.start ? a.start > b.start : a.id < b.id }
            guard let newest = samples.first else { continue }
            let group = samples.filter { $0.level == newest.level }.prefix(AdaptationConstants.nudgeSessionCount)
            guard group.count == AdaptationConstants.nudgeSessionCount else { continue }

            let sorted = group.map(\.deviation).sorted()
            let median = sorted[sorted.count / 2]
            guard abs(median) >= AdaptationConstants.nudgeTriggerFraction else { continue }
            let direction = median > 0 ? 1 : -1
            guard group.allSatisfy({ ($0.deviation > 0 ? 1 : ($0.deviation < 0 ? -1 : 0)) == direction }) else { continue }

            let current = edited.zoneNudgeSteps[sport] ?? 0
            let next = min(max(current + direction, -AdaptationConstants.nudgeMaximumSteps), AdaptationConstants.nudgeMaximumSteps)
            guard next != current else { continue }
            edited.zoneNudgeSteps[sport] = next == 0 ? nil : next
            edited.zoneNudgeBaselineDates[sport] = next == 0 ? nil : run.context.benchmarks.lastTestDate(for: sport)

            let levelWord = Self.levelWord(newest.level)
            let plural = AdaptationSupport.sportPlural(sport)
            let line: String
            if sport == .bike {
                line = direction > 0
                    ? "Your last three \(levelWord) \(plural) came in higher than target, so power targets moved up slightly"
                    : "Your last three \(levelWord) \(plural) came in lower than target, so power targets eased slightly"
            } else {
                line = direction > 0
                    ? "Your last three \(levelWord) \(plural) came in faster than target, so paces moved up slightly"
                    : "Your last three \(levelWord) \(plural) came in slower than target, so paces eased slightly"
            }
            events.append(AdaptationEvent(
                rule: .zoneNudge, reasonLine: line, date: run.today, isStructural: false,
                sessionIDs: group.map(\.id), sport: sport))
        }
        return Rule3Result(plan: edited, events: events)
    }

    /// A sport can only be nudged against a tested (not Estimated) benchmark that the comparison can use.
    private func nudgeBenchmarkIsTested(sport: Sport, plan: Plan, run: AdaptationRun) -> Bool {
        let benchmarks = run.context.benchmarks
        if benchmarks.isOnlyEstimated(for: sport) { return false }
        switch sport {
        case .swim:
            return benchmarks.cssSecondsPer100m.map { !$0.isEstimated } ?? false
        case .bike:
            return plan.athlete.hasPowerMeter && (benchmarks.ftpWatts.map { !$0.isEstimated } ?? false)
        case .run:
            return benchmarks.thresholdPaceSecondsPerKm.map { !$0.isEstimated } ?? false
        }
    }

    /// Deviation of a workout from the plan's target: positive means faster (swim, run) or stronger (bike).
    ///
    /// Compares like with like: the expected value is the duration weighted mean of the resolved targets of the
    /// session's work steps at level 3 or harder, with the sport's current nudge applied, and the actual value is
    /// the workout's work interval average. Warm ups, recoveries, cool downs and easy steps never enter the
    /// expected value. A workout that only carries whole workout averages is used only when the session has no
    /// easy or recovery parts at all (a continuous effort); otherwise it is skipped, because the average would mix
    /// the easy minutes in. Nil when not comparable.
    private func nudgeDeviation(
        workout: CompletedWorkout, session: Session, plan: Plan, run: AdaptationRun
    ) -> (deviation: Double, level: Int)? {
        let steps = session.steps.filter { $0.sport == workout.sport && $0.durationSeconds > 0 }
        let workSteps = steps.filter { $0.kind == .work && $0.level >= AdaptationConstants.nudgeMinimumWorkLevel }
        guard !workSteps.isEmpty else { return nil }
        let hasEasyParts = steps.contains { $0.kind != .work || $0.level < AdaptationConstants.nudgeMinimumWorkLevel }
        let nudge = plan.zoneNudgeSteps[workout.sport] ?? 0
        var weighted = 0.0
        var seconds = 0.0
        for step in workSteps {
            let resolved = zones.resolveTarget(for: step, athlete: plan.athlete, benchmarks: run.context.benchmarks, nudgeSteps: nudge)
            let value: Double
            switch (workout.sport, resolved) {
            case let (.run, .pacePerKm(range)) where range.midpoint > 0: value = 1000 / range.midpoint
            case let (.swim, .pacePer100m(range)) where range.midpoint > 0: value = 100 / range.midpoint
            case let (.bike, .powerRange(range)) where range.midpoint > 0: value = range.midpoint
            default: return nil
            }
            let weight = step.durationSeconds * Double(step.repeats)
            weighted += value * weight
            seconds += weight
        }
        guard seconds > 0 else { return nil }
        let expected = weighted / seconds

        let actual: Double
        switch workout.sport {
        case .run:
            guard let pace = workout.workIntervalAveragePacePerKm ?? (hasEasyParts ? nil : workout.averagePacePerKm),
                  pace > 0 else { return nil }
            actual = 1000 / pace
        case .swim:
            guard let pace = workout.workIntervalAveragePacePer100m ?? (hasEasyParts ? nil : workout.averagePacePer100m),
                  pace > 0 else { return nil }
            actual = 100 / pace
        case .bike:
            guard let power = workout.workIntervalAveragePower ?? (hasEasyParts ? nil : (workout.adjustedPower ?? workout.averagePower)),
                  power > 0 else { return nil }
            actual = power
        }
        guard expected.isFinite, expected > 0, actual.isFinite else { return nil }

        // Key level: the level holding the most work time, ties to the harder level.
        var byLevel: [Int: Double] = [:]
        for step in workSteps { byLevel[step.level, default: 0] += step.durationSeconds * Double(step.repeats) }
        let level = byLevel.max { a, b in a.value != b.value ? a.value < b.value : a.key < b.key }?.key
            ?? workSteps.map(\.level).max() ?? 3
        return (actual / expected - 1, level)
    }

    private static func levelWord(_ level: Int) -> String {
        switch level {
        case ...2: return "easy"
        case 3: return "steady"
        case 4: return "threshold"
        default: return "VO2"
        }
    }

    // MARK: Rule 4: unwell mode

    /// Annex C rule 4. Easy sessions only for up to 14 days from the toggle, then quality returns over one week:
    /// the first 3 days stay easy, after that at most one quality session, capped at level 4.
    ///
    /// Only sessions in the next 7 days (today included) are adapted on each pass, so switching the toggle off
    /// early leaves later sessions as the plan wrote them.
    func rule4(plan: Plan, run: AdaptationRun) -> AdaptationOutcome? {
        guard !run.periods.isEmpty else { return nil }
        let calendar = run.calendar
        let horizon = calendar.addDays(AdaptationConstants.unwellHorizonDays - 1, to: run.today)
        var edited = plan
        var changed: [String] = []

        func period(on day: Date) -> (AdaptationUnwellPeriod, AdaptationUnwellPeriod.Mode)? {
            for period in run.periods {
                let mode = period.mode(on: day, calendar: calendar)
                if mode != .none { return (period, mode) }
            }
            return nil
        }

        // Hard sessions already inside a return window before today use up its single quality slot.
        var qualityUsed: [Date: Int] = [:]
        for session in plan.allSessions where AdaptationSupport.isLive(session) && AdaptationSupport.isHard(session) {
            let day = calendar.startOfDay(for: session.scheduledDate)
            if day < run.today, let (period, mode) = period(on: day), mode == .limitedQuality {
                qualityUsed[period.start, default: 0] += 1
            }
        }

        let upcoming = plan.allSessions.filter {
            let day = calendar.startOfDay(for: $0.scheduledDate)
            return $0.state == .planned && day >= run.today && day <= horizon
        }
        for session in upcoming {
            let day = calendar.startOfDay(for: session.scheduledDate)
            guard let (period, mode) = period(on: day) else { continue }
            var replacement = session
            switch mode {
            case .none:
                continue
            case .easyOnly:
                if AdaptationSupport.hasHardSteps(session) { replacement = AdaptationSupport.easy(session, zones: zones) }
            case .limitedQuality:
                if AdaptationSupport.isHard(session) {
                    let used = qualityUsed[period.start] ?? 0
                    if session.isTest || used >= AdaptationConstants.unwellReturnMaximumQuality {
                        replacement = AdaptationSupport.easy(session, zones: zones)
                    } else {
                        qualityUsed[period.start] = used + 1
                        replacement.steps = session.steps.map {
                            AdaptationSupport.cap($0, maxLevel: AdaptationConstants.unwellReturnMaximumLevel, zones: zones)
                        }
                    }
                } else if session.steps.contains(where: { $0.level > AdaptationConstants.unwellReturnMaximumLevel }) {
                    replacement.steps = session.steps.map {
                        AdaptationSupport.cap($0, maxLevel: AdaptationConstants.unwellReturnMaximumLevel, zones: zones)
                    }
                }
            }
            if replacement != session {
                edited.updateSession(id: session.id) { $0 = replacement }
                changed.append(session.id)
            }
        }
        guard !changed.isEmpty else { return nil }

        let reference = period(on: run.today)?.0 ?? run.periods[run.periods.count - 1]
        let returnDay = AdaptationSupport.dayName(of: reference.qualityReturnDate(calendar: calendar), calendar: calendar)
        let event = AdaptationEvent(
            rule: .unwellCap,
            reasonLine: "Easy week while you recover; quality returns \(returnDay)",
            date: run.today, isStructural: true, sessionIDs: changed)
        return AdaptationOutcome(plan: edited, event: event)
    }
}
