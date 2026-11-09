import Foundation

// Capability tier logic (annex E "Capability tiers"). Everything here is a pure function over plain values:
// the app fills a `CapabilityReport` from the WorkoutKit supports APIs (supportsActivity, supportsGoal,
// supportsAlert) plus the explicit older watch setting, and the functions below decide what each activity
// may carry and say so in plain words. No API reads the paired watch's OS version.

/// Supports check results for one activity and location, as the app reads them from WorkoutKit at runtime
/// (annex E "Alerts", B12). Every flag defaults to false so a missing check never over promises.
public struct ActivityCapability: Codable, Hashable, Sendable {
    public var sport: Sport
    public var location: CompiledLocation
    /// `CustomWorkout.supportsActivity` for this sport.
    public var supportsActivity: Bool
    /// `supportsGoal` for a distance goal.
    public var supportsDistanceGoal: Bool
    /// `supportsGoal` for a time goal.
    public var supportsTimeGoal: Bool
    /// `supportsGoal` for the pool swim distance with time goal (iOS 18, watchOS 11).
    public var supportsDistanceWithTimeGoal: Bool
    /// `supportsAlert` for a speed range alert.
    public var supportsSpeedRangeAlert: Bool
    /// `supportsAlert` for a power range alert.
    public var supportsPowerRangeAlert: Bool
    /// `supportsAlert` for a heart rate range alert.
    public var supportsHeartRateRangeAlert: Bool

    public init(
        sport: Sport,
        location: CompiledLocation,
        supportsActivity: Bool = false,
        supportsDistanceGoal: Bool = false,
        supportsTimeGoal: Bool = false,
        supportsDistanceWithTimeGoal: Bool = false,
        supportsSpeedRangeAlert: Bool = false,
        supportsPowerRangeAlert: Bool = false,
        supportsHeartRateRangeAlert: Bool = false
    ) {
        self.sport = sport
        self.location = location
        self.supportsActivity = supportsActivity
        self.supportsDistanceGoal = supportsDistanceGoal
        self.supportsTimeGoal = supportsTimeGoal
        self.supportsDistanceWithTimeGoal = supportsDistanceWithTimeGoal
        self.supportsSpeedRangeAlert = supportsSpeedRangeAlert
        self.supportsPowerRangeAlert = supportsPowerRangeAlert
        self.supportsHeartRateRangeAlert = supportsHeartRateRangeAlert
    }

    /// Every check passes for the given activity (the watchOS 11 feature set).
    public static func allSupported(sport: Sport, location: CompiledLocation) -> ActivityCapability {
        ActivityCapability(
            sport: sport,
            location: location,
            supportsActivity: true,
            supportsDistanceGoal: true,
            supportsTimeGoal: true,
            supportsDistanceWithTimeGoal: sport == .swim,
            supportsSpeedRangeAlert: sport == .run,
            supportsPowerRangeAlert: sport != .swim,
            supportsHeartRateRangeAlert: true)
    }
}

/// What the app learned about the watch at runtime (annex E "Capability tiers"). Pure data, so tests can build
/// any combination without WorkoutKit.
public struct CapabilityReport: Codable, Hashable, Sendable {
    /// One entry per activity and location. A missing entry counts as unsupported.
    public var activities: [ActivityCapability]
    /// False when there is no watch, it is unpaired, or authorization was denied (tier 3).
    public var watchAvailable: Bool
    /// The explicit "My watch runs watchOS 10" setting (tier 2).
    public var olderWatchSetting: Bool
    /// Step display names are available (iOS 18, watchOS 11).
    public var supportsStepDisplayNames: Bool

    public init(
        activities: [ActivityCapability],
        watchAvailable: Bool = true,
        olderWatchSetting: Bool = false,
        supportsStepDisplayNames: Bool = true
    ) {
        self.activities = activities
        self.watchAvailable = watchAvailable
        self.olderWatchSetting = olderWatchSetting
        self.supportsStepDisplayNames = supportsStepDisplayNames
    }

    /// The activities TriSpike compiles for: pool swim, indoor and outdoor bike, indoor and outdoor run.
    public static let compiledActivities: [CompiledActivity] = [
        CompiledActivity(sport: .swim, location: .pool),
        CompiledActivity(sport: .bike, location: .indoor),
        CompiledActivity(sport: .bike, location: .outdoor),
        CompiledActivity(sport: .run, location: .indoor),
        CompiledActivity(sport: .run, location: .outdoor)
    ]

    /// Every supports check passes on a watch that is available: the default watchOS 11 path.
    public static let allSupported = CapabilityReport(
        activities: compiledActivities.map { ActivityCapability.allSupported(sport: $0.sport, location: $0.location) })

    /// Looks up the entry for an activity. Exact sport and location match only.
    public func capability(for activity: CompiledActivity) -> ActivityCapability? {
        activities.first { $0.sport == activity.sport && $0.location == activity.location }
    }

