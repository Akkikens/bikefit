import Foundation
import BricklinePlanKit

// The words on the Today readiness line and the Connections screen, as pure functions of engine output so they can be
// tested. Rules for every sentence here: say what the numbers are, never name a cause, never tell the athlete to
// rest, and keep the planned session one tap away. Heart rate variability is spelled out; the screens add a
// glossary link beside it.

/// What the Today readiness line shows.
struct ReadinessLineModel: Equatable {
    enum Tone: Equatable { case neutral, steady, notice }
    var symbol: String
    var headline: String
    var detail: String?
    var tone: Tone
    /// The Keep my planned session button is offered.
    var offersKeep: Bool
    /// The line talks about heart rate variability, so the screen shows the glossary link.
    var mentionsHRV: Bool
}

enum ReadinessPlainCopy {
    static let keepButtonTitle = "Keep my planned session"

    // MARK: Words

    /// Spells out the shorthand: "HRV" becomes "heart rate variability", capitalised at the start of a sentence.
    static func spellOut(_ text: String) -> String {
        var out = text.replacingOccurrences(of: "HRV", with: "heart rate variability")
        if out.hasPrefix("heart rate variability") { out = "Heart rate variability" + out.dropFirst("heart rate variability".count) }
        return out.replacingOccurrences(of: ". heart rate variability", with: ". Heart rate variability")
    }

