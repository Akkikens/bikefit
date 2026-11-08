import Foundation

// Annex C rules 5, 6 and 8. Rule 7 (taper lock) is enforced in `DefaultAdaptationEngine.apply`.

extension DefaultAdaptationEngine {
    // MARK: Rule 5: ramp clamp

    /// Annex C rule 5. A recomputed or athlete edited load week (named by a `weekEdited` event) may not exceed
    /// 110 percent of the most recent load week. Recovery weeks are excluded on both sides, and peak and taper
    /// weeks are exempt. An over the cap week is clamped by shortening future planned sessions, easy ones first.
    func rule5(plan: Plan, run: AdaptationRun, extraWeeks: Set<Int> = []) -> AdaptationOutcome? {
        let calendar = run.calendar
        let firstWeek: Int
        if run.today < calendar.startOfDay(for: plan.startDate) {
            firstWeek = 0
        } else if let index = plan.weekIndex(containing: run.today, calendar: calendar) {
            firstWeek = index
        } else {
            return nil
        }

        var edited = Set<Int>()
        for event in run.context.events {
            if case let .weekEdited(index, on) = event, calendar.startOfDay(for: on) <= run.today, index >= firstWeek,
               plan.weeks.indices.contains(index) {
                edited.insert(index)
            }
        }
        edited.formUnion(extraWeeks.filter { $0 >= firstWeek && plan.weeks.indices.contains($0) })
        guard !edited.isEmpty else { return nil }

        var working = plan
        var changed: [String] = []
        for index in edited.sorted() {
            let week = working.weeks[index]
            if week.isRecovery || isDesignedExempt(week) { continue }
            guard let reference = referenceLoad(plan: working, before: index, run: run),
                  let trimmed = working.adaptWeekWithoutSkipped(index) else { continue }
            let cap = reference.load * AdaptationConstants.rampCapFactor
            let load = loadModel.plannedLoad(for: trimmed, benchmarks: run.context.benchmarks)
            guard load > cap + AdaptationConstants.loadTolerance else { continue }
            changed.append(contentsOf: shortenWeek(plan: &working, weekIndex: index, cap: cap, run: run))
        }
        guard !changed.isEmpty else { return nil }

        let line = changed.count == 1
            ? "This week grew too fast, so one session got shorter"
            : "This week grew too fast, so \(changed.count) sessions got shorter"
        let event = AdaptationEvent(
            rule: .rampClamp, reasonLine: line, date: run.today, isStructural: true, sessionIDs: changed)
        return AdaptationOutcome(plan: working, event: event)
    }

    /// A peak or taper week is exempt while it is still as the template designed it. Once the athlete has changed
    /// its hours, the cap applies to it like to any other load week (spec 3.3: the cap polices edits).
    func isDesignedExempt(_ week: PlannedWeek) -> Bool {
        guard AdaptationConstants.rampExemptPhases.contains(week.phase) else { return false }
        guard let designed = week.designedHours else { return true }
        return abs(week.plannedHours - designed) <= AdaptationConstants.designedHoursTolerance
    }

    // MARK: Rule 6: load spike

