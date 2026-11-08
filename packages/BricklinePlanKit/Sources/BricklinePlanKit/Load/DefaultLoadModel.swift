import Foundation

/// The Load model of annex D. Concrete `LoadModel`. Pure and deterministic: no clock, no randomness.
///
/// Session Load comes from the best data available, in this order:
/// 1. Power (bike only, needs FTP): (adjusted power / FTP) squared times hours times 100.
/// 2. Time in the five LTHR zones times the per zone hourly factors in `LoadConstants`.
/// 3. Average heart rate against LTHR, mapped to one zone for the whole duration (Estimated).
/// 4. A planned level, then a feel rating, each mapped to a zone factor (Estimated).
/// 5. A swim with nothing else counts as an easy swim (Estimated); any other sport scores zero (Estimated).
public struct DefaultLoadModel: LoadModel {
    public init() {}

    // MARK: Completed workouts

    /// Annex D session Load. See the type documentation for the order of data sources.
    public func load(for workout: CompletedWorkout, benchmarks: Benchmarks) -> SessionLoad {
        load(for: workout, benchmarks: benchmarks, plannedLevel: nil)
    }

    /// Same as `load(for:benchmarks:)` with an optional planned level (1 to 5) used when the workout has no
    /// measured intensity. Annex D "Swim load": duration times the planned zone's factor, labelled Estimated.
    public func load(for workout: CompletedWorkout, benchmarks: Benchmarks, plannedLevel: Int?) -> SessionLoad {
        let seconds = workout.durationSeconds
        let hours = (seconds.isFinite && seconds > 0) ? seconds / 3600 : 0

        // 1. Power path (annex D "With power").
        if workout.sport == .bike,
           let ftp = benchmarks.ftpWatts, ftp.value.isFinite, ftp.value > 0 {
            let adjusted = workout.adjustedPower.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            let average = workout.averagePower.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            if let power = adjusted ?? average {
                let intensity = power / ftp.value
                // Average power stands in for adjusted power on a variable ride and understates it, so the
                // result is flagged Estimated when adjusted power is missing.
                let substituted = adjusted == nil
                return SessionLoad(load: intensity * intensity * hours * 100, isEstimated: ftp.isEstimated || substituted)
            }
        }

        // 2. Time in LTHR zones (annex D "Without power").
        if let zones = workout.secondsInHeartRateZones, zones.count == LoadConstants.heartRateZoneFactorsPerHour.count,
           zones.allSatisfy({ $0.isFinite && $0 >= 0 }), zones.reduce(0, +) > 0 {
            var total = 0.0
            for (index, zoneSeconds) in zones.enumerated() {
                total += zoneSeconds / 3600 * LoadConstants.heartRateZoneFactorsPerHour[index]
            }
            return SessionLoad(load: total, isEstimated: false)
        }

        // 3. Average heart rate against the sport's LTHR.
        if let average = workout.averageHeartRate, average.isFinite, average > 0,
           let lthr = lthrBenchmark(for: workout.sport, in: benchmarks), lthr.value.isFinite, lthr.value > 0 {
            let level = LoadConstants.heartRateLevel(fractionOfLTHR: average / lthr.value)
            return SessionLoad(load: hours * LoadConstants.heartRateFactor(level: level), isEstimated: true)
        }

        // 4. Planned level, then feel rating.
        if let level = plannedLevel {
            return SessionLoad(load: hours * LoadConstants.heartRateFactor(level: level), isEstimated: true)
        }
        if let rpe = workout.rpe {
            return SessionLoad(load: hours * LoadConstants.heartRateFactor(level: LoadConstants.level(forRPE: rpe)), isEstimated: true)
        }

        // 5. Swim default, otherwise no usable data.
        if workout.sport == .swim {
            return SessionLoad(load: hours * LoadConstants.heartRateFactor(level: LoadConstants.defaultSwimLevel), isEstimated: true)
        }
        return SessionLoad(load: 0, isEstimated: true)
    }

    private func lthrBenchmark(for sport: Sport, in benchmarks: Benchmarks) -> BenchmarkValue? {
        switch sport {
        case .bike: return benchmarks.lthrBpm
        case .run: return benchmarks.runLthrBpm
        case .swim: return nil
        }
    }

