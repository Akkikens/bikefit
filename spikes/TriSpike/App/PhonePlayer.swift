import ActivityKit
import AVFoundation
import Foundation
import HealthKit
import UIKit
import UserNotifications

/// Spike 6: the phone interval player with the spec annex E background model.
/// 1 audio background mode plus playback session for spoken cues;
/// 2 every remaining step boundary pre scheduled as a local notification (the guaranteed cue if the process suspends);
/// 3 timing from wall clock dates, never accumulated timers; pause, previous and next rebuild the boundaries;
/// 4 idle timer disabled while foregrounded;
/// 5 a Live Activity countdown rendered by the system;
/// 6 no promise of background haptics.
/// Every in process cue logs its actual versus expected time, so missing or late entries show when iOS suspended us.
@MainActor
final class PhonePlayer: ObservableObject {
    /// One player step. `sport` drives the Health workout type; `cue` is the prebuilt phrase ("Threshold, rep 2 of 2")
    /// that every voice, notification and announcement path uses, so they all say the same thing.
    struct Step {
        var name: String
        var seconds: TimeInterval
        var target: String? = nil
        var sport: Sport = .run
        var cue: String? = nil
        var spokenName: String { cue ?? name }
    }

    /// What the last session amounted to, for Today to close the loop. Cleared by the next start.
    struct Result: Equatable {
        var name: String
        /// Active time: wall clock from start to end minus paused time. Skipped steps are not counted as done.
        var seconds: TimeInterval
        var completed: Bool
        /// True once the workout reached Health. False for smoke runs, denied access or an unfinished save.
        var saved: Bool = false
    }

    /// A contiguous run of steps in one sport, with the wall clock interval the player actually spent in it.
    private struct Leg {
        var sport: Sport
        var start: Date
        var end: Date?
    }

    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var stepIndex = 0
    @Published private(set) var steps: [Step] = []
    @Published private(set) var now = Date()
    @Published var voiceOn = true
    @Published private(set) var lastResult: Result?

    private(set) var sessionName = ""
    private(set) var sport: Sport = .run
    private var startDate = Date()
    /// The real start. `startDate` is shifted by skips so `elapsed` follows the plan; this one never moves.
    private var originalStart = Date()
    private var legs: [Leg] = []
    private var boundaries: [Date] = []
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var ticker: Timer?
    private var activity: Activity<PlayerActivityAttributes>?
    private let speech = AVSpeechSynthesizer()
    private let health = HKHealthStore()
    private let notificationPrefix = "trispike.boundary."
    private var notificationsAllowed = false
    private var log: SpikeLog { SpikeLog.shared }

    /// Smoke mode (simulator, unattended): skips the notification and Health prompts, which cannot be answered headless.
    private(set) var smoke = false
    static let smokeTest: [Step] = (0..<3).map { Step(name: "Smoke \($0 + 1)", seconds: 5) }
    static let quickTest: [Step] = (0..<6).map { Step(name: $0.isMultiple(of: 2) ? "Work \($0 / 2 + 1)" : "Easy", seconds: 30) }
    static let specTest: [Step] = [Step(name: "Warm up", seconds: 300)]
        + (0..<3).flatMap { i in [Step(name: "Tempo \(i + 1)", seconds: 300), Step(name: "Easy", seconds: 120)] }
        + [Step(name: "Cool down", seconds: 240)]

    var totalSeconds: TimeInterval { steps.reduce(0) { $0 + $1.seconds } }
    /// Seconds of session time completed, excluding paused time.
    var elapsed: TimeInterval {
        let reference = pausedAt ?? now
        return max(0, min(totalSeconds, reference.timeIntervalSince(startDate) - pausedTotal))
    }
    var stepRemaining: TimeInterval {
        guard isRunning, stepIndex < boundaries.count else { return 0 }
        let reference = pausedAt ?? now
        return max(0, boundaries[stepIndex].timeIntervalSince(reference))
    }

