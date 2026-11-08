import Foundation

/// Everything the step builders need to know about the week and the athlete.
struct BuildContext {
    var level: Level
    var phase: Phase
    var distance: RaceDistance
    var runWalk: Bool
    /// CSS in seconds per 100 m, used only to turn swim distances into durations.
    var css: Double
    /// Long sessions may carry steady (level 3) blocks. False in recovery weeks and when the sport has no other
    /// easy session that week.
    var allowSteady: Bool
    /// Length of the transition run attached to a brick, 10 to 20 minutes (annex B "Bricks").
    var brickRunSeconds: Double
}

struct BuiltSession {
    var steps: [Step]
    var brickSecondSport: Sport?
}

/// Turns a session kind and a target duration into structured steps. Targets are RPE (and CSS offsets for swims);
/// concrete paces, watts and heart rates are resolved later by the session compiler (Core contract).
enum StepFactory {
    static func total(_ steps: [Step]) -> Double {
        steps.reduce(0) { $0 + $1.durationSeconds * Double($1.repeats) }
    }

    /// Build the steps for `kind`. `seconds` is the wanted duration of the session; tests ignore it.
    static func build(_ kind: SessionKind, seconds: Double, ctx: BuildContext) -> BuiltSession {
        let d = seconds.isFinite ? max(seconds, 0) : 0
        switch kind {
        case .swimTechnique: return BuiltSession(steps: swimTechnique(d, ctx), brickSecondSport: nil)
        case .swimEndurance: return BuiltSession(steps: swimEndurance(d, ctx), brickSecondSport: nil)
        case .swimThreshold: return BuiltSession(steps: swimThreshold(d, ctx), brickSecondSport: nil)
        case .swimSpeed: return BuiltSession(steps: swimSpeed(d, ctx), brickSecondSport: nil)
        case .swimTest: return BuiltSession(steps: swimTest(ctx), brickSecondSport: nil)
        case .bikeEasy: return BuiltSession(steps: bikeEasy(d), brickSecondSport: nil)
        case .bikeLong: return BuiltSession(steps: bikeLong(d, ctx), brickSecondSport: nil)
        case .bikeBrick:
            return BuiltSession(steps: bikeLong(d, ctx) + transitionRun(ctx), brickSecondSport: .run)
        case .bikeThreshold: return BuiltSession(steps: bikeThreshold(d, ctx), brickSecondSport: nil)
        case .bikeVO2: return BuiltSession(steps: bikeVO2(d, ctx), brickSecondSport: nil)
        case .bikeOpeners: return BuiltSession(steps: bikeOpeners(d, ctx), brickSecondSport: nil)
        case .bikeTestFTP: return BuiltSession(steps: bikeTestFTP(), brickSecondSport: nil)
        case .bikeTestLTHR: return BuiltSession(steps: bikeTestLTHR(), brickSecondSport: nil)
        case .runEasy: return BuiltSession(steps: runSteady(d, long: false, ctx), brickSecondSport: nil)
        case .runLong: return BuiltSession(steps: runSteady(d, long: true, ctx), brickSecondSport: nil)
        case .runThreshold: return BuiltSession(steps: runThreshold(d, ctx), brickSecondSport: nil)
        case .runVO2: return BuiltSession(steps: runVO2(d, ctx), brickSecondSport: nil)
        case .runOpeners: return BuiltSession(steps: runOpeners(d, ctx), brickSecondSport: nil)
        case .runTest: return BuiltSession(steps: runTest(), brickSecondSport: nil)
        }
    }

    // MARK: Step helper

    private static func make(
        _ sport: Sport,
        _ kind: StepKind,
        seconds: Double,
        meters: Double? = nil,
        level: Int,
        name: String,
        group: String? = nil,
        count: Int? = nil,
        rpe: ValueRange? = nil,
        detail: String? = nil
    ) -> Step {
        let target: StepTarget
        if let rpe = rpe {
            target = .rpe(rpe)
        } else if sport == .swim && kind != .recovery {
            target = .cssOffset(Intensity.swimOffset(level))
        } else {
            target = .rpe(Intensity.rpe(level))
        }
        return Step(
            sport: sport,
            kind: kind,
            durationSeconds: seconds.rounded(),
            distanceMeters: meters,
            level: level,
            target: target,
            repeatGroupID: group,
            repeatCount: count,
            name: name,
            note: Intensity.note(level: level, sport: sport, kind: kind, rpe: rpe, detail: detail)
        )
    }

