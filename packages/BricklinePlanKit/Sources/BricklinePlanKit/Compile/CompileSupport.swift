import Foundation

// Small pure helpers for the session compiler (annex E): unit conversion, plain text formatting and the
// feel descriptions every step carries (annex A: "RPE descriptions on every step regardless").

enum CompileSupport {
    /// Largest magnitude converted to Int. Keeps `Int(_:)` from trapping on absurd or non finite input.
    private static let intLimit = 1_000_000_000.0

    static func safeInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(value.rounded(), -intLimit), intLimit))
    }

    static func isPositiveFinite(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    /// Run pace in seconds per km to speed in metres per second. Nil for a non positive or non finite pace.
    static func speed(fromPacePerKm pace: Double) -> Double? {
        guard isPositiveFinite(pace) else { return nil }
        return 1000 / pace
    }

    /// Inverts a pace range (seconds per km) to a speed range (metres per second). The faster pace becomes the
    /// upper speed. Nil when either bound is not a usable pace (annex E "Alerts": run pace as speed range).
    static func speedRange(fromPaceRange range: ValueRange) -> ValueRange? {
        guard let fast = speed(fromPacePerKm: range.lower), let slow = speed(fromPacePerKm: range.upper) else {
            return nil
        }
        return ValueRange(slow, fast)
    }

    /// A range usable as an alert: both bounds finite, upper above zero, and a real width.
    static func isUsableAlertRange(_ range: ValueRange) -> Bool {
        range.lower.isFinite && range.upper.isFinite && range.upper > 0 && range.lower >= 0 && range.width > 0
    }

    /// Whole seconds as m:ss, or h:mm:ss from one hour.
    static func clock(_ seconds: Double) -> String {
        let total = max(safeInt(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(pad(minutes)):\(pad(secs))"
        }
        return "\(minutes):\(pad(secs))"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// Plain words for a resolved target, used when an alert is dropped so the target still reaches the card.
    static func describe(_ request: AlertRequest, sport: Sport) -> String {
        switch request {
        case .none:
            return ""
        case .speed(let range):
            // Convert back to pace so the card reads the way runners think (fast pace first).
            let fast = range.upper > 0 ? 1000 / range.upper : 0
            let slow = range.lower > 0 ? 1000 / range.lower : 0
            return "\(clock(fast)) to \(clock(slow)) per km"
        case .power(let range):
            return "\(safeInt(range.lower)) to \(safeInt(range.upper)) watts"
        case .heartRate(let range):
            return "\(safeInt(range.lower)) to \(safeInt(range.upper)) beats per minute"
        }
    }

    /// Feel description on the 1 to 10 scale for a target range, for example "RPE 5 to 6 of 10".
    static func rpeText(for range: ValueRange) -> String {
        let low = min(max(safeInt(range.lower), 1), 10)
        let high = min(max(safeInt(range.upper), 1), 10)
        if low == high { return "RPE \(low) of 10" }
        return "RPE \(min(low, high)) to \(max(low, high)) of 10"
    }

    /// Default feel text per intensity level when a step carries no RPE target.
    static func rpeText(forLevel level: Int) -> String {
        switch IntensityLevel.clamped(level) {
        case 1: return "RPE 1 to 2 of 10"
        case 2: return "RPE 3 to 4 of 10"
        case 3: return "RPE 5 to 6 of 10"
        case 4: return "RPE 7 to 8 of 10"
        default: return "RPE 9 to 10 of 10"
        }
    }

    /// Stock watch label for a step kind (what the stock app shows without display names).
    static func stockLabel(for kind: StepKind) -> String {
        switch kind {
        case .warmUp: return "Warm Up"
        case .work: return "Work"
        case .recovery: return "Recovery"
        case .coolDown: return "Cool Down"
        }
    }

    static func title(for sport: Sport) -> String {
        switch sport {
        case .swim: return "Swim"
        case .bike: return "Bike"
        case .run: return "Run"
        }
    }
}

/// An alert in the form the compiler decides on, before gating by the capability tier.
enum AlertRequest: Hashable {
    case none
    /// Metres per second.
    case speed(ValueRange)
    /// Watts.
    case power(ValueRange)
    /// Beats per minute.
    case heartRate(ValueRange)

    var compiled: CompiledAlert {
        switch self {
        case .none: return .none
        case .speed(let range): return .speedRange(range)
        case .power(let range): return .powerRange(range)
        case .heartRate(let range): return .heartRateRange(range)
        }
    }
}
