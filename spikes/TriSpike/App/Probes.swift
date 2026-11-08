import Foundation
import HealthKit
import WorkoutKit

/// Spikes 1 to 5 from tri-spec section 11. Every probe records what it saw; none of them traps.
@MainActor
enum Probes {
    static var log: SpikeLog { SpikeLog.shared }

    // MARK: Capability matrix (runs anywhere, including the simulator)

    static func capabilityMatrix() {
        let s = "capability"
        let activities: [(String, HKWorkoutActivityType)] = [
            ("running", .running), ("cycling", .cycling), ("swimming", .swimming),
            ("swimBikeRun", .swimBikeRun), ("walking", .walking),
        ]
        for (name, a) in activities {
            log.record(s, "CustomWorkout.supportsActivity(\(name))", "\(CustomWorkout.supportsActivity(a))")
            log.record(s, "SingleGoalWorkout.supportsActivity(\(name))", "\(SingleGoalWorkout.supportsActivity(a))")
        }

        let locations: [(String, HKWorkoutSessionLocationType)] = [("indoor", .indoor), ("outdoor", .outdoor), ("unknown", .unknown)]
        let goals: [(String, WorkoutGoal)] = [
            ("time", .time(10, .minutes)),
            ("distance", .distance(1, .kilometers)),
            ("energy", .energy(100, .kilocalories)),
            ("poolSwimDistanceWithTime", .poolSwimDistanceWithTime(Measurement(value: 100, unit: .meters), Measurement(value: 2, unit: .minutes))),
        ]
        for (an, a) in [("running", HKWorkoutActivityType.running), ("cycling", .cycling), ("swimming", .swimming)] {
            for (ln, l) in locations {
                for (gn, g) in goals {
                    let custom = CustomWorkout.supportsGoal(g, activity: a, location: l)
                    let single = SingleGoalWorkout.supportsGoal(g, activity: a, location: l)
                    log.record(s, "goal \(gn) \(an) \(ln)", "custom=\(custom) single=\(single)")
                }
            }
        }

        let alerts: [(String, any WorkoutAlert)] = [
            ("speedRange", SpeedRangeAlert.speed(3.0...4.0, unit: .metersPerSecond)),
            ("speedThreshold", SpeedThresholdAlert.speed(3.5, unit: .metersPerSecond)),
            ("powerRange current", PowerRangeAlert.power(200...240, unit: .watts)),
            ("powerRange average", PowerRangeAlert.power(200...240, unit: .watts, metric: .average)),
            ("powerZone", PowerZoneAlert.power(zone: 3)),
            ("heartRateRange", HeartRateRangeAlert.heartRate(140...155)),
            ("heartRateZone", HeartRateZoneAlert.heartRate(zone: 3)),
            ("cadenceRange", CadenceRangeAlert.cadence(85...95)),
        ]
        for (an, a) in [("running", HKWorkoutActivityType.running), ("cycling", .cycling), ("swimming", .swimming)] {
            for (ln, l) in locations {
                for (alertName, alert) in alerts {
                    log.record(s, "alert \(alertName) \(an) \(ln)", "\(CustomWorkout.supportsAlert(alert, activity: a, location: l))")
                }
            }
        }

        let orderings: [(String, [SwimBikeRunWorkout.Activity])] = [
            ("open water, outdoor, outdoor", SampleSessions.raceLegs),
            ("pool, indoor, indoor", [.swimming(.pool), .cycling(.indoor), .running(.indoor)]),
            ("duathlon run, bike, run", [.running(.outdoor), .cycling(.outdoor), .running(.outdoor)]),
            ("aquathlon swim, run", [.swimming(.openWater), .running(.outdoor)]),
            ("single leg", [.running(.outdoor)]),
        ]
        for (n, o) in orderings {
            log.record(s, "SwimBikeRun.supportsActivityOrdering(\(n))", "\(SwimBikeRunWorkout.supportsActivityOrdering(o))")
        }
    }

    // MARK: Composition (runs anywhere): every production shape builds and round trips

    static func composition() {
        let s = "composition"
        for (label, plan) in SampleSessions.allPlans() {
            do {
                let data = try plan.dataRepresentation
                let decoded = try WorkoutPlan(from: data)
                log.record(s, "round trip \(label)", "\(data.count) bytes, equal=\(decoded == plan)", pass: decoded == plan)
            } catch {
                log.record(s, "round trip \(label)", "encode or decode error: \(error)", pass: false)
            }
        }
        let run = SampleSessions.thresholdRun()
        let names = ([run.warmup] + run.blocks.flatMap { $0.steps.map(\.step) } + [run.cooldown]).compactMap { $0?.displayName }
        log.record(s, "step display names survive", names.joined(separator: ", "), pass: names.count == 4)
        let band = Pace.thresholdBand(thresholdSecondsPerKm: 270)
        let range = Pace.speedRange(fasterSecondsPerKm: band.faster, slowerSecondsPerKm: band.slower)
        log.record(s, "threshold 4:30/km band to speed", String(format: "%.0f to %.0f s/km = %.3f to %.3f m/s", band.faster, band.slower, range.lowerBound, range.upperBound), pass: range.lowerBound < range.upperBound)
    }

    // MARK: Spike 1: WorkoutScheduler (needs a paired watch for the real answer)

