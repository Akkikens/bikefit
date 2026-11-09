import Foundation
import BricklinePlanKit
#if canImport(HealthKit)
import HealthKit
#endif

// Reads the recovery numbers the readiness rules need from Apple Health: heart rate variability, resting heart rate
// and time asleep. Everything stays on the phone. Nothing here logs a value, writes a value to a file, or sends
// anything anywhere; the readings only feed the engine in memory.

/// One reading from Health, before it is grouped into nights.
struct RecoverySample: Equatable {
    enum Kind: Equatable { case hrv, restingHeartRate, sleep }
    var kind: Kind
    var start: Date
    var end: Date
    /// Milliseconds for `.hrv`, beats per minute for `.restingHeartRate`, minutes asleep for `.sleep`.
    var value: Double
    /// The name of the app or device that wrote it, as Health shows it ("Apple Watch", "WHOOP", "Oura").
    var sourceName: String
}

/// What a read of Health came back with.
enum RecoveryReadOutcome: Equatable {
    /// Grouped nights. An empty list means Health has nothing to read, or access was not given: Health does not say which.
    case nights([ReadinessNight])
    /// Health is not available on this device.
    case unavailable
    /// The read failed.
    case failed
}

/// Where the nights come from. The real implementation reads Apple Health; a fixture feeds the simulator and the tests.
protocol RecoveryReading {
    /// True for a reader that makes up its data.
    var isFixture: Bool { get }
    /// Shows the Apple Health permission sheet. Returns false when Health is unavailable or the request failed.
    /// Allowing or denying is private to the athlete: Health never reports a denied read.
    func requestAccess() async -> Bool
    /// The nights of the last `days` days up to `now`, one entry per source and morning.
    func fetchNights(now: Date, days: Int, calendar: Calendar) async -> RecoveryReadOutcome
}

// MARK: Grouping

/// Turns raw samples into engine nights, one per source device and morning.
enum RecoveryGrouping {
    /// Which engine source a Health sample belongs to. WHOOP, Oura and Garmin show up by the name of the app that wrote
    /// the sample. Anything else counts as the Apple Watch, so every sample has a source and no source is pooled with another.
    static func source(forSourceName name: String) -> ReadinessSource {
        let lower = name.lowercased()
        if lower.contains("whoop") { return .whoop }
        if lower.contains("oura") { return .oura }
        if lower.contains("garmin") { return .garmin }
        return .appleWatch
    }

    /// The morning a heart rate variability reading belongs to. Only readings taken overnight count (from 9 pm to
    /// 10 am): Health also records them through the day, and those are not comparable with a night.
    static func overnightMorning(for time: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: time)
        let day = calendar.startOfDay(for: time)
        if hour >= 21 { return calendar.date(byAdding: .day, value: 1, to: day) }
        if hour < 10 { return day }
        return nil
    }

    /// The morning a stretch of sleep belongs to: the day it ends, with the evening hours counted to the next morning.
    static func sleepMorning(endingAt end: Date, calendar: Calendar) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: 6, to: end) ?? end
        return calendar.startOfDay(for: shifted)
    }

    /// Averages heart rate variability and resting heart rate, and adds up time asleep, per source and morning. A
    /// source that reports no heart rate variability statistic (Garmin) keeps none, because the engine never uses it.
    static func nights(from samples: [RecoverySample], calendar: Calendar) -> [ReadinessNight] {
        struct Key: Hashable { var source: ReadinessSource; var day: Date }
        struct Bucket { var hrv: [Double] = []; var rhr: [Double] = []; var sleep: Double = 0; var hasSleep = false }
        var buckets: [Key: Bucket] = [:]

        for sample in samples where sample.value.isFinite && sample.value > 0 {
            let source = source(forSourceName: sample.sourceName)
            switch sample.kind {
            case .hrv:
                guard source.hrvKind != nil, let day = overnightMorning(for: sample.start, calendar: calendar) else { continue }
                buckets[Key(source: source, day: day), default: Bucket()].hrv.append(sample.value)
            case .restingHeartRate:
                let day = calendar.startOfDay(for: sample.end)
                buckets[Key(source: source, day: day), default: Bucket()].rhr.append(sample.value)
            case .sleep:
                let day = sleepMorning(endingAt: sample.end, calendar: calendar)
                var bucket = buckets[Key(source: source, day: day)] ?? Bucket()
                bucket.sleep += sample.value
                bucket.hasSleep = true
                buckets[Key(source: source, day: day)] = bucket
            }
        }

        func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
        return buckets.map { key, b in
            ReadinessNight(
                date: key.day, source: key.source, hrvMilliseconds: mean(b.hrv), restingHeartRate: mean(b.rhr),
                sleepMinutes: b.hasSleep ? b.sleep : nil)
        }
        .sorted { a, b in a.date != b.date ? a.date < b.date : a.source.rawValue < b.source.rawValue }
    }
}

