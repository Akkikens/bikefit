import Foundation

/// Everything onboarding collects. Persisted as one JSON blob so the flow can be redone or reset in one call.
/// The plan engine will read this to build the plan; until it lands the demo plan ignores everything except `tracker`.
enum RaceChoice: String, Codable, CaseIterable, Identifiable {
    case sprint, olympic, half
    var id: String { rawValue }
    var title: String {
        switch self { case .sprint: "Sprint"; case .olympic: "Olympic"; case .half: "Half iron (70.3)" }
    }
    /// Plain distances, so nobody has to know what "Olympic" means.
    var swimMeters: Int { switch self { case .sprint: 750; case .olympic: 1500; case .half: 1900 } }
    var bikeKm: Int { switch self { case .sprint: 20; case .olympic: 40; case .half: 90 } }
    var runKm: Double { switch self { case .sprint: 5; case .olympic: 10; case .half: 21.1 } }
    var summary: String {
        "Swim \(swimMeters) m, bike \(bikeKm) km, run \(runKm == runKm.rounded() ? String(Int(runKm)) : String(runKm)) km"
    }
    var blurb: String {
        switch self {
        case .sprint: "The shortest race. A good first triathlon: about 1 to 1.5 hours for most people."
        case .olympic: "Twice the sprint. Most people finish in 2.5 to 3.5 hours."
        case .half: "Half of an Ironman. A long day: most people finish in 5 to 7 hours."
        }
    }
    var typicalWeeks: String {
        switch self { case .sprint: "8 to 12 weeks"; case .olympic: "10 to 16 weeks"; case .half: "14 to 24 weeks" }
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

/// How the athlete records workouts today. Drives whether "Send to watch" exists at all.
enum TrackerChoice: String, Codable, CaseIterable, Identifiable {
    case appleWatch, whoop, garmin, otherWatch, phoneOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appleWatch: "Apple Watch"
        case .whoop: "WHOOP band"
        case .garmin: "Garmin watch"
        case .otherWatch: "Another watch or band"
        case .phoneOnly: "Just my phone"
        }
    }
    var symbol: String {
        switch self {
        case .appleWatch: "applewatch"
        case .whoop: "waveform.path.ecg"
        case .garmin: "figure.run"
        case .otherWatch: "dot.radiowaves.left.and.right"
        case .phoneOnly: "iphone"
        }
    }
    var blurb: String {
        switch self {
        case .appleWatch: "Send each session to the Workout app on your watch, with alerts at the right pace. You can also follow it on your phone."
        case .whoop: "Follow each session on your phone. Your WHOOP keeps recording on its own; Brickline does not read it."
        case .garmin: "Follow each session on your phone. Start your recording on your Garmin as usual."
        case .otherWatch: "Follow each session on your phone. Start your recording on your own device as usual."
        case .phoneOnly: "Follow each session on your phone with voice cues. No gear needed."
        }
    }
    var canReceiveSessionsOnWrist: Bool { self == .appleWatch }
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
    var tracker: TrackerChoice = .phoneOnly
    var hasPowerMeter = false
    var hasTrainer = false
    var useEstimates = true
    var cssSecondsPer100: Double?
    var ftpWatts: Int?
    var thresholdPaceSecondsPerKm: Double?
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
    var tracker: TrackerChoice { data.tracker }
    var canSendToWatch: Bool { data.tracker.canReceiveSessionsOnWrist }

    func reset() { data = SetupData() }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }
}
