import Foundation

/// Conservative pacing numbers for the race pacing card (annex F "Pacing card").
///
/// PLACEHOLDERS FOR THE COACH REVIEWER. Annex F says the exact bands are fixed with the coach reviewer, so
/// every number in this enum is a conservative starting value, kept in one place so it can be retuned without
/// touching logic. Each band is deliberately below what a fit athlete could hold, so the card never invites a
/// pace that blows up the run.
public enum RacePacingPlaceholders {
    /// Swim race effort as seconds per 100 m slower than CSS.
    public static func swimCSSOffset(_ distance: RaceDistance) -> ValueRange {
        switch distance {
        case .sprint: return ValueRange(0, 3)
        case .olympic: return ValueRange(2, 5)
        case .half: return ValueRange(3, 7)
        }
    }

    /// Bike race effort as a fraction of FTP.
    public static func bikeFTPFraction(_ distance: RaceDistance) -> ValueRange {
        switch distance {
        case .sprint: return ValueRange(0.85, 0.95)
        case .olympic: return ValueRange(0.78, 0.88)
        case .half: return ValueRange(0.68, 0.78)
        }
    }

    /// Bike race effort as a fraction of bike LTHR, used when there is no FTP.
    public static func bikeLTHRFraction(_ distance: RaceDistance) -> ValueRange {
        switch distance {
        case .sprint: return ValueRange(0.94, 1.00)
        case .olympic: return ValueRange(0.89, 0.97)
        case .half: return ValueRange(0.85, 0.92)
        }
    }

    /// Run race effort as seconds per km slower than threshold pace (the run follows a bike, so it is
    /// conservative).
    public static func runThresholdOffset(_ distance: RaceDistance) -> ValueRange {
        switch distance {
        case .sprint: return ValueRange(5, 15)
        case .olympic: return ValueRange(10, 25)
        case .half: return ValueRange(25, 45)
        }
    }

    /// The training intensity level (1 to 5, see `IntensityLevel`) that matches the race effort of a leg. The
    /// openers and the steady blocks of the template read this one table, so training and race bands cannot
    /// drift apart. Bike: the race band is 85 to 95 percent of FTP for a Sprint (level 4 reaches it), 78 to 88
    /// for an Olympic (level 3) and 68 to 78 for a 70.3 (level 3 is the nearest zone, a touch above). Run: Sprint
    /// level 4, Olympic and 70.3 level 3 (the steady run zone).
    public static func trainingLevel(forRaceEffort sport: Sport, distance: RaceDistance) -> Int {
        switch (sport, distance) {
        case (.bike, .sprint), (.run, .sprint), (.swim, .sprint): return 4
        case (.bike, _), (.run, _), (.swim, _): return 3
        }
    }

    /// True when the training level for the race effort sits above the race band, so training copy says
    /// "a touch above race effort" instead of "at race effort".
    public static func trainingLevelRunsAboveRace(sport: Sport, distance: RaceDistance) -> Bool {
        sport == .bike && distance == .half
    }

    /// Feel based range on the 1 to 10 scale, used for a leg whose benchmark is missing.
    public static func rpe(_ distance: RaceDistance) -> ValueRange {
        switch distance {
        case .sprint: return ValueRange(7, 8)
        case .olympic: return ValueRange(6, 7)
        case .half: return ValueRange(5, 6)
        }
    }

    /// Swim pace in seconds per 100 m used to predict a leg duration when no CSS exists.
    public static func defaultSwimPacePer100m(_ level: Level) -> ValueRange {
        switch level {
        case .firstTimer: return ValueRange(135, 160)
        case .intermediate: return ValueRange(110, 130)
        case .experienced: return ValueRange(92, 108)
        }
    }

    /// Bike speed in km/h used to predict a bike leg duration when the athlete has not entered one. Power alone
    /// cannot give speed without mass and course data, so the prediction uses this band by level and the card
    /// marks the duration `typicalForLevel`.
    public static func defaultBikeSpeedKph(_ level: Level) -> ValueRange {
        switch level {
        case .firstTimer: return ValueRange(20, 25)
        case .intermediate: return ValueRange(25, 30)
        case .experienced: return ValueRange(30, 35)
        }
    }

