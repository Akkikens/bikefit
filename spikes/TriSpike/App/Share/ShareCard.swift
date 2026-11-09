import SwiftUI
import UIKit

/// Everything printed on a share card. Built only from what the athlete already sees on screen, so a card can never
/// carry more than the app shows: no heart rate, sleep, health data, location, devices or account names.
struct ShareCardData: Equatable {
    enum Style: String, CaseIterable { case light, dark }

    struct Row: Equatable, Identifiable {
        var label: String
        var value: String
        var id: String { label }
    }

    var symbol: String
    var kicker: String
    var headline: String
    var bigValue: String
    var bigUnit: String
    var rows: [Row]
    var footer: String?
    var dateText: String

    /// The wordmark: text only, original.
    static let wordmark = "TriSpike"

    /// Every string on the card, for tests and for the accessibility label.
    var allText: [String] {
        [Self.wordmark, kicker, headline, bigValue, bigUnit] + rows.flatMap { [$0.label, $0.value] } + (footer.map { [$0] } ?? []) + [dateText]
    }

    var accessibilityLabel: String {
        var parts = ["TriSpike", kicker, headline, "\(bigValue) \(bigUnit)"]
        parts += rows.map { "\($0.label) \($0.value)" }
        if let footer { parts.append(footer) }
        return parts.joined(separator: ". ")
    }

    var shareTitle: String { headline }
}

enum ShareCards {
    /// The card for a finished session.
    /// - Parameters:
    ///   - distanceMeters: the session's planned distance, offered only for a swim finished in full.
    ///   - target: the session's headline target, offered only when it rests on a tested or typed number.
    static func session(
        name: String, sport: Sport, brickSecond: Sport?, minutes: Int, finishedInFull: Bool,
        distanceMeters: Int?, target: (value: String, unit: String)?, targetEstimated: Bool,
        weekDoneMinutes: Int, weekDoneSessions: Int, weekLabel: String, date: Date
    ) -> ShareCardData {
        var rows: [ShareCardData.Row] = []
        if finishedInFull, let m = distanceMeters, m > 0 {
            rows.append(.init(label: "Planned distance", value: "\(m) m"))
        }
        if let target, !targetEstimated, let label = targetLabel(unit: target.unit) {
            rows.append(.init(label: label, value: "\(target.value) \(target.unit)"))
        }
        rows.append(.init(label: "This week", value: "\(weekDoneSessions) \(weekDoneSessions == 1 ? "session" : "sessions"), \(OBFormat.duration(minutes: weekDoneMinutes))"))
        let kicker = brickSecond.map { "\(sport.word) then \($0.word.lowercased())" } ?? sport.word
        return ShareCardData(
            symbol: sport.symbol(), kicker: kicker, headline: name, bigValue: "\(max(minutes, 1))", bigUnit: "min",
            rows: rows, footer: finishedInFull ? weekLabel : "Ended early, and that counts. \(weekLabel)",
            dateText: date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }

    private static func targetLabel(unit: String) -> String? {
        switch unit {
        case "per km", "per 100 m": return "Target pace"
        case "watts": return "Target power"
        default: return nil
        }
    }

    /// The card for the race: what it is, how far away, and the legs.
    static func race(
        name: String, race: RaceChoice, hasRace: Bool, daysToRace: Int, raceDate: Date,
        estimatedFinish: TimeInterval?, weekLabel: String
    ) -> ShareCardData {
        var rows: [ShareCardData.Row] = [
            .init(label: "Swim", value: "\(race.swimMeters) m"),
            .init(label: "Bike", value: "\(race.bikeKm) km"),
            .init(label: "Run", value: race.runKm == race.runKm.rounded() ? "\(Int(race.runKm)) km" : "\(race.runKm) km"),
        ]
        if let finish = estimatedFinish, finish > 0 {
            rows.append(.init(label: "Estimated finish", value: duration(finish)))
        }
        let big: (String, String)
        let date: String
        if hasRace && daysToRace > 0 {
            big = ("\(daysToRace)", daysToRace == 1 ? "day to go" : "days to go")
            date = raceDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        } else if hasRace {
            big = ("Race", "day")
            date = raceDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        } else {
            big = (race.title, "triathlon")
            date = "Training for it"
        }
        return ShareCardData(
            symbol: "flag.checkered", kicker: "Triathlon", headline: name, bigValue: big.0, bigUnit: big.1,
            rows: rows, footer: weekLabel, dateText: date)
    }
}

/// The card itself, drawn at a fixed 360 by 450 points. It carries its own colors so the picture looks the same on any
/// phone setting, and `style` picks the light or the dark look.
struct ShareCardView: View {
    var data: ShareCardData
    var style: ShareCardData.Style

    static let size = CGSize(width: 360, height: 450)

    private var background: Color { style == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color(red: 0.96, green: 0.95, blue: 0.93) }
    private var ink: Color { style == .dark ? Color(red: 0.95, green: 0.94, blue: 0.92) : Color(red: 0.11, green: 0.11, blue: 0.12) }
    private var quiet: Color { style == .dark ? Color(red: 0.70, green: 0.69, blue: 0.66) : Color(red: 0.30, green: 0.31, blue: 0.34) }
    private var line: Color { style == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(ShareCardData.wordmark.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(ink)
                Spacer()
                Image(systemName: data.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ink)
            }
            Rectangle().fill(line).frame(height: 1).padding(.top, 14)

            Text(data.kicker.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(quiet)
                .padding(.top, 22)
            Text(data.headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, 6)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(data.bigValue)
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(ink)
                Text(data.bigUnit)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(quiet)
            }
            .padding(.top, 14)

            VStack(spacing: 0) {
                ForEach(data.rows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label).font(.system(size: 14)).foregroundStyle(quiet)
                        Spacer(minLength: 12)
                        Text(row.value).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 8)
                    Rectangle().fill(line).frame(height: 1)
                }
            }
            .padding(.top, 14)

            Spacer(minLength: 8)
            if let footer = data.footer {
                Text(footer).font(.system(size: 13)).foregroundStyle(quiet).lineLimit(2)
            }
            Text(data.dateText).font(.system(size: 13, weight: .medium)).foregroundStyle(quiet).padding(.top, 2)
        }
        .padding(26)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilityLabel)
    }
}

/// Draws a card to a picture on the phone. No network, no files.
@MainActor
enum ShareCardRenderer {
    /// 3 times the point size: 1080 by 1350 pixels.
    static func image(_ data: ShareCardData, style: ShareCardData.Style) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(data: data, style: style))
        renderer.proposedSize = ProposedViewSize(ShareCardView.size)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// A preview of the card and a system share button. The picture is drawn when the view appears and again if the
/// card or the phone's light or dark setting changes. It never leaves the phone unless the athlete picks a place to send it.
struct ShareCardButton: View {
    var data: ShareCardData
    var title = "Share card"
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    private var style: ShareCardData.Style { scheme == .dark ? .dark : .light }

    var body: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous).strokeBorder(BL.separator, lineWidth: 1))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(data.accessibilityLabel)
                ShareLink(item: Image(uiImage: image), preview: SharePreview(data.shareTitle, image: Image(uiImage: image))) {
                    Label(title, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("A picture made on your phone. It shows only what is on this card.")
                    .font(.footnote).foregroundStyle(BL.textSecondary)
            }
        }
        .task(id: "\(data.accessibilityLabel)|\(style.rawValue)") {
            image = ShareCardRenderer.image(data, style: style)
        }
    }
}
