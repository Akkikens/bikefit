import Foundation

/// Typed errors for every module. Engines throw these instead of trapping (house rule: no fatalError,
/// precondition or force unwrap on inputs).
public enum PlanKitError: Error, Equatable, Hashable, Sendable {
    /// An input was out of range or inconsistent. The string is a short developer facing reason.
    case invalidInput(String)
    /// The 200 m time was not faster than the 400 m pace, so the swim test is rejected and a retest is offered
    /// (annex A, swim).
    case cssTestRejected
    /// A required benchmark is missing for the requested operation.
    case missingBenchmark(BenchmarkKind)
    /// The race date leaves fewer weeks than the distance's minimum plan length (annex B).
    case raceDateTooSoon(minimumWeeks: Int, availableWeeks: Int)
    /// The athlete profile cannot be satisfied (for example no available weekdays).
    case infeasibleProfile(String)
    /// No session with this id exists in the plan.
    case sessionNotFound(String)
    /// A realignment option is not available (for example shifting the plan when the race date does not allow it).
    case realignmentUnavailable
    /// A session cannot be compiled to a watch workout (empty steps, unknown sport mix).
    case uncompilableSession(String)
    /// A share code is malformed or comes from a newer codec version (annex G).
    case malformedShareCode
}

extension PlanKitError: LocalizedError {
    /// Calm, plain wording the app can show as is. No blame, no dashes.
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return reason.isEmpty ? "That value does not look right. Please check it and try again." : reason
        case .cssTestRejected:
            return "Your 200 m pace was not faster than your 400 m pace, so these times cannot give a clean result. Rest a day or two and swim the pair again."
        case .missingBenchmark:
            return "This needs a test result first. A short test will add it."
        case .raceDateTooSoon(let minimum, let available):
            return "That race is \(available) weeks away and this distance needs at least \(minimum) weeks of plan. Pick a later race or a shorter distance."
        case .infeasibleProfile(let reason):
            return "The plan cannot fit your answers yet: \(reason). Try more training days or more hours."
        case .sessionNotFound:
            return "That session is no longer in your plan."
        case .realignmentUnavailable:
            return "That option is not available right now. The other one still is."
        case .uncompilableSession(let reason):
            return "This session cannot be sent to your watch: \(reason)"
        case .malformedShareCode:
            return "That plan code could not be read. It may be damaged or from a newer version of the app."
        }
    }
}
