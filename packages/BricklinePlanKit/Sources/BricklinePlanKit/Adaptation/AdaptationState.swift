import Foundation

/// The plan together with the two logs the adaptation engine needs, so the host cannot forget to persist one of
/// them. Annex C rules lean on both: `events` is what the athlete did, `history` is what the engine fired earlier
/// (it carries the once per 2 weeks nudge gap, the realignment floor and the one structural change per day budget).
///
/// Keep one `AdaptationState` per plan and save it whole. Every mutating method appends the new engine events to
/// `history` before returning, which is the step that is easy to miss when calling the engine by hand.
public struct AdaptationState: Codable, Hashable, Sendable {
    public var plan: Plan
    /// Everything the athlete did that the engine reacts to, oldest first. Unwell toggles stay in it for as long as
    /// they matter.
    public var events: [AthleteEvent]
    /// Every event the engine returned so far.
    public var history: [AdaptationEvent]

    public init(plan: Plan, events: [AthleteEvent] = [], history: [AdaptationEvent] = []) {
        self.plan = plan
        self.events = events
        self.history = history
    }

    /// Records something the athlete did (a skip, the unwell toggle, a weekly edit).
    public mutating func record(_ event: AthleteEvent) {
        events.append(event)
    }

    /// Runs the eight rules for `today`, replaces the plan with the result and appends the fired events to
    /// `history`. Returns the full result so the UI can show a pending realignment prompt.
    @discardableResult
    public mutating func apply(
        using engine: any AdaptationEngine,
        today: Date,
        completedWorkouts: [CompletedWorkout] = [],
        benchmarks: Benchmarks = Benchmarks(),
        dailyLoads: [LoadSample] = [],
        calendar: Calendar
    ) -> AdaptationResult {
        let result = engine.apply(
            to: plan,
            context: context(today: today, completedWorkouts: completedWorkouts, benchmarks: benchmarks, dailyLoads: dailyLoads),
            calendar: calendar)
        plan = result.plan
        history.append(contentsOf: result.events)
        return result
    }

    /// Applies the athlete's confirmed rule 2 choice, then logs the realignment event and the athlete's choice.
    @discardableResult
    public mutating func realign(
        _ option: RealignmentOption,
        using engine: any AdaptationEngine,
        today: Date,
        completedWorkouts: [CompletedWorkout] = [],
        benchmarks: Benchmarks = Benchmarks(),
        dailyLoads: [LoadSample] = [],
        calendar: Calendar
    ) throws -> AdaptationResult {
        let result = try engine.applyRealignment(
            option,
            to: plan,
            context: context(today: today, completedWorkouts: completedWorkouts, benchmarks: benchmarks, dailyLoads: dailyLoads),
            calendar: calendar)
        plan = result.plan
        history.append(contentsOf: result.events)
        events.append(.realignmentChosen(option, on: today))
        return result
    }

    /// Keep planned session (annex C rule 13) for a rule 10 or 11 event in `history`: puts the sessions back, valid on
    /// the day of the change, and marks the event as kept on `today`. The rule 13 override count (3 in 14 days) reads
    /// those marks, so the host cannot forget to record the tap. A second tap on an event already kept does
    /// nothing. Throws as `ReadinessRules.keepPlannedSession` does, and `PlanKitError.invalidInput` for an event
    /// that is not in the history. The state is unchanged on a throw.
    public mutating func keepPlannedSession(
        _ event: AdaptationEvent, using rules: ReadinessRules, today: Date, calendar: Calendar
    ) throws {
        func same(_ other: AdaptationEvent) -> Bool {
            other.rule == event.rule && other.date == event.date && other.sessionIDs == event.sessionIDs
                && other.reasonLine == event.reasonLine
        }
        if history.contains(where: { same($0) && $0.advisory?.keptOn != nil })
            && !history.contains(where: { same($0) && $0.advisory?.keptOn == nil }) {
            return
        }
        guard let index = history.firstIndex(where: { same($0) && $0.advisory?.keptOn == nil }) else {
            throw PlanKitError.invalidInput("That change is not in your log.")
        }
        let result = try rules.keepPlannedSession(history[index], in: plan, today: today, calendar: calendar)
        plan = result.plan
        history[index].advisory?.keptOn = result.overrideDay
    }

    /// Drops the stored original sessions of advisory changes dated before `today`: Keep planned session is only
    /// valid on the day of the change, so they can no longer be used and would only grow the saved log. The kept
    /// marks stay, since they feed the override count.
    public mutating func pruneAdvisories(before today: Date, calendar: Calendar) {
        let calendar = plan.resolvedCalendar(calendar)
        let start = calendar.startOfDay(for: today)
        for index in history.indices where calendar.startOfDay(for: history[index].date) < start {
            if let advisory = history[index].advisory, !advisory.originalSessions.isEmpty {
                history[index].advisory = advisory.pruned()
            }
        }
    }

    private func context(
        today: Date, completedWorkouts: [CompletedWorkout], benchmarks: Benchmarks, dailyLoads: [LoadSample]
    ) -> AdaptationContext {
        AdaptationContext(
            today: today, events: events, completedWorkouts: completedWorkouts, benchmarks: benchmarks,
            history: history, dailyLoads: dailyLoads)
    }
}