    func start(name: String, sport: Sport, steps: [Step], smoke: Bool = false) async {
        guard !isRunning, !steps.isEmpty else { return }
        self.smoke = smoke
        sessionName = name
        self.sport = sport
        self.steps = steps
        lastResult = nil
        startDate = Date()
        originalStart = startDate
        legs = [Leg(sport: steps[0].sport, start: startDate, end: nil)]
        pausedAt = nil
        pausedTotal = 0
        rebuildBoundaries(from: 0, at: startDate)
        stepIndex = 0
        isRunning = true
        isPaused = false
        now = Date()
        log.record("player", "start \(name)", "\(steps.count) steps, \(Int(totalSeconds / 60)) min, ends \(boundaries.last!.formatted(date: .omitted, time: .standard))")

        configureAudio()
        if smoke {
            log.record("player", "boundary notifications", "skipped in smoke mode")
        } else {
            let center = UNUserNotificationCenter.current()
            notificationsAllowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            log.record("player", "notification authorization", "\(notificationsAllowed)", pass: notificationsAllowed)
            await rescheduleNotifications()
        }
        startLiveActivity()
        UIApplication.shared.isIdleTimerDisabled = true
        speak("\(name). \(steps[0].spokenName), \(spoken(steps[0].seconds)).")
        startTicker()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        pausedAt = Date()
        isPaused = true
        ticker?.invalidate()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
        speak("Paused.")
        log.record("player", "pause", "at step \(stepIndex + 1)")
        updateLiveActivity()
    }

    func resume() async {
        guard isRunning, isPaused, let p = pausedAt else { return }
        let gap = Date().timeIntervalSince(p)
        pausedTotal += gap
        boundaries = boundaries.map { $0.addingTimeInterval(gap) }
        pausedAt = nil
        isPaused = false
        now = Date()
        await rescheduleNotifications()
        speak("Resuming. \(steps[stepIndex].spokenName).")
        log.record("player", "resume", String(format: "paused %.0f s", gap))
        updateLiveActivity()
        startTicker()
    }

    /// Jump to the previous or next step; the step starts fresh from now.
    func skip(by delta: Int) async {
        guard isRunning else { return }
        let target = stepIndex + delta
        guard target >= 0, target < steps.count else { return }
        let reference = pausedAt ?? Date()
        // Session time spent so far is kept honest: elapsed becomes the sum of steps before the target.
        let before = steps[..<target].reduce(0) { $0 + $1.seconds }
        startDate = reference.addingTimeInterval(-before - pausedTotal)
        rebuildBoundaries(from: target, at: reference)
        stepIndex = target
        noteStepEntered(target, at: reference)
        now = Date()
        if !isPaused { await rescheduleNotifications() }
        speak("\(steps[target].spokenName), \(spoken(steps[target].seconds)).")
        log.record("player", delta < 0 ? "previous step" : "next step", "now step \(target + 1)")
        updateLiveActivity()
    }

    func stop(save: Bool) async {
        guard isRunning else { return }
        ticker?.invalidate()
        ticker = nil
        let end = min(pausedAt ?? Date(), boundaries.last ?? Date())
        let done = max(0, end.timeIntervalSince(originalStart) - pausedTotal)
        // Published before isRunning flips, so Today already has the result when the player dismisses.
        lastResult = Result(name: sessionName, seconds: done, completed: stepIndex >= steps.count)
        if !legs.isEmpty { legs[legs.count - 1].end = end }
        isRunning = false
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        log.record("player", "stop", "elapsed \(Int(done)) s, save=\(save)")
        if save {
            let ok = await saveWorkout()
            lastResult?.saved = ok
        }
    }

    /// Called on foreground: rebuild state from the wall clock (spec annex G, player suspended mid session).
    func resyncAfterForeground() {
        guard isRunning, !isPaused else { return }
        now = Date()
        let expectedIndex = boundaries.firstIndex { $0 > now } ?? boundaries.count
        log.record("player", "foreground resync", "wall clock says step \(expectedIndex + 1), in process state was step \(stepIndex + 1)", pass: true)
        tick()
    }

    private var notificationIDs: [String] { steps.indices.map { notificationPrefix + "\($0)" } }

