import Foundation
import BricklinePlanKit

/// Everything onboarding collects. Persisted as one JSON blob so the flow can be redone or reset in one call.
/// The plan engine will read this to build the plan; until it lands the demo plan ignores everything except `tracker`.
enum RaceChoice: String, Codable, CaseIterable, Identifiable {
    case superSprint, sprint, olympic, half
    var id: String { rawValue }
    var title: String {
        switch self {
        case .superSprint: "Super sprint"
        case .sprint: "Sprint"
        case .olympic: "Olympic"
        case .half: "Half iron (70.3)"
        }
    }
    /// Plain distances, so nobody has to know what "Olympic" means.
    var swimMeters: Int { switch self { case .superSprint: 400; case .sprint: 750; case .olympic: 1500; case .half: 1900 } }
    var bikeKm: Int { switch self { case .superSprint: 10; case .sprint: 20; case .olympic: 40; case .half: 90 } }
    var runKm: Double { switch self { case .superSprint: 2.5; case .sprint: 5; case .olympic: 10; case .half: 21.1 } }
    /// True for the shortest race, made for people who have never done a triathlon.
    var isBeginnerRace: Bool { self == .superSprint }
    var summary: String {
        "Swim \(swimMeters) m, bike \(bikeKm) km, run \(runKm == runKm.rounded() ? String(Int(runKm)) : String(runKm)) km"
    }
    var blurb: String {
        switch self {
        case .superSprint: "The gentlest race, made for first timers. Most people finish in 45 to 75 minutes. Distances vary a little between events, so check yours."
        case .sprint: "A short race. A good first triathlon: about 1 to 1.5 hours for most people."
        case .olympic: "Twice the sprint. Most people finish in 2.5 to 3.5 hours."
        case .half: "Half of an Ironman. A long day: most people finish in 5 to 7 hours."
        }
    }
    var typicalWeeks: String {
        switch self { case .superSprint: "8 to 12 weeks"; case .sprint: "8 to 12 weeks"; case .olympic: "10 to 16 weeks"; case .half: "14 to 24 weeks" }
    }
}

enum ExperienceChoice: String, Codable, CaseIterable, Identifiable {
    case firstTimer, intermediate, experienced
    var id: String { rawValue }
    var title: String {
        switch self { case .firstTimer: "First triathlon"; case .intermediate: "Done a few"; case .experienced: "Experienced" }
    }
    var blurb: String {
        switch self {
        case .firstTimer: "New to triathlon, or coming back after a long break. Shorter hard efforts, more easy time."
        case .intermediate: "A few races behind you and a regular training habit."
        case .experienced: "Years of structured training. Comfortable with hard sessions."
        }
    }
}

/// The devices the athlete wears. They decide how sessions reach the athlete (only an Apple Watch takes sessions on
/// the wrist) and where recovery data (sleep, resting heart rate, heart rate variability) can come from.
enum DeviceChoice: String, Codable, CaseIterable, Identifiable {
    case appleWatch, whoop, oura, garmin, otherWatch, phoneOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appleWatch: "Apple Watch"
        case .whoop: "WHOOP band"
        case .oura: "Oura ring"
        case .garmin: "Garmin watch"
        case .otherWatch: "Another watch or band"
        case .phoneOnly: "Just my phone"
        }
    }
    /// The short product name used in sentences and on the Connections screen.
    var shortName: String {
        switch self {
        case .appleWatch: "Apple Watch"
        case .whoop: "WHOOP"
        case .oura: "Oura"
        case .garmin: "Garmin"
        case .otherWatch: "Your other device"
        case .phoneOnly: "Your phone"
        }
    }
    var symbol: String {
        switch self {
        case .appleWatch: "applewatch"
        case .whoop: "waveform.path.ecg"
        case .oura: "circle.dashed"
        case .garmin: "figure.run"
        case .otherWatch: "dot.radiowaves.left.and.right"
        case .phoneOnly: "iphone"
        }
    }
    /// What this device gives you, in plain words. Heart rate variability is spelled out; the step links to its glossary entry.
    var blurb: String {
        switch self {
        case .appleWatch:
            return "Send each session to the Workout app on your watch, with alerts at the right pace. Your sleep, resting heart rate and heart rate variability come from Apple Health."
        case .whoop:
            return "Your sleep, resting heart rate and heart rate variability reach TriSpike through Apple Health for now. A direct WHOOP connection is coming soon. Follow sessions on your phone."
        case .oura:
            return "Your sleep, resting heart rate and heart rate variability reach TriSpike through Apple Health for now. A direct Oura connection is coming soon. Follow sessions on your phone."
        case .garmin:
            return "Sleep and resting heart rate come through Apple Health when Garmin Connect shares them. Heart rate variability does not come through. Start your recording on your Garmin as usual."
        case .otherWatch:
            return "Follow each session on your phone. Start your recording on your own device as usual. TriSpike does not read its data."
        case .phoneOnly:
            return "Follow each session on your phone with voice cues. No gear needed, and no recovery data is used."
        }
    }
    /// WHOOP and Oura are early: they work through Apple Health and a direct connection is not built yet.
    var isBeta: Bool { self == .whoop || self == .oura }
    var canReceiveSessionsOnWrist: Bool { self == .appleWatch }
    /// The recovery source this device feeds in the engine. Nil for devices TriSpike cannot read from.
    var readinessSource: ReadinessSource? {
        switch self {
        case .appleWatch: .appleWatch
        case .whoop: .whoop
        case .oura: .oura
        case .garmin: .garmin
        case .otherWatch, .phoneOnly: nil
        }
    }
}

