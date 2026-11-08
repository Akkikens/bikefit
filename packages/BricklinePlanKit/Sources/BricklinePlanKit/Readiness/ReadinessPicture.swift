import Foundation

// The gates of annex C rule 9 (calibration) and rule 13 (guardrails), and the assessment built from them.
extension ReadinessRules {
    /// Where the gates of annex C rule 9 and rule 13 stand.
    enum Gate: Equatable {
        /// No device source: only check-ins can drive rule 11. Rule 9 has no baseline to wait for.
        case checkInOnly
        /// A device source is chosen but holds no valid nights.
        case noData
        /// No sync for 48 hours (rule 13).
        case staleSync
        /// Fewer than 14 valid nights (rule 9). The value is the night count.
        case calibrating(Int)
        /// Fewer than 3 valid nights in the latest 7 (rule 9).
        case tooFewRecent
        /// Calibrated, with enough recent nights.
        case ready
    }

    /// Everything one run reads from its inputs, computed once.
    struct Picture {
        var choice: SourceChoice?
        var baseline: SourceBaseline?
        var gate: Gate
        var raceWindow: Bool
        var notesOnly: Bool
        var changesInWindow: Int
        var overrideDays: Int
        var structuralSpent: Bool
        var restrictedToday: Bool
        /// A hard session is still planned today, so a change is possible at all.
        var hasHardSessionToday: Bool
        /// The day the source last changed, when it did (rule 9). Nil when nothing says it changed.
        var sourceChangedOn: Date?
        /// The athlete chose check-ins only (preference `.manual`).
        var prefersCheckIns: Bool
        /// Check-in score per whole days before today (0 is today), the latest tap of each day.
        var checkIns: [Int: Int]

        /// Whether rules 10 and 11 may change the plan today: the gates are open and no guardrail is hit. Rule 12
        /// needs only `gate == .ready`.
        var canChangePlan: Bool {
            (gate == .ready || gate == .checkInOnly) && !raceWindow && !notesOnly
                && changesInWindow < ReadinessConstants.maximumPlanChanges
                && !structuralSpent && !restrictedToday
        }

        /// - Parameter structuralReserved: true when another rule has already claimed today's one structural change
        ///   without logging it as structural, which is what a pending rule 2 realignment prompt does.
        static func make(
            plan: Plan, inputs: ReadinessInputs, run: AdaptationRun, history: [AdaptationEvent],
            structuralReserved: Bool = false
        ) -> Picture {
            let calendar = run.calendar
            // Nights inside an unwell period are left out of the baseline and the signal: they would pull the
            // mean down and the SD up, and dull the rules for weeks afterwards.
            let nights = inputs.nights.filter { night in
                guard night.date.isUsable else { return false }
                let day = calendar.startOfDay(for: night.date)
                return !run.periods.contains { $0.start <= day && day < $0.easyEnd }
            }
            let choice = BaselineCalculator.chooseSource(
                nights: nights, preferred: inputs.preferredRecoverySource, current: inputs.activeSource,
                today: run.today, calendar: calendar)

            var changedOn: Date? = inputs.sourceChangedOn.flatMap { $0.isUsable ? calendar.startOfDay(for: $0) : nil }
            if let choice, let previous = inputs.activeSource, previous != choice.source { changedOn = run.today }
            let baseline = choice.map {
                BaselineCalculator.baseline(
                    for: $0.source, nights: nights, today: run.today, calendar: calendar, since: changedOn)
            }

            let gate: Gate
            if let baseline {
                let calibration = baseline.calibration
                if calibration.validNights == 0 && baseline.newestNightDaysAgo == nil {
                    gate = .noData
                } else if isSyncStale(inputs: inputs, run: run, baseline: baseline) {
                    gate = .staleSync
                } else if !calibration.isCalibrated {
                    gate = .calibrating(calibration.night)
                } else if !calibration.hasEnoughRecentNights {
                    gate = .tooFewRecent
                } else {
                    gate = .ready
                }
            } else {
                gate = .checkInOnly
            }

            let changeRules: Set<AdaptationRuleID> = [.readinessDefer, .readinessEasy, .sleepNote]
            let changes = history.filter { event in
                guard changeRules.contains(event.rule), event.isStructural else { return false }
                let age = calendar.daysBetween(calendar.startOfDay(for: event.date), run.today)
                return age >= 0 && age < ReadinessConstants.planChangeWindowDays
            }.count

            var overrideDays = Set<Date>()
            var taps = inputs.overrides.filter(\.isUsable)
            taps.append(contentsOf: history.compactMap { $0.advisory?.keptOn }.filter(\.isUsable))
            for tap in taps {
                let day = calendar.startOfDay(for: tap)
                let age = calendar.daysBetween(day, run.today)
                if age >= 0 && age < ReadinessConstants.overrideWindowDays { overrideDays.insert(day) }
            }

            let hardToday = plan.adaptSessions(on: run.today, calendar: calendar)
                .contains { $0.state == .planned && AdaptationSupport.isHard($0) }

            return Picture(
                choice: choice, baseline: baseline, gate: gate,
                raceWindow: run.taperLockActive(plan: plan),
                notesOnly: overrideDays.count >= ReadinessConstants.overrideLimit,
                changesInWindow: changes, overrideDays: overrideDays.count,
                structuralSpent: structuralReserved || run.structuralUsedToday(includingChosenEvents: true),
                restrictedToday: run.isRestricted(run.today),
                hasHardSessionToday: hardToday,
                sourceChangedOn: changedOn,
                prefersCheckIns: inputs.preferredRecoverySource == .manual,
                checkIns: checkInScores(inputs.checkIns, run: run))
        }