    /// Annex C rule 6. When the acute (7 day) over chronic (28 day) Load ratio is above 1.5, today goes easy: a
    /// hard planned session today is brought down to easy, or a short easy session is added when today is open.
    /// Needs 28 days of recorded history, so a new athlete never trips it. A caution rule, not a prediction.
    func rule6(plan: Plan, run: AdaptationRun) -> AdaptationOutcome? {
        let calendar = run.calendar
        guard let weekIndex = plan.weekIndex(containing: run.today, calendar: calendar) else { return nil }
        if let raceDay = run.raceDay(plan: plan), run.today >= raceDay { return nil }

        var loads = run.context.dailyLoads
        if loads.isEmpty, !run.context.completedWorkouts.isEmpty {
            loads = loadModel.dailyLoads(
                workouts: run.context.completedWorkouts, benchmarks: run.context.benchmarks,
                from: calendar.addDays(-(AdaptationConstants.spikeMinimumHistoryDays + 13), to: run.today),
                through: run.today, calendar: calendar)
        }
        var firstRecorded: Date?
        for sample in loads where sample.load > 0 {
            let day = calendar.startOfDay(for: sample.date)
            if firstRecorded.map({ day < $0 }) ?? true { firstRecorded = day }
        }
        for workout in run.context.completedWorkouts {
            let day = calendar.startOfDay(for: workout.start)
            if firstRecorded.map({ day < $0 }) ?? true { firstRecorded = day }
        }
        guard let first = firstRecorded,
              calendar.daysBetween(first, run.today) >= AdaptationConstants.spikeMinimumHistoryDays,
              let ratio = loadModel.acuteChronicRatio(dailyLoads: loads, asOf: run.today, calendar: calendar),
              ratio > AdaptationConstants.spikeRatio else { return nil }

        var edited = plan
        let todays = plan.adaptSessions(on: run.today, calendar: calendar)
        var changed: [String] = []
        for session in todays where session.state == .planned && AdaptationSupport.hasHardSteps(session) {
            edited.updateSession(id: session.id) { $0 = AdaptationSupport.easy(session, zones: zones) }
            changed.append(session.id)
        }
        if changed.isEmpty {
            let hasLiveSession = todays.contains { AdaptationSupport.isLive($0) }
            let weekday = Weekday(date: run.today, calendar: calendar)
            guard !hasLiveSession, plan.athlete.availableWeekdays.contains(weekday) else { return nil }
            let sport = easyDaySport(plan: plan, run: run, weekday: weekday)
            let id = plan.adaptNewSessionID(weekIndex: weekIndex, date: run.today, sport: sport, calendar: calendar)
            let target: StepTarget = sport == .swim
                ? .cssOffset(zones.swimOffsetRange(.easy))
                : .rpe(ZoneConstants.rpeRange(forLevel: AdaptationConstants.easyMaximumLevel))
            let step = Step(
                sport: sport, kind: .work, durationSeconds: AdaptationConstants.easyDayDurationSeconds,
                level: AdaptationConstants.easyMaximumLevel, target: target, name: "Easy",
                note: "Keep it conversational. Stop early if it does not feel right.")
            let inserted = Session(
                id: id, sport: sport, name: "Easy \(AdaptationSupport.sportNoun(sport))",
                purpose: "A short easy day after a jump in recent load.",
                steps: [step], scheduledDate: run.today)
            guard edited.adaptInsert(inserted, calendar: calendar) else { return nil }
            changed.append(id)
        }
        edited.adaptRefreshHours(weekIndex: weekIndex)
        edited.weeks[weekIndex].cautionFlag = true
        let event = AdaptationEvent(
            rule: .loadSpike, reasonLine: AdaptationConstants.loadSpikeReason, date: run.today,
            isStructural: true, sessionIDs: changed)
        return AdaptationOutcome(plan: edited, event: event)
    }

    /// Sport for an inserted easy day: the sport of the latest recorded workout, else run, else bike. Swim only on
    /// a pool day.
    private func easyDaySport(plan: Plan, run: AdaptationRun, weekday: Weekday) -> Sport {
        var order: [Sport] = []
        if let latest = run.context.completedWorkouts.max(by: { $0.start < $1.start }) { order.append(latest.sport) }
        order.append(contentsOf: [.run, .bike])
        for sport in order {
            if sport == .swim, !plan.athlete.poolWeekdays.contains(weekday) { continue }
            return sport
        }
        return .run
    }

    // MARK: Rule 8: retest

    /// Sports whose last completed test is older than 8 weeks, or that were never tested (annex C rule 8, through
    /// `Benchmarks.lastTestDate`, which ignores Estimated values), and that have no test planned up to the next
    /// block boundary.
    func staleSports(plan: Plan, run: AdaptationRun) -> [Sport] {
        let calendar = run.calendar
        let limit = AdaptationConstants.staleTestWeeks * 7
        let boundary = retestBoundaryWeeks(plan: plan, run: run).first
        var result: [Sport] = []
        for sport in Sport.allCases {
            if let last = run.context.benchmarks.lastTestDate(for: sport),
               calendar.daysBetween(calendar.startOfDay(for: last), run.today) <= limit { continue }
            guard let boundary else { continue }
            let planned = plan.allSessions.contains { session in
                guard session.isTest, session.state == .planned,
                      calendar.startOfDay(for: session.scheduledDate) >= run.today,
                      session.benchmarkKind?.sport == sport || (session.benchmarkKind == nil && session.sport == sport),
                      let week = plan.weekIndex(containing: session.scheduledDate, calendar: calendar) else { return false }
                return week <= boundary
            }
            if !planned { result.append(sport) }
        }
        return result
    }