/// The multi select rules for the device cards, kept apart from the view so they can be tested.
enum DeviceSelection {
    /// Tapping a card. "Just my phone" is exclusive: choosing it clears every device, and choosing any device clears it.
    /// Turning off the last device falls back to "Just my phone", so the set is never empty.
    static func toggled(_ device: DeviceChoice, in current: Set<DeviceChoice>) -> Set<DeviceChoice> {
        var next = current
        if device == .phoneOnly { return [.phoneOnly] }
        next.remove(.phoneOnly)
        if next.contains(device) { next.remove(device) } else { next.insert(device) }
        return next.isEmpty ? [.phoneOnly] : next
    }

    /// A set made valid: never empty, and "Just my phone" never together with a device.
    static func normalized(_ devices: Set<DeviceChoice>) -> Set<DeviceChoice> {
        if devices.isEmpty { return [.phoneOnly] }
        if devices.count > 1 { return devices.subtracting([.phoneOnly]) }
        return devices
    }

    /// Cards in the order shown on screen.
    static let displayOrder: [DeviceChoice] = [.appleWatch, .whoop, .oura, .garmin, .otherWatch, .phoneOnly]
}

struct SetupData: Codable, Equatable {
    var hasOnboarded = false
    var acknowledged = false
    var raceChoice: RaceChoice = .olympic
    var raceName = ""
    var raceDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    var noRaceYet = false
    var experience: ExperienceChoice = .firstTimer
    var hoursPerWeek = 7
    /// Calendar weekday numbers, 1 = Sunday ... 7 = Saturday.
    var trainingDays: Set<Int> = [2, 3, 4, 5, 7, 1]
    var poolDays: Set<Int> = [2, 5]
    /// Every device the athlete wears. Never empty; "Just my phone" is only ever alone.
    var devices: Set<DeviceChoice> = [.phoneOnly]
    var hasPowerMeter = false
    var hasTrainer = false
    /// Plain answers to the starting point questions. Nil means not answered, and the plan then follows `experience`.
    var swimAbility: StartAbility?
    var bikeAbility: StartAbility?
    var runAbility: StartAbility?
    var useEstimates = true
    var cssSecondsPer100: Double?
    var ftpWatts: Int?
    var thresholdPaceSecondsPerKm: Double?
}

extension SetupData {
    /// Only an Apple Watch takes sessions on the wrist.
    var canSendToWatch: Bool { devices.contains(.appleWatch) }

    /// The device the "how you will follow this" copy talks about: the watch when there is one, else the first
    /// other device, else the phone.
    var followDevice: DeviceChoice {
        if devices.contains(.appleWatch) { return .appleWatch }
        for d in [DeviceChoice.whoop, .oura, .garmin, .otherWatch] where devices.contains(d) { return d }
        return .phoneOnly
    }

    /// Devices the engine can read recovery data from.
    var readinessSources: Set<ReadinessSource> { Set(devices.compactMap(\.readinessSource)) }

