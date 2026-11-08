import Foundation

/// Intensity vocabulary shared by the step builders: feel words, RPE ranges and the swim offsets of annex A.
/// The swim offsets are repeated here as plain numbers so Templates does not depend on the Zones module.
enum Intensity {
    /// Rate of perceived exertion range for a step level (1 to 5), on the 1 to 10 feel scale.
    static func rpe(_ level: Int) -> ValueRange {
        switch IntensityLevel.clamped(level) {
        case 1: return ValueRange(1, 2)
        case 2: return ValueRange(3, 4)
        case 3: return ValueRange(5, 6)
        case 4: return ValueRange(7, 8)
        default: return ValueRange(9, 10)
        }
    }

    /// Plain description of how a level should feel, so every step is executable by feel alone (annex A).
    static func feel(_ level: Int) -> String {
        switch IntensityLevel.clamped(level) {
        case 1: return "Very easy, like a relaxed stroll"
        case 2: return "Easy, you could chat in full sentences"
        case 3: return "Steady, you can speak in short sentences"
        case 4: return "Hard but controlled, a few words at a time"
        default: return "Very hard, no talking"
        }
    }

    /// Swim offsets from CSS in seconds per 100 m (annex A, swim): easy +8 to +15, steady +4 to +7,
    /// threshold within 3, VO2 minus 8 to minus 4.
    static func swimOffset(_ level: Int) -> ValueRange {
        switch SwimZone(level: level) {
        case .easy: return ValueRange(8, 15)
        case .steady: return ValueRange(4, 7)
        case .threshold: return ValueRange(-3, 3)
        case .vo2: return ValueRange(-8, -4)
        }
    }

    static func swimOffsetText(_ level: Int) -> String {
        switch SwimZone(level: level) {
        case .easy: return "CSS plus 8 to 15 s per 100 m"
        case .steady: return "CSS plus 4 to 7 s per 100 m"
        case .threshold: return "within 3 s per 100 m of CSS"
        case .vo2: return "CSS minus 4 to 8 s per 100 m"
        }
    }

    /// Nominal pace in seconds per 100 m used only to estimate swim step durations.
    static func swimPace(css: Double, level: Int) -> Double {
        css + swimOffset(level).midpoint
    }

    /// Step note: feel, RPE, and for swims the CSS pace guide.
    static func note(level: Int, sport: Sport, kind: StepKind, rpe override: ValueRange?, detail: String?) -> String {
        let range = override ?? rpe(level)
        var text = "\(feel(level)). RPE \(whole(range.lower)) to \(whole(range.upper))."
        if sport == .swim && kind != .recovery && override == nil {
            text += " Pace guide: \(swimOffsetText(level))."
        }
        if let detail = detail, !detail.isEmpty {
            text += " " + detail
        }
        return text
    }

    /// Rounds a finite double to Int without trapping.
    static func whole(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(max(min(value.rounded(), 1_000_000_000), -1_000_000_000))
    }

    /// Floors a finite double to Int without trapping.
    static func floorInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(max(min(value.rounded(.down), 1_000_000_000), -1_000_000_000))
    }
}
