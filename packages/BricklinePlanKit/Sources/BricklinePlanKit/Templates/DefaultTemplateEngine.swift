import Foundation

/// Template engine for race plans and the no race base block. Implements annex B (parameters, phases, blocks,
/// microcycle assembly) and the retest rotation of annex A. Deterministic: identical inputs give an identical
/// plan, session ids included. Nothing here reads the clock or uses randomness.
///
/// Notes on choices the annex leaves open:
/// - The athlete's declared weekly hours are the plan's average (clipped to the distance's published range);
///   peak weeks run 25 percent above it and recovery weeks 35 percent below.
/// - Declared hours under three quarters of the distance's lowest published hours are refused with
///   `infeasibleProfile`; between that and the table minimum the declared hours are used as given.
/// - Weeks are calendar weeks: week 0 starts on `calendar.firstWeekday` on or before the requested start date, and
///   the days of week 0 before the requested start are not used. The plan records the time zone it was built in.
/// - Declared hours above the table maximum are clipped, and hours between three quarters of the table minimum and
///   the minimum are accepted; both are reported in `Plan.warnings`, as is every session left out or eased.
/// - When the race is further away than the longest plan for its distance, the plan starts later, so the final
///   week always contains the race date. The caller can bridge the gap with `makeBasePlan`.
public struct DefaultTemplateEngine: TemplateEngine {
    public init() {}

    // MARK: TemplateEngine

    public func planWeekCount(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date,
        calendar: Calendar
    ) throws -> Int {
        let available = availableWeeks(from: Self.weekStart(containing: startDate, calendar: calendar), to: raceDate, calendar: calendar)
        let range = raceDistance.parameters.planWeeks
        guard available >= range.lowerBound else {
            throw PlanKitError.raceDateTooSoon(minimumWeeks: range.lowerBound, availableWeeks: available)
        }
        return min(available, range.upperBound)
    }

    /// First day of the calendar week (by `calendar.firstWeekday`) that contains `date`.
    static func weekStart(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let back = ((weekday - calendar.firstWeekday) % 7 + 7) % 7
        return calendar.startOfDay(for: calendar.addDays(-back, to: day))
    }