    /// Builds a report from the coarser `DeviceCapabilities` flags, so the protocol level `compile` and the
    /// report level `compile` share one code path.
    public init(capabilities: DeviceCapabilities) {
        let available = capabilities.tier != .noWatch
        let entries = CapabilityReport.compiledActivities.map { activity -> ActivityCapability in
            let outdoor = activity.location == .outdoor
            switch activity.sport {
            case .swim:
                return ActivityCapability(
                    sport: .swim,
                    location: activity.location,
                    supportsActivity: available,
                    supportsDistanceGoal: available,
                    supportsTimeGoal: available,
                    supportsDistanceWithTimeGoal: available && capabilities.supportsPoolSwimDistanceWithTimeGoal,
                    supportsHeartRateRangeAlert: capabilities.supportsSwimHeartRateAlert)
            case .bike:
                return ActivityCapability(
                    sport: .bike,
                    location: activity.location,
                    supportsActivity: available,
                    supportsDistanceGoal: available,
                    supportsTimeGoal: available,
                    supportsPowerRangeAlert: capabilities.supportsBikePowerAlert,
                    supportsHeartRateRangeAlert: capabilities.supportsBikeHeartRateAlert)
            case .run:
                return ActivityCapability(
                    sport: .run,
                    location: activity.location,
                    supportsActivity: available,
                    supportsDistanceGoal: available,
                    supportsTimeGoal: available,
                    supportsSpeedRangeAlert: capabilities.supportsRunSpeedAlert,
                    supportsPowerRangeAlert: outdoor && capabilities.supportsRunPowerAlertOutdoor)
            }
        }
        self.init(
            activities: entries,
            watchAvailable: available,
            olderWatchSetting: capabilities.tier == .olderWatch,
            supportsStepDisplayNames: capabilities.supportsStepDisplayNames)
    }

    /// The tier this report resolves to (annex E "Capability tiers").
    public var tier: WatchTier {
        CapabilityTiering.tier(for: self)
    }

    /// The coarse flags a caller can pass to `SessionCompiler.compile`. Conservative: a flag is true only when
    /// every compiled activity of that sport supports it.
    public var deviceCapabilities: DeviceCapabilities {
        let tier = CapabilityTiering.tier(for: self)
        if tier == .noWatch { return .noWatch }
        func all(_ sport: Sport, _ check: (ActivityCapability) -> Bool) -> Bool {
            let entries = activities.filter { $0.sport == sport }
            return !entries.isEmpty && entries.allSatisfy(check)
        }
        let outdoorRun = capability(for: CompiledActivity(sport: .run, location: .outdoor))
        let pool = capability(for: CompiledActivity(sport: .swim, location: .pool))
        let older = tier == .olderWatch
        return DeviceCapabilities(
            tier: tier,
            supportsRunSpeedAlert: all(.run) { $0.supportsSpeedRangeAlert },
            supportsRunPowerAlertOutdoor: outdoorRun?.supportsPowerRangeAlert ?? false,
            supportsBikePowerAlert: all(.bike) { $0.supportsPowerRangeAlert },
            supportsBikeHeartRateAlert: all(.bike) { $0.supportsHeartRateRangeAlert },
            supportsSwimHeartRateAlert: all(.swim) { $0.supportsHeartRateRangeAlert },
            supportsPoolSwimDistanceWithTimeGoal: !older && (pool?.supportsDistanceWithTimeGoal ?? false),
            supportsStepDisplayNames: !older && supportsStepDisplayNames)
    }
}

/// How a compiled activity reaches the person (annex E "Capability tiers").
public enum WatchDelivery: String, Codable, Hashable, Sendable, CaseIterable {
    /// A custom workout with named steps, goals and alerts goes to the watch.
    case customWorkout
    /// A goal only single workout goes to the watch (older watch pool swims, tier 2). The sets live on the phone.
    case goalOnlyWorkout
    /// Nothing goes to the watch. The printed set card and the phone player lead (tier 2 fallback, tier 3).
    case phoneOnly
}

/// What one activity may carry, decided from a `CapabilityReport`.
public struct ActivityDelivery: Hashable, Sendable {
    public var activity: CompiledActivity
    public var tier: WatchTier
    public var delivery: WatchDelivery
    public var allowsDistanceGoal: Bool
    public var allowsTimeGoal: Bool
    public var allowsDistanceWithTimeGoal: Bool
    public var allowsSpeedAlert: Bool
    public var allowsPowerAlert: Bool
    public var allowsHeartRateAlert: Bool
    /// Step display names reach the watch. When false the stock Work and Recovery labels appear instead.
    public var showsStepNames: Bool
    /// Plain words about what the watch will and will not show for this activity.
    public var lines: [String]
}

