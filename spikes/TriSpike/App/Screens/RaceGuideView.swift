import SwiftUI

/// "What to expect on race day": a plain walk through the race for people who have never done one, then a gear
/// list split into what you need and what is nice to have. Ticks survive relaunch.
struct RaceGuideView: View {
    var race: RaceChoice
    @AppStorage("race.gear.checked") private var checkedRaw = ""
    @ScaledMetric(relativeTo: .body) private var glyphWidth: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                Text("A first timer's guide to \(race.title.lowercased()) race day. Nothing here is a rule you must pass. It is what usually happens, so nothing surprises you.")
                    .font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(RaceDayGuide.sections(for: race)) { section in
                    sectionCard(section)
                }

                VStack(alignment: .leading, spacing: BL.Space.s) {
                    SectionLabel(text: "Gear: what you need")
                    Text(RaceDayGuide.gearIntro)
                        .font(.subheadline).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    gearList("Need", RaceDayGuide.requiredGear)
                }
                VStack(alignment: .leading, spacing: BL.Space.s) {
                    SectionLabel(text: "Gear: nice to have")
                    gearList("Nice", RaceDayGuide.niceToHaveGear)
                }
            }
            .padding(.horizontal, BL.Space.gutter)
            .padding(.top, BL.Space.s)
            .padding(.bottom, BL.Space.l)
        }
        .background(BL.background.ignoresSafeArea())
        .navigationTitle("What to expect")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionCard(_ s: RaceDayGuide.Section) -> some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            HStack(spacing: BL.Space.s) {
                Image(systemName: s.symbol).foregroundStyle(BL.textSecondary).frame(width: glyphWidth)
                    .accessibilityHidden(true)
                Text(s.title).font(.headline).foregroundStyle(BL.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(s.lines, id: \.self) { line in
                Text(line).font(.subheadline).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let term = s.term {
                CompactJargon(term: term, label: s.termLabel, font: .subheadline, ink: BL.textSecondary, textHeight: 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Gear

    private var checkedKeys: Set<String> { Set(checkedRaw.split(separator: "\n").map(String.init)) }

    private func key(_ list: String, _ item: String) -> String { list + "\u{1F}" + item }

    private func gearList(_ list: String, _ items: [RaceDayGuide.Gear]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                VStack(alignment: .leading, spacing: 0) {
                    ChecklistRow(text: item.name, done: Binding(
                        get: { checkedKeys.contains(key(list, item.name)) },
                        set: { on in
                            var keys = checkedKeys
                            if on { keys.insert(key(list, item.name)) } else { keys.remove(key(list, item.name)) }
                            checkedRaw = keys.sorted().joined(separator: "\n")
                        }))
                    if let note = item.note {
                        Text(note).font(.footnote).foregroundStyle(BL.textSecondary)
                            .padding(.leading, 34).padding(.bottom, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if i < items.count - 1 { Divider().overlay(BL.separator).padding(.leading, 34) }
            }
        }
        .card()
    }
}
