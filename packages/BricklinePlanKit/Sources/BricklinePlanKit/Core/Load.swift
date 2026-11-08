import Foundation

/// A daily total of Load (annex D). The name is Load, never any other brand's term.
public struct LoadSample: Codable, Hashable, Sendable {
    /// Start of the day.
    public var date: Date
    public var load: Double

    public init(date: Date, load: Double) {
        self.date = date
        self.load = load
    }
}

/// Fitness, Fatigue and Form on one day (annex D). Fatigue is internal and not shown in the UI.
/// Form is Fitness minus Fatigue using yesterday's values.
public struct FitnessForm: Codable, Hashable, Sendable {
    public var date: Date
    /// 42 day exponentially weighted average of daily Load.
    public var fitness: Double
    /// 7 day exponentially weighted average of daily Load.
    public var fatigue: Double
    public var form: Double

    public init(date: Date, fitness: Double, fatigue: Double, form: Double) {
        self.date = date
        self.fitness = fitness
        self.fatigue = fatigue
        self.form = form
    }
}

/// Load of one session with a flag for labelled estimates (annex D: swims without heart rate are Estimated).
public struct SessionLoad: Codable, Hashable, Sendable {
    public var load: Double
    public var isEstimated: Bool

    public init(load: Double, isEstimated: Bool = false) {
        self.load = load
        self.isEstimated = isEstimated
    }
}
