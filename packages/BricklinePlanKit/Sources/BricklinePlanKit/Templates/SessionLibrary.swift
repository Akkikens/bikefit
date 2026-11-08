import Foundation

/// Every kind of session the template engine can generate (annex B "Microcycle assembly", spec 3.2).
/// The kind decides the name, the purpose sentence, the step structure and the quality flags.
public enum SessionKind: String, Codable, Hashable, Sendable, CaseIterable {
    case swimTechnique
    case swimEndurance
    case swimThreshold
    case swimSpeed
    case swimTest
    case bikeEasy
    case bikeLong
    case bikeBrick
    case bikeThreshold
    case bikeVO2
    case bikeOpeners
    case bikeTestFTP
    case bikeTestLTHR
    case runEasy
    case runLong
    case runThreshold
    case runVO2
    case runOpeners
    case runTest

    /// Primary sport of the session. A brick is a bike session with a short run attached.
    public var sport: Sport {
        switch self {
        case .swimTechnique, .swimEndurance, .swimThreshold, .swimSpeed, .swimTest:
            return .swim
        case .bikeEasy, .bikeLong, .bikeBrick, .bikeThreshold, .bikeVO2, .bikeOpeners, .bikeTestFTP, .bikeTestLTHR:
            return .bike
        case .runEasy, .runLong, .runThreshold, .runVO2, .runOpeners, .runTest:
            return .run
        }
    }

    /// Maximal effort test session (annex A retest rotation).
    public var isTest: Bool {
        switch self {
        case .swimTest, .bikeTestFTP, .bikeTestLTHR, .runTest: return true
        default: return false
        }
    }

    /// Counts toward the weekly quality caps (annex B "Intensity distribution"). Tests count as quality.
    public var isQuality: Bool {
        switch self {
        case .swimThreshold, .swimSpeed, .bikeThreshold, .bikeVO2, .bikeOpeners, .runThreshold, .runVO2, .runOpeners:
            return true
        default:
            return isTest
        }
    }

    /// Which benchmark a test session refreshes.
    public var benchmarkKind: BenchmarkKind? {
        switch self {
        case .swimTest: return .swimCSS
        case .bikeTestFTP: return .bikeFTP
        case .bikeTestLTHR: return .bikeLTHR
        case .runTest: return .runThreshold
        default: return nil
        }
    }

    /// The plain session used when a quality session cannot be placed (annex B: all other sessions are easy).
    var easyCounterpart: SessionKind {
        switch sport {
        case .swim: return .swimTechnique
        case .bike: return .bikeEasy
        case .run: return .runEasy
        }
    }
}

/// Names and purpose sentences for every session kind. One plain, honest sentence each (spec 3.2, section 6).
public enum SessionLibrary {
    /// Display name of a session kind. `runWalk` swaps the easy run name for the run walk variant.
    public static func name(for kind: SessionKind, runWalk: Bool = false) -> String {
        switch kind {
        case .swimTechnique: return "Technique swim"
        case .swimEndurance: return "Endurance swim"
        case .swimThreshold: return "Threshold swim"
        case .swimSpeed: return "Fast 50s swim"
        case .swimTest: return "Swim speed test"
        case .bikeEasy: return "Easy spin"
        case .bikeLong: return "Long ride"
        case .bikeBrick: return "Brick: ride then run"
        case .bikeThreshold: return "Threshold ride"
        case .bikeVO2: return "Short hard intervals ride"
        case .bikeOpeners: return "Race week openers ride"
        case .bikeTestFTP: return "Bike power test"
        case .bikeTestLTHR: return "Bike heart rate test"
        case .runEasy: return runWalk ? "Run walk session" : "Easy run"
        case .runLong: return runWalk ? "Long run walk session" : "Long run"
        case .runThreshold: return "Threshold run"
        case .runVO2: return "Fast intervals run"
        case .runOpeners: return "Race week openers run"
        case .runTest: return "Run threshold test"
        }
    }

    /// One sentence on why the session exists.
    public static func purpose(for kind: SessionKind, runWalk: Bool = false) -> String {
        switch kind {
        case .swimTechnique:
            return "Easy laps and drills build a smooth, relaxed stroke, which saves energy in every later swim."
        case .swimEndurance:
            return "A longer, comfortable swim builds the aerobic base you need to cover the race distance without fading."
        case .swimThreshold:
            return "Repeats near your critical swim speed teach you to hold a strong pace for longer."
        case .swimSpeed:
            return "Short, fast swims with short rests raise your top speed while keeping your form clean."
        case .swimTest:
            return "A 400 m and a 200 m swim, both all out, set the pace zones for every swim in your plan."
        case .bikeEasy:
            return "Light pedalling at conversation pace adds aerobic volume and loosens your legs without much fatigue."
        case .bikeLong:
            return "Your longest ride of the week builds the endurance, and the eating and drinking habits, that the race needs."
        case .bikeBrick:
            return "Running straight after a ride teaches your legs the switch you will make in transition on race day."
        case .bikeThreshold:
            return "Hard, even blocks near your limit raise the effort you can hold for a long time."
        case .bikeVO2:
            return "Short, very hard efforts raise your top end."
        case .bikeOpeners:
            return "A few short efforts at race effort keep your legs sharp while you rest for the race."
        case .bikeTestFTP:
            return "A guided 20 minute effort sets your power zones, so every ride after it is aimed at the right level."
        case .bikeTestLTHR:
            return "A 30 minute solo effort sets your heart rate zones, so every ride after it is aimed at the right level."
        case .runEasy:
            return runWalk
                ? "Short runs with walking breaks build running fitness gradually and keep the session comfortable."
                : "Relaxed running builds aerobic fitness and keeps your legs used to the impact of running."
        case .runLong:
            return runWalk
                ? "Your longest session of the week, with walking breaks, builds the endurance to keep moving strongly late in the race."
                : "Your longest run of the week builds the endurance to run strong at the end of the race."
        case .runThreshold:
            return "Steady, hard running near your threshold pace raises the pace you can sustain."
        case .runVO2:
            return "Short, fast repeats with easy jogging between raise your top end and your running efficiency."
        case .runOpeners:
            return "A few short efforts at race pace keep your legs sharp while you rest for the race."
        case .runTest:
            return "A 30 minute even effort sets your run pace and heart rate zones, so every run after it is aimed at the right level."
        }
    }

    /// Every name and purpose sentence, for copy scans (annex J "Forbidden word scan").
    public static var allCopy: [String] {
        var out: [String] = []
        for kind in SessionKind.allCases {
            out.append(name(for: kind))
            out.append(purpose(for: kind))
            out.append(name(for: kind, runWalk: true))
            out.append(purpose(for: kind, runWalk: true))
        }
        return out
    }
}
