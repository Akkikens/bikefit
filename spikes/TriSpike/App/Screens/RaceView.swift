import SwiftUI

struct RaceView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var hero: CGFloat = 112
    @State private var checked: [UUID: Set<Int>] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    countdown
                    courseCard
                    timeline
                    ForEach(Demo.checklists) { list in checklistCard(list) }
                    fueling
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.vertical, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .navigationTitle(Demo.raceName)
        }
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Demo.daysToRace)")
                    .font(BLFont.hero(min(160, max(72, hero))))
                    .kerning(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(BL.textPrimary)
                Text("days").font(BLFont.label).foregroundStyle(BL.textSecondary)
            }
            Text("Start \(Demo.raceStart), wake \(Demo.raceWake)").font(BLFont.meta).foregroundStyle(BL.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Demo.daysToRace) days to race. Start \(Demo.raceStart), wake \(Demo.raceWake).")
    }

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.l) {
            SectionLabel(text: "Race day", trailing: "predicted 2:28")
            ProfileView(steps: Demo.raceLegs, mode: .structure, height: 56, ruler: true)
            VStack(spacing: 0) {
                ForEach(Array(Demo.raceLegs.enumerated()), id: \.offset) { i, leg in
                    HStack {
                        Image(systemName: leg.sport.symbol(openWater: leg.sport == .swim)).foregroundStyle(leg.sport.ink).frame(width: 24)
                        Text(leg.name).font(.body)
                        Spacer()
                        Text(leg.target ?? "").font(.body.weight(.medium).monospacedDigit()).foregroundStyle(leg.sport.ink)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                    if i < Demo.raceLegs.count - 1 {
                        HStack {
                            Text(i == 0 ? "t1" : "t2").font(BLFont.label).foregroundStyle(BL.textSecondary)
                            Rectangle().fill(BL.separator).frame(height: 0.5)
                        }
                    }
                }
            }
            Text("Targets are ranges. On a hilly or windy course they can be off by several percent, so ride and run by feel first.")
                .font(.footnote).foregroundStyle(BL.textSecondary)
        }
        .card()
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Timeline")
            VStack(spacing: 0) {
                ForEach(Array(Demo.timeline.enumerated()), id: \.element.id) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 24).foregroundStyle(BL.textPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.tMinus.lowercased()).font(BLFont.label).foregroundStyle(BL.textSecondary)
                            Text(item.text).font(.body).foregroundStyle(BL.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if i < Demo.timeline.count - 1 { Divider().overlay(BL.separator) }
                }
            }
            .card()
        }
    }

    private func checklistCard(_ list: Demo.Checklist) -> some View {
        let done = checked[list.id, default: []]
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: list.title, trailing: "\(done.count) of \(list.items.count)")
            VStack(spacing: 0) {
                ForEach(Array(list.items.enumerated()), id: \.offset) { i, item in
                    ChecklistRow(text: item, done: Binding(
                        get: { checked[list.id, default: []].contains(i) },
                        set: { on in
                            var s = checked[list.id, default: []]
                            if on { s.insert(i) } else { s.remove(i) }
                            checked[list.id] = s
                        }))
                    if i < list.items.count - 1 { Divider().overlay(BL.separator).padding(.leading, 34) }
                }
            }
            .card()
        }
    }

    private var fueling: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Fueling")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                fuelRow(.swim, "Swim, 28 min", "Nothing needed. Breakfast carries you.")
                Divider().overlay(BL.separator)
                fuelRow(.bike, "Bike, 70 min", "About 30 to 45 g carbohydrate per hour. Practice it in training.")
                Divider().overlay(BL.separator)
                fuelRow(.run, "Run, 47 min", "Fluids to thirst. A gel at the start is optional.")
            }
            .card()
        }
    }

    private func fuelRow(_ sport: Sport, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: sport.symbol()).foregroundStyle(sport.ink).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