    // MARK: Planned sessions

    /// Planned Load of a session (annex D, used by annex C rule 5). Each step contributes its hours (repeats
    /// expanded) times an intensity from its level: on the power path, for bike steps when FTP exists, the square
    /// of the zone midpoint fraction times 100; otherwise the heart rate zone factor. Estimated when the session
    /// holds a swim step (swim has no benchmark path) or when it leans on an estimated FTP.
    public func plannedLoad(for session: Session, benchmarks: Benchmarks) -> SessionLoad {
        var total = 0.0
        var estimated = false
        let ftp = benchmarks.ftpWatts.flatMap { $0.value.isFinite && $0.value > 0 ? $0 : nil }
        for step in session.steps {
            let seconds = step.durationSeconds * Double(step.repeats)
            guard seconds.isFinite, seconds > 0 else { continue }
            let hours = seconds / 3600
            if step.sport == .bike, let ftp = ftp {
                let fraction = LoadConstants.powerMidpointFraction(level: step.level)
                total += fraction * fraction * 100 * hours
                if ftp.isEstimated { estimated = true }
            } else {
                total += LoadConstants.heartRateFactor(level: step.level) * hours
                if step.sport == .swim { estimated = true }
            }
        }
        return SessionLoad(load: total, isEstimated: estimated)
    }

    /// Sum of planned Load of every session in the week (annex C rule 5).
    public func plannedLoad(for week: PlannedWeek, benchmarks: Benchmarks) -> Double {
        // Fixed day order: floating point sums must not depend on dictionary order (same inputs, same bits).
        week.days.keys.sorted().reduce(0) { dayTotal, key in
            dayTotal + (week.days[key] ?? []).reduce(0) { $0 + plannedLoad(for: $1, benchmarks: benchmarks).load }
        }
    }

    /// A single level 1 to 5 summarising a session: the duration weighted mean level of its steps, rounded.
    /// Handy as the `plannedLevel` of a swim that was logged without heart rate. Level 2 when the session is empty.
    public func representativeLevel(for session: Session) -> Int {
        var weighted = 0.0
        var seconds = 0.0
        for step in session.steps {
            let duration = step.durationSeconds * Double(step.repeats)
            guard duration.isFinite, duration > 0 else { continue }
            weighted += Double(step.level) * duration
            seconds += duration
        }
        guard seconds > 0 else { return LoadConstants.defaultSwimLevel }
        return IntensityLevel.clamped(Int((weighted / seconds).rounded()))
    }

    /// Representative levels keyed by session id, for the `plannedLevels` argument of the daily series builder.
    public func plannedLevels(for sessions: [Session]) -> [String: Int] {
        var result: [String: Int] = [:]
        for session in sessions { result[session.id] = representativeLevel(for: session) }
        return result
    }

    // MARK: Daily series

    /// Daily Load for every day from `from` through `through` inclusive. Days without workouts score zero.
    /// Returns an empty array when `through` is before `from`; spans longer than
    /// `LoadConstants.maximumSeriesDays` are cut short.
    public func dailyLoads(
        workouts: [CompletedWorkout],
        benchmarks: Benchmarks,
        from: Date,
        through: Date,
        calendar: Calendar
    ) -> [LoadSample] {
        dailyLoads(workouts: workouts, benchmarks: benchmarks, plannedLevels: [:], from: from, through: through, calendar: calendar)
    }

    /// Same as the protocol method, with planned levels keyed by `CompletedWorkout.plannedSessionID` for
    /// workouts that carry no measured intensity (see `plannedLevels(for:)`).
    public func dailyLoads(
        workouts: [CompletedWorkout],
        benchmarks: Benchmarks,
        plannedLevels: [String: Int],
        from: Date,
        through: Date,
        calendar: Calendar
    ) -> [LoadSample] {
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: through)
        guard last >= first else { return [] }
        let span = min(calendar.daysBetween(first, last), LoadConstants.maximumSeriesDays - 1)
        guard span >= 0 else { return [] }