        /// No sync for 48 hours (rule 13). Silent when the chosen source's newest valid night is 2 or more whole days
        /// old, whatever the host reports as the sync date. Otherwise the reference is the chosen source's own last
        /// sync, else the host's single last sync date. A date that is not a number counts as stale.
        static func isSyncStale(inputs: ReadinessInputs, run: AdaptationRun, baseline: SourceBaseline) -> Bool {
            if let newest = baseline.newestNightDaysAgo, newest >= ReadinessConstants.silenceAfterNightDays { return true }
            guard let reference = inputs.lastSyncBySource[baseline.source] ?? inputs.lastSyncDate else { return false }
            let interval = run.context.today.timeIntervalSince(reference)
            return !(interval < ReadinessConstants.silenceAfterHours * 3600)
        }

        /// The latest tap of each day. Two taps with the same time keep the higher score, which acts less.
        static func checkInScores(_ checkIns: [ReadinessCheckIn], run: AdaptationRun) -> [Int: Int] {
            var byDay: [Int: [ReadinessCheckIn]] = [:]
            for item in checkIns where item.date.isUsable {
                let age = run.calendar.daysBetween(run.calendar.startOfDay(for: item.date), run.today)
                if age >= 0 && age < ReadinessConstants.recentWindowDays {
                    byDay[age, default: []].append(ReadinessCheckIn(date: item.date, score: item.score))
                }
            }
            var result: [Int: Int] = [:]
            for (age, items) in byDay {
                let sorted = items.sorted { a, b in a.date != b.date ? a.date < b.date : a.score < b.score }
                if let last = sorted.last { result[age] = last.score }
            }
            return result
        }
    }

    /// Builds the `ReadinessAssessment` for the Today card.
    enum Assessor {
        static func make(picture p: Picture, note: String?, firedToday: Bool) -> ReadinessAssessment {
            let hrv = hrvComponent(p)
            let rhr = restingHeartRateComponent(p)
            let sleep = sleepComponent(p)
            let checkIn = checkInComponent(p)

            let status: ReadinessStatus
            let line: String
            switch p.gate {
            case .checkInOnly:
                status = .noData
                line = checkIn.isAvailable || p.prefersCheckIns
                    ? joined(["Using check-ins only.", checkIn.text]) : "No readiness data yet."
            case .noData:
                status = .noData
                line = "No \(p.choice?.source.displayName ?? "device") nights yet."
            case .staleSync:
                status = .paused(.noRecentSync)
                line = ReadinessCopy.pause(.noRecentSync)
            case .calibrating(let night):
                status = .calibrating(night: night, of: ReadinessConstants.calibrationNights)
                line = "Learning your baseline, night \(night) of \(ReadinessConstants.calibrationNights)."
            case .tooFewRecent:
                status = .paused(.tooFewRecentNights)
                line = ReadinessCopy.pause(.tooFewRecentNights)
            case .ready:
                let data = joined([hrv.text, rhr.text, sleep.text, checkIn.text])
                if p.raceWindow {
                    status = .paused(.raceWindow)
                    line = joined([data, ReadinessCopy.pause(.raceWindow)])
                } else if p.notesOnly {
                    status = .paused(.notesOnly)
                    line = joined([data, ReadinessCopy.pause(.notesOnly)])
                } else {
                    status = hrv.level == .below ? .belowUsualRange : .onTrack
                    line = data
                }
            }

            let changes = p.changesInWindow + (firedToday ? 1 : 0)
            let room = p.canChangePlan && !firedToday
            return ReadinessAssessment(
                status: status, line: line, hrv: hrv, restingHeartRate: rhr, sleep: sleep, checkIn: checkIn,
                source: p.choice, calibration: p.baseline?.calibration, sleepNote: note,
                canChangePlanToday: room && p.hasHardSessionToday, hasRoomForChange: room,
                sourceChangedOn: p.sourceChangedOn,
                planChangesInLast7Days: changes, overridesInLast14Days: p.overrideDays,
                usesCheckInsOnly: p.gate == .checkInOnly)
        }