// MARK: Apple Health

#if canImport(HealthKit)
/// Reads from Apple Health. Asks for read access to heart rate variability, resting heart rate and sleep, and write
/// access to workouts (the phone player saves its sessions there).
final class HealthRecoveryReader: RecoveryReading {
    private let store = HKHealthStore()
    var isFixture: Bool { false }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }
        return types
    }

    func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func fetchNights(now: Date, days: Int, calendar: Calendar) async -> RecoveryReadOutcome {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        guard let from = calendar.date(byAdding: .day, value: -max(days, 1), to: now) else { return .failed }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: now, options: [])

        async let hrv = quantitySamples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), kind: .hrv, predicate: predicate)
        async let rhr = quantitySamples(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), kind: .restingHeartRate, predicate: predicate)
        async let sleep = sleepSamples(predicate: predicate)
        guard let h = await hrv, let r = await rhr, let s = await sleep else { return .failed }
        return .nights(RecoveryGrouping.nights(from: h + r + s, calendar: calendar))
    }

    /// Nil when the query itself fails. An empty list is a normal answer.
    private func quantitySamples(
        _ id: HKQuantityTypeIdentifier, unit: HKUnit, kind: RecoverySample.Kind, predicate: NSPredicate
    ) async -> [RecoverySample]? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if error != nil { continuation.resume(returning: nil); return }
                let list = (results as? [HKQuantitySample] ?? []).map {
                    RecoverySample(kind: kind, start: $0.startDate, end: $0.endDate,
                                   value: $0.quantity.doubleValue(for: unit), sourceName: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: list)
            }
            store.execute(query)
        }
    }

    private func sleepSamples(predicate: NSPredicate) async -> [RecoverySample]? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if error != nil { continuation.resume(returning: nil); return }
                let list = (results as? [HKCategorySample] ?? []).filter { asleep.contains($0.value) }.map {
                    RecoverySample(kind: .sleep, start: $0.startDate, end: $0.endDate,
                                   value: $0.endDate.timeIntervalSince($0.startDate) / 60, sourceName: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: list)
            }
            store.execute(query)
        }
    }
}
#endif

// MARK: Fixture

/// Made up nights for the simulator and the tests. They pass through `RecoveryGrouping` like real samples, so the
/// grouping is exercised the same way. Nothing here comes from a person.
struct FixtureRecoveryReader: RecoveryReading {
    enum Scenario: String, CaseIterable {
        /// No readings at all.
        case none
        /// A few nights in, still learning.
        case calibrating
        /// A full history, 7 night heart rate variability inside the usual range.
        case onTrack
        /// A full history, the latest week clearly lower.
        case below
        /// A full history that stopped three days ago.
        case stale
    }

    var scenario: Scenario
    /// Names of the apps or devices that wrote the readings, as Health would show them.
    var sourceNames: [String] = ["Apple Watch"]
    var grantsAccess = true

    var isFixture: Bool { true }

    func requestAccess() async -> Bool { grantsAccess }

    func fetchNights(now: Date, days: Int, calendar: Calendar) async -> RecoveryReadOutcome {
        .nights(RecoveryGrouping.nights(from: samples(now: now, days: days, calendar: calendar), calendar: calendar))
    }

    /// Plain arithmetic, so the same inputs always give the same nights.
    func samples(now: Date, days: Int, calendar: Calendar) -> [RecoverySample] {
        let count: Int
        let skipNewest: Int
        switch scenario {
        case .none: return []
        case .calibrating: count = 9; skipNewest = 0
        case .onTrack, .below: count = min(days, 45); skipNewest = 0
        case .stale: count = min(days, 45); skipNewest = 3
        }
        let today = calendar.startOfDay(for: now)
        var out: [RecoverySample] = []
        for name in sourceNames {
            for back in skipNewest..<(skipNewest + count) {
                guard let morning = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
                let wobble = sin(Double(back) * 1.7)
                var hrv = 62 + 4 * wobble
                if scenario == .below && back < 7 { hrv = 44 + 2 * wobble }
                let rhr = 52 + 1.5 * wobble
                let sleepMinutes = 440 + 25 * wobble
                if let t = calendar.date(byAdding: .hour, value: 3, to: morning) {
                    out.append(RecoverySample(kind: .hrv, start: t, end: t.addingTimeInterval(60), value: hrv, sourceName: name))
                }
                if let t = calendar.date(byAdding: .hour, value: 12, to: morning) {
                    out.append(RecoverySample(kind: .restingHeartRate, start: t, end: t.addingTimeInterval(60), value: rhr, sourceName: name))
                }
                if let end = calendar.date(byAdding: .minute, value: 6 * 60 + 45, to: morning) {
                    let start = end.addingTimeInterval(-sleepMinutes * 60)
                    out.append(RecoverySample(kind: .sleep, start: start, end: end, value: sleepMinutes, sourceName: name))
                }
            }
        }
        return out
    }
}