    // MARK: Rep fitting

    /// Chooses a rep count so the main set fits, and trims the work length when the hard share would exceed
    /// `hardShare` of the session (annex B: roughly 80 percent of time is easy and steady).
    private static func fitReps(
        session: Double,
        fixedBefore: Double,
        fixedAfter: Double,
        work: Double,
        rest: Double,
        minReps: Int,
        maxReps: Int,
        hardShare: Double = 0.26
    ) -> (n: Int, work: Double, warm: Double) {
        let available = session - fixedBefore - fixedAfter
        var n = min(max(Intensity.floorInt(available / (work + rest)), minReps), maxReps)
        var w = work
        let cap = hardShare * session
        if Double(n) * w > cap {
            let trimmed = (cap / Double(n) / 30).rounded(.down) * 30
            w = max(120, min(w, trimmed))
        }
        var warm = session - fixedAfter - Double(n) * (w + rest)
        while warm < fixedBefore * 0.7 && n > minReps {
            n -= 1
            warm = session - fixedAfter - Double(n) * (w + rest)
        }
        warm = max(warm, min(fixedBefore, 300))
        return (n, w, warm)
    }

    // MARK: Swim

    private static func swimMeters(_ seconds: Double, _ ctx: BuildContext) -> Double {
        let pace = Intensity.swimPace(css: ctx.css, level: 2)
        let raw = seconds / pace * 100
        let rounded = (raw / 50).rounded() * 50
        return max(rounded.isFinite ? rounded : 600, 600)
    }

    private static func swimStep(
        _ kind: StepKind,
        meters: Double,
        level: Int,
        name: String,
        ctx: BuildContext,
        group: String? = nil,
        count: Int? = nil,
        rpe: ValueRange? = nil,
        detail: String? = nil
    ) -> Step {
        let pace = Intensity.swimPace(css: ctx.css, level: level)
        return make(.swim, kind, seconds: meters / 100 * pace, meters: meters, level: level, name: name,
                    group: group, count: count, rpe: rpe, detail: detail)
    }

    private static func swimRest(_ seconds: Double, group: String, count: Int) -> Step {
        make(.swim, .recovery, seconds: seconds, level: 1, name: "Rest at the wall", group: group, count: count,
             detail: "Breathe and let your heart rate settle.")
    }

    private static func swimEndurance(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let total = swimMeters(d, ctx)
        let repSize: Double
        let rest: Double
        switch ctx.level {
        case .firstTimer: repSize = 100; rest = 20
        case .intermediate: repSize = 200; rest = 15
        case .experienced: repSize = 400; rest = 15
        }
        let cool: Double = total >= 1500 ? 200 : 100
        let warm0 = max(200, (total * 0.15 / 50).rounded() * 50)
        let main = max(total - warm0 - cool, repSize)
        let reps = max(Intensity.floorInt(main / repSize), 1)
        let warm = max(total - cool - Double(reps) * repSize, 100)
        let mainLevel = (ctx.level == .experienced && ctx.allowSteady && (ctx.phase == .build || ctx.phase == .peak)) ? 3 : 2
        return [
            swimStep(.warmUp, meters: warm, level: 2, name: "Easy warm up swim", ctx: ctx),
            swimStep(.work, meters: repSize, level: mainLevel, name: mainLevel == 3 ? "Steady swim" : "Easy aerobic swim",
                     ctx: ctx, group: "g1", count: reps, detail: "Smooth and long, keep the stroke relaxed."),
            swimRest(rest, group: "g1", count: reps),
            swimStep(.coolDown, meters: cool, level: 1, name: "Cool down swim", ctx: ctx)
        ]
    }

    private static func swimTechnique(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let total = swimMeters(d, ctx)
        let drills = 6
        let drillMeters = 50.0
        let cool = 100.0
        let warm0 = 200.0
        let main = max(total - warm0 - Double(drills) * drillMeters - cool, 200)
        let reps = max(Intensity.floorInt(main / 100), 2)
        let warm = max(total - cool - Double(drills) * drillMeters - Double(reps) * 100, 200)
        return [
            swimStep(.warmUp, meters: warm, level: 2, name: "Easy warm up swim", ctx: ctx),
            swimStep(.work, meters: drillMeters, level: 2, name: "Drill lap", ctx: ctx, group: "g1", count: drills,
                     detail: "Pick one focus, such as a long reach or a steady kick."),
            swimRest(15, group: "g1", count: drills),
            swimStep(.work, meters: 100, level: 2, name: "Aerobic 100", ctx: ctx, group: "g2", count: reps,
                     detail: "Put the drill focus into a smooth, easy 100."),
            swimRest(15, group: "g2", count: reps),
            swimStep(.coolDown, meters: cool, level: 1, name: "Cool down swim", ctx: ctx)
        ]
    }

