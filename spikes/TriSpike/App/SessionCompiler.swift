import Foundation
import HealthKit
import WorkoutKit

/// Mirrors spec annex E: each planned session compiles to a WorkoutKit plan.
/// The sample sessions are the exact shapes the real app will send, so the spikes test production shapes.
enum Pace {
    /// Seconds per km to metres per second. Speed range alerts are the only way WorkoutKit expresses pace.
    static func speed(secondsPerKm: Double) -> Double { 1000.0 / secondsPerKm }

    /// A pace band (slower bound first, as athletes say it) to a speed range (lower bound first, as WorkoutKit wants).
    static func speedRange(fasterSecondsPerKm: Double, slowerSecondsPerKm: Double) -> ClosedRange<Double> {
        speed(secondsPerKm: slowerSecondsPerKm)...speed(secondsPerKm: fasterSecondsPerKm)
    }

    /// Annex A threshold band: plus or minus 3 percent, floored at plus or minus 10 s per km.
    static func thresholdBand(thresholdSecondsPerKm t: Double) -> (faster: Double, slower: Double) {
        let delta = max(t * 0.03, 10)
        return (t - delta, t + delta)
    }
}

enum SampleSessions {
    /// Run: 2 x 15 min at threshold, pace as a speed range alert. Threshold pace 4:30 per km.
    static func thresholdRun() -> CustomWorkout {
        let band = Pace.thresholdBand(thresholdSecondsPerKm: 270)
        let range = Pace.speedRange(fasterSecondsPerKm: band.faster, slowerSecondsPerKm: band.slower)
        let work = IntervalStep(.work, step: WorkoutStep(
            goal: .time(15, .minutes),
            alert: .speed(range, unit: .metersPerSecond, metric: .current),
            displayName: "Threshold"))
        let recover = IntervalStep(.recovery, step: WorkoutStep(goal: .time(3, .minutes), displayName: "Jog"))
        return CustomWorkout(
            activity: .running, location: .outdoor, displayName: "Threshold run 2x15",
            warmup: WorkoutStep(goal: .time(10, .minutes), displayName: "Easy warm up"),
            blocks: [IntervalBlock(steps: [work, recover], iterations: 2)],
            cooldown: WorkoutStep(goal: .time(10, .minutes), displayName: "Easy cool down"))
    }

    /// Bike: 3 x 10 min sweet spot on power (FTP 250 W), with an average power metric variant.
    static func sweetSpotBike(location: HKWorkoutSessionLocationType = .indoor) -> CustomWorkout {
        let work = IntervalStep(.work, step: WorkoutStep(
            goal: .time(10, .minutes),
            alert: .power(220...235, unit: .watts, metric: .average),
            displayName: "Sweet spot"))
        let recover = IntervalStep(.recovery, step: WorkoutStep(goal: .time(5, .minutes), displayName: "Spin easy"))
        return CustomWorkout(
            activity: .cycling, location: location, displayName: "Sweet spot 3x10",
            warmup: WorkoutStep(goal: .time(10, .minutes), displayName: "Warm up"),
            blocks: [IntervalBlock(steps: [work, recover], iterations: 3)],
            cooldown: WorkoutStep(goal: .time(10, .minutes), displayName: "Cool down"))
    }

    /// Bike with no power meter: the same session on heart rate zone alerts.
    static func heartRateBike() -> CustomWorkout {
        let work = IntervalStep(.work, step: WorkoutStep(
            goal: .time(10, .minutes), alert: .heartRate(zone: 3), displayName: "Zone 3"))
        let recover = IntervalStep(.recovery, step: WorkoutStep(goal: .time(5, .minutes), displayName: "Easy"))
        return CustomWorkout(
            activity: .cycling, location: .outdoor, displayName: "Tempo 3x10 HR",
            blocks: [IntervalBlock(steps: [work, recover], iterations: 3)])
    }

    /// Pool swim, watchOS 11 path: 8 x 100 m on 2:00 with the distance with time goal.
    static func poolSwimSets() -> CustomWorkout {
        let rep = IntervalStep(.work, step: WorkoutStep(
            goal: .poolSwimDistanceWithTime(
                Measurement(value: 100, unit: .meters), Measurement(value: 2, unit: .minutes)),
            displayName: "100 on 2:00"))
        return CustomWorkout(
            activity: .swimming, location: .indoor, displayName: "CSS 8x100",
            warmup: WorkoutStep(goal: .distance(300, .meters), displayName: "Easy 300"),
            blocks: [IntervalBlock(steps: [rep], iterations: 8)],
            cooldown: WorkoutStep(goal: .distance(200, .meters), displayName: "Easy 200"))
    }

    /// Pool swim, older watch tier (annex E tier 2): a goal only distance swim.
    static func goalOnlyPoolSwim() -> SingleGoalWorkout {
        SingleGoalWorkout(activity: .swimming, location: .indoor, swimmingLocation: .pool, goal: .distance(1500, .meters))
    }

    /// Race day: an open goal multisport workout. Ordered legs only; the API has no per leg goals.
    static let raceLegs: [SwimBikeRunWorkout.Activity] = [.swimming(.openWater), .cycling(.outdoor), .running(.outdoor)]

    static func raceDay() -> SwimBikeRunWorkout {
        SwimBikeRunWorkout(activities: raceLegs, displayName: "Race day: Olympic")
    }

    /// A brick is two consecutive custom workouts (spec research: no structured multisport intervals).
    static func brick() -> [CustomWorkout] {
        let runOff = CustomWorkout(
            activity: .running, location: .outdoor, displayName: "Brick: run off the bike",
            blocks: [IntervalBlock(steps: [IntervalStep(.work, step: WorkoutStep(goal: .time(15, .minutes), displayName: "Run off the bike"))])])
        return [sweetSpotBike(location: .outdoor), runOff]
    }

    /// Every sample as a plan, with a stable label, for scheduling and round trip checks.
    static func allPlans() -> [(label: String, plan: WorkoutPlan)] {
        var plans: [(String, WorkoutPlan)] = [
            ("threshold run", WorkoutPlan(.custom(thresholdRun()))),
            ("sweet spot bike", WorkoutPlan(.custom(sweetSpotBike()))),
            ("HR bike", WorkoutPlan(.custom(heartRateBike()))),
            ("pool swim sets", WorkoutPlan(.custom(poolSwimSets()))),
            ("goal only pool swim", WorkoutPlan(.goal(goalOnlyPoolSwim()))),
            ("race day multisport", WorkoutPlan(.swimBikeRun(raceDay()))),
        ]
        for (i, w) in brick().enumerated() {
            plans.append(("brick part \(i + 1)", WorkoutPlan(.custom(w))))
        }
        return plans
    }
}
