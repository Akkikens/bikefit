import Foundation
import BricklinePlanKit

/// Turns engine session copy into the plain wording the screens use (design spec section 10): titles carry units,
/// and every technical word moves into `idea`, which the screens wrap in JargonText. Pure, so it can be tested
/// without the UI. The engine owns the numbers; this file only chooses words.
enum PlainCopy {
    /// The engine's kind for a session, found from its library name. Nil for a hand built session.
    static func engineKind(of s: BricklinePlanKit.Session) -> SessionKind? {
        let runWalk = s.name.lowercased().contains("walk")
        return SessionKind.allCases.first {
            $0.sport == s.sport && SessionLibrary.name(for: $0, runWalk: runWalk) == s.name
        }
    }

    // MARK: Numbers as words

    static func minutes(_ seconds: Double) -> String {
        let s = max(0, seconds.isFinite ? seconds : 0)
        if s < 90, s.truncatingRemainder(dividingBy: 60) != 0 { return "\(Int(s.rounded())) s" }
        return "\(Int((s / 60).rounded())) min"
    }

    private static func roundedMeters(_ meters: Double) -> Int {
        Int((meters / 50).rounded()) * 50
    }

    // MARK: Titles

    /// Plain title with units, for example "Steady hard run, 2 times 15 min". No shorthand, no dashes.
    static func title(for s: BricklinePlanKit.Session) -> String {
        let total = Int((s.durationSeconds / 60).rounded())
        let repeated = s.steps.first { $0.kind == .work && $0.repeatGroupID != nil }
        let reps = repeated.map { "\($0.repeats) times \(minutes($0.durationSeconds))" }
        let swimReps = repeated.map { r -> String in
            let m = Int(((r.distanceMeters ?? 0)).rounded())
            return "\(r.repeats) times \(m) m"
        }
        guard let kind = engineKind(of: s) else { return sanitize(s.name) }
        let runWalk = s.name.lowercased().contains("walk")
        switch kind {
        case .swimTechnique:
            let m = roundedMeters(s.distanceMeters)
            return m > 0 ? "Easy swim with drills, \(m) m" : "Easy swim with drills, \(total) min"
        case .swimEndurance:
            let m = roundedMeters(s.distanceMeters)
            return m > 0 ? "Steady swim, \(m) m" : "Steady swim, \(total) min"
        case .swimThreshold: return "Steady hard swims, \(swimReps ?? "\(total) min")"
        case .swimSpeed: return "Fast swims, \(swimReps ?? "\(total) min")"
        case .swimTest: return "Swim pace test, 400 m then 200 m"
        case .bikeEasy: return "Easy ride, \(total) min"
        case .bikeLong: return "Long ride, \(total) min"
        case .bikeBrick:
            let bike = s.steps.filter { $0.sport == s.sport }.reduce(0.0) { $0 + $1.durationSeconds * Double($1.repeats) }
            let run = s.steps.filter { $0.sport != s.sport }.reduce(0.0) { $0 + $1.durationSeconds * Double($1.repeats) }
            return "Ride \(Int((bike / 60).rounded())) min, then run \(Int((run / 60).rounded())) min"
        case .bikeThreshold: return "Strong steady ride, \(reps ?? "\(total) min")"
        case .bikeVO2: return "Hard short efforts ride, \(reps ?? "\(total) min")"
        case .bikeOpeners: return "Race week ride with short efforts, \(total) min"
        case .bikeTestFTP: return "Bike power test, 20 min effort"
        case .bikeTestLTHR: return "Bike heart rate test, 30 min effort"
        case .runEasy: return runWalk ? "Run and walk, \(total) min" : "Easy run, \(total) min"
        case .runLong: return runWalk ? "Long run and walk, \(total) min" : "Long run, \(total) min"
        case .runThreshold: return "Steady hard run, \(reps ?? "\(total) min")"
        case .runVO2: return "Fast run intervals, \(reps ?? "\(total) min")"
        case .runOpeners: return "Race week run with short efforts, \(total) min"
        case .runTest: return "Run pace test, 30 min effort"
        }
    }

    /// The technical idea behind a session and the plain line that introduces it, or nil when there is none.
    static func idea(for s: BricklinePlanKit.Session) -> (term: Term, label: String)? {
        guard let kind = engineKind(of: s) else { return nil }
        switch kind {
        case .bikeBrick: return (.brick, "Known as a brick session")
        case .runThreshold: return (.threshold, "Known as a threshold run")
        case .bikeThreshold: return (.threshold, "Known as a threshold ride")
        case .swimThreshold: return (.css, "Pace is set from your steady hard swim speed")
        case .swimTest: return (.css, "This test sets your swim pace")
        case .bikeTestFTP: return (.ftp, "This test sets your power zones")
        case .bikeTestLTHR: return (.lthr, "This test sets your heart rate zones")
        case .runTest: return (.threshold, "This test sets your run pace")
        default: return nil
        }
    }