    /// The connected recovery sources in the engine's default order (Oura, WHOOP, Apple Watch, Garmin).
    var recoveryOrder: [ReadinessSource] { ReadinessSource.defaultOrder.filter { readinessSources.contains($0) } }

    /// Devices in the order the cards are shown, for lists.
    var orderedDevices: [DeviceChoice] { DeviceSelection.displayOrder.filter { devices.contains($0) } }

    /// Whether any connected device can supply recovery data.
    var hasRecoverySource: Bool { !readinessSources.isEmpty }

    /// Whether a connected device reports heart rate variability, the only signal that can ease a session.
    /// Garmin supplies sleep and resting heart rate only.
    var hasHRVSource: Bool { readinessSources.contains { $0.hrvKind != nil } }
}

extension SetupData {
    private enum LegacyKeys: String, CodingKey { case tracker }

    /// Reads setup saved by any earlier version. The old single `tracker` key becomes a one device set, and a stored
    /// `devices` list is made valid, so nothing stored can leave the app with an empty or contradictory set.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? hasOnboarded
        acknowledged = try c.decodeIfPresent(Bool.self, forKey: .acknowledged) ?? acknowledged
        raceChoice = try c.decodeIfPresent(RaceChoice.self, forKey: .raceChoice) ?? raceChoice
        raceName = try c.decodeIfPresent(String.self, forKey: .raceName) ?? raceName
        raceDate = try c.decodeIfPresent(Date.self, forKey: .raceDate) ?? raceDate
        noRaceYet = try c.decodeIfPresent(Bool.self, forKey: .noRaceYet) ?? noRaceYet
        experience = try c.decodeIfPresent(ExperienceChoice.self, forKey: .experience) ?? experience
        hoursPerWeek = try c.decodeIfPresent(Int.self, forKey: .hoursPerWeek) ?? hoursPerWeek
        trainingDays = try c.decodeIfPresent(Set<Int>.self, forKey: .trainingDays) ?? trainingDays
        poolDays = try c.decodeIfPresent(Set<Int>.self, forKey: .poolDays) ?? poolDays
        hasPowerMeter = try c.decodeIfPresent(Bool.self, forKey: .hasPowerMeter) ?? hasPowerMeter
        hasTrainer = try c.decodeIfPresent(Bool.self, forKey: .hasTrainer) ?? hasTrainer
        useEstimates = try c.decodeIfPresent(Bool.self, forKey: .useEstimates) ?? useEstimates
        swimAbility = try c.decodeIfPresent(StartAbility.self, forKey: .swimAbility)
        bikeAbility = try c.decodeIfPresent(StartAbility.self, forKey: .bikeAbility)
        runAbility = try c.decodeIfPresent(StartAbility.self, forKey: .runAbility)
        cssSecondsPer100 = try c.decodeIfPresent(Double.self, forKey: .cssSecondsPer100)
        ftpWatts = try c.decodeIfPresent(Int.self, forKey: .ftpWatts)
        thresholdPaceSecondsPerKm = try c.decodeIfPresent(Double.self, forKey: .thresholdPaceSecondsPerKm)

        if let stored = try c.decodeIfPresent([DeviceChoice].self, forKey: .devices) {
            devices = DeviceSelection.normalized(Set(stored))
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            if let old = try? legacy.decodeIfPresent(DeviceChoice.self, forKey: .tracker) {
                devices = [old]
            }
        }
    }
}

@MainActor
final class UserSetup: ObservableObject {
    static let shared = UserSetup()
    private let key = "brickline.setup.v1"

    @Published var data: SetupData {
        didSet { if data != oldValue { save() } }
    }

    private init() {
        if let raw = UserDefaults.standard.data(forKey: "brickline.setup.v1"),
           let decoded = try? JSONDecoder().decode(SetupData.self, from: raw) {
            data = decoded
        } else {
            data = SetupData()
        }
    }

    var hasOnboarded: Bool { data.hasOnboarded }
    var devices: Set<DeviceChoice> { data.devices }
    var followDevice: DeviceChoice { data.followDevice }
    var canSendToWatch: Bool { data.canSendToWatch }

    /// Tap on a device card (onboarding) or a change from the Connections screen.
    func toggleDevice(_ device: DeviceChoice) {
        data.devices = DeviceSelection.toggled(device, in: data.devices)
    }

    func reset() { data = SetupData() }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }
}
