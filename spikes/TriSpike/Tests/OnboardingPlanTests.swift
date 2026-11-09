import XCTest
@testable import TriSpike

/// Onboarding choices and copy rules. The engine derived plan numbers are tested in EngineWiringTests.
/// No test traps: failures are assertions only.
final class OnboardingPlanTests: XCTestCase {
    func testFirstTimerIsTheDefaultExperience() {
        XCTAssertEqual(SetupData().experience, .firstTimer)
    }

    func testOnlyAppleWatchCanReceiveSessions() {
        for t in DeviceChoice.allCases {
            XCTAssertEqual(t.canReceiveSessionsOnWrist, t == .appleWatch, "\(t)")
        }
    }

    func testDevicesHaveDistinctSymbols() {
        XCTAssertEqual(Set(DeviceChoice.allCases.map(\.symbol)).count, DeviceChoice.allCases.count)
    }

    func testSafetyLinesJoinBackToTheAnnexString() {
        XCTAssertEqual(OnboardingSafetyStep.lines.joined(separator: " "), OnboardingSafetyStep.acknowledgement)
        XCTAssertEqual(OnboardingSafetyStep.lines.count, 3)
    }

    func testNoDashesInUserFacingStrings() {
        var strings: [String] = []
        for t in Term.allCases { strings += [t.title, t.short, t.explanation] }
        for t in DeviceChoice.allCases { strings += [t.title, t.blurb, ReadinessPlainCopy.usedFor(t)] }
        for r in RaceChoice.allCases { strings += [r.title, r.summary, r.blurb, r.typicalWeeks] }
        for e in ExperienceChoice.allCases { strings += [e.title, e.blurb] }
        for p in Phase.allCases { strings.append(p.plainLine) }
        for s in strings {
            XCTAssertFalse(s.contains("\u{2014}") || s.contains("\u{2013}"), "dash in: \(s)")
        }
    }
}