    private static func swimThreshold(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let total = swimMeters(d, ctx)
        let rep: Double = (ctx.level == .firstTimer || ctx.phase == .base) ? 100 : 200
        let rest: Double = rep == 100 ? 15 : 20
        let drills = 4
        let cool = 200.0
        let warm0 = 300.0
        let main = max(total - warm0 - Double(drills) * 50 - cool, rep * 4)
        let mainSets = min(main, total * 0.4)
        let n = min(max(Intensity.floorInt(mainSets / rep), 4), 12)
        let warm = max(total - cool - Double(drills) * 50 - Double(n) * rep, 300)
        return [
            swimStep(.warmUp, meters: warm, level: 2, name: "Easy warm up swim", ctx: ctx),
            swimStep(.work, meters: 50, level: 2, name: "Drill lap", ctx: ctx, group: "g1", count: drills,
                     detail: "Smooth and relaxed, getting ready for the main set."),
            swimRest(15, group: "g1", count: drills),
            swimStep(.work, meters: rep, level: 4, name: "Threshold repeat", ctx: ctx, group: "g2", count: n,
                     detail: "Even pace on every repeat. The last one should match the first."),
            swimRest(rest, group: "g2", count: n),
            swimStep(.coolDown, meters: cool, level: 1, name: "Cool down swim", ctx: ctx)
        ]
    }

    private static func swimSpeed(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let total = swimMeters(d, ctx)
        let cool = 200.0
        let n = min(max(Intensity.floorInt(total * 0.25 / 50), 6), 12)
        let warm = max(total - cool - Double(n) * 50, 300)
        return [
            swimStep(.warmUp, meters: warm, level: 2, name: "Easy warm up swim", ctx: ctx),
            swimStep(.work, meters: 50, level: 5, name: "Fast 50", ctx: ctx, group: "g1", count: n,
                     detail: "Fast and long, not frantic. Keep the stroke clean."),
            swimRest(25, group: "g1", count: n),
            swimStep(.coolDown, meters: cool, level: 1, name: "Cool down swim", ctx: ctx)
        ]
    }

    /// Annex A swim test: warm up, all out 400 m, 5 to 10 minutes active recovery, all out 200 m, cool down.
    private static func swimTest(_ ctx: BuildContext) -> [Step] {
        let hard = ValueRange(9, 10)
        return [
            swimStep(.warmUp, meters: 400, level: 2, name: "Easy warm up swim", ctx: ctx),
            swimStep(.work, meters: 50, level: 2, name: "Drill lap", ctx: ctx, group: "g1", count: 4,
                     detail: "Smooth and relaxed, getting ready for the test."),
            swimRest(15, group: "g1", count: 4),
            swimStep(.work, meters: 400, level: 5, name: "400 m all out", ctx: ctx, rpe: hard,
                     detail: "Start controlled and finish as strong as you can. Note your time. Swim with other people around, and stop if anything feels wrong."),
            make(.swim, .recovery, seconds: 420, level: 1, name: "Active recovery",
                 detail: "Seven minutes of very easy swimming and floating, so the 200 m is a real effort."),
            swimStep(.work, meters: 200, level: 5, name: "200 m all out", ctx: ctx, rpe: hard,
                     detail: "Go faster than your 400 m pace and note your time. Stop if anything feels wrong."),
            swimStep(.coolDown, meters: 200, level: 1, name: "Cool down swim", ctx: ctx)
        ]
    }

    // MARK: Bike

    private static func bikeEasy(_ d: Double) -> [Step] {
        let edge: Double = d >= 2400 ? 300 : 180
        let main = max(d - 2 * edge, 300)
        return [
            make(.bike, .warmUp, seconds: edge, level: 1, name: "Warm up"),
            make(.bike, .work, seconds: main, level: 2, name: "Easy spin",
                 detail: "Light gear and smooth, round pedal strokes."),
            make(.bike, .coolDown, seconds: edge, level: 1, name: "Cool down")
        ]
    }

