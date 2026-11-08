import Foundation

/// Which statistic a source reports for heart rate variability. The two are not comparable, so a baseline is never
/// built from a mix of kinds (annex C rules 9 to 13: "never pool HRV across sources").
public enum HRVKind: String, Codable, Hashable, Sendable, CaseIterable {
    /// Standard deviation of normal beats. Apple Watch reports this.
    case sdnn
    /// Root mean square of successive differences. WHOOP and Oura report this.
    case rmssd
}

/// Where a night of readiness data came from (annex C rules 9 to 13). Every source keeps its own baseline.
public enum ReadinessSource: String, Codable, Hashable, Sendable, CaseIterable {
    case appleWatch
    case whoop
    case oura
    /// Garmin writes sleep and resting heart rate to Apple Health but no HRV, and its own API is not used. A
    /// Garmin source therefore feeds rule 12 and the check-in form of rule 11 only.
    case garmin
    /// "No device": the athlete uses the 1 to 5 check-in only. Manual entries carry no HRV statistic that any
    /// rule could compare, so a preference for `manual` means check-ins only. `manual` is a legacy value for a
    /// night; a host should prefer `RecoveryPreference.checkInsOnly` for the setting.
    case manual

    /// The HRV statistic this source reports. Nil when the source reports none, in which case any HRV value on
    /// its nights is ignored (Garmin, manual).
    public var hrvKind: HRVKind? {
        switch self {
        case .appleWatch: return .sdnn
        case .whoop, .oura: return .rmssd
        case .garmin, .manual: return nil
        }
    }

    /// True for a device (everything except `manual`). A device source can be chosen as the recovery source even
    /// without HRV, so sleep and resting heart rate nights still open rule 12.
    public var isDevice: Bool { self != .manual }

    /// Plain name for the Sources screen and the reason copy.
    public var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .whoop: return "WHOOP"
        case .oura: return "Oura"
        case .garmin: return "Garmin"
        case .manual: return "Check-ins"
        }
    }

    /// The default order when several sources have enough recent nights: Oura, WHOOP, then Apple Watch, by how
    /// well each tracks nightly HRV. Garmin comes last: it has no HRV here, so it is chosen only when no source
    /// with HRV has enough nights. The athlete can override it (`ReadinessInputs.preferredRecoverySource`).
    public static let defaultOrder: [ReadinessSource] = [.oura, .whoop, .appleWatch, .garmin]

    /// Whether this source's HRV may trigger rule 10 on its own. Apple Watch HRV alone cannot (annex C rule 10):
    /// it may still count as the first signal of rule 11, which needs a second signal anyway.
    public var canTriggerDeferral: Bool { hrvKind != nil && self != .appleWatch }
}

/// One night from one source. `date` is the day the athlete woke up, so the night before today's session is dated
/// today. Missing or implausible values are simply not valid for that metric (see `ReadinessConstants`).
public struct ReadinessNight: Codable, Hashable, Sendable {
    public var date: Date
    public var source: ReadinessSource
    /// Overnight HRV in milliseconds, in the statistic of `source.hrvKind`.
    public var hrvMilliseconds: Double?
    /// Resting heart rate in beats per minute.
    public var restingHeartRate: Double?
    /// Time asleep in minutes. Duration only; sleep stages are never used.
    public var sleepMinutes: Double?

    public init(
        date: Date,
        source: ReadinessSource,
        hrvMilliseconds: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepMinutes: Double? = nil
    ) {
        self.date = date
        self.source = source
        self.hrvMilliseconds = hrvMilliseconds
        self.restingHeartRate = restingHeartRate
        self.sleepMinutes = sleepMinutes
    }
}

/// The optional one tap morning check-in, 1 to 5 (annex C rule 11). The initializer and the decoder clamp the
/// score, so a stored or imported value outside 1 to 5 never reaches a rule or a reason line.
public struct ReadinessCheckIn: Codable, Hashable, Sendable {
    public var date: Date
    /// 1 (poor) to 5 (great).
    public var score: Int

    public init(date: Date, score: Int) {
        self.date = date
        self.score = ReadinessCheckIn.clamped(score)
    }

    private enum CodingKeys: String, CodingKey { case date, score }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let score = try container.decode(Int.self, forKey: .score)
        self.init(date: date, score: score)
    }

    /// `score` forced into 1 to 5.
    static func clamped(_ score: Int) -> Int {
        min(max(score, ReadinessConstants.checkInRange.lowerBound), ReadinessConstants.checkInRange.upperBound)
    }
}

/// The athlete's recovery source setting in one clear type. `ReadinessInputs.recoveryPreference` maps it to the
/// stored `preferredRecoverySource` (nil is automatic, `.manual` is check-ins only).
public enum RecoveryPreference: Hashable, Sendable {
    /// The default order: Oura, WHOOP, Apple Watch, Garmin, by enough recent nights.
    case automatic
    /// Use this device.
    case source(ReadinessSource)
    /// No device: check-ins only.
    case checkInsOnly

