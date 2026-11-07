import HealthKit
import WorkoutKit
import XCTest
@testable import TriSpike

/// Simulator verifiable parts of the week 1 gate. No test traps: failures are assertions only.
final class CompositionTests: XCTestCase {
    func testEveryProductionShapeRoundTrips() throws {
        for (label, plan) in SampleSessions.allPlans() {
            let decoded = try WorkoutPlan(from: try plan.dataRepresentation)
            XCTAssertEqual(decoded, plan, "round trip failed for \(label)")
        }
    }

    func testPoolSwimUsesDistanceWithTimeGoal() {
        let swim = SampleSessions.poolSwimSets()
        let goals = swim.blocks.flatMap { $0.steps.map(\.step.goal) }
        XCTAssertEqual(swim.blocks.first?.iterations, 8)
        XCTAssertTrue(goals.allSatisfy {
            if case .poolSwimDistanceWithTime = $0 { return true }
            return false
        })
    }

    func testStepDisplayNamesSurviveRoundTrip() throws {
        let plan = WorkoutPlan(.custom(SampleSessions.thresholdRun()))
        guard case .custom(let run) = try WorkoutPlan(from: try plan.dataRepresentation).workout else {
            return XCTFail("not a custom workout")
        }
        XCTAssertEqual(run.warmup?.displayName, "Easy warm up")
        XCTAssertEqual(run.blocks.first?.steps.first?.step.displayName, "Threshold")
    }

    func testRaceDayKeepsLegOrder() throws {
        let plan = WorkoutPlan(.swimBikeRun(SampleSessions.raceDay()))
        guard case .swimBikeRun(let race) = try WorkoutPlan(from: try plan.dataRepresentation).workout else {
            return XCTFail("not multisport")
        }
        XCTAssertEqual(race.activities, SampleSessions.raceLegs)
    }

    func testThresholdBandUsesPercentWithTenSecondFloor() {
        // 4:30/km: 3 percent is 8.1 s, so the 10 s floor applies.
        let slowRunner = Pace.thresholdBand(thresholdSecondsPerKm: 270)
        XCTAssertEqual(slowRunner.faster, 260, accuracy: 0.001)
        XCTAssertEqual(slowRunner.slower, 280, accuracy: 0.001)
        // 6:00/km: 3 percent is 10.8 s, above the floor.
        let easyRunner = Pace.thresholdBand(thresholdSecondsPerKm: 360)
        XCTAssertEqual(easyRunner.faster, 349.2, accuracy: 0.001)
    }

    func testPaceToSpeedOrdersTheRange() {
        let range = Pace.speedRange(fasterSecondsPerKm: 260, slowerSecondsPerKm: 280)
        XCTAssertEqual(range.lowerBound, 1000.0 / 280, accuracy: 1e-9)
        XCTAssertEqual(range.upperBound, 1000.0 / 260, accuracy: 1e-9)
    }

    func testSchedulerCountIsReadableAtRuntime() {
        // The spec says the max count is undocumented; this records it. It must at least cover one week.
        XCTAssertGreaterThanOrEqual(WorkoutScheduler.maxAllowedScheduledWorkoutCount, 7)
    }

    @MainActor
    func testSpecTestPlayerSessionIsThirtyMinutes() {
        let total = PhonePlayer.specTest.reduce(0) { $0 + $1.seconds }
        XCTAssertEqual(total, 30 * 60)
    }

    @MainActor
    func testQuickTestPlayerSessionIsThreeMinutes() {
        let total = PhonePlayer.quickTest.reduce(0) { $0 + $1.seconds }
        XCTAssertEqual(total, 3 * 60)
    }
}