        private static func joined(_ parts: [String]) -> String {
            parts.filter { !$0.isEmpty }.joined(separator: " ")
        }

        /// The 7 night mean against the baseline: below at 0.5 SD under, above at 0.5 SD over.
        private static func hrvComponent(_ p: Picture) -> ReadinessComponent {
            guard let b = p.baseline, let recent = b.hrv.recentMean,
                  let low = b.hrv.lowerLimit(sds: ReadinessConstants.deferralSDMultiple),
                  let high = b.hrv.upperLimit(sds: ReadinessConstants.deferralSDMultiple) else { return ReadinessComponent() }
            let value = exp(recent)
            let reference = b.hrv.mean.map { exp($0) }
            if recent < low {
                return ReadinessComponent(
                    level: .below, text: "HRV below your usual range.", value: value, reference: reference, unit: .milliseconds)
            }
            if recent > high {
                return ReadinessComponent(
                    level: .above, text: "HRV above your usual range.", value: value, reference: reference, unit: .milliseconds)
            }
            return ReadinessComponent(
                level: .usual, text: "HRV on track.", value: value, reference: reference, unit: .milliseconds)
        }

        /// Last night against the baseline: up at 1 SD over, lower at 1 SD under.
        private static func restingHeartRateComponent(_ p: Picture) -> ReadinessComponent {
            guard let b = p.baseline, let value = b.restingHeartRateByDaysAgo[0],
                  let low = b.restingHeartRate.lowerLimit(sds: ReadinessConstants.restingHeartRateSDMultiple),
                  let high = b.restingHeartRate.upperLimit(sds: ReadinessConstants.restingHeartRateSDMultiple) else {
                return ReadinessComponent()
            }
            let logged = log(value)
            let reference = b.restingHeartRate.mean.map { exp($0) }
            if logged >= high {
                return ReadinessComponent(
                    level: .above, text: "Resting heart rate up.", value: value, reference: reference, unit: .beatsPerMinute)
            }
            if logged <= low {
                return ReadinessComponent(
                    level: .below, text: "Resting heart rate lower than usual.", value: value, reference: reference,
                    unit: .beatsPerMinute)
            }
            return ReadinessComponent(
                level: .usual, text: "Resting heart rate normal.", value: value, reference: reference, unit: .beatsPerMinute)
        }

        /// Last night's duration. Below when it sits an hour or more under the median.
        private static func sleepComponent(_ p: Picture) -> ReadinessComponent {
            guard let b = p.baseline, let slept = b.sleepByDaysAgo[0] else { return ReadinessComponent() }
            let text = "Sleep \(ReadinessCopy.duration(minutes: slept))."
            if let median = b.sleepMedianMinutes, median - slept >= ReadinessConstants.sleepUnderMedianMinutes {
                return ReadinessComponent(level: .below, text: text, value: slept, reference: median, unit: .minutes)
            }
            return ReadinessComponent(
                level: .usual, text: text, value: slept, reference: b.sleepMedianMinutes, unit: .minutes)
        }

        private static func checkInComponent(_ p: Picture) -> ReadinessComponent {
            guard let score = p.checkIns[0] else { return ReadinessComponent() }
            let text = "Check-in \(score) of \(ReadinessConstants.checkInRange.upperBound)."
            return ReadinessComponent(
                level: score <= ReadinessConstants.lowCheckIn ? .below : .usual, text: text, value: Double(score),
                unit: .score)
        }
    }
}