    /// Course speed bounds for an athlete entered bike speed, in km/h.
    static let bikeSpeedBounds = 10.0...60.0

    /// Run pace in seconds per km used to predict a run leg duration when no threshold pace exists.
    public static func defaultRunPacePerKm(_ level: Level) -> ValueRange {
        switch level {
        case .firstTimer: return ValueRange(420, 480)
        case .intermediate: return ValueRange(345, 390)
        case .experienced: return ValueRange(285, 330)
        }
    }

    /// Plausible benchmark bounds. A value outside them reads as missing so a typo can never produce a
    /// nonsense card.
    static let cssBounds = ZoneConstants.cssBounds
    static let ftpBounds = ZoneConstants.ftpBounds
    static let lthrBounds = ZoneConstants.lthrBounds
    static let thresholdPaceBounds = ZoneConstants.thresholdPaceBounds
}

extension DefaultRaceWindow {
    /// Annex F "Pacing card": per leg target ranges from the athlete's own benchmarks, always ranges, with a
    /// feel based fallback when a benchmark is missing, and the distance scaled caveat.
    public func pacing(for distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks) -> PacingCard {
        pacing(for: distance, athlete: athlete, benchmarks: benchmarks, bikeSpeedKph: nil)
    }

    /// Same card with an optional bike speed the athlete expects to hold on the course, in km/h. Power alone cannot
    /// give a bike leg time (it needs mass and course data), so without a speed the bike duration is marked
    /// `typicalForLevel` and is never presented as the athlete's plan.
    public func pacing(
        for distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks, bikeSpeedKph: Double?
    ) -> PacingCard {
        let targets = distance.legs.map { leg -> PacingTarget in
            switch leg.sport {
            case .swim: return swimTarget(leg, distance: distance, athlete: athlete, benchmarks: benchmarks)
            case .bike:
                return bikeTarget(leg, distance: distance, athlete: athlete, benchmarks: benchmarks, speedKph: bikeSpeedKph)
            case .run: return runTarget(leg, distance: distance, athlete: athlete, benchmarks: benchmarks)
            }
        }
        return PacingCard(distance: distance, targets: targets, caveat: RaceWindowCopy.caveat(for: distance))
    }

    // MARK: Legs

    private func usable(_ value: BenchmarkValue?, in bounds: ClosedRange<Double>) -> BenchmarkValue? {
        guard let value, value.value.isFinite, bounds.contains(value.value) else { return nil }
        return value
    }

    private func estimatedNote(_ value: BenchmarkValue) -> String {
        value.isEstimated ? " This benchmark is an estimate, so a test would sharpen it." : ""
    }

    private func swimTarget(_ leg: RaceLeg, distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks) -> PacingTarget {
        let units = leg.distanceKm * 10 // number of 100 m blocks
        if let css = usable(benchmarks.cssSecondsPer100m, in: RacePacingPlaceholders.cssBounds) {
            let offset = RacePacingPlaceholders.swimCSSOffset(distance)
            let pace = ValueRange(css.value + offset.lower, css.value + offset.upper)
            let duration = ValueRange(units * pace.lower, units * pace.upper)
            let summary = "CSS plus \(RaceFormat.safeInt(offset.lower)) to \(RaceFormat.safeInt(offset.upper)) s per 100 m, about \(RaceFormat.duration(pace.lower)) to \(RaceFormat.duration(pace.upper)) per 100 m.\(estimatedNote(css))"
            return PacingTarget(
                leg: leg, target: .cssOffset(offset), expectedDurationSeconds: duration, summary: summary,
                durationBasis: .fromBenchmark)
        }
        let pace = RacePacingPlaceholders.defaultSwimPacePer100m(athlete.level)
        return PacingTarget(
            leg: leg,
            target: .rpe(RacePacingPlaceholders.rpe(distance)),
            expectedDurationSeconds: ValueRange(units * pace.lower, units * pace.upper),
            summary: rpeSummary(distance, hint: "No swim test yet, so the effort is by feel. A swim test would turn this into a pace range."),
            durationBasis: .typicalForLevel)
    }

