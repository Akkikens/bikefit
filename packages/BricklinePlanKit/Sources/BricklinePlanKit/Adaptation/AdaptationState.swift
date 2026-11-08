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

    private func context(
        today: Date, completedWorkouts: [CompletedWorkout], benchmarks: Benchmarks, dailyLoads: [LoadSample]
    ) -> AdaptationContext {
        AdaptationContext(
            today: today, events: events, completedWorkouts: completedWorkouts, benchmarks: benchmarks,
            history: history, dailyLoads: dailyLoads)
    }
}
