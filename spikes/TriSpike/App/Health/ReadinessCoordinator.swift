import Foundation
import SwiftUI
import BricklinePlanKit

// Holds what the readiness rules need between launches (which source is in use, when it changed, which days the
// athlete kept the planned session, when each source last delivered) and the nights read from Apple Health.
// The readings themselves are held in memory only and are read again from Health on every refresh.

/// Saved on the phone between launches. Contains no readings.
struct ReadinessState: Codable, Equatable {
    /// The source the athlete chose. Nil means the engine's default order (Oura, WHOOP, Apple Watch, Garmin).
    var preferredSource: ReadinessSource?
    /// The source the engine used on the previous run (rule 9: a change of source restarts calibration).
    var activeSource: ReadinessSource?
    /// The day the source changed, when it did.
    var sourceChangedOn: Date?
    /// Days the athlete tapped Keep my planned session (rule 13: three in 14 days leaves notes only).
    var overrides: [Date] = []
    /// When each source last delivered a night.
    var lastSyncBySource: [ReadinessSource: Date] = [:]
    /// True once the Apple Health permission sheet has been shown.
    var healthAsked = false
    /// When Health was last read.
    var lastRead: Date?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case preferredSource, activeSource, sourceChangedOn, overrides, lastSyncBySource, healthAsked, lastRead
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferredSource = try c.decodeIfPresent(ReadinessSource.self, forKey: .preferredSource)
        activeSource = try c.decodeIfPresent(ReadinessSource.self, forKey: .activeSource)
        sourceChangedOn = try c.decodeIfPresent(Date.self, forKey: .sourceChangedOn)
        overrides = try c.decodeIfPresent([Date].self, forKey: .overrides) ?? []
        lastSyncBySource = try c.decodeIfPresent([ReadinessSource: Date].self, forKey: .lastSyncBySource) ?? [:]
        healthAsked = try c.decodeIfPresent(Bool.self, forKey: .healthAsked) ?? false
        lastRead = try c.decodeIfPresent(Date.self, forKey: .lastRead)
    }
}

enum ReadinessStore {
    static let key = "brickline.readiness.v1"

    static func load(from defaults: UserDefaults = .standard) -> ReadinessState {
        guard let raw = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(ReadinessState.self, from: raw) else { return ReadinessState() }
        return state
    }

    static func save(_ state: ReadinessState, to defaults: UserDefaults = .standard) {
        guard let raw = try? JSONEncoder().encode(state) else { return }
        defaults.set(raw, forKey: key)
    }

    static func clear(from defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
}

@MainActor
final class ReadinessCoordinator: ObservableObject {
    /// How the last read of Health went.
    enum ReadStatus: Equatable {
        case idle
        case reading
        /// Read finished. The count is the nights found for the connected sources.
        case read(nights: Int)
        case unavailable
        case failed
    }

    static let shared = ReadinessCoordinator(reader: ReadinessCoordinator.defaultReader(), defaults: .standard)

    @Published private(set) var state: ReadinessState
    @Published private(set) var nights: [ReadinessNight] = []
    @Published private(set) var status: ReadStatus = .idle

    let reader: RecoveryReading
    private let defaults: UserDefaults

    /// Days of history read: the 42 day window the rules use, plus a margin.
    static let historyDays = 60

    init(reader: RecoveryReading, defaults: UserDefaults) {
        self.reader = reader
        self.defaults = defaults
        self.state = ReadinessStore.load(from: defaults)
    }

    /// The simulator and screenshot runs can feed made up nights: `-readinessFixture none|calibrating|onTrack|below|stale`.
    /// Real runs read Apple Health. The fixture writes nights for every device name; only the connected ones are used.
    static func defaultReader() -> RecoveryReading {
        if let raw = LaunchArgs.value("-readinessFixture"),
           let scenario = FixtureRecoveryReader.Scenario.allCases.first(where: { LaunchArgs.normalized($0.rawValue) == LaunchArgs.normalized(raw) }) {
            return FixtureRecoveryReader(scenario: scenario, sourceNames: ["Apple Watch", "WHOOP", "Oura", "Garmin"])
        }
        #if canImport(HealthKit)
        return HealthRecoveryReader()
        #else
        return FixtureRecoveryReader(scenario: .none)
        #endif
    }

    // MARK: Inputs for the engine

    /// The nights of the sources the athlete connected. A night from a device that was disconnected is left out.
    func connectedNights(for data: SetupData) -> [ReadinessNight] {
        let sources = data.readinessSources
        return nights.filter { sources.contains($0.source) }
    }