/// Pure tier decisions (annex E "Capability tiers"). Tiers are keyed by supports checks plus the explicit older
/// watch setting, never by version sniffing.
public enum CapabilityTiering {
    /// Tier 3 when no watch is usable, tier 2 when the person set "My watch runs watchOS 10", else tier 1.
    public static func tier(for report: CapabilityReport) -> WatchTier {
        if !report.watchAvailable { return .noWatch }
        if report.olderWatchSetting { return .olderWatch }
        return .standard
    }

    /// Decides what an activity may carry. Run power alerts are outdoor only whatever the report says
    /// (annex E "Alerts"), swim steps take heart rate alerts only, and alerts are always explicit ranges.
    public static func delivery(for activity: CompiledActivity, report: CapabilityReport) -> ActivityDelivery {
        let tier = tier(for: report)
        let word = sportWord(activity.sport)

        if tier == .noWatch {
            // The phone player has no device limits, so it keeps every target (annex E tier 3).
            return ActivityDelivery(
                activity: activity, tier: tier, delivery: .phoneOnly,
                allowsDistanceGoal: true, allowsTimeGoal: true,
                allowsDistanceWithTimeGoal: activity.sport == .swim && activity.location == .pool,
                allowsSpeedAlert: activity.sport == .run,
                allowsPowerAlert: activity.sport == .bike || (activity.sport == .run && activity.location == .outdoor),
                allowsHeartRateAlert: true,
                showsStepNames: true,
                lines: ["No watch is connected, so the phone player runs this \(word) session and shows every target."])
        }

        guard let capability = report.capability(for: activity), capability.supportsActivity else {
            return phoneOnly(
                activity, tier,
                "Your watch cannot take this \(word) workout, so it stays on your phone. Use the session card and the phone player.")
        }

        let isPoolSwim = activity.sport == .swim && activity.location == .pool

        if tier == .olderWatch && isPoolSwim {
            if capability.supportsDistanceGoal {
                return ActivityDelivery(
                    activity: activity, tier: tier, delivery: .goalOnlyWorkout,
                    allowsDistanceGoal: true, allowsTimeGoal: false, allowsDistanceWithTimeGoal: false,
                    allowsSpeedAlert: false, allowsPowerAlert: false, allowsHeartRateAlert: false,
                    showsStepNames: false,
                    lines: [
                        "This swim goes to your watch as a total distance goal only. The sets are on the session card and the phone player."
                    ])
            }
            return phoneOnly(
                activity, tier,
                "Your watch cannot take a pool swim goal, so this swim stays on your phone. Use the printed set card and the phone player.")
        }

        let older = tier == .olderWatch
        let namesShown = !older && report.supportsStepDisplayNames
        var lines: [String] = []
        if older {
            lines.append("Steps show the stock Work and Recovery labels on your watch. Your phone shows the named steps.")
        } else if !report.supportsStepDisplayNames {
            lines.append("Your watch shows the stock Work and Recovery labels. Your phone shows the named steps.")
        } else {
            lines.append("Your watch shows each step by name with its goal.")
        }

        return ActivityDelivery(
            activity: activity, tier: tier, delivery: .customWorkout,
            allowsDistanceGoal: capability.supportsDistanceGoal,
            allowsTimeGoal: capability.supportsTimeGoal,
            allowsDistanceWithTimeGoal: !older && isPoolSwim && capability.supportsDistanceWithTimeGoal,
            allowsSpeedAlert: activity.sport == .run && capability.supportsSpeedRangeAlert,
            allowsPowerAlert: allowsPower(activity, capability),
            allowsHeartRateAlert: capability.supportsHeartRateRangeAlert,
            showsStepNames: namesShown,
            lines: lines)
    }

    /// One plain sentence per compiled activity about where it will run, for a settings or session card summary.
    public static func summary(for report: CapabilityReport) -> [String] {
        var seen: [String] = []
        for activity in CapabilityReport.compiledActivities {
            for line in delivery(for: activity, report: report).lines where !seen.contains(line) {
                seen.append(line)
            }
        }
        return seen
    }

    private static func allowsPower(_ activity: CompiledActivity, _ capability: ActivityCapability) -> Bool {
        switch activity.sport {
        case .bike: return capability.supportsPowerRangeAlert
        case .run: return activity.location == .outdoor && capability.supportsPowerRangeAlert
        case .swim: return false
        }
    }

    private static func phoneOnly(_ activity: CompiledActivity, _ tier: WatchTier, _ line: String) -> ActivityDelivery {
        ActivityDelivery(
            activity: activity, tier: tier, delivery: .phoneOnly,
            allowsDistanceGoal: false, allowsTimeGoal: false, allowsDistanceWithTimeGoal: false,
            allowsSpeedAlert: false, allowsPowerAlert: false, allowsHeartRateAlert: false,
            showsStepNames: false, lines: [line])
    }

    static func sportWord(_ sport: Sport) -> String {
        switch sport {
        case .swim: return "swim"
        case .bike: return "bike"
        case .run: return "run"
        }
    }
}