    /// The engine's "Tap to keep the original." sentence goes: the button says it.
    static func withoutKeepPrompt(_ text: String) -> String {
        var out = text
        for tail in [" Tap to keep the original.", " Tap to keep the originals.", "Tap to keep the original.", "Tap to keep the originals."] {
            out = out.replacingOccurrences(of: tail, with: "")
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// The reason line under a session that readiness changed.
    static func sessionReason(from engineLine: String) -> String {
        PlainCopy.sanitize(spellOut(withoutKeepPrompt(engineLine)))
    }

    /// Only the part of the reason that says what happened to the session, without the "below your usual range" fact the
    /// headline already states.
    static func changeSentence(from engineLine: String) -> String {
        var out = withoutKeepPrompt(engineLine)
        out = out.replacingOccurrences(of: "Your 7 night HRV is below your usual range.", with: "")
        // The headline already says heart rate variability is below range; keep only the extra fact.
        out = out.replacingOccurrences(of: "Your HRV has been below your usual range two mornings running and resting heart rate is up.", with: "Your resting heart rate is up.")
        out = out.replacingOccurrences(of: "Your HRV has been below your usual range two mornings running and your check-in was low.", with: "Your check-in was low.")
        return PlainCopy.sanitize(spellOut(out.trimmingCharacters(in: .whitespaces)))
    }

    /// The rule behind a readiness change, for the expandable reason line.
    static let ruleExplanation = "When your 7 night heart rate variability sits below your own usual range, the plan can ease or move one hard session. It never adds work, it changes at most 2 sessions a week, and you can keep the planned session with one tap."

    // MARK: Today line

    static func line(
        assessment: ReadinessAssessment?, event: AdaptationEvent?, kept: Bool, hasSources: Bool
    ) -> ReadinessLineModel? {
        guard hasSources, let a = assessment else { return nil }
        switch a.status {
        case .noData:
            return ReadinessLineModel(
                symbol: "moon.stars", headline: "Waiting for your first night of data.",
                detail: "Brickline reads sleep and heart rate from Apple Health. Wear your device overnight, then open the app.",
                tone: .neutral, offersKeep: false, mentionsHRV: false)
        case .calibrating(let night, let of):
            return ReadinessLineModel(
                symbol: "moon.stars", headline: "Learning your usual range: night \(night) of \(of).",
                detail: "Your plan does not change from sleep or heart rate data until then.",
                tone: .neutral, offersKeep: false, mentionsHRV: false)
        case .onTrack:
            return ReadinessLineModel(
                symbol: "checkmark.circle", headline: "On track.",
                detail: details(a), tone: .steady, offersKeep: false, mentionsHRV: a.hrv.isAvailable)
        case .belowUsualRange:
            let headline = "Your 7 night heart rate variability is below your usual range."
            if let event, !kept {
                return ReadinessLineModel(
                    symbol: "arrow.triangle.branch", headline: headline,
                    detail: changeSentence(from: event.reasonLine), tone: .notice,
                    offersKeep: event.canKeepPlannedSession, mentionsHRV: true)
            }
            return ReadinessLineModel(
                symbol: "arrow.triangle.branch", headline: headline,
                detail: kept ? "You kept your planned session." : "Your planned session stays as it is.",
                tone: .notice, offersKeep: false, mentionsHRV: true)
        case .paused(let reason):
            let name = a.source?.source.displayName ?? "Your device"
            switch reason {
            case .tooFewRecentNights:
                return ReadinessLineModel(
                    symbol: "pause.circle", headline: "Paused: fewer than 3 nights of data this week.",
                    detail: "Your plan keeps its planned sessions until more nights come in.",
                    tone: .neutral, offersKeep: false, mentionsHRV: false)
            case .noRecentSync:
                return ReadinessLineModel(
                    symbol: "pause.circle", headline: "Paused: no new data from \(name) in 48 hours.",
                    detail: "Open the \(name) app so it can send its latest nights to Apple Health.",
                    tone: .neutral, offersKeep: false, mentionsHRV: false)
            case .notesOnly:
                return ReadinessLineModel(
                    symbol: "pause.circle", headline: "Notes only for now.",
                    detail: "You kept your planned session 3 times lately, so Brickline will leave your sessions as planned. " + details(a),
                    tone: .neutral, offersKeep: false, mentionsHRV: a.hrv.isAvailable)
            case .raceWindow:
                return ReadinessLineModel(
                    symbol: "flag.checkered", headline: "Race window: your plan holds steady on purpose.",
                    detail: details(a), tone: .neutral, offersKeep: false, mentionsHRV: a.hrv.isAvailable)
            }
        }
    }

    /// The facts of the night as short sentences, with a short night note when there is one.
    static func details(_ a: ReadinessAssessment) -> String {
        var parts = [a.hrv.text, a.restingHeartRate.text, a.sleep.text].filter { !$0.isEmpty }
        if let note = a.sleepNote { parts.append(note) }
        return spellOut(parts.joined(separator: " "))
    }

    // MARK: Connections screen

    /// How one connected device is doing, for the Connections screen.
    enum SourceState: Equatable {
        case inUse
        case calibrating(night: Int, of: Int)
        case paused(String)
        case notEnoughData
        /// Has nights but another device is in use.
        case standby
        /// A device Brickline does not read from.
        case notRead

        var label: String {
            switch self {
            case .inUse: return "Connected"
            case .calibrating(let n, let of): return "Calibrating, night \(n) of \(of)"
            case .paused: return "Paused"
            case .notEnoughData: return "Not enough data"
            case .standby: return "Connected, not in use"
            case .notRead: return "Followed on your phone"
            }
        }
    }

    struct SourceRow: Equatable, Identifiable {
        var device: DeviceChoice
        var state: SourceState
        /// What Brickline uses this device for, in plain words.
        var usedFor: String
        /// A line under the state: why it is paused, or why it is not in use.
        var note: String?
        var id: DeviceChoice { device }
    }

    static func usedFor(_ device: DeviceChoice) -> String {
        switch device {
        case .appleWatch: return "Sleep, resting heart rate and heart rate variability, from Apple Health. Also takes your sessions on the wrist."
        case .whoop: return "Sleep, resting heart rate and heart rate variability, through Apple Health for now. Beta: a direct connection is coming soon."
        case .oura: return "Sleep, resting heart rate and heart rate variability, through Apple Health for now. Beta: a direct connection is coming soon."
        case .garmin: return "Sleep and resting heart rate, through Apple Health. Garmin does not share heart rate variability."
        case .otherWatch: return "Nothing is read from it. You follow sessions on your phone and record on the device as usual."
        case .phoneOnly: return "Sessions are followed on your phone. No recovery data is used."
        }
    }

    /// One row per connected device, in the order the cards are shown.
    static func sourceRows(
        data: SetupData, assessment: ReadinessAssessment?, nights: [ReadinessNight], today: Date, calendar: Calendar
    ) -> [SourceRow] {
        let active = assessment?.source?.source
        return data.orderedDevices.map { device in
            guard let source = device.readinessSource else {
                return SourceRow(device: device, state: .notRead, usedFor: usedFor(device), note: nil)
            }
            let window = ReadinessConstants.baselineWindowDays + ReadinessConstants.recentWindowDays
            let recent = nights.filter { n in
                let age = calendar.daysBetween(calendar.startOfDay(for: n.date), calendar.startOfDay(for: today))
                return n.source == source && age >= 0 && age < window
            }
            if source == active, let a = assessment {
                switch a.status {
                case .calibrating(let night, let of):
                    return SourceRow(device: device, state: .calibrating(night: night, of: of), usedFor: usedFor(device),
                                     note: "Your plan does not change from this device until then.")
                case .paused(let reason):
                    let why: String
                    switch reason {
                    case .tooFewRecentNights: why = "Fewer than 3 nights of data this week."
                    case .noRecentSync: why = "No new data in 48 hours."
                    case .notesOnly: why = "Notes only: you kept your planned session 3 times lately."
                    case .raceWindow: why = "Race window: the plan holds steady on purpose."
                    }
                    return SourceRow(device: device, state: .paused(why), usedFor: usedFor(device), note: why)
                case .noData:
                    return SourceRow(device: device, state: .notEnoughData, usedFor: usedFor(device),
                                     note: "No nights from this device in Apple Health yet.")
                case .onTrack, .belowUsualRange:
                    return SourceRow(device: device, state: .inUse, usedFor: usedFor(device), note: a.source?.explanation)
                }
            }
            if recent.isEmpty {
                return SourceRow(device: device, state: .notEnoughData, usedFor: usedFor(device),
                                 note: "No nights from this device in Apple Health yet.")
            }
            return SourceRow(device: device, state: .standby, usedFor: usedFor(device),
                             note: assessment?.source?.explanation)
        }
    }
}
