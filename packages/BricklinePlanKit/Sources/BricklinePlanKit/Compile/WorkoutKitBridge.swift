#if canImport(WorkoutKit)
import Foundation
import HealthKit
import WorkoutKit

// Annex E: maps the platform neutral intermediate to WorkoutKit types on device. Tests cover the neutral
// representation; this bridge only translates values and holds no decisions. Which goals and alerts survive was
// already decided by the compiler through `CapabilityTiering`.

/// Converts `CompiledWorkout` values to WorkoutKit types (CustomWorkout, SingleGoalWorkout, SwimBikeRunWorkout,
/// WorkoutPlan). Alerts are always explicit ranges, never zone alerts (annex E "Alerts").
@available(iOS 18, macOS 15, watchOS 11, *)
public enum WorkoutKitBridge {

    /// One plan per compiled workout of the session, in order (a brick gives bike then run). `makeID` supplies
    /// each plan's UUID by position so the caller controls identity and the bridge stays deterministic.
    public static func makePlans(
        from session: CompiledSession,
        capabilities: DeviceCapabilities,
        makeID: (Int) -> UUID
    ) -> [WorkoutPlan] {
        let showNames = capabilities.supportsStepDisplayNames && capabilities.tier == .standard
        return session.workouts.enumerated().map { index, workout in
            makePlan(from: workout, id: makeID(index), includeStepNames: showNames)
        }
    }

    /// Wraps one compiled workout in a `WorkoutPlan`. When `includeStepNames` is false the steps carry no display
    /// name and the stock Work and Recovery labels show (annex E tier 2).
    public static func makePlan(from workout: CompiledWorkout, id: UUID, includeStepNames: Bool) -> WorkoutPlan {
        switch workout {
        case .custom(let custom):
            return WorkoutPlan(.custom(customWorkout(from: custom, includeStepNames: includeStepNames)), id: id)
        case .singleGoal(let single):
            return WorkoutPlan(.goal(singleGoalWorkout(from: single)), id: id)
        case .swimBikeRun(let race):
            return WorkoutPlan(.swimBikeRun(swimBikeRunWorkout(from: race)), id: id)
        }
    }

    // MARK: - Workouts

    public static func customWorkout(from workout: CompiledCustomWorkout, includeStepNames: Bool) -> CustomWorkout {
        let location = sessionLocation(workout.activity.location)
        return CustomWorkout(
            activity: activityType(workout.activity.sport),
            location: location,
            displayName: workout.displayName,
            warmup: workout.warmUp.map { workoutStep(from: $0, includeName: includeStepNames) },
            blocks: workout.blocks.map { block in
                IntervalBlock(
                    steps: block.steps.map { step in
                        IntervalStep(purpose(for: step.kind), step: workoutStep(from: step, includeName: includeStepNames))
                    },
                    iterations: block.iterations)
            },
            cooldown: workout.coolDown.map { workoutStep(from: $0, includeName: includeStepNames) })
    }

    public static func singleGoalWorkout(from workout: CompiledSingleGoalWorkout) -> SingleGoalWorkout {
        SingleGoalWorkout(
            activity: activityType(workout.activity.sport),
            location: sessionLocation(workout.activity.location),
            swimmingLocation: swimmingLocation(workout.activity.location),
            goal: goal(from: workout.goal))
    }

    public static func swimBikeRunWorkout(from workout: CompiledSwimBikeRunWorkout) -> SwimBikeRunWorkout {
        let activities = workout.legs.map { leg -> SwimBikeRunWorkout.Activity in
            switch leg.activity.sport {
            case .swim: return .swimming(swimmingLocation(leg.activity.location))
            case .bike: return .cycling(sessionLocation(leg.activity.location))
            case .run: return .running(sessionLocation(leg.activity.location))
            }
        }
        return SwimBikeRunWorkout(activities: activities, displayName: workout.displayName)
    }

    // MARK: - Steps, goals, alerts

    public static func workoutStep(from step: CompiledStep, includeName: Bool) -> WorkoutStep {
        WorkoutStep(
            goal: goal(from: step.goal),
            alert: alert(from: step.alert),
            displayName: includeName ? step.displayName : nil)
    }

    /// Energy goals are never produced (annex E "Goals").
    public static func goal(from goal: CompiledGoal) -> WorkoutGoal {
        switch goal {
        case .open:
            return .open
        case .time(let seconds):
            return .time(seconds, .seconds)
        case .distance(let meters):
            return .distance(meters, .meters)
        case .distanceWithTime(let meters, let seconds):
            return .poolSwimDistanceWithTime(
                Measurement(value: meters, unit: UnitLength.meters),
                Measurement(value: seconds, unit: UnitDuration.seconds))
        }
    }

    /// Explicit ranges only. Speed is metres per second, power watts, heart rate beats per minute.
    public static func alert(from alert: CompiledAlert) -> (any WorkoutAlert)? {
        switch alert {
        case .none:
            return nil
        case .speedRange(let range), .powerRange(let range), .heartRateRange(let range):
            // A non finite bound is dropped. A reversed range (possible from a hand edited or decoded value) is put
            // in order, because a reversed closed range traps.
            guard range.lower.isFinite, range.upper.isFinite else { return nil }
            return makeRangeAlert(alert, ValueRange(min(range.lower, range.upper), max(range.lower, range.upper)))
        }
    }

    private static func makeRangeAlert(_ alert: CompiledAlert, _ range: ValueRange) -> (any WorkoutAlert)? {
        switch alert {
        case .none:
            return nil
        case .speedRange:
            let target = Measurement(value: range.lower, unit: UnitSpeed.metersPerSecond)
                ... Measurement(value: range.upper, unit: UnitSpeed.metersPerSecond)
            return SpeedRangeAlert(target: target, metric: .current)
        case .powerRange:
            let target = Measurement(value: range.lower, unit: UnitPower.watts)
                ... Measurement(value: range.upper, unit: UnitPower.watts)
            return PowerRangeAlert(target: target)
        case .heartRateRange:
            let target = Measurement(value: range.lower, unit: WorkoutAlertMetric.countPerMinute)
                ... Measurement(value: range.upper, unit: WorkoutAlertMetric.countPerMinute)
            return HeartRateRangeAlert(target: target)
        }
    }

    // MARK: - Mapping tables

    public static func activityType(_ sport: Sport) -> HKWorkoutActivityType {
        switch sport {
        case .swim: return .swimming
        case .bike: return .cycling
        case .run: return .running
        }
    }

    /// A pool counts as an indoor session location; the pool itself is expressed through the swimming location.
    public static func sessionLocation(_ location: CompiledLocation) -> HKWorkoutSessionLocationType {
        switch location {
        case .pool, .indoor: return .indoor
        case .outdoor: return .outdoor
        case .unspecified: return .unknown
        }
    }

    /// Race swims are open water, which the compiler writes as `.outdoor`.
    public static func swimmingLocation(_ location: CompiledLocation) -> HKWorkoutSwimmingLocationType {
        switch location {
        case .pool, .indoor: return .pool
        case .outdoor: return .openWater
        case .unspecified: return .unknown
        }
    }

    public static func purpose(for kind: StepKind) -> IntervalStep.Purpose {
        switch kind {
        case .work: return .work
        case .recovery, .warmUp, .coolDown: return .recovery
        }
    }
}
#endif
