import ActivityKit
import AVFoundation
import Foundation
import HealthKit
import UIKit
import UserNotifications

/// Spike 6: the phone interval player with the spec annex E background model.
/// 1 audio background mode plus playback session for spoken cues;
/// 2 every step boundary pre scheduled as a local notification (the guaranteed cue if the process suspends);
/// 3 timing from wall clock dates, never accumulated timers;
/// 4 idle timer disabled while foregrounded;
/// 5 a Live Activity countdown rendered by the system;
/// 6 no promise of background haptics.
/// Every in process cue logs its actual versus expected time, so missing or late entries show exactly when iOS suspended us.
@MainActor
final class PhonePlayer: ObservableObject {
    struct Step { var name: String; var seconds: TimeInterval }

    @Published private(set) var isRunning = false
    @Published private(set) var stepIndex = 0
    @Published private(set) var steps: [Step] = []
    @Published private(set) var now = Date()

    private var sessionName = ""
    private var startDate = Date()
    private var boundaries: [Date] = []
    private var ticker: Timer?
    private var activity: Activity<PlayerActivityAttributes>?
    private let speech = AVSpeechSynthesizer()
    private let health = HKHealthStore()
    private let notificationPrefix = "trispike.boundary."
    private var log: SpikeLog { SpikeLog.shared }

    static let quickTest: [Step] = (0..<6).map { Step(name: $0.isMultiple(of: 2) ? "Work \($0 / 2 + 1)" : "Easy", seconds: 30) }
    static let specTest: [Step] = [Step(name: "Warm up", seconds: 300)]
        + (0..<3).flatMap { i in [Step(name: "Tempo \(i + 1)", seconds: 300), Step(name: "Easy", seconds: 120)] }
        + [Step(name: "Cool down", seconds: 240)]

    var elapsed: TimeInterval { now.timeIntervalSince(startDate) }
    var stepRemaining: TimeInterval {
        guard isRunning, stepIndex < boundaries.count else { return 0 }
        return max(0, boundaries[stepIndex].timeIntervalSince(now))
    }

    /// Smoke mode (simulator, unattended): skips the notification and Health prompts, which cannot be answered headless.
    private(set) var smoke = false
    static let smokeTest: [Step] = (0..<3).map { Step(name: "Smoke \($0 + 1)", seconds: 5) }

    func start(name: String, steps: [Step], smoke: Bool = false) async {
        guard !isRunning else { return }
        self.smoke = smoke
        sessionName = name
        self.steps = steps
        startDate = Date()
        var t = startDate
        boundaries = steps.map { t = t.addingTimeInterval($0.seconds); return t }
        stepIndex = 0
        isRunning = true
        now = Date()
        log.record("player", "start \(name)", "\(steps.count) steps, \(Int(steps.reduce(0) { $0 + $1.seconds } / 60)) min, ends \(boundaries.last!.formatted(date: .omitted, time: .standard))")

        configureAudio()
        if smoke {
            log.record("player", "boundary notifications", "skipped in smoke mode")
        } else {
            await scheduleBoundaryNotifications()
        }
        startLiveActivity()
        UIApplication.shared.isIdleTimerDisabled = true
        speak("\(name). \(steps[0].name), \(spoken(steps[0].seconds)).")

        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop(save: Bool) async {
        guard isRunning else { return }
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        let end = min(Date(), boundaries.last ?? Date())
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: steps.indices.map { notificationPrefix + "\($0)" })
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        log.record("player", "stop", "elapsed \(Int(end.timeIntervalSince(startDate))) s, save=\(save)")
        if save { await saveWorkout(end: end) }
    }

    /// Called on foreground: rebuild state from the wall clock (spec annex G, player suspended mid session).
    func resyncAfterForeground() {
        guard isRunning else { return }
        now = Date()
        let expectedIndex = boundaries.firstIndex { $0 > now } ?? boundaries.count
        log.record("player", "foreground resync", "wall clock says step \(expectedIndex + 1), in process state was step \(stepIndex + 1)", pass: true)
        tick()
    }

    private func tick() {
        now = Date()
        guard isRunning else { return }
        let newIndex = boundaries.firstIndex { $0 > now } ?? boundaries.count
        guard newIndex != stepIndex else { return }
        // Report every boundary we crossed, so a suspension shows up as one late batch.
        for crossed in stepIndex..<newIndex {
            let expected = boundaries[crossed]
            let lateBy = now.timeIntervalSince(expected)
            let state = UIApplication.shared.applicationState == .active ? "foreground" : "background"
            log.record("player", "in process cue \(crossed + 1)", String(format: "late by %.1f s, app %@", lateBy, state), pass: lateBy < 2)
        }
        stepIndex = newIndex
        if stepIndex >= steps.count {
            speak("Session complete. Well done.")
            let save = !smoke
            Task { await stop(save: save) }
            return
        }
        let step = steps[stepIndex]
        speak("\(step.name), \(spoken(step.seconds)).")
        updateLiveActivity()
    }

    private func configureAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            log.record("player", "audio session", "playback, spokenAudio, duckOthers: active")
        } catch {
            log.record("player", "audio session", "error \(error)", pass: false)
        }
    }

    private func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        seconds >= 60 ? "\(Int(seconds / 60)) minutes" : "\(Int(seconds)) seconds"
    }

    private func scheduleBoundaryNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        log.record("player", "notification authorization", "\(granted)", pass: granted)
        guard granted else { return }
        for (i, boundary) in boundaries.enumerated() {
            let content = UNMutableNotificationContent()
            if i + 1 < steps.count {
                content.title = steps[i + 1].name
                content.body = "\(spoken(steps[i + 1].seconds)). Step \(i + 2) of \(steps.count)."
            } else {
                content.title = "Session complete"
                content.body = sessionName
            }
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let interval = max(1, boundary.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notificationPrefix + "\(i)", content: content, trigger: trigger))
        }
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(notificationPrefix) }.count
        log.record("player", "boundary notifications scheduled", "\(pending) of \(boundaries.count)", pass: pending == boundaries.count)
    }

    private func currentState() -> PlayerActivityAttributes.ContentState {
        let i = min(stepIndex, steps.count - 1)
        let stepStart = i == 0 ? startDate : boundaries[i - 1]
        return .init(stepName: steps[i].name, stepIndex: i, stepCount: steps.count, stepStart: stepStart, stepEnd: boundaries[i])
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.record("player", "live activity", "disabled in Settings or unsupported", pass: false)
            return
        }
        do {
            activity = try Activity.request(
                attributes: PlayerActivityAttributes(sessionName: sessionName),
                content: ActivityContent(state: currentState(), staleDate: boundaries.last))
            log.record("player", "live activity", "started", pass: true)
        } catch {
            log.record("player", "live activity", "error \(error)", pass: false)
        }
    }

    private func updateLiveActivity() {
        guard let activity else { return }
        let state = currentState()
        Task { await activity.update(ActivityContent(state: state, staleDate: boundaries.last)) }
    }

    /// Spec annex E: save with HKWorkoutBuilder, duration only, never fabricated energy, distance or heart rate.
    private func saveWorkout(end: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            log.record("player", "save workout", "Health unavailable", pass: false)
            return
        }
        do {
            try await health.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor
            let builder = HKWorkoutBuilder(healthStore: health, configuration: config, device: .local())
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata(["TriSpikeSession": sessionName])
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            log.record("player", "save workout", workout.map { "saved \(Int($0.duration)) s, source \($0.sourceRevision.source.name)" } ?? "finishWorkout returned nil", pass: workout != nil)
        } catch {
            log.record("player", "save workout", "error \(error)", pass: false)
        }
    }
}