    /// Candidate block boundary weeks from the current week on: test weeks, else recovery weeks. Taper weeks, the
    /// race week and anything inside the race window are excluded (no added intensity).
    func retestBoundaryWeeks(plan: Plan, run: AdaptationRun) -> [Int] {
        let calendar = run.calendar
        let current: Int
        if run.today < calendar.startOfDay(for: plan.startDate) {
            current = 0
        } else if let index = plan.weekIndex(containing: run.today, calendar: calendar) {
            current = index
        } else {
            return []
        }
        var lockStart: Date?
        if let distance = plan.raceDistance, let raceDay = run.raceDay(plan: plan) {
            lockStart = calendar.addDays(-distance.parameters.windowOpensTMinusDays, to: raceDay)
        }
        func eligible(_ index: Int) -> Bool {
            let week = plan.weeks[index]
            if week.phase == .taper { return false }
            if let lockStart, calendar.addDays(6, to: calendar.startOfDay(for: week.startDate)) >= lockStart { return false }
            return true
        }
        let candidates = (current..<plan.weeks.count).filter(eligible)
        let tests = candidates.filter { plan.weeks[$0].isTest }
        return tests.isEmpty ? candidates.filter { plan.weeks[$0].isRecovery } : tests
    }

    /// Annex C rule 8. Inserts a test for each stale sport in the next block boundary week that can take it: at most
    /// 2 tests a week, at least 48 hours apart, on the athlete's days (pool days for swim), and within the weekly
    /// quality caps. When the caps are full, a planned quality session replaces itself with the test.
    func rule8(plan: Plan, run: AdaptationRun) -> AdaptationOutcome? {
        let stale = staleSports(plan: plan, run: run)
        guard !stale.isEmpty else { return nil }
        let boundaries = retestBoundaryWeeks(plan: plan, run: run)
        var edited = plan
        var changed: [String] = []
        var insertedSports: [Sport] = []

        for sport in stale {
            let kind = testKind(for: sport, athlete: plan.athlete)
            for weekIndex in boundaries.prefix(3) {
                if let ids = placeTest(kind: kind, sport: sport, weekIndex: weekIndex, plan: &edited, run: run) {
                    changed.append(contentsOf: ids)
                    insertedSports.append(sport)
                    break
                }
            }
        }
        guard !insertedSports.isEmpty else { return nil }
        let event = AdaptationEvent(
            rule: .retest, reasonLine: AdaptationConstants.retestReason, date: run.today, isStructural: true,
            sessionIDs: changed, sport: insertedSports.count == 1 ? insertedSports[0] : nil)
        return AdaptationOutcome(plan: edited, event: event)
    }

    private func testKind(for sport: Sport, athlete: AthleteProfile) -> BenchmarkKind {
        switch sport {
        case .swim: return .swimCSS
        case .bike: return athlete.hasPowerMeter ? .bikeFTP : .bikeLTHR
        case .run: return .runThreshold
        }
    }

