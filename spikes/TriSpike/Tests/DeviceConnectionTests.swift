import XCTest
import BricklinePlanKit
@testable import TriSpike

/// Multi device setup, the Apple Health reader's grouping, and the readiness line. No test traps and none touches
/// Apple Health: readings come from the fixture reader.
@MainActor
final class DeviceConnectionTests: XCTestCase {
    private let cal = EngineBuilder.calendar()

    /// Monday 9 November 2026, midday.
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12)) ?? Date() }
    private var today: Date { cal.startOfDay(for: now) }

    private func decode(_ json: String) -> SetupData? {
        try? JSONDecoder().decode(SetupData.self, from: Data(json.utf8))
    }

    private func freshDefaults() -> UserDefaults {
        let name = "DeviceConnectionTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name) ?? .standard
        d.removePersistentDomain(forName: name)
        return d
    }

    // MARK: Migration

    func testOldSingleTrackerKeyBecomesAOneDeviceSet() {
        for old in ["appleWatch", "whoop", "garmin", "otherWatch", "phoneOnly"] {
            let d = decode(#"{"hasOnboarded":true,"hoursPerWeek":9,"tracker":"\#(old)"}"#)
            XCTAssertEqual(d?.devices, DeviceChoice(rawValue: old).map { [$0] }, old)
            XCTAssertEqual(d?.hoursPerWeek, 9, "other answers survive the migration")
            XCTAssertEqual(d?.hasOnboarded, true)
        }
    }

    func testStoredDeviceListIsRead() {
        XCTAssertEqual(decode(#"{"devices":["appleWatch","oura"]}"#)?.devices, [.appleWatch, .oura])
    }

    func testStoredDevicesAreMadeValid() {
        XCTAssertEqual(decode(#"{"devices":[]}"#)?.devices, [.phoneOnly], "empty becomes phone only")
        XCTAssertEqual(decode(#"{"devices":["phoneOnly","garmin"]}"#)?.devices, [.garmin], "phone only never sits with a device")
    }

    func testSetupWithNoDeviceKeyDecodesToPhoneOnly() {
        XCTAssertEqual(decode("{}")?.devices, [.phoneOnly])
        XCTAssertEqual(decode(#"{"tracker":"nonsense"}"#)?.devices, [.phoneOnly])
    }

    func testSetupRoundTripsWithDevices() throws {
        var d = SetupData()
        d.devices = [.appleWatch, .whoop]
        let back = try JSONDecoder().decode(SetupData.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(back.devices, [.appleWatch, .whoop])
        XCTAssertEqual(back, d)
    }

    // MARK: Multi select

    func testSelectingDevicesAddsThemAndPhoneOnlyClearsThem() {
        var set: Set<DeviceChoice> = [.phoneOnly]
        set = DeviceSelection.toggled(.appleWatch, in: set)
        XCTAssertEqual(set, [.appleWatch], "choosing a device clears Just my phone")
        set = DeviceSelection.toggled(.oura, in: set)
        XCTAssertEqual(set, [.appleWatch, .oura])
        set = DeviceSelection.toggled(.phoneOnly, in: set)
        XCTAssertEqual(set, [.phoneOnly], "Just my phone is exclusive")
    }

    func testTurningOffTheLastDeviceFallsBackToPhoneOnly() {
        XCTAssertEqual(DeviceSelection.toggled(.garmin, in: [.garmin]), [.phoneOnly])
        XCTAssertEqual(DeviceSelection.toggled(.garmin, in: [.garmin, .whoop]), [.whoop])
        XCTAssertEqual(DeviceSelection.toggled(.phoneOnly, in: [.phoneOnly]), [.phoneOnly])
    }

    func testSelectionNeverLeavesAnInvalidSet() {
        var set: Set<DeviceChoice> = [.phoneOnly]
        for device in DeviceSelection.displayOrder + DeviceSelection.displayOrder.reversed() {
            set = DeviceSelection.toggled(device, in: set)
            XCTAssertFalse(set.isEmpty)
            XCTAssertFalse(set.contains(.phoneOnly) && set.count > 1, "\(set)")
        }
    }

    func testEveryCardIsShownOnce() {
        XCTAssertEqual(Set(DeviceSelection.displayOrder), Set(DeviceChoice.allCases))
        XCTAssertEqual(DeviceSelection.displayOrder.count, DeviceChoice.allCases.count)
    }

    func testDerivedValues() {
        var d = SetupData()
        XCTAssertFalse(d.canSendToWatch)
        XCTAssertFalse(d.hasRecoverySource)
        XCTAssertEqual(d.followDevice, .phoneOnly)
        d.devices = [.garmin, .appleWatch, .oura, .whoop]
        XCTAssertTrue(d.canSendToWatch)
        XCTAssertEqual(d.followDevice, .appleWatch)
        XCTAssertEqual(d.recoveryOrder, ReadinessSource.defaultOrder, "Oura, WHOOP, Apple Watch, Garmin")
        d.devices = [.otherWatch]
        XCTAssertFalse(d.hasRecoverySource, "another watch cannot be read")
        XCTAssertEqual(d.followDevice, .otherWatch)
        d.devices = [.whoop, .oura]
        XCTAssertEqual(d.recoveryOrder, [.oura, .whoop])
        XCTAssertFalse(d.canSendToWatch)
    }

    func testWhoopAndOuraAreBetaAndTheRestAreNot() {
        XCTAssertEqual(Set(DeviceChoice.allCases.filter(\.isBeta)), [.whoop, .oura])
        for d in [DeviceChoice.whoop, .oura] { XCTAssertTrue(d.blurb.contains("coming soon"), "\(d)") }
    }

    func testLaunchArgumentTakesACommaList() {
        XCTAssertEqual(LaunchConfig.devices(fromList: "appleWatch,oura"), [.appleWatch, .oura])
        XCTAssertEqual(LaunchConfig.devices(fromList: "Apple-Watch, WHOOP"), [.appleWatch, .whoop])
        XCTAssertEqual(LaunchConfig.devices(fromList: "garmin"), [.garmin])
        XCTAssertTrue(LaunchConfig.devices(fromList: "toaster").isEmpty)
    }

    // MARK: Reader grouping

    private func sample(_ kind: RecoverySample.Kind, _ hour: Int, daysBack: Int, _ value: Double, _ source: String) -> RecoverySample {
        let day = cal.date(byAdding: .day, value: -daysBack, to: today) ?? today
        let t = cal.date(byAdding: .hour, value: hour, to: day) ?? day
        return RecoverySample(kind: kind, start: t, end: t.addingTimeInterval(kind == .sleep ? value * 60 : 60), value: value, sourceName: source)
    }

    func testSourceNamesMapToEngineSources() {
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "WHOOP"), .whoop)
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "Oura"), .oura)
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "oura ring"), .oura)
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "Garmin Connect"), .garmin)
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "Apple Watch"), .appleWatch)
        XCTAssertEqual(RecoveryGrouping.source(forSourceName: "Some Other App"), .appleWatch)
    }

    func testGroupingKeepsEachSourceApart() {
        let samples = [
            sample(.hrv, 3, daysBack: 0, 60, "Apple Watch"), sample(.hrv, 4, daysBack: 0, 70, "Apple Watch"),
            sample(.hrv, 3, daysBack: 0, 90, "Oura"),
            sample(.restingHeartRate, 12, daysBack: 0, 52, "Apple Watch"),
            sample(.sleep, 6, daysBack: 0, 420, "Apple Watch"), sample(.sleep, 2, daysBack: 0, 30, "Apple Watch"),
            sample(.sleep, 7, daysBack: 0, 400, "WHOOP"),
        ]
        let nights = RecoveryGrouping.nights(from: samples, calendar: cal)
        XCTAssertEqual(Set(nights.map(\.source)), [.appleWatch, .oura, .whoop])
        let watch = nights.first { $0.source == .appleWatch }
        XCTAssertEqual(watch?.hrvMilliseconds, 65, "two readings are averaged")
        XCTAssertEqual(watch?.restingHeartRate, 52)
        XCTAssertEqual(watch?.sleepMinutes, 450, "stretches of sleep add up")
        XCTAssertEqual(nights.first { $0.source == .oura }?.hrvMilliseconds, 90)
        XCTAssertNil(nights.first { $0.source == .oura }?.sleepMinutes)
        XCTAssertEqual(nights.first { $0.source == .whoop }?.sleepMinutes, 400)
        XCTAssertTrue(nights.allSatisfy { $0.date == today })
    }

    func testDaytimeHeartRateVariabilityIsIgnoredAndEveningCountsForNextMorning() {
        let samples = [
            sample(.hrv, 14, daysBack: 1, 30, "Apple Watch"),
            sample(.hrv, 23, daysBack: 1, 55, "Apple Watch"),
        ]
        let nights = RecoveryGrouping.nights(from: samples, calendar: cal)
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights.first?.date, today, "a reading at 11 pm belongs to the next morning")
        XCTAssertEqual(nights.first?.hrvMilliseconds, 55)
    }

    func testGarminKeepsNoHeartRateVariability() {
        let samples = [
            sample(.hrv, 3, daysBack: 0, 80, "Garmin Connect"),
            sample(.restingHeartRate, 12, daysBack: 0, 50, "Garmin Connect"),
            sample(.sleep, 6, daysBack: 0, 430, "Garmin Connect"),
        ]
        let night = RecoveryGrouping.nights(from: samples, calendar: cal).first
        XCTAssertEqual(night?.source, .garmin)
        XCTAssertNil(night?.hrvMilliseconds)
        XCTAssertEqual(night?.restingHeartRate, 50)
        XCTAssertEqual(night?.sleepMinutes, 430)
    }

    func testBadValuesAreDropped() {
        let samples = [
            sample(.hrv, 3, daysBack: 0, .nan, "Apple Watch"),
            sample(.hrv, 3, daysBack: 1, -4, "Apple Watch"),
            sample(.restingHeartRate, 12, daysBack: 2, 0, "Apple Watch"),
        ]
        XCTAssertTrue(RecoveryGrouping.nights(from: samples, calendar: cal).isEmpty)
        XCTAssertTrue(RecoveryGrouping.nights(from: [], calendar: cal).isEmpty)
    }

    func testFixtureScenariosFeedTheEngine() async {
        for scenario in FixtureRecoveryReader.Scenario.allCases {
            let reader = FixtureRecoveryReader(scenario: scenario)
            let outcome = await reader.fetchNights(now: now, days: 60, calendar: cal)
            guard case .nights(let nights) = outcome else { XCTFail("\(scenario)"); continue }
            switch scenario {
            case .none: XCTAssertTrue(nights.isEmpty)
            case .calibrating: XCTAssertEqual(nights.count, 9)
            case .onTrack, .below: XCTAssertEqual(nights.count, 45)
            case .stale: XCTAssertEqual(nights.count, 45); XCTAssertLessThan(nights.map(\.date).max() ?? .distantFuture, today)
            }
        }
    }

    func testFixtureAccessCanBeDenied() async {
        let granted = await FixtureRecoveryReader(scenario: .none, grantsAccess: true).requestAccess()
        let denied = await FixtureRecoveryReader(scenario: .none, grantsAccess: false).requestAccess()
        XCTAssertTrue(granted)
        XCTAssertFalse(denied)
    }

    // MARK: Coordinator

    private func coordinator(_ scenario: FixtureRecoveryReader.Scenario, names: [String] = ["Apple Watch"]) -> ReadinessCoordinator {
        ReadinessCoordinator(reader: FixtureRecoveryReader(scenario: scenario, sourceNames: names), defaults: freshDefaults())
    }

    func testNoRecoveryDeviceMeansNoReadinessInputs() async {
        let c = coordinator(.onTrack)
        await c.refresh(now: now, calendar: cal)
        var d = SetupData()
        d.devices = [.phoneOnly]
        XCTAssertNil(c.inputs(for: d))
        d.devices = [.otherWatch]
        XCTAssertNil(c.inputs(for: d))
    }

    func testOnlyConnectedDevicesFeedTheEngine() async {
        let c = coordinator(.onTrack, names: ["Apple Watch", "Oura", "WHOOP"])
        await c.refresh(now: now, calendar: cal)
        var d = SetupData()
        d.devices = [.appleWatch]
        XCTAssertEqual(Set(c.inputs(for: d)?.nights.map(\.source) ?? []), [.appleWatch])
        d.devices = [.appleWatch, .oura]
        XCTAssertEqual(Set(c.inputs(for: d)?.nights.map(\.source) ?? []), [.appleWatch, .oura])
    }

    func testStateIsSavedAndRestored() async {
        let defaults = freshDefaults()
        let c = ReadinessCoordinator(reader: FixtureRecoveryReader(scenario: .onTrack), defaults: defaults)
        await c.refresh(now: now, calendar: cal)
        c.keepPlannedSession(on: now, calendar: cal)
        c.keepPlannedSession(on: now, calendar: cal)
        c.setPreferred(.appleWatch, today: now, calendar: cal)
        let again = ReadinessCoordinator(reader: FixtureRecoveryReader(scenario: .none), defaults: defaults)
        XCTAssertEqual(again.state.overrides, [today], "one tap per day")
        XCTAssertEqual(again.state.preferredSource, .appleWatch)
        XCTAssertEqual(again.state.sourceChangedOn, today)
        XCTAssertNotNil(again.state.lastSyncBySource[.appleWatch])
        XCTAssertNotNil(again.state.lastRead)
        XCTAssertTrue(again.nights.isEmpty, "readings are never saved")
    }

    func testAbsorbRemembersTheSourceInUse() async {
        let c = coordinator(.onTrack)
        await c.refresh(now: now, calendar: cal)
        var d = SetupData()
        d.devices = [.appleWatch]
        guard let inputs = c.inputs(for: d) else { XCTFail("no inputs"); return }
        let ran = EngineBuilder.kit.readiness(plan: basePlan(d), inputs: inputs, today: today, calendar: cal)
        c.absorb(ran.assessment)
        XCTAssertEqual(c.state.activeSource, .appleWatch)
        XCTAssertEqual(c.inputs(for: d)?.activeSource, .appleWatch)
    }

    func testChangingTheTopDeviceRestartsCalibrationButAddingASecondDoesNot() {
        let c = coordinator(.none)
        var old = SetupData()
        old.devices = [.appleWatch]
        var withGarmin = old
        withGarmin.devices = [.appleWatch, .garmin]
        c.devicesChanged(from: old, to: withGarmin, today: now, calendar: cal)
        XCTAssertNil(c.state.sourceChangedOn, "Apple Watch is still first in line")
        var withOura = old
        withOura.devices = [.appleWatch, .oura]
        c.devicesChanged(from: old, to: withOura, today: now, calendar: cal)
        XCTAssertEqual(c.state.sourceChangedOn, today, "Oura now comes first")
    }

    func testRemovingTheChosenDeviceClearsTheChoice() {
        let c = coordinator(.none)
        c.setPreferred(.oura, today: now, calendar: cal)
        var old = SetupData(); old.devices = [.oura, .appleWatch]
        var new = old; new.devices = [.appleWatch]
        c.devicesChanged(from: old, to: new, today: now, calendar: cal)
        XCTAssertNil(c.state.preferredSource)
        var d = SetupData(); d.devices = [.appleWatch]
        XCTAssertNil(c.inputs(for: d)?.preferredRecoverySource)
    }

    func testRemovingANonTopChosenDeviceClearsTheChoice() {
        let c = coordinator(.none)
        c.setPreferred(.garmin, today: now, calendar: cal)
        var old = SetupData(); old.devices = [.oura, .garmin]
        var new = old; new.devices = [.oura]
        XCTAssertEqual(old.recoveryOrder.first, new.recoveryOrder.first, "the top source does not change")
        c.devicesChanged(from: old, to: new, today: now, calendar: cal)
        XCTAssertNil(c.state.preferredSource)
    }

    func testFailedAndUnavailableReadsAreReportedNotHidden() {
        let c = coordinator(.none)
        c.apply(.unavailable, now: now)
        XCTAssertEqual(c.status, .unavailable)
        c.apply(.failed, now: now)
        XCTAssertEqual(c.status, .failed)
        c.apply(.nights([]), now: now)
        XCTAssertEqual(c.status, .read(nights: 0))
    }

    func testPermissionResultLinesOnlyReportWhatWasFound() {
        XCTAssertNil(OnboardingDevicesStep.resultLine(asked: false, status: .read(nights: 12)))
        XCTAssertEqual(OnboardingDevicesStep.resultLine(asked: true, status: .read(nights: 12)), "Found 12 nights of data from your devices.")
        XCTAssertTrue(OnboardingDevicesStep.resultLine(asked: true, status: .read(nights: 0))?.contains("No nights found") == true)
        XCTAssertNotNil(OnboardingDevicesStep.resultLine(asked: true, status: .unavailable))
    }

    // MARK: Engine and readiness line

    private func basePlan(_ d: SetupData) -> EnginePlan {
        let bench = EngineBuilder.benchmarks(d, today: today)
        return EngineBuilder.buildPlan(d, planStart: today, today: today, benchmarks: bench, calendar: cal).plan
            ?? EnginePlan(raceDistance: nil, raceDate: nil, startDate: today, weeks: [], athlete: EngineBuilder.athlete(d))
    }

    private func setupWithWatch() -> SetupData {
        var d = SetupData()
        d.devices = [.appleWatch]
        d.raceChoice = .olympic
        d.raceDate = cal.date(byAdding: .day, value: 90, to: today) ?? today
        return d
    }

    private func lineFor(_ scenario: FixtureRecoveryReader.Scenario, devices: Set<DeviceChoice> = [.appleWatch]) async -> (ReadinessLineModel?, EngineModel) {
        let c = coordinator(scenario)
        await c.refresh(now: now, calendar: cal)
        var d = setupWithWatch()
        d.devices = devices
        let m = EngineBuilder.build(setup: d, planStart: today, today: today, completions: [:], readiness: c.inputs(for: d), calendar: cal)
        let line = ReadinessPlainCopy.line(assessment: m.readiness, event: m.readinessEvent, kept: m.readinessKept, hasSources: d.hasRecoverySource)
        return (line, m)
    }

    func testNoLineForPhoneOnly() async {
        let (line, m) = await lineFor(.onTrack, devices: [.phoneOnly])
        XCTAssertNil(line)
        XCTAssertNil(m.readiness, "readiness does not run without a device")
    }

    func testWaitingLineWhenHealthHasNothing() async {
        let (line, _) = await lineFor(.none)
        XCTAssertEqual(line?.headline, "Waiting for your first night of data.")
        XCTAssertFalse(line?.offersKeep ?? true)
    }

    func testCalibratingLineSaysNightNOf14() async {
        let (line, m) = await lineFor(.calibrating)
        XCTAssertEqual(m.readiness?.status, .calibrating(night: 9, of: 14))
        XCTAssertEqual(line?.headline, "Learning your usual range: night 9 of 14.")
        XCTAssertFalse(line?.offersKeep ?? true)
    }

    func testOnTrackLineIsPlain() async {
        let (line, m) = await lineFor(.onTrack)
        XCTAssertEqual(m.readiness?.status, .onTrack)
        XCTAssertEqual(line?.headline, "On track.")
        XCTAssertTrue(line?.detail?.hasPrefix("Heart rate variability on track.") == true, line?.detail ?? "nil")
        XCTAssertFalse(line?.detail?.contains("HRV") ?? true, "the shorthand is spelled out")
        XCTAssertFalse(line?.offersKeep ?? true)
    }

    func testBelowRangeLineNeverTellsAnyoneToRestOrNamesACause() async {
        let (line, m) = await lineFor(.below)
        XCTAssertEqual(m.readiness?.status, .belowUsualRange)
        XCTAssertEqual(line?.headline, "Your 7 night heart rate variability is below your usual range.")
        let text = ((line?.headline ?? "") + " " + (line?.detail ?? "")).lowercased()
        for banned in ["rest", "recover", "sick", "ill", "stress", "overtrain", "you should", "must", "need to", "hrv"] {
            XCTAssertFalse(words(text).contains(banned) || (banned.contains(" ") && text.contains(banned)), "\(banned) in: \(text)")
        }
    }

    func testBelowRangeOffersKeepOnlyWhenASessionWasChanged() async {
        // A line built from a real change event offers Keep, and says what changed without repeating the engine prompt.
        let event = AdaptationEvent(
            rule: .readinessEasy,
            reasonLine: "Today's brick became an easy brick. Your HRV has been below your usual range two mornings running and resting heart rate is up. Tap to keep the original.",
            date: today, isStructural: true, sessionIDs: ["x"], advisory: AdvisoryChange(originalSessions: []))
        let (_, m) = await lineFor(.below)
        let withEvent = ReadinessPlainCopy.line(assessment: m.readiness, event: event, kept: false, hasSources: true)
        XCTAssertEqual(withEvent?.offersKeep, event.canKeepPlannedSession)
        XCTAssertFalse(withEvent?.detail?.contains("Tap to keep") ?? true, "the button says it")
        XCTAssertFalse(withEvent?.detail?.lowercased().contains("brick") ?? true)
        XCTAssertFalse(withEvent?.detail?.contains("below your usual range") ?? true, "the headline already says it")
        // With no change event, no dead button.
        let without = ReadinessPlainCopy.line(assessment: m.readiness, event: nil, kept: false, hasSources: true)
        XCTAssertFalse(without?.offersKeep ?? true)
        XCTAssertEqual(without?.detail, "Your planned session stays as it is.")
    }

    func testKeepingPutsThePlannedSessionBackAndTheLineSaysSo() async {
        // Walk forward through the plan until a day where readiness changes a session.
        // Oura heart rate variability can ease a hard session on its own (Apple Watch alone cannot), so a walk over
        // an experienced athlete with every day free reaches a day where readiness changes a session.
        let c = coordinator(.below, names: ["Oura"])
        var d = setupWithWatch()
        d.devices = [.oura]
        d.experience = .experienced
        d.trainingDays = Set(1...7)
        d.hoursPerWeek = 10
        var found = false
        for offset in 0..<28 {
            let day = cal.date(byAdding: .day, value: offset, to: today) ?? today
            let noon = cal.date(byAdding: .hour, value: 12, to: day) ?? day
            await c.refresh(now: noon, calendar: cal)
            let m = EngineBuilder.build(setup: d, planStart: today, today: day, completions: [:], readiness: c.inputs(for: d), calendar: cal)
            guard let event = m.readinessEvent else { continue }
            found = true
            let changedID = event.sessionIDs.first
            let reasonShown = m.week.flatMap(\.sessions).contains { $0.reason != nil }
            XCTAssertTrue(reasonShown, "a changed session carries its reason")
            c.keepPlannedSession(on: day, calendar: cal)
            let kept = EngineBuilder.build(setup: d, planStart: today, today: day, completions: [:], readiness: c.inputs(for: d), calendar: cal)
            XCTAssertTrue(kept.readinessKept)
            XCTAssertNil(kept.readinessEvent)
            XCTAssertFalse(kept.week.flatMap(\.sessions).contains { $0.reason != nil }, "no reason once the original is back")
            let line = ReadinessPlainCopy.line(assessment: kept.readiness, event: kept.readinessEvent, kept: kept.readinessKept, hasSources: true)
            XCTAssertFalse(line?.offersKeep ?? true)
            XCTAssertEqual(line?.detail, "You kept your planned session.")
            _ = changedID
            break
        }
        XCTAssertTrue(found, "the walk reaches a day where readiness changes a hard session")
    }

    func testPausedLinesForEachReason() {
        func assessment(_ status: ReadinessStatus, source: ReadinessSource = .oura) -> ReadinessAssessment {
            ReadinessAssessment(status: status, line: "", source: SourceChoice(source: source, reason: .onlySource))
        }
        let few = ReadinessPlainCopy.line(assessment: assessment(.paused(.tooFewRecentNights)), event: nil, kept: false, hasSources: true)
        XCTAssertEqual(few?.headline, "Paused: fewer than 3 nights of data this week.")
        let stale = ReadinessPlainCopy.line(assessment: assessment(.paused(.noRecentSync)), event: nil, kept: false, hasSources: true)
        XCTAssertEqual(stale?.headline, "Paused: no new data from Oura in 48 hours.")
        let notes = ReadinessPlainCopy.line(assessment: assessment(.paused(.notesOnly)), event: nil, kept: false, hasSources: true)
        XCTAssertEqual(notes?.headline, "Notes only for now.")
        let race = ReadinessPlainCopy.line(assessment: assessment(.paused(.raceWindow)), event: nil, kept: false, hasSources: true)
        XCTAssertEqual(race?.headline, "Race window: your plan holds steady on purpose.")
        for l in [few, stale, notes, race] { XCTAssertFalse(l?.offersKeep ?? true) }
    }

    func testStalePauseFromRealRun() async {
        let (line, m) = await lineFor(.stale)
        XCTAssertEqual(m.readiness?.status, .paused(.noRecentSync))
        XCTAssertEqual(line?.headline, "Paused: no new data from Apple Watch in 48 hours.")
    }

    func testReadinessCopyHasNoDashesOrMedicalWords() async {
        var texts: [String] = [ReadinessPlainCopy.ruleExplanation, ReadinessPlainCopy.keepButtonTitle,
                               OnboardingDevicesStep.whyLine, OnboardingDevicesStep.phoneOnlyLine]
        for scenario in FixtureRecoveryReader.Scenario.allCases {
            let (line, _) = await lineFor(scenario)
            texts += [line?.headline, line?.detail].compactMap { $0 }
        }
        for d in DeviceChoice.allCases { texts.append(ReadinessPlainCopy.usedFor(d)) }
        for t in texts {
            XCTAssertFalse(t.contains("\u{2014}") || t.contains("\u{2013}"), "dash in: \(t)")
            for banned in ["TSS", "CTL", "ATL", "TrainingPeaks", "diagnos", "disease", "illness", "injur"] {
                XCTAssertFalse(t.contains(banned), "\(banned) in: \(t)")
            }
        }
    }

    // MARK: Connections rows

    func testRowsListEveryConnectedDeviceWithAStateAndAUse() async {
        let c = coordinator(.onTrack, names: ["Apple Watch", "Garmin"])
        await c.refresh(now: now, calendar: cal)
        var d = setupWithWatch()
        d.devices = [.appleWatch, .garmin, .otherWatch, .whoop]
        let m = EngineBuilder.build(setup: d, planStart: today, today: today, completions: [:], readiness: c.inputs(for: d), calendar: cal)
        let rows = ReadinessPlainCopy.sourceRows(data: d, assessment: m.readiness, nights: c.nights, today: today, calendar: cal)
        XCTAssertEqual(rows.map(\.device), [.appleWatch, .whoop, .garmin, .otherWatch])
        XCTAssertEqual(rows.first { $0.device == .appleWatch }?.state, .inUse)
        XCTAssertEqual(rows.first { $0.device == .garmin }?.state, .standby)
        XCTAssertEqual(rows.first { $0.device == .whoop }?.state, .notEnoughData, "no WHOOP nights in Health")
        XCTAssertEqual(rows.first { $0.device == .otherWatch }?.state, .notRead)
        XCTAssertTrue(rows.allSatisfy { !$0.usedFor.isEmpty })
        XCTAssertTrue(rows.first { $0.device == .whoop }?.usedFor.contains("Beta") ?? false)
    }

    func testRowShowsCalibratingAndPausedStates() async {
        var d = setupWithWatch()
        d.devices = [.appleWatch]
        let cal1 = coordinator(.calibrating)
        await cal1.refresh(now: now, calendar: cal)
        var m = EngineBuilder.build(setup: d, planStart: today, today: today, completions: [:], readiness: cal1.inputs(for: d), calendar: cal)
        var rows = ReadinessPlainCopy.sourceRows(data: d, assessment: m.readiness, nights: cal1.nights, today: today, calendar: cal)
        XCTAssertEqual(rows.first?.state, .calibrating(night: 9, of: 14))
        XCTAssertEqual(rows.first?.state.label, "Calibrating, night 9 of 14")

        let stale = coordinator(.stale)
        await stale.refresh(now: now, calendar: cal)
        m = EngineBuilder.build(setup: d, planStart: today, today: today, completions: [:], readiness: stale.inputs(for: d), calendar: cal)
        rows = ReadinessPlainCopy.sourceRows(data: d, assessment: m.readiness, nights: stale.nights, today: today, calendar: cal)
        XCTAssertEqual(rows.first?.state.label, "Paused")
        XCTAssertEqual(rows.first?.note, "No new data in 48 hours.")

        let none = coordinator(.none)
        await none.refresh(now: now, calendar: cal)
        m = EngineBuilder.build(setup: d, planStart: today, today: today, completions: [:], readiness: none.inputs(for: d), calendar: cal)
        rows = ReadinessPlainCopy.sourceRows(data: d, assessment: m.readiness, nights: none.nights, today: today, calendar: cal)
        XCTAssertEqual(rows.first?.state, .notEnoughData)
    }

    func testPhoneOnlyRowIsNotRead() {
        let d = SetupData()
        let rows = ReadinessPlainCopy.sourceRows(data: d, assessment: nil, nights: [], today: today, calendar: cal)
        XCTAssertEqual(rows.map(\.device), [.phoneOnly])
        XCTAssertEqual(rows.first?.state, .notRead)
    }

    // MARK: Helpers

    private func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