    private func rebuildBoundaries(from index: Int, at reference: Date) {
        var b = boundaries.count == steps.count ? boundaries : Array(repeating: reference, count: steps.count)
        var t = reference
        for i in index..<steps.count {
            t = t.addingTimeInterval(steps[i].seconds)
            b[i] = t
        }
        boundaries = b
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        now = Date()
        guard isRunning, !isPaused else { return }
        let newIndex = boundaries.firstIndex { $0 > now } ?? boundaries.count
        guard newIndex > stepIndex else { return }
        // Report every boundary we crossed, so a suspension shows up as one late batch.
        for crossed in stepIndex..<newIndex {
            let lateBy = now.timeIntervalSince(boundaries[crossed])
            let state = UIApplication.shared.applicationState == .active ? "foreground" : "background"
            log.record("player", "in process cue \(crossed + 1)", String(format: "late by %.1f s, app %@", lateBy, state), pass: lateBy < 2)
        }
        // A sport change is stamped at the boundary actually crossed, even if the app was suspended past several.
        var entered = stepIndex + 1
        while entered <= newIndex, entered < steps.count {
            noteStepEntered(entered, at: boundaries[entered - 1])
            entered += 1
        }
        stepIndex = newIndex
        if stepIndex >= steps.count {
            speak("Session complete.")
            let save = !smoke
            Task { await stop(save: save) }
            return
        }
        let step = steps[stepIndex]
        speak("\(step.spokenName), \(spoken(step.seconds))\(step.target.map { ", \($0)" } ?? "").")
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
        guard voiceOn else { return }
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        seconds >= 60 ? "\(Int(seconds / 60)) minutes" : "\(Int(seconds)) seconds"
    }

    private func rescheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIDs)
        guard notificationsAllowed, !smoke else { return }
        var scheduled = 0
        for i in stepIndex..<boundaries.count {
            let content = UNMutableNotificationContent()
            if i + 1 < steps.count {
                content.title = steps[i + 1].spokenName
                content.body = "\(spoken(steps[i + 1].seconds))."
            } else {
                content.title = "Session complete"
                content.body = sessionName
            }
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let interval = max(1, boundaries[i].timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notificationPrefix + "\(i)", content: content, trigger: trigger))
            scheduled += 1
        }
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(notificationPrefix) }.count
        log.record("player", "boundary notifications scheduled", "\(pending) of \(scheduled)", pass: pending == scheduled)
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

    /// Closes the open leg and opens a new one when the step just entered is a different sport.
    private func noteStepEntered(_ index: Int, at date: Date) {
        guard steps.indices.contains(index), let last = legs.last, last.sport != steps[index].sport else { return }
        legs[legs.count - 1].end = max(date, last.start)
        legs.append(Leg(sport: steps[index].sport, start: max(date, last.start), end: nil))
    }

    private func configuration(for sport: Sport) -> HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        switch sport {
        case .swim:
            config.activityType = .swimming
            config.locationType = .indoor
            config.swimmingLocationType = .pool
        case .bike:
            // The phone player is the trainer experience; an outdoor ride runs on the watch.
            config.activityType = .cycling
            config.locationType = .indoor
        case .run:
            config.activityType = .running
            config.locationType = .outdoor
        }
        return config
    }

    /// Spec annex E: save with HKWorkoutBuilder, duration only, never fabricated energy, distance or heart rate.
    /// One workout per contiguous leg of one sport, split where the player actually crossed (a brick is a ride, then a run).
    /// Returns true when every leg was saved.
    private func saveWorkout() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            log.record("player", "save workout", "Health unavailable", pass: false)
            return false
        }
        let toSave = legs.compactMap { leg -> (sport: Sport, start: Date, end: Date)? in
            guard let end = leg.end, end > leg.start else { return nil }
            return (leg.sport, leg.start, end)
        }
        guard !toSave.isEmpty else {
            log.record("player", "save workout", "no time recorded", pass: false)
            return false
        }
        var allSaved = true
        do {
            try await health.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            for leg in toSave {
                let builder = HKWorkoutBuilder(healthStore: health, configuration: configuration(for: leg.sport), device: .local())
                try await builder.beginCollection(at: leg.start)
                try await builder.addMetadata(["TriSpikeSession": sessionName])
                try await builder.endCollection(at: leg.end)
                let workout = try await builder.finishWorkout()
                if workout == nil { allSaved = false }
                log.record("player", "save workout", workout.map { "\(leg.sport.rawValue) saved \(Int($0.duration)) s, source \($0.sourceRevision.source.name)" } ?? "\(leg.sport.rawValue) finishWorkout returned nil", pass: workout != nil)
            }
        } catch {
            log.record("player", "save workout", "error \(error)", pass: false)
            return false
        }
        return allSaved
    }
}