    static func schedulerStatus() async {
        let s = "scheduler"
        let probe = WatchProbe()
        let w = await probe.read()
        log.record("watch", "WCSession isPaired", "\(w.paired)", pass: w.paired)
        log.record("watch", "WCSession isWatchAppInstalled", "\(w.appInstalled)")
        log.record("watch", "WCSession detail", w.detail)
        log.record(s, "isSupported", "\(WorkoutScheduler.isSupported)")
        log.record(s, "maxAllowedScheduledWorkoutCount", "\(WorkoutScheduler.maxAllowedScheduledWorkoutCount)")
        let state = await WorkoutScheduler.shared.authorizationState
        log.record(s, "authorizationState", "\(state)")
    }

    static func schedulerFullRun() async {
        let s = "scheduler"
        let scheduler = WorkoutScheduler.shared
        guard WorkoutScheduler.isSupported else {
            log.record(s, "full run", "WorkoutScheduler.isSupported is false: needs an iPhone with a paired Apple Watch", pass: false)
            return
        }
        let auth = await scheduler.requestAuthorization()
        log.record(s, "requestAuthorization", "\(auth)", pass: auth == .authorized)
        guard auth == .authorized else { return }

        await scheduler.removeAllWorkouts()
        let cal = Calendar.current
        func components(daysAhead: Int, hour: Int = 7) -> DateComponents {
            let day = cal.date(byAdding: .day, value: daysAhead, to: Date())!
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = hour
            return c
        }

        // A normal Sunday Sync week: one session per day for the next 7 days.
        let plans = SampleSessions.allPlans()
        for day in 0..<7 {
            let (label, plan) = plans[day % plans.count]
            await scheduler.schedule(plan, at: components(daysAhead: day))
            log.record(s, "scheduled day +\(day)", label)
        }
        // Horizon probes past the 7 day window the Watch displays.
        for day in [8, 14, 30] {
            await scheduler.schedule(WorkoutPlan(.custom(SampleSessions.thresholdRun())), at: components(daysAhead: day))
        }
        let after = await scheduler.scheduledWorkouts
        log.record(s, "scheduledWorkouts after week plus horizon", "\(after.count) of 10 requested")
        for day in [8, 14, 30] {
            let target = components(daysAhead: day)
            let kept = after.contains { $0.date.year == target.year && $0.date.month == target.month && $0.date.day == target.day }
            log.record(s, "horizon +\(day) days kept", "\(kept)")
        }

        // Count limit: keep scheduling until the count stops growing.
        await scheduler.removeAllWorkouts()
        var accepted = 0
        let limit = WorkoutScheduler.maxAllowedScheduledWorkoutCount
        for i in 0..<(limit + 5) {
            await scheduler.schedule(WorkoutPlan(.custom(SampleSessions.thresholdRun())), at: components(daysAhead: i % 7, hour: 5 + (i / 7) % 15))
            let n = await scheduler.scheduledWorkouts.count
            if n == accepted { break }
            accepted = n
        }
        log.record(s, "count limit observed", "\(accepted) accepted, documented max \(limit)", pass: accepted <= limit)
        await scheduler.removeAllWorkouts()

        // Leave the real test week on the watch for the on device checks.
        for day in 0..<7 {
            await scheduler.schedule(plans[day % plans.count].plan, at: components(daysAhead: day))
        }
        let final = await scheduler.scheduledWorkouts.count
        log.record(s, "test week left on watch", "\(final) workouts; open the Workout app on the watch and check each one", pass: final > 0)
    }

    // MARK: Spike 5: HealthKit read back, including HKWorkout.workoutPlan

    static func healthReadBack() async {
        let s = "health"
        guard HKHealthStore.isHealthDataAvailable() else {
            log.record(s, "isHealthDataAvailable", "false", pass: false)
            return
        }
        let store = HKHealthStore()
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate), HKQuantityType(.distanceSwimming), HKQuantityType(.swimmingStrokeCount),
            HKQuantityType(.cyclingPower), HKQuantityType(.distanceCycling), HKQuantityType(.distanceWalkingRunning),
            HKSeriesType.workoutRoute(),
        ]
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: read)
            log.record(s, "requestAuthorization", "completed (read status is never reported, by design)")
        } catch {
            log.record(s, "requestAuthorization", "error \(error)", pass: false)
            return
        }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout()],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 20)
        do {
            let workouts = try await descriptor.result(for: store)
            log.record(s, "recent workouts", "\(workouts.count)")
            for w in workouts {
                let legs = w.workoutActivities.map { "\($0.workoutConfiguration.activityType.rawValue)" }.joined(separator: ",")
                var planNote = "no plan"
                do {
                    if let plan = try await w.workoutPlan {
                        planNote = "plan id \(plan.id.uuidString.prefix(8))"
                    }
                } catch {
                    planNote = "workoutPlan error \(error)"
                }
                let source = w.sourceRevision.source.name
                log.record(s, "workout \(w.workoutActivityType.rawValue) \(w.startDate.formatted(date: .abbreviated, time: .shortened))",
                           "source \(source), legs [\(legs)], \(Int(w.duration / 60)) min, \(planNote)")
            }
        } catch {
            log.record(s, "workout query", "error \(error)", pass: false)
        }
    }
}