    private static func bikeLong(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let warm = 600.0
        let cool = 300.0
        let main = max(d - warm - cool, 600)
        let steadyShare: Double
        if !ctx.allowSteady {
            steadyShare = 0
        } else {
            switch ctx.phase {
            case .base: steadyShare = 0.15
            case .build: steadyShare = 0.30
            case .peak: steadyShare = 0.40
            case .taper: steadyShare = 0
            }
        }
        let blockLen: Double
        switch ctx.distance {
        case .sprint: blockLen = 600
        case .olympic: blockLen = 900
        case .half: blockLen = ctx.phase == .peak ? 1800 : 1200
        }
        let gap = 300.0
        var blocks = min(max(Intensity.floorInt(main * steadyShare / blockLen), 0), 4)
        while blocks > 0 && main - Double(blocks) * (blockLen + gap) < 900 { blocks -= 1 }
        var steps = [make(.bike, .warmUp, seconds: warm, level: 1, name: "Warm up")]
        let easyMain = main - Double(blocks) * (blockLen + gap)
        if easyMain > 0 {
            steps.append(make(.bike, .work, seconds: easyMain, level: 2, name: "Easy aerobic riding",
                              detail: "Settle in and practise your eating and drinking."))
        }
        if blocks > 0 {
            let aboveRace = RacePacingPlaceholders.trainingLevelRunsAboveRace(sport: .bike, distance: ctx.distance)
            steps.append(make(.bike, .work, seconds: blockLen, level: 3, name: "Steady block", group: "g1", count: blocks,
                              detail: aboveRace
                                  ? "A steady aerobic push, a little above race effort. Strong but sustainable."
                                  : "Strong but sustainable, close to the effort you plan for the race."))
            steps.append(make(.bike, .recovery, seconds: gap, level: 2, name: "Easy spin between blocks",
                              group: "g1", count: blocks))
        }
        steps.append(make(.bike, .coolDown, seconds: cool, level: 1, name: "Cool down"))
        return steps
    }

    private static func bikeThreshold(_ d: Double, _ ctx: BuildContext) -> [Step] {
        var work: Double
        let rest: Double
        let minReps: Int
        let maxReps: Int
        switch ctx.phase {
        case .base: work = 360; rest = 180; minReps = 2; maxReps = 4
        case .build: work = 600; rest = 240; minReps = 2; maxReps = 5
        default: work = 720; rest = 240; minReps = 3; maxReps = 5
        }
        if ctx.level == .firstTimer { work = max(240, (work * 0.7 / 60).rounded() * 60) }
        let cool = 300.0
        let fit = fitReps(session: d, fixedBefore: 600, fixedAfter: cool, work: work, rest: rest,
                          minReps: minReps, maxReps: maxReps)
        return [
            make(.bike, .warmUp, seconds: fit.warm, level: 2, name: "Warm up",
                 detail: "Start easy and add a couple of short pickups in the last minutes."),
            make(.bike, .work, seconds: fit.work, level: 4, name: "Threshold interval", group: "g1", count: fit.n,
                 detail: "Hard but even. Hold the same effort from the start to the end of each block."),
            make(.bike, .recovery, seconds: rest, level: 1, name: "Easy spin recovery", group: "g1", count: fit.n),
            make(.bike, .coolDown, seconds: cool, level: 1, name: "Cool down")
        ]
    }

    private static func bikeVO2(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let cool = 300.0
        let fit = fitReps(session: d, fixedBefore: 600, fixedAfter: cool, work: 180, rest: 180,
                          minReps: 4, maxReps: ctx.phase == .peak ? 6 : 5)
        return [
            make(.bike, .warmUp, seconds: fit.warm, level: 2, name: "Warm up",
                 detail: "Start easy and add a couple of short pickups in the last minutes."),
            make(.bike, .work, seconds: fit.work, level: 5, name: "Hard interval", group: "g1", count: fit.n,
                 detail: "Very hard but controlled. Keep every effort the same."),
            make(.bike, .recovery, seconds: 180, level: 1, name: "Easy spin recovery", group: "g1", count: fit.n),
            make(.bike, .coolDown, seconds: cool, level: 1, name: "Cool down")
        ]
    }

