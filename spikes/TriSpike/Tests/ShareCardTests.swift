import XCTest
import SwiftUI
import UIKit
@testable import TriSpike

/// Share cards: they render without crashing, in light and dark, and carry only what the screen shows.
@MainActor
final class ShareCardTests: XCTestCase {
    private let when = Date(timeIntervalSince1970: 1_800_000_000)

    private func sessionCard(finished: Bool = true, estimated: Bool = false) -> ShareCardData {
        ShareCards.session(
            name: "Steady swim, 1200 m", sport: .swim, brickSecond: nil, minutes: 32, finishedInFull: finished,
            distanceMeters: 1200, target: (value: "1:52", unit: "per 100 m"), targetEstimated: estimated,
            weekDoneMinutes: 95, weekDoneSessions: 3, weekLabel: "Week 3 of 12", date: when)
    }

    private func raceCard() -> ShareCardData {
        ShareCards.race(name: "Lakeside Sprint", race: .sprint, hasRace: true, daysToRace: 42, raceDate: when,
                        estimatedFinish: 4800, weekLabel: "Week 3 of 12")
    }

    func testBothCardsRenderAtThePrintSizeInLightAndDark() {
        for data in [sessionCard(), raceCard()] {
            for style in ShareCardData.Style.allCases {
                let image = ShareCardRenderer.image(data, style: style)
                XCTAssertNotNil(image, "\(data.headline) \(style)")
                XCTAssertEqual(image?.size.width ?? 0, 360, accuracy: 0.5)
                XCTAssertEqual(image?.size.height ?? 0, 450, accuracy: 0.5)
                XCTAssertEqual(image?.scale ?? 0, 3, accuracy: 0.01)
            }
        }
    }

    func testLightAndDarkLookDifferent() {
        let light = ShareCardRenderer.image(sessionCard(), style: .light)?.pngData()
        let dark = ShareCardRenderer.image(sessionCard(), style: .dark)?.pngData()
        XCTAssertNotNil(light); XCTAssertNotNil(dark)
        XCTAssertNotEqual(light, dark)
    }

    func testOddInputsDoNotCrash() {
        let odd = ShareCards.session(
            name: String(repeating: "Long name ", count: 40), sport: .run, brickSecond: .bike, minutes: 0, finishedInFull: false,
            distanceMeters: nil, target: nil, targetEstimated: true, weekDoneMinutes: 0, weekDoneSessions: 0,
            weekLabel: "", date: Date(timeIntervalSince1970: 0))
        XCTAssertNotNil(ShareCardRenderer.image(odd, style: .light))
        let race = ShareCards.race(name: "", race: .half, hasRace: false, daysToRace: -3, raceDate: when, estimatedFinish: nil, weekLabel: "")
        XCTAssertNotNil(ShareCardRenderer.image(race, style: .dark))
    }

    func testSessionCardCarriesOnlyWhatTheScreenShows() {
        let card = sessionCard()
        XCTAssertEqual(card.kicker, "Swim")
        XCTAssertEqual(card.bigValue, "32")
        XCTAssertEqual(card.bigUnit, "min")
        XCTAssertEqual(card.rows.map(\.label), ["Planned distance", "Target pace", "This week"])
        XCTAssertEqual(card.rows.last?.value, "3 sessions, 1 h 35 min")
        XCTAssertTrue(card.allText.contains("TriSpike"))
        let text = card.allText.joined(separator: " ").lowercased()
        for private_ in ["heart", "bpm", "sleep", "hrv", "resting", "apple", "watch", "whoop", "oura", "garmin", "strava", "location", "gps", "@"] {
            XCTAssertFalse(text.contains(private_), private_)
        }
        XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"))
    }

    func testEstimatedTargetsAndEndedEarlySessionsHideWhatIsNotKnown() {
        let est = sessionCard(estimated: true)
        XCTAssertFalse(est.rows.contains { $0.label == "Target pace" }, "an estimate is not shared as a number")
        let early = sessionCard(finished: false)
        XCTAssertFalse(early.rows.contains { $0.label == "Planned distance" })
        XCTAssertTrue(early.footer?.hasPrefix("Ended early") == true)
    }

    func testFeelWordsAreNotShownAsTargets() {
        let card = ShareCards.session(
            name: "Easy run, 30 min", sport: .run, brickSecond: nil, minutes: 30, finishedInFull: true, distanceMeters: nil,
            target: (value: "Easy", unit: "effort"), targetEstimated: false, weekDoneMinutes: 30, weekDoneSessions: 1,
            weekLabel: "Week 1 of 8", date: when)
        XCTAssertEqual(card.rows.map(\.label), ["This week"])
    }

    func testRaceCardShowsLegsAndCountdownOnly() {
        let card = raceCard()
        XCTAssertEqual(card.bigValue, "42")
        XCTAssertEqual(card.bigUnit, "days to go")
        XCTAssertEqual(card.rows.map(\.label), ["Swim", "Bike", "Run", "Estimated finish"])
        XCTAssertEqual(card.rows.first?.value, "750 m")
        XCTAssertEqual(card.rows.last?.value, "1 h 20 min")
        let none = ShareCards.race(name: "Triathlon", race: .superSprint, hasRace: false, daysToRace: 0, raceDate: when, estimatedFinish: nil, weekLabel: "")
        XCTAssertEqual(none.bigValue, "Super sprint")
        XCTAssertEqual(none.rows.map(\.value), ["400 m", "10 km", "2.5 km"])
    }
}