    /// Everything the engine needs for readiness. Nil when no connected device can supply recovery data, in which case
    /// readiness does not run and the plan is untouched.
    func inputs(for data: SetupData) -> ReadinessInputs? {
        guard data.hasRecoverySource else { return nil }
        let sources = data.readinessSources
        let preferred = state.preferredSource.flatMap { sources.contains($0) ? $0 : nil }
        return ReadinessInputs(
            nights: connectedNights(for: data), checkIns: [], overrides: state.overrides,
            lastSyncDate: nil, lastSyncBySource: state.lastSyncBySource,
            preferredRecoverySource: preferred,
            activeSource: state.activeSource.flatMap { sources.contains($0) ? $0 : nil },
            sourceChangedOn: state.sourceChangedOn)
    }

    // MARK: Reading Health

    /// Reads the last 60 days from Health. Safe to call often: it does nothing while a read is running, and it never
    /// shows a permission sheet.
    func refresh(now: Date = Date(), calendar: Calendar = EngineBuilder.calendar()) async {
        guard status != .reading else { return }
        status = .reading
        let outcome = await reader.fetchNights(now: now, days: Self.historyDays, calendar: calendar)
        apply(outcome, now: now)
    }

    /// Takes the result of a read. Separate from `refresh` so a test can feed it directly.
    func apply(_ outcome: RecoveryReadOutcome, now: Date) {
        switch outcome {
        case .nights(let list):
            nights = list
            var next = state
            next.lastRead = now
            var newest: [ReadinessSource: Date] = [:]
            for n in list { newest[n.source] = max(newest[n.source] ?? .distantPast, n.date) }
            for (source, date) in newest { next.lastSyncBySource[source] = date }
            update(next)
            status = .read(nights: list.count)
        case .unavailable:
            status = .unavailable
        case .failed:
            status = .failed
        }
    }

    /// Shows the Apple Health permission sheet, then reads.
    @discardableResult
    func requestHealthAccess(now: Date = Date()) async -> Bool {
        let ok = await reader.requestAccess()
        var next = state
        next.healthAsked = true
        update(next)
        if !ok { status = .unavailable }
        await refresh(now: now)
        return ok
    }

    // MARK: Athlete actions

    /// Keep my planned session: remembers the day, so the rebuilt plan puts the original session back.
    func keepPlannedSession(on day: Date, calendar: Calendar = EngineBuilder.calendar()) {
        let start = calendar.startOfDay(for: day)
        guard !state.overrides.contains(start) else { return }
        var next = state
        next.overrides.append(start)
        // Rule 13 only looks 14 days back, so older taps are dropped.
        next.overrides = next.overrides.filter { calendar.daysBetween($0, start) < 30 }
        update(next)
    }

    /// The athlete chose a recovery source, or nil for automatic. A change restarts calibration (rule 9).
    func setPreferred(_ source: ReadinessSource?, today: Date, calendar: Calendar = EngineBuilder.calendar()) {
        guard source != state.preferredSource else { return }
        var next = state
        next.preferredSource = source
        next.sourceChangedOn = calendar.startOfDay(for: today)
        update(next)
    }

    /// A device was connected or removed. Calibration restarts only when the top source in the default order changes:
    /// adding a second device that is not first in line leaves the source in use alone.
    func devicesChanged(from old: SetupData, to new: SetupData, today: Date, calendar: Calendar = EngineBuilder.calendar()) {
        var next = state
        // A choice for a device that is no longer connected is dropped, even when the top ranked source stays the same.
        if let preferred = next.preferredSource, !new.readinessSources.contains(preferred) { next.preferredSource = nil }
        guard old.recoveryOrder.first != new.recoveryOrder.first else { update(next); return }
        next.sourceChangedOn = calendar.startOfDay(for: today)
        update(next)
    }

    /// Remembers which source the engine used and when it changed, so the next run can tell a change of source.
    func absorb(_ assessment: ReadinessAssessment?) {
        guard let assessment else { return }
        var next = state
        next.activeSource = assessment.source?.source
        if let changed = assessment.sourceChangedOn { next.sourceChangedOn = changed }
        update(next)
    }

    func reset() {
        ReadinessStore.clear(from: defaults)
        state = ReadinessState()
        nights = []
        status = .idle
    }

    private func update(_ next: ReadinessState) {
        guard next != state else { return }
        state = next
        ReadinessStore.save(next, to: defaults)
    }
}

extension ReadinessCoordinator {
    /// Reads Health, then lets the engine run once on the new nights and remembers which source it chose.
    func refreshAndSync() async {
        await refresh()
        absorb(EngineAdapter.shared.model.readiness)
    }
}