    /// Puts one test into a week, or returns nil when the week cannot take it. Returns the ids touched.
    private func placeTest(
        kind: BenchmarkKind, sport: Sport, weekIndex: Int, plan: inout Plan, run: AdaptationRun
    ) -> [String]? {
        let calendar = run.calendar
        guard plan.weeks.indices.contains(weekIndex) else { return nil }
        let week = plan.weeks[weekIndex]
        let athlete = plan.athlete
        let live = week.sessions.filter { AdaptationSupport.isLive($0) }
        let tests = live.filter { $0.isTest }
        guard tests.count < AdaptationConstants.maximumTestsPerWeek else { return nil }
        guard !tests.contains(where: { $0.benchmarkKind?.sport == sport }) else { return nil }

        let hardLive = live.filter { AdaptationSupport.isHard($0) }
        let sameSportHard = hardLive.filter { $0.sport == sport }.count
        let needsReplacement = hardLive.count + 1 > athlete.level.maxQualityPerWeek
            || sameSportHard + 1 > Level.maxQualityPerSport

        let weekStart = calendar.startOfDay(for: week.startDate)
        var lastDay = calendar.addDays(6, to: weekStart)
        if let raceDay = run.raceDay(plan: plan), calendar.addDays(-1, to: raceDay) < lastDay {
            lastDay = calendar.addDays(-1, to: raceDay)
        }
        var firstDay = weekStart
        if firstDay <= run.today { firstDay = calendar.addDays(1, to: run.today) }
        guard firstDay <= lastDay else { return nil }

        func dayAllowed(_ day: Date) -> Bool {
            let weekday = Weekday(date: day, calendar: calendar)
            guard athlete.availableWeekdays.contains(weekday) else { return false }
            if sport == .swim, !athlete.poolWeekdays.contains(weekday) { return false }
            for test in tests {
                let gap = abs(calendar.daysBetween(calendar.startOfDay(for: test.scheduledDate), day))
                if gap < AdaptationConstants.testSpacingDays { return false }
            }
            return true
        }

        var date: Date?
        var replaced: Session?
        if needsReplacement {
            let replaceable = live.filter {
                $0.state == .planned && $0.isQuality && !$0.isTest
                    && calendar.startOfDay(for: $0.scheduledDate) >= firstDay
                    && calendar.startOfDay(for: $0.scheduledDate) <= lastDay
            }.filter { candidate in
                let sameSportAfter = sameSportHard - (candidate.sport == sport ? 1 : 0) + 1
                return sameSportAfter <= Level.maxQualityPerSport && dayAllowed(calendar.startOfDay(for: candidate.scheduledDate))
            }.sorted { a, b in
                let aSame = a.sport == sport, bSame = b.sport == sport
                if aSame != bSame { return aSame }
                if a.scheduledDate != b.scheduledDate { return a.scheduledDate < b.scheduledDate }
                return a.id < b.id
            }
            if let pick = replaceable.first {
                replaced = pick
                date = calendar.startOfDay(for: pick.scheduledDate)
            }
        } else {
            var day = firstDay
            while day <= lastDay {
                if dayAllowed(day) {
                    let present = live.filter { calendar.startOfDay(for: $0.scheduledDate) == day }
                    let neighbourClash = [-1, 1].contains { offset in
                        let next = calendar.addDays(offset, to: day)
                        return live.contains {
                            calendar.startOfDay(for: $0.scheduledDate) == next && AdaptationSupport.isHard($0)
                                && $0.sport == sport
                        }
                    }
                    if !present.contains(where: { AdaptationSupport.isHard($0) }) && !neighbourClash {
                        date = day
                        break
                    }
                }
                day = calendar.addDays(1, to: day)
            }
        }
        guard let day = date else { return nil }

        // The id is taken before the replaced session leaves, so a replacement never reuses its id.
        let id = plan.adaptNewSessionID(weekIndex: weekIndex, date: day, sport: sport, calendar: calendar)
        var ids: [String] = []
        if let replaced {
            plan.adaptRemove(id: replaced.id)
            ids.append(replaced.id)
        }
        let session = makeTestSession(kind: kind, id: id, date: day, plan: plan, run: run)
        guard plan.adaptInsert(session, calendar: calendar) else { return nil }
        plan.adaptRefreshHours(weekIndex: weekIndex)
        ids.append(id)
        return ids
    }

    /// The test protocol of annex A as a session. There is one definition of each protocol, in `StepFactory`, so
    /// a test inserted here is the same session the template engine would have generated.
    func makeTestSession(kind: BenchmarkKind, id: String, date: Date, plan: Plan, run: AdaptationRun) -> Session {
        let sessionKind: SessionKind
        switch kind {
        case .swimCSS: sessionKind = .swimTest
        case .bikeFTP: sessionKind = .bikeTestFTP
        case .bikeLTHR: sessionKind = .bikeTestLTHR
        case .runThreshold: sessionKind = .runTest
        }
        let athlete = plan.athlete
        let context = BuildContext(
            level: athlete.level,
            phase: .base,
            distance: plan.raceDistance ?? DefaultTemplateEngine.referenceDistance(hours: athlete.weeklyHours),
            runWalk: athlete.prefersRunWalk,
            css: DefaultTemplateEngine.swimCSS(benchmarks: run.context.benchmarks, level: athlete.level),
            allowSteady: false,
            brickRunSeconds: 0)
        let built = StepFactory.build(sessionKind, seconds: 0, ctx: context)
        return Session(
            id: id, sport: kind.sport,
            name: SessionLibrary.name(for: sessionKind, runWalk: athlete.prefersRunWalk),
            purpose: SessionLibrary.purpose(for: sessionKind, runWalk: athlete.prefersRunWalk),
            steps: built.steps, scheduledDate: date, isQuality: true, isTest: true, benchmarkKind: kind)
    }
}