        var byDay: [Date: Double] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.start)
            guard day >= first, day <= last else { continue }
            let level = workout.plannedSessionID.flatMap { plannedLevels[$0] }
            let value = load(for: workout, benchmarks: benchmarks, plannedLevel: level).load
            if value.isFinite { byDay[day, default: 0] += value }
        }

        var samples: [LoadSample] = []
        samples.reserveCapacity(span + 1)
        for offset in 0...span {
            let day = calendar.startOfDay(for: calendar.addDays(offset, to: first))
            samples.append(LoadSample(date: day, load: byDay[day] ?? 0))
        }
        return samples
    }

    // MARK: Fitness, Fatigue, Form

    /// Fitness (42 day), Fatigue (7 day) and Form (annex D).
    ///
    /// Both averages are exponentially weighted, seeded at zero, with smoothing factor 1 minus e to the power of
    /// minus one over the time constant. For each emitted day, Fitness and Fatigue include that day's Load, and
    /// Form is yesterday's Fitness minus yesterday's Fatigue, so the first day's Form is zero. Samples are sorted
    /// by day, samples on one day are summed, and missing days between samples count as zero Load days.
    /// Negative or non finite Load counts as zero.
    public func fitnessForm(dailyLoads: [LoadSample], calendar: Calendar) -> [FitnessForm] {
        var byDay: [Date: Double] = [:]
        for sample in dailyLoads {
            let day = calendar.startOfDay(for: sample.date)
            let value = (sample.load.isFinite && sample.load > 0) ? sample.load : 0
            byDay[day, default: 0] += value
        }
        let days = byDay.keys.sorted()

        let fitnessAlpha = LoadConstants.smoothingFactor(timeConstantDays: LoadConstants.fitnessTimeConstantDays)
        let fatigueAlpha = LoadConstants.smoothingFactor(timeConstantDays: LoadConstants.fatigueTimeConstantDays)

        var fitness = 0.0
        var fatigue = 0.0
        var previousDay: Date?
        var result: [FitnessForm] = []
        result.reserveCapacity(days.count)

        for day in days {
            if let previous = previousDay {
                let gap = calendar.daysBetween(previous, day)
                if gap > 1 {
                    // Zero Load days in between: only decay.
                    let skipped = Double(gap - 1)
                    fitness *= pow(1 - fitnessAlpha, skipped)
                    fatigue *= pow(1 - fatigueAlpha, skipped)
                }
            }
            let form = fitness - fatigue
            let load = byDay[day] ?? 0
            fitness += (load - fitness) * fitnessAlpha
            fatigue += (load - fatigue) * fatigueAlpha
            result.append(FitnessForm(date: day, fitness: fitness, fatigue: fatigue, form: form))
            previousDay = day
        }
        return result
    }

    // MARK: Acute to chronic ratio

    /// Average daily Load over the last 7 days divided by the average over the last 28 days, both ending on
    /// `asOf` inclusive (annex C rule 6). Days missing from the series count as zero. Nil when the series starts
    /// later than the first day of the 28 day window or the chronic average is zero.
    public func acuteChronicRatio(dailyLoads: [LoadSample], asOf: Date, calendar: Calendar) -> Double? {
        let end = calendar.startOfDay(for: asOf)
        let chronicStart = calendar.startOfDay(for: calendar.addDays(-(LoadConstants.chronicWindowDays - 1), to: end))
        let acuteStart = calendar.startOfDay(for: calendar.addDays(-(LoadConstants.acuteWindowDays - 1), to: end))

        var byDay: [Date: Double] = [:]
        var earliest: Date?
        for sample in dailyLoads {
            let day = calendar.startOfDay(for: sample.date)
            if earliest == nil || day < (earliest ?? day) { earliest = day }
            let value = (sample.load.isFinite && sample.load > 0) ? sample.load : 0
            byDay[day, default: 0] += value
        }
        guard let start = earliest, start <= chronicStart else { return nil }

        var acuteSum = 0.0
        var chronicSum = 0.0
        for day in byDay.keys.sorted() where day >= chronicStart && day <= end {
            let value = byDay[day] ?? 0
            chronicSum += value
            if day >= acuteStart { acuteSum += value }
        }
        let chronicAverage = chronicSum / Double(LoadConstants.chronicWindowDays)
        guard chronicAverage > 0 else { return nil }
        let acuteAverage = acuteSum / Double(LoadConstants.acuteWindowDays)
        return acuteAverage / chronicAverage
    }
}