    private func bikeTarget(
        _ leg: RaceLeg, distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks, speedKph: Double?
    ) -> PacingTarget {
        let basis: DurationBasis
        let speed: ValueRange
        if let entered = speedKph, entered.isFinite, RacePacingPlaceholders.bikeSpeedBounds.contains(entered) {
            // Five percent either side of the speed the athlete entered.
            speed = ValueRange(entered * 0.95, entered * 1.05)
            basis = .athleteEntered
        } else {
            speed = RacePacingPlaceholders.defaultBikeSpeedKph(athlete.level)
            basis = .typicalForLevel
        }
        let duration = ValueRange(leg.distanceKm / speed.upper * 3600, leg.distanceKm / speed.lower * 3600)

        if let ftp = usable(benchmarks.ftpWatts, in: RacePacingPlaceholders.ftpBounds) {
            let band = RacePacingPlaceholders.bikeFTPFraction(distance)
            let watts = ValueRange(ftp.value * band.lower, ftp.value * band.upper)
            let summary = "\(RaceFormat.safeInt(band.lower * 100)) to \(RaceFormat.safeInt(band.upper * 100)) percent of FTP, \(RaceFormat.safeInt(watts.lower)) to \(RaceFormat.safeInt(watts.upper)) W.\(estimatedNote(ftp))"
            return PacingTarget(
                leg: leg, target: .powerRange(watts), expectedDurationSeconds: duration, summary: summary,
                durationBasis: basis)
        }
        if let lthr = usable(benchmarks.lthrBpm, in: RacePacingPlaceholders.lthrBounds) {
            let band = RacePacingPlaceholders.bikeLTHRFraction(distance)
            let bpm = ValueRange(lthr.value * band.lower, lthr.value * band.upper)
            let summary = "\(RaceFormat.safeInt(band.lower * 100)) to \(RaceFormat.safeInt(band.upper * 100)) percent of bike LTHR, \(RaceFormat.safeInt(bpm.lower)) to \(RaceFormat.safeInt(bpm.upper)) bpm.\(estimatedNote(lthr))"
            return PacingTarget(
                leg: leg, target: .heartRateRange(bpm), expectedDurationSeconds: duration, summary: summary,
                durationBasis: basis)
        }
        return PacingTarget(
            leg: leg,
            target: .rpe(RacePacingPlaceholders.rpe(distance)),
            expectedDurationSeconds: duration,
            summary: rpeSummary(distance, hint: "No bike benchmark yet, so the effort is by feel. A bike test would turn this into a range."),
            durationBasis: basis)
    }

    private func runTarget(_ leg: RaceLeg, distance: RaceDistance, athlete: AthleteProfile, benchmarks: Benchmarks) -> PacingTarget {
        if let threshold = usable(benchmarks.thresholdPaceSecondsPerKm, in: RacePacingPlaceholders.thresholdPaceBounds) {
            let offset = RacePacingPlaceholders.runThresholdOffset(distance)
            let pace = ValueRange(threshold.value + offset.lower, threshold.value + offset.upper)
            let duration = ValueRange(leg.distanceKm * pace.lower, leg.distanceKm * pace.upper)
            let summary = "Threshold pace plus \(RaceFormat.safeInt(offset.lower)) to \(RaceFormat.safeInt(offset.upper)) s per km, about \(RaceFormat.duration(pace.lower)) to \(RaceFormat.duration(pace.upper)) per km.\(estimatedNote(threshold))"
            return PacingTarget(
                leg: leg, target: .pacePerKm(pace), expectedDurationSeconds: duration, summary: summary,
                durationBasis: .fromBenchmark)
        }
        let pace = RacePacingPlaceholders.defaultRunPacePerKm(athlete.level)
        return PacingTarget(
            leg: leg,
            target: .rpe(RacePacingPlaceholders.rpe(distance)),
            expectedDurationSeconds: ValueRange(leg.distanceKm * pace.lower, leg.distanceKm * pace.upper),
            summary: rpeSummary(distance, hint: "No run test yet, so the effort is by feel. A run test would turn this into a pace range."),
            durationBasis: .typicalForLevel)
    }

    private func rpeSummary(_ distance: RaceDistance, hint: String) -> String {
        let rpe = RacePacingPlaceholders.rpe(distance)
        return "Effort \(RaceFormat.safeInt(rpe.lower)) to \(RaceFormat.safeInt(rpe.upper)) out of 10. \(hint)"
    }
}
