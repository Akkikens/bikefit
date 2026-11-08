import Foundation

/// Default race window: timeline, pacing, fueling and the notification cap. Implements annex F and annex H.
/// Pure and deterministic: no clock reads, every date comes in as a parameter.
///
/// Times of day are local wall clock minutes after midnight. The app builds the notification trigger from hour
/// and minute, so it fires at that local time wherever the device is on race morning.
public struct DefaultRaceWindow: RaceWindow {
    public let parameters: RaceWindowParameters

    public init() {
        self.parameters = RaceWindowParameters()
    }

    public init(parameters: RaceWindowParameters) {
        self.parameters = parameters
    }

    // MARK: Window

    /// Annex F "Window opens": T minus 21 days, or T minus 10 for Sprint, through race day inclusive.
    public func isWindowActive(raceDate: Date, distance: RaceDistance, today: Date, calendar: Calendar) -> Bool {
        let daysToRace = calendar.daysBetween(today, raceDate)
        return daysToRace >= 0 && daysToRace <= distance.parameters.windowOpensTMinusDays
    }

    // MARK: Timeline

    /// Wake up time in minutes after local midnight (annex F: start time minus transit minus setup minus
    /// breakfast lead). Inputs are clamped to sane values and the result never goes below midnight, so an
    /// early start with long lead times still yields a usable time on race morning.
    public func wakeUpMinutes(for race: RaceDetails) -> Int {
        max(rawWakeUpMinutes(for: race), 0)
    }

    /// True when the lead times are longer than the time before the start, so the wake up time was held at
    /// midnight. The race editor shows `RaceWindowCopy.wakeUpClampedWarning` and asks for shorter leads.
    public func wakeUpIsClamped(for race: RaceDetails) -> Bool {
        rawWakeUpMinutes(for: race) < 0
    }

    private func rawWakeUpMinutes(for race: RaceDetails) -> Int {
        let start = min(max(race.startMinutesAfterMidnight, 0), 24 * 60 - 1)
        let lead = max(race.transitMinutes, 0) + max(race.setupMinutes, 0) + max(race.breakfastLeadMinutes, 0)
        return start - lead
    }

    /// Annex F "Timeline entries", ordered by `tMinusDays` descending. The bike service entry appears only when
    /// a Bike record exists; travel and pack only for a travel race.
    public func entries(for race: RaceDetails, calendar: Calendar) -> [RaceWindowEntry] {
        let opens = race.distance.parameters.windowOpensTMinusDays
        var result: [RaceWindowEntry] = []

        if race.hasBikeRecord {
            result.append(RaceWindowEntry(
                tMinusDays: min(parameters.bikeServiceTMinus, opens),
                kind: .bikeService,
                text: RaceWindowCopy.bikeServiceText))
        }
        if race.isTravelRace {
            result.append(RaceWindowEntry(
                tMinusDays: min(parameters.travelPackTMinus, opens),
                kind: .pack,
                text: RaceWindowCopy.travelPackText))
            result.append(RaceWindowEntry(
                tMinusDays: min(parameters.travelTMinus, opens),
                kind: .travel,
                text: RaceWindowCopy.travelText))
        }
        if race.distance == .half {
            result.append(RaceWindowEntry(
                tMinusDays: parameters.carbLoadTMinusLongCourse,
                kind: .carbLoad,
                text: RaceWindowCopy.carbLoadLongText))
        } else {
            result.append(RaceWindowEntry(
                tMinusDays: parameters.carbLoadTMinusShortCourse,
                kind: .carbLoad,
                text: RaceWindowCopy.carbLoadShortText))
        }
        result.append(RaceWindowEntry(
            tMinusDays: parameters.packTonightTMinus,
            kind: .packTonight,
            text: RaceWindowCopy.packTonightText))

        let start = min(max(race.startMinutesAfterMidnight, 0), 24 * 60 - 1)
        let wake = wakeUpMinutes(for: race)
        result.append(RaceWindowEntry(
            tMinusDays: 0,
            kind: .wakeUp,
            text: RaceWindowCopy.wakeUpText(
                wake: wake,
                start: start,
                transit: max(race.transitMinutes, 0),
                setup: max(race.setupMinutes, 0),
                breakfast: max(race.breakfastLeadMinutes, 0),
                clamped: wakeUpIsClamped(for: race)),
            minutesAfterMidnight: wake))

        return Self.sortedByRaceDistance(result)
    }

    // MARK: Notification cap

    /// Annex H: at most `maxNotificationsPerDay` per day and `maxNotificationsPerWeek` in any seven day span,
    /// the entries closest to race day winning. The wake up entry is always kept (one per day). The week limit
    /// is checked on every sliding seven day span, so it holds for any calendar alignment.
    public func cappedForNotifications(_ entries: [RaceWindowEntry]) -> [RaceWindowEntry] {
        let perDay = max(parameters.maxNotificationsPerDay, 1)
        let perWeek = max(parameters.maxNotificationsPerWeek, 1)

        // Wake up entries first (always kept), then the rest nearest to race day first.
        let wakeUps = entries.filter { $0.kind == .wakeUp }
        let others = entries.enumerated()
            .filter { $0.element.kind != .wakeUp }
            .sorted { lhs, rhs in
                if lhs.element.tMinusDays != rhs.element.tMinusDays {
                    return lhs.element.tMinusDays < rhs.element.tMinusDays
                }
                let lp = Self.priority(lhs.element.kind)
                let rp = Self.priority(rhs.element.kind)
                if lp != rp { return lp < rp }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        var kept: [RaceWindowEntry] = []
        for wake in wakeUps where !kept.contains(where: { $0.kind == .wakeUp && $0.tMinusDays == wake.tMinusDays }) {
            kept.append(wake)
        }
        for candidate in others {
            let day = candidate.tMinusDays
            if kept.filter({ $0.tMinusDays == day }).count >= perDay {
                // Race eve dinner and the pack reminder share a day on short courses. Only one notification fits,
                // so the pack reminder carries both messages instead of silently losing the dinner advice.
                if candidate.kind == .carbLoad,
                   let index = kept.firstIndex(where: { $0.tMinusDays == day && $0.kind == .packTonight }) {
                    kept[index].text = RaceWindowCopy.packAndDinnerText
                }
                continue
            }
            var fits = true
            for spanStart in (day - 6)...day {
                let inSpan = kept.filter { $0.tMinusDays >= spanStart && $0.tMinusDays <= spanStart + 6 }.count
                if inSpan + 1 > perWeek { fits = false; break }
            }
            if fits { kept.append(candidate) }
        }
        return Self.sortedByRaceDistance(kept)
    }

    // MARK: Helpers

    /// Lower number wins when two entries share a day (annex H tie break, an implementation choice).
    static func priority(_ kind: RaceWindowEntryKind) -> Int {
        switch kind {
        case .wakeUp: return 0
        case .packTonight: return 1
        case .carbLoad: return 2
        case .travel: return 3
        case .pack: return 4
        case .bikeService: return 5
        }
    }

    /// Descending `tMinusDays`, ties broken by kind priority so the order is stable and deterministic.
    static func sortedByRaceDistance(_ entries: [RaceWindowEntry]) -> [RaceWindowEntry] {
        entries.enumerated().sorted { lhs, rhs in
            if lhs.element.tMinusDays != rhs.element.tMinusDays {
                return lhs.element.tMinusDays > rhs.element.tMinusDays
            }
            let lp = priority(lhs.element.kind)
            let rp = priority(rhs.element.kind)
            if lp != rp { return lp > rp }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
