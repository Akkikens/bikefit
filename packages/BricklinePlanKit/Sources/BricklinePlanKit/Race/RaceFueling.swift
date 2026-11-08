import Foundation

extension DefaultRaceWindow {
    /// Annex F "Fueling card": one advice per leg, keyed to the midpoint of the leg's expected duration.
    ///
    /// Tiers come from `FuelingTier.tier(forDurationSeconds:)` (75 and 150 minute boundaries). The swim leg is
    /// always fluids only, because nothing can be taken in mid swim; its tier is therefore not read from the
    /// duration. Fluids go by thirst and there are no sodium numbers anywhere (annex F).
    public func fueling(for card: PacingCard) -> [FuelingAdvice] {
        card.targets.map { target in
            let leg = target.leg
            var seconds = Self.safeMidpoint(target.expectedDurationSeconds)

            if leg.sport == .swim {
                return FuelingAdvice(
                    leg: leg,
                    tier: .fluidsOnly,
                    carbsGramsPerHour: nil,
                    practiceLine: "Nothing to take in while swimming. Have your drink and fuel ready for the bike, and practice that handover in training.",
                    stomachLine: RaceWindowCopy.stomachLine)
            }

            // A typical duration is a guess. Near a tier edge the lower tier is shown, with a line saying so, so a
            // generic assumption never pushes the athlete to a heavier carbohydrate target than they may need.
            var edgeLine = ""
            if target.durationBasis == .typicalForLevel, Self.isNearTierEdge(seconds) {
                seconds = max(seconds - Self.typicalEdgeMarginSeconds, 0)
                edgeLine = " Your time could land on either side of a fueling step, so start with this and adjust in training."
            }
            let tier = FuelingTier.tier(forDurationSeconds: seconds)
            switch tier {
            case .fluidsOnly:
                return FuelingAdvice(
                    leg: leg,
                    tier: tier,
                    carbsGramsPerHour: nil,
                    practiceLine: "Drink to thirst; a sipped sports drink is fine. No carbohydrate target for a leg this short. Try your race drink in training first." + edgeLine,
                    stomachLine: RaceWindowCopy.stomachLine)
            case .moderate:
                let range = Self.moderateCarbs(forDurationSeconds: seconds)
                return FuelingAdvice(
                    leg: leg,
                    tier: tier,
                    carbsGramsPerHour: range,
                    practiceLine: "Aim for about \(RaceFormat.safeInt(range.lower)) to \(RaceFormat.safeInt(range.upper)) g of carbohydrate per hour, with fluids to thirst. Practice it in training so race day holds no surprises." + edgeLine,
                    stomachLine: RaceWindowCopy.stomachLine)
            case .high:
                let range = leg.sport == .bike ? ValueRange(60, 90) : ValueRange(50, 70)
                return FuelingAdvice(
                    leg: leg,
                    tier: tier,
                    carbsGramsPerHour: range,
                    practiceLine: "Aim for about \(RaceFormat.safeInt(range.lower)) to \(RaceFormat.safeInt(range.upper)) g of carbohydrate per hour, with fluids to thirst. At this rate a glucose and fructose mix works best, because the two sugars are absorbed by different routes. Build up to it in training." + edgeLine,
                    stomachLine: RaceWindowCopy.stomachLine)
            }
        }
    }

    /// Annex F moderate tier: roughly 30 g per hour at 75 minutes scaling toward 60 as duration approaches
    /// 2.5 hours, as a five gram wide band rounded to 5 g and held inside 30 to 60.
    static func moderateCarbs(forDurationSeconds seconds: Double) -> ValueRange {
        let lowEdge = 75.0 * 60
        let highEdge = 150.0 * 60
        let t = min(max((seconds - lowEdge) / (highEdge - lowEdge), 0), 1)
        let center = 30 + 30 * t
        let lower = min(max((((center - 2.5) / 5).rounded()) * 5, 30), 55)
        return ValueRange(lower, min(lower + 5, 60))
    }

    /// A typical duration within this many seconds of a tier edge (75 or 150 minutes) takes the lower tier.
    static let typicalEdgeMarginSeconds: Double = 15 * 60

    static func isNearTierEdge(_ seconds: Double) -> Bool {
        abs(seconds - 75 * 60) <= typicalEdgeMarginSeconds || abs(seconds - 150 * 60) <= typicalEdgeMarginSeconds
    }

    /// Midpoint of a duration range, or 0 when it is not usable (which reads as the shortest tier).
    static func safeMidpoint(_ range: ValueRange) -> Double {
        let mid = range.midpoint
        return mid.isFinite && mid > 0 ? mid : 0
    }
}