    private static func bikeOpeners(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let level = RacePacingPlaceholders.trainingLevel(forRaceEffort: .bike, distance: ctx.distance)
        let above = RacePacingPlaceholders.trainingLevelRunsAboveRace(sport: .bike, distance: ctx.distance)
        let session = min(max(d, 1500), 2400)
        let cool = 300.0
        let n = 3
        let warm = session - cool - Double(n) * 240
        return [
            make(.bike, .warmUp, seconds: warm, level: 2, name: "Warm up"),
            make(.bike, .work, seconds: 120, level: level, name: "Opener", group: "g1", count: n,
                 detail: above ? "Smooth and strong, a touch above race effort, then stop."
                               : "Smooth and strong at planned race effort, then stop."),
            make(.bike, .recovery, seconds: 120, level: 1, name: "Easy spin recovery", group: "g1", count: n),
            make(.bike, .coolDown, seconds: cool, level: 1, name: "Cool down")
        ]
    }

    /// Recovery after the clearing effort of the bike power test. FTP is 0.95 times the 20 minute power only when
    /// the legs have recovered from the clearing effort, so the break is 10 minutes.
    static let bikeTestRecoverySeconds = 600.0

    /// Annex A bike power test: a 5 minute clearing effort in the warm up, then 20 minutes all out.
    private static func bikeTestFTP() -> [Step] {
        let hard = ValueRange(9, 10)
        return [
            make(.bike, .warmUp, seconds: 900, level: 2, name: "Warm up"),
            make(.bike, .work, seconds: 300, level: 5, name: "Clearing effort", rpe: hard,
                 detail: "Five minutes hard to clear the legs. Then recover fully. Stop if anything feels wrong."),
            make(.bike, .recovery, seconds: bikeTestRecoverySeconds, level: 1, name: "Easy spin recovery"),
            make(.bike, .work, seconds: 1200, level: 5, name: "20 minute test effort", rpe: ValueRange(8, 9),
                 detail: "Pace it evenly, as hard as you can hold for the full 20 minutes. Start a little under that effort and build. Stop if anything feels wrong."),
            make(.bike, .coolDown, seconds: 600, level: 1, name: "Cool down")
        ]
    }

    /// Annex A bike heart rate test: 30 minute solo time trial, average heart rate of the final 20 minutes.
    private static func bikeTestLTHR() -> [Step] {
        [
            make(.bike, .warmUp, seconds: 900, level: 2, name: "Warm up"),
            make(.bike, .work, seconds: 1800, level: 4, name: "30 minute time trial", rpe: ValueRange(8, 9),
                 detail: "Ride alone, hard and even from start to finish. The last 20 minutes set your zones. Stop if anything feels wrong."),
            make(.bike, .coolDown, seconds: 600, level: 1, name: "Cool down")
        ]
    }

    private static func transitionRun(_ ctx: BuildContext) -> [Step] {
        let seconds = min(max(ctx.brickRunSeconds, 600), 1200)
        let level = (ctx.phase == .peak && ctx.distance == .half) ? 3 : 2
        return [
            make(.run, .work, seconds: seconds, level: level, name: "Transition run",
                 detail: "The first minutes feel odd. Take short, quick steps and let your legs settle.")
        ]
    }

    // MARK: Run

    private static func runSteady(_ d: Double, long: Bool, _ ctx: BuildContext) -> [Step] {
        let edge: Double = d >= 2400 ? 300 : 180
        let main = max(d - 2 * edge, 600)
        var steps: [Step] = []
        if ctx.runWalk {
            let run: Double = ctx.level == .firstTimer ? 180 : 360
            let walk = 60.0
            let n = max(Intensity.floorInt(main / (run + walk)), 1)
            let leftover = max(main - Double(n) * (run + walk), 0)
            steps.append(make(.run, .warmUp, seconds: edge + leftover, level: 1, name: "Brisk walk or easy jog"))
            steps.append(make(.run, .work, seconds: run, level: 2, name: "Easy run interval", group: "g1", count: n,
                              detail: "Relaxed and even. Stop the interval early if you need to."))
            steps.append(make(.run, .recovery, seconds: walk, level: 1, name: "Walk break", group: "g1", count: n))
        } else {
            let finish: Double = (long && ctx.allowSteady && ctx.phase == .peak && ctx.level != .firstTimer && main >= 3000) ? 900 : 0
            steps.append(make(.run, .warmUp, seconds: edge, level: 1, name: "Easy jog or brisk walk"))
            steps.append(make(.run, .work, seconds: main - finish, level: 2, name: long ? "Long easy run" : "Easy run",
                              detail: "Relaxed and even. If you cannot chat, slow down."))
            if finish > 0 {
                steps.append(make(.run, .work, seconds: finish, level: 3, name: "Steady finish",
                                  detail: "Lift to a strong, steady rhythm for the last stretch."))
            }
        }
        steps.append(make(.run, .coolDown, seconds: edge, level: 1, name: "Walk or jog to cool down"))
        return steps
    }

