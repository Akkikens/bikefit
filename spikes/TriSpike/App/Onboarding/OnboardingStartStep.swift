import SwiftUI

/// Step 5: where you start. Three plain questions, no wrong answers. They decide how gentle the first weeks are.
struct OnboardingStartStep: View {
    @ObservedObject var setup: UserSetup

    private var point: StartingPoint { setup.data.startingPoint }

    var body: some View {
        OBPage(title: "Where you start",
               why: "Three quick questions so the first weeks match your body today. There are no wrong answers, and nobody sees them.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                ForEach(StartQuestion.allCases) { question in
                    questionBlock(question)
                }
                result
            }
        }
    }

    private func questionBlock(_ q: StartQuestion) -> some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Label(q.title, systemImage: q.symbol)
                .font(BLFont.label)
                .foregroundStyle(BL.textSecondary)
                .accessibilityAddTraits(.isHeader)
            Text(q.prompt)
                .font(.body)
                .foregroundStyle(BL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: BL.Space.cardGap) {
                ForEach(StartAbility.allCases) { ability in
                    OBChoiceCard(selected: point.ability(q) == ability, action: { choose(q, ability) }) {
                        Text(q.answer(ability)).font(.body.weight(.medium)).foregroundStyle(BL.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func choose(_ q: StartQuestion, _ ability: StartAbility) {
        var p = point
        switch q { case .swim: p.swim = ability; case .bike: p.bike = ability; case .run: p.run = ability }
        setup.data.startingPoint = p
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Label(point.headline, systemImage: point.needsGentleStart ? "leaf" : "checkmark.circle")
                .font(.headline)
                .foregroundStyle(BL.textPrimary)
            Text(point.detail)
                .font(.subheadline)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(point.helpLines, id: \.self) { line in
                Text(line).font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = setup.data.gentleRaceNote {
                Text(note).font(.subheadline.weight(.medium)).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(setup.data.gentleRaceAlternatives.reversed()) { race in
                    Button("Choose \(race.title)") { setup.data.raceChoice = race }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BL.accent)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityHint("Changes your race to \(race.title)")
                }
            }
            if point.anyAnswered {
                JargonText(term: .base, label: "What is a base phase?", font: .subheadline, ink: BL.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .contain)
    }
}