    init(_ stored: ReadinessSource?) {
        switch stored {
        case nil: self = .automatic
        case .some(.manual): self = .checkInsOnly
        case .some(let source): self = .source(source)
        }
    }

    var stored: ReadinessSource? {
        switch self {
        case .automatic: return nil
        case .source(let source): return source == .manual ? .manual : source
        case .checkInsOnly: return .manual
        }
    }
}

/// Everything readiness needs besides the plan (annex C rules 9 to 13). Plain data, so a run is deterministic.
public struct ReadinessInputs: Codable, Hashable, Sendable {
    public var nights: [ReadinessNight]
    public var checkIns: [ReadinessCheckIn]
    /// Extra days of Keep planned session taps from outside the log. Taps made through
    /// `AdaptationState.keepPlannedSession` are read from the history and need no entry here. Three distinct days in
    /// 14 drop readiness to notes only (rule 13).
    public var overrides: [Date]
    /// When any device last delivered data. Nil when unknown. Prefer `lastSyncBySource`. It must be a delivery, not
    /// a pull attempt: the chosen source's newest valid night is checked as well (rule 13).
    public var lastSyncDate: Date?
    /// When each source last delivered data. The chosen source's entry is read first, so a fresh Apple Watch sync
    /// cannot hide a silent ring. With no entry for the chosen source, `lastSyncDate` is used.
    public var lastSyncBySource: [ReadinessSource: Date]
    /// The athlete's choice of recovery source. Nil means the default order. `.manual` means check-ins only.
    public var preferredRecoverySource: ReadinessSource?
    /// The source readiness used on the previous run (`ReadinessAssessment.source`). The host persists it so a
    /// change of source, automatic or chosen, restarts calibration (annex C rule 9) and so a source with one
    /// quiet week is kept rather than flipped.
    public var activeSource: ReadinessSource?
    /// The day the recovery source changed, set by the host when the athlete changes the source or connects or
    /// removes one (annex C rule 9: a source change restarts calibration). Persist `ReadinessAssessment.sourceChangedOn`
    /// here after each run. Only nights dated on or after this day count toward the 14 valid nights; the older
    /// nights of the new source still feed its mean and SD. An automatic flip caused by sparse nights is detected
    /// through `activeSource`, not through this field.
    public var sourceChangedOn: Date?

    public init(
        nights: [ReadinessNight] = [],
        checkIns: [ReadinessCheckIn] = [],
        overrides: [Date] = [],
        lastSyncDate: Date? = nil,
        lastSyncBySource: [ReadinessSource: Date] = [:],
        preferredRecoverySource: ReadinessSource? = nil,
        activeSource: ReadinessSource? = nil,
        sourceChangedOn: Date? = nil
    ) {
        self.nights = nights
        self.checkIns = checkIns
        self.overrides = overrides
        self.lastSyncDate = lastSyncDate
        self.lastSyncBySource = lastSyncBySource
        self.preferredRecoverySource = preferredRecoverySource
        self.activeSource = activeSource
        self.sourceChangedOn = sourceChangedOn
    }

    private enum CodingKeys: String, CodingKey {
        case nights, checkIns, overrides, lastSyncDate, lastSyncBySource, preferredRecoverySource, activeSource, sourceChangedOn
    }

    /// Reads inputs stored before the source fields existed: every key but the three lists is optional.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            nights: try container.decodeIfPresent([ReadinessNight].self, forKey: .nights) ?? [],
            checkIns: try container.decodeIfPresent([ReadinessCheckIn].self, forKey: .checkIns) ?? [],
            overrides: try container.decodeIfPresent([Date].self, forKey: .overrides) ?? [],
            lastSyncDate: try container.decodeIfPresent(Date.self, forKey: .lastSyncDate),
            lastSyncBySource: try container.decodeIfPresent([ReadinessSource: Date].self, forKey: .lastSyncBySource) ?? [:],
            preferredRecoverySource: try container.decodeIfPresent(ReadinessSource.self, forKey: .preferredRecoverySource),
            activeSource: try container.decodeIfPresent(ReadinessSource.self, forKey: .activeSource),
            sourceChangedOn: try container.decodeIfPresent(Date.self, forKey: .sourceChangedOn))
    }

    /// The source setting as one type. Setting it writes `preferredRecoverySource`.
    public var recoveryPreference: RecoveryPreference {
        get { RecoveryPreference(preferredRecoverySource) }
        set { preferredRecoverySource = newValue.stored }
    }

    /// A copy that records one Keep planned session tap on `day`, once per exact date. Prefer
    /// `AdaptationState.keepPlannedSession`, which records the tap in the log for you.
    public func recordingOverride(on day: Date) -> ReadinessInputs {
        var copy = self
        if !copy.overrides.contains(day) { copy.overrides.append(day) }
        return copy
    }
}