    public func makePlan(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan {
        let requested = calendar.startOfDay(for: startDate)
        let start = Self.weekStart(containing: requested, calendar: calendar)
        let race = calendar.startOfDay(for: raceDate)
        let available = availableWeeks(from: start, to: race, calendar: calendar)
        let n = try planWeekCount(raceDistance: raceDistance, raceDate: race, startDate: start, calendar: calendar)
        let generationStart = calendar.addDays(7 * (available - n), to: start)
        let context = try makeContext(
            distance: raceDistance, athlete: athlete, benchmarks: benchmarks, calendar: calendar,
            sequenceStart: generationStart, earliestDay: requested)
        let specs = SequencePlanner.raceSequence(
            distance: raceDistance, weekCount: n, start: generationStart, outputOffset: 0, raceDate: race,
            level: athlete.level, benchmarks: benchmarks, calendar: calendar)
        var history: [PlacedRecord] = []
        var warnings = hoursWarnings(distance: raceDistance, athlete: athlete)
        let weeks = assemble(specs, context: context, history: &history, previousLoadHours: nil, warnings: &warnings)
        warnings.append(contentsOf: peakWarning(weeks: weeks, averageHours: min(athlete.weeklyHours, raceDistance.parameters.weeklyHours.upperBound)))
        return Plan(
            raceDistance: raceDistance, raceDate: race, startDate: generationStart, weeks: weeks, athlete: athlete,
            timeZoneIdentifier: calendar.timeZone.identifier, warnings: warnings)
    }

    public func makeBasePlan(
        startDate: Date,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan {
        let requested = calendar.startOfDay(for: startDate)
        let start = Self.weekStart(containing: requested, calendar: calendar)
        let reference = Self.referenceDistance(hours: athlete.weeklyHours)
        let context = try makeContext(
            distance: reference, athlete: athlete, benchmarks: benchmarks,
            calendar: calendar, sequenceStart: start, earliestDay: requested)
        let specs = SequencePlanner.baseSequence(
            count: Self.baseBlockWeeks, start: start, outputOffset: 0, benchmarks: benchmarks, calendar: calendar)
        var history: [PlacedRecord] = []
        var warnings = hoursWarnings(distance: reference, athlete: athlete)
        let weeks = assemble(specs, context: context, history: &history, previousLoadHours: nil, warnings: &warnings)
        return Plan(
            raceDistance: nil, raceDate: nil, startDate: start, weeks: weeks, athlete: athlete,
            timeZoneIdentifier: calendar.timeZone.identifier, warnings: warnings)
    }

    public func convertToRacePlan(
        _ base: Plan,
        raceDistance: RaceDistance,
        raceDate: Date,
        today: Date,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan {
        try rebuild(
            base, raceDistance: raceDistance, raceDate: raceDate, today: today, benchmarks: benchmarks,
            calendar: calendar)
    }

    public func replan(
        _ plan: Plan,
        raceDistance: RaceDistance?,
        raceDate: Date?,
        today: Date,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan {
        try rebuild(
            plan, raceDistance: raceDistance, raceDate: raceDate, today: today, benchmarks: benchmarks,
            calendar: calendar)
    }

    // MARK: Constants

    /// Length of the rolling base block (annex B "No race yet mode").
    static let baseBlockWeeks = 4

    /// Distance table used for session counts in a plan with no race: chosen by declared hours.
    static func referenceDistance(hours: Double) -> RaceDistance {
        if hours <= 6 { return .sprint }
        if hours <= 10 { return .olympic }
        return .half
    }

    // MARK: Internals

    private func availableWeeks(from start: Date, to race: Date, calendar: Calendar) -> Int {
        let offset = calendar.daysBetween(start, race)
        return offset >= 0 ? offset / 7 + 1 : 0
    }

    private func makeContext(
        distance: RaceDistance,
        athlete: AthleteProfile,
        benchmarks: Benchmarks,
        calendar: Calendar,
        sequenceStart: Date,
        earliestDay: Date? = nil
    ) throws -> GenerationContext {
        guard athlete.weeklyHours.isFinite, athlete.weeklyHours > 0 else {
            throw PlanKitError.invalidInput("weekly hours must be a positive number")
        }
        guard !athlete.availableWeekdays.isEmpty else {
            throw PlanKitError.infeasibleProfile("no available training days")
        }
        let pool = athlete.poolWeekdays.intersection(athlete.availableWeekdays)
        guard !pool.isEmpty else {
            throw PlanKitError.infeasibleProfile("no pool day among the available days")
        }
        let params = distance.parameters
        guard athlete.weeklyHours >= params.weeklyHours.lowerBound * 0.75 else {
            throw PlanKitError.infeasibleProfile("weekly hours too low for \(distance.displayName)")
        }
        let average = min(athlete.weeklyHours, params.weeklyHours.upperBound)
        guard let counts = WeekAssembler.weekShape(
            distance: distance, level: athlete.level, averageHours: average,
            dayCount: athlete.availableWeekdays.count, poolDayCount: pool.count)
        else {
            throw PlanKitError.infeasibleProfile("not enough training days for a swim, a ride and a run")
        }
        return GenerationContext(
            distance: distance,
            athlete: athlete,
            benchmarks: benchmarks,
            calendar: calendar,
            sequenceStart: sequenceStart,
            earliestDay: earliestDay,
            averageHours: average,
            counts: counts,
            available: athlete.availableWeekdays,
            pool: pool,
            css: Self.swimCSS(benchmarks: benchmarks, level: athlete.level)
        )
    }

    /// CSS for duration estimates only: the athlete's value when sane, else a typical value for the level.
    static func swimCSS(benchmarks: Benchmarks, level: Level) -> Double {
        if let value = benchmarks.cssSecondsPer100m?.value, value.isFinite, value >= 50, value <= 300 {
            return value
        }
        switch level {
        case .firstTimer: return 130
        case .intermediate: return 110
        case .experienced: return 95
        }
    }

    private func assemble(
        _ specs: [WeekSpec],
        context: GenerationContext,
        history: inout [PlacedRecord],
        previousLoadHours: Double?,
        warnings: inout [PlanWarning]
    ) -> [PlannedWeek] {
        let assembler = WeekAssembler(ctx: context)
        let loadModel = DefaultLoadModel()
        var lastLoadHours = previousLoadHours
        var lastLoadValue: Double?
        var weeks: [PlannedWeek] = []
        for (position, spec) in specs.enumerated() {
            let historyBefore = history
            let warningsBefore = warnings
            var week = assembler.assemble(spec, history: &history, previousLoadHours: lastLoadHours, warnings: &warnings)
            var load = loadModel.plannedLoad(for: week, benchmarks: context.benchmarks)
            // Annex C rule 5 caps growth at 110 percent of the last load week. Entering a new phase adds quality
            // and a brick, so the same hours carry more Load. Where the designed week would grow more than the
            // target, it is rebuilt once at a smaller volume, so the template itself keeps inside the ramp. Peak
            // and taper weeks are designed to sit above or below the average and are left alone (annex B).
            if !spec.isRecovery, spec.phase != .taper, let previous = lastLoadValue, previous > 0,
               load > previous * Self.designedLoadRamp {
                var tighter = spec
                // Peak weeks keep at least 20 percent above the average (annex B); other weeks may give up to 15.
                let floor = spec.phase == .peak ? min(spec.hoursFactor, 1.20) : spec.hoursFactor * 0.85
                tighter.hoursFactor = max(spec.hoursFactor * previous * Self.designedLoadRamp / load, floor)
                history = historyBefore
                warnings = warningsBefore
                week = assembler.assemble(tighter, history: &history, previousLoadHours: lastLoadHours, warnings: &warnings)
                load = loadModel.plannedLoad(for: week, benchmarks: context.benchmarks)
            }
            if !spec.isRecovery, week.plannedHours > 0 {
                lastLoadHours = week.plannedHours
                // The first week of a run can be a part week (the plan starts mid week), so it never sets the
                // Load the next week is compared with.
                lastLoadValue = position == 0 ? nil : load
            }
            weeks.append(week)
        }
        return weeks
    }

    /// Target growth of planned Load from one load week to the next inside the template. Annex C rule 5 allows
    /// 10 percent for recomputed weeks; the template aims a little under it and the property test allows 12.
    static let designedLoadRamp = 1.09

    /// Notes for declared hours the template had to clip or stretch (annex B weekly hours).
    private func hoursWarnings(distance: RaceDistance, athlete: AthleteProfile) -> [PlanWarning] {
        let range = distance.parameters.weeklyHours
        var out: [PlanWarning] = []
        if athlete.weeklyHours > range.upperBound { out.append(.hoursClampedToMaximum(used: range.upperBound)) }
        if athlete.weeklyHours < range.lowerBound { out.append(.hoursBelowPublishedRange(distance: distance)) }
        return out
    }

    /// Peak weeks run above the declared average (annex B: 20 to 30 percent above), so the preview can say so.
    private func peakWarning(weeks: [PlannedWeek], averageHours: Double) -> [PlanWarning] {
        let peak = weeks.map(\.plannedHours).max() ?? 0
        return peak > averageHours * 1.1 ? [.peakExceedsDeclared(peakHours: peak)] : []
    }

    /// Placement records for sessions that already exist, so new weeks respect the days around them.
    private func records(of weeks: [PlannedWeek], context: GenerationContext) -> [PlacedRecord] {
        var out: [PlacedRecord] = []
        for week in weeks {
            let sessions = week.sessions
            let maxBike = sessions.filter { $0.sport == .bike }.map { $0.durationSeconds }.max() ?? 0
            let maxRun = sessions.filter { $0.sport == .run }.map { $0.durationSeconds }.max() ?? 0
            for s in sessions {
                out.append(PlacedRecord(
                    day: context.calendar.daysBetween(context.sequenceStart, s.scheduledDate),
                    sport: s.sport,
                    quality: s.isQuality || s.isTest,
                    test: s.isTest,
                    longRide: s.sport == .bike && !s.isQuality && maxBike > 0 && s.durationSeconds >= 0.8 * maxBike,
                    longRun: s.sport == .run && !s.isQuality && maxRun > 0 && s.durationSeconds >= 0.8 * maxRun,
                    brick: s.brickSecondSport != nil))
            }
        }
        return out
    }

    /// Keeps history, regenerates the rest from the week containing `today` (annex G "Race date moved or
    /// cancelled"). Weeks before the current week stay exactly as they were. Sessions already dated before
    /// `today` in the current week stay too, with their state.
    private func rebuild(
        _ plan: Plan,
        raceDistance: RaceDistance?,
        raceDate: Date?,
        today: Date,
        benchmarks: Benchmarks,
        calendar: Calendar
    ) throws -> Plan {
        let calendar = plan.resolvedCalendar(calendar)
        let planStart = calendar.startOfDay(for: plan.startDate)
        let today0 = calendar.startOfDay(for: today)
        let currentIndex = today0 >= planStart ? max(calendar.daysBetween(planStart, today0) / 7, 0) : 0
        let currentStart = calendar.addDays(7 * currentIndex, to: planStart)

        var prefix: [PlannedWeek] = []
        for k in 0..<currentIndex {
            if k < plan.weeks.count {
                prefix.append(plan.weeks[k])
            } else {
                prefix.append(PlannedWeek(index: k, startDate: calendar.addDays(7 * k, to: planStart), phase: .base))
            }
        }

        let athlete = plan.athlete
        var generated: [PlannedWeek]
        var warnings: [PlanWarning] = []
        var newDistance: RaceDistance?
        var newRace: Date?
        if let distance = raceDistance, let rawRace = raceDate {
            let race = calendar.startOfDay(for: rawRace)
            let available = availableWeeks(from: currentStart, to: race, calendar: calendar)
            let range = distance.parameters.planWeeks
            guard available >= range.lowerBound else {
                throw PlanKitError.raceDateTooSoon(minimumWeeks: range.lowerBound, availableWeeks: available)
            }
            let n = min(available, range.upperBound)
            let gap = available - n
            let context = try makeContext(
                distance: distance, athlete: athlete, benchmarks: benchmarks, calendar: calendar,
                sequenceStart: currentStart)
            var history = records(of: Array(prefix.suffix(2)), context: context)
            warnings = hoursWarnings(distance: distance, athlete: athlete)
            var specs: [WeekSpec] = []
            if gap > 0 {
                specs += SequencePlanner.baseSequence(
                    count: gap, start: currentStart, outputOffset: currentIndex, benchmarks: benchmarks,
                    calendar: calendar)
            }
            specs += SequencePlanner.raceSequence(
                distance: distance, weekCount: n, start: calendar.addDays(7 * gap, to: currentStart),
                outputOffset: currentIndex + gap, raceDate: race, level: athlete.level, benchmarks: benchmarks,
                calendar: calendar)
            generated = assemble(
                specs, context: context, history: &history, previousLoadHours: lastLoadHours(of: prefix),
                warnings: &warnings)
            newDistance = distance
            newRace = race
        } else {
            let context = try makeContext(
                distance: Self.referenceDistance(hours: athlete.weeklyHours), athlete: athlete,
                benchmarks: benchmarks, calendar: calendar, sequenceStart: currentStart)
            var history = records(of: Array(prefix.suffix(2)), context: context)
            let specs = SequencePlanner.baseSequence(
                count: Self.baseBlockWeeks, start: currentStart, outputOffset: currentIndex, benchmarks: benchmarks,
                calendar: calendar)
            warnings = hoursWarnings(distance: Self.referenceDistance(hours: athlete.weeklyHours), athlete: athlete)
            generated = assemble(
                specs, context: context, history: &history, previousLoadHours: lastLoadHours(of: prefix),
                warnings: &warnings)
        }

        // Days already behind us in the current week keep what the old plan had there.
        if !generated.isEmpty {
            var first = generated[0]
            for day in Array(first.days.keys) where day < today0 { first.days[day] = nil }
            if currentIndex < plan.weeks.count {
                for (day, list) in plan.weeks[currentIndex].days {
                    if day < today0 {
                        first.days[day] = list
                        continue
                    }
                    // Work already done or skipped today or later stays, and replaces the generated session of
                    // the same sport on that day (annex G: keep completed history).
                    let kept = list.filter { $0.state != .planned }
                    guard !kept.isEmpty else { continue }
                    var regenerated = first.days[day] ?? []
                    regenerated.removeAll { generated in kept.contains { $0.sport == generated.sport } }
                    first.days[day] = kept + regenerated
                }
            }
            let all = first.days.values.flatMap { $0 }
            first.isTest = all.contains { $0.isTest }
            first.plannedHours = (all.reduce(0) { $0 + $1.durationHours } * 100).rounded() / 100
            first.designedHours = first.plannedHours
            generated[0] = first
        }

        return Plan(
            raceDistance: newDistance,
            raceDate: newRace,
            startDate: planStart,
            weeks: prefix + generated,
            athlete: athlete,
            zoneNudgeSteps: plan.zoneNudgeSteps,
            zoneNudgeBaselineDates: plan.zoneNudgeBaselineDates,
            timeZoneIdentifier: plan.timeZoneIdentifier ?? calendar.timeZone.identifier,
            warnings: warnings
        )
    }

    /// Planned hours of the last load week in `weeks`, for the recovery ceiling of the weeks that follow.
    private func lastLoadHours(of weeks: [PlannedWeek]) -> Double? {
        weeks.last(where: { !$0.isRecovery && $0.plannedHours > 0 })?.plannedHours
    }
}