    private static func runThreshold(_ d: Double, _ ctx: BuildContext) -> [Step] {
        var work: Double
        let rest: Double = 180
        let minReps: Int
        let maxReps: Int
        switch ctx.phase {
        case .base: work = 360; minReps = 2; maxReps = 4
        case .build: work = 480; minReps = 2; maxReps = 5
        default: work = 600; minReps = 3; maxReps = 5
        }
        if ctx.level == .firstTimer { work = max(240, (work * 0.7 / 60).rounded() * 60) }
        let cool = 300.0
        let fit = fitReps(session: d, fixedBefore: 600, fixedAfter: cool, work: work, rest: rest,
                          minReps: minReps, maxReps: maxReps)
        return [
            make(.run, .warmUp, seconds: fit.warm, level: 2, name: "Easy warm up jog"),
            make(.run, .work, seconds: fit.work, level: 4, name: "Threshold interval", group: "g1", count: fit.n,
                 detail: "Comfortably hard and even. Finish the last one as strongly as the first."),
            make(.run, .recovery, seconds: rest, level: 1, name: ctx.runWalk ? "Walk recovery" : "Easy jog recovery",
                 group: "g1", count: fit.n),
            make(.run, .coolDown, seconds: cool, level: 1, name: "Cool down jog")
        ]
    }

    private static func runVO2(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let peak = ctx.phase == .peak
        let work: Double = peak ? 180 : 120
        let rest: Double = peak ? 180 : 120
        let cool = 300.0
        let fit = fitReps(session: d, fixedBefore: 600, fixedAfter: cool, work: work, rest: rest,
                          minReps: 4, maxReps: peak ? 6 : 8)
        return [
            make(.run, .warmUp, seconds: fit.warm, level: 2, name: "Easy warm up jog"),
            make(.run, .work, seconds: fit.work, level: 5, name: "Fast interval", group: "g1", count: fit.n,
                 detail: "Fast and relaxed, not a sprint. Keep every repeat the same."),
            make(.run, .recovery, seconds: rest, level: 1, name: ctx.runWalk ? "Walk recovery" : "Easy jog recovery",
                 group: "g1", count: fit.n),
            make(.run, .coolDown, seconds: cool, level: 1, name: "Cool down jog")
        ]
    }

    private static func runOpeners(_ d: Double, _ ctx: BuildContext) -> [Step] {
        let level = RacePacingPlaceholders.trainingLevel(forRaceEffort: .run, distance: ctx.distance)
        let session = min(max(d, 1500), 2400)
        let cool = 300.0
        let n = 4
        let warm = session - cool - Double(n) * 120
        return [
            make(.run, .warmUp, seconds: warm, level: 2, name: "Easy warm up jog"),
            make(.run, .work, seconds: 60, level: level, name: "Opener", group: "g1", count: n,
                 detail: ctx.distance == .olympic ? "Quick and smooth, close to planned race pace, then ease off."
                                                    : "Quick and smooth at planned race pace, then ease off."),
            make(.run, .recovery, seconds: 60, level: 1, name: "Easy jog recovery", group: "g1", count: n),
            make(.run, .coolDown, seconds: cool, level: 1, name: "Cool down jog")
        ]
    }

    /// Annex A run test: 10 minute warm up, 30 minutes hard and even.
    private static func runTest() -> [Step] {
        [
            make(.run, .warmUp, seconds: 600, level: 2, name: "Easy warm up jog"),
            make(.run, .work, seconds: 180, level: 3, name: "Build up",
                 detail: "Raise the pace gently toward the test effort."),
            make(.run, .work, seconds: 1800, level: 4, name: "30 minute test effort", rpe: ValueRange(8, 9),
                 detail: "Hard and even from the first minute to the last. Note the distance you cover. Stop if anything feels wrong."),
            make(.run, .coolDown, seconds: 600, level: 1, name: "Cool down jog")
        ]
    }
}