    /// Engine purpose sentence with the technical words replaced, since the purpose is plain text, not JargonText.
    static func purpose(for s: BricklinePlanKit.Session) -> String {
        sanitize(s.purpose)
    }

    // MARK: Steps

    private static let stepNames: [String: String] = [
        "Easy aerobic swim": "Easy swim",
        "Easy aerobic riding": "Easy ride",
        "Easy aerobic ride": "Easy ride",
        "Easy aerobic running": "Easy run",
        "Easy warm up swim": "Easy warm up",
        "Cool down swim": "Easy cool down",
        "Warm up": "Easy warm up",
        "Cool down": "Easy cool down",
        "Easy warm up jog": "Easy warm up",
        "Cool down jog": "Easy cool down",
        "Walk or jog to cool down": "Easy cool down",
        "Easy jog or brisk walk": "Easy warm up",
        "Brisk walk or easy jog": "Easy warm up",
        "Threshold interval": "Steady hard effort",
        "Threshold repeat": "Steady hard swim",
        "Hard interval": "Hard effort",
        "Fast interval": "Fast run",
        "Fast 50": "Fast swim",
        "Opener": "Short effort",
        "Aerobic 100": "Steady swim",
        "Transition run": "Run straight off the bike",
        "Easy spin recovery": "Spin easy",
        "Easy spin between blocks": "Spin easy",
        "Easy jog recovery": "Easy jog",
        "Rest at the wall": "Rest",
        "Active recovery": "Easy swim rest",
    ]

    /// Name of one step: plain words, with its length when the name does not already say it.
    static func stepName(_ step: BricklinePlanKit.Step) -> String {
        let base = stepNames[step.name] ?? sanitize(step.name)
        let hasNumber = base.contains(where: \.isNumber)
        switch step.kind {
        case .warmUp, .coolDown:
            return base
        case .recovery:
            return hasNumber ? base : "\(base), \(minutes(step.durationSeconds))"
        case .work:
            if hasNumber { return base }
            if step.sport == .swim, let m = step.distanceMeters, m > 0 { return "\(base), \(Int(m.rounded())) m" }
            return "\(base), \(minutes(step.durationSeconds))"
        }
    }

    // MARK: Jargon

    /// Words that must live inside a JargonText, never in plain copy.
    static let bannedInPlainText = ["threshold", "brick", "sweet spot", "ftp", "css", "vo2", "lthr", "rpe",
                                    "critical swim speed", "tss", "ctl", "atl", "trainingpeaks", "aerobic", "zone"]

    private static let replacements: [(String, String)] = [
        ("Brick: ride then run", "Ride then run"),
        ("Threshold swim", "Steady hard swim"),
        ("Threshold ride", "Strong steady ride"),
        ("Threshold run", "Steady hard run"),
        ("near your critical swim speed", "at a steady hard swim pace"),
        ("threshold pace", "steady hard pace"),
        ("Threshold", "Steady hard"),
        ("threshold", "steady hard"),
        ("critical swim speed", "steady hard swim speed"),
        ("VO2", "top end"),
        ("FTP", "power number"),
        ("LTHR", "heart rate number"),
        ("CSS", "swim pace number"),
        ("\u{2014}", ", "),
        ("\u{2013}", " to "),
    ]

    /// Whole word, case blind replacements for the lower case names the engine builds into sentences, such as
    /// "Today's brick became an easy brick." Longer phrases come first.
    private static let looseReplacements: [(pattern: String, to: String)] = [
        ("\\beasy brick\\b", "easy ride"),
        ("\\bbrick\\b", "ride then run"),
        ("\\btechnique swim\\b", "easy swim with drills"),
        ("\\bendurance swim\\b", "steady swim"),
        ("\\bfast 50s swim\\b", "fast swim"),
        ("\\brace week openers\\b", "race week short efforts"),
        ("\\bvo2\\b", "top end"),
        ("\\baerobic base\\b", "steady endurance"),
        ("\\baerobic volume\\b", "easy time in the saddle"),
        ("\\baerobic fitness\\b", "endurance"),
        ("\\b(?:pace|power|heart rate) zones\\b", "effort ranges"),
    ]

    static func sanitize(_ text: String) -> String {
        var out = text
        for (from, to) in replacements { out = out.replacingOccurrences(of: from, with: to) }
        for (pattern, to) in looseReplacements {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            // Back to front so earlier ranges stay valid; a capital letter at the start of a match is kept.
            let matches = re.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
            for m in matches {
                guard let r = Range(m.range, in: out) else { continue }
                let capital = out[r].first?.isUppercase == true
                out.replaceSubrange(r, with: capital ? to.prefix(1).uppercased() + to.dropFirst() : to)
            }
        }
        return out
    }
}
