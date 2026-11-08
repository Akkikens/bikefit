import SwiftUI

/// Step 3: pick a race distance, a date and an optional name, with live feedback on the lead time.
struct OnboardingRaceStep: View {
    @ObservedObject var setup: UserSetup

    private var weeks: Int { OBPlan.weeksUntil(setup.data.raceDate) }

    var body: some View {
        OBPage(title: "Your race",
               why: "The distance and the date decide how long your plan is and how it ramps up.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(spacing: BL.Space.cardGap) {
                    ForEach(RaceChoice.allCases) { race in
                        let selected = setup.data.raceChoice == race
                        OBChoiceCard(selected: selected, action: { setup.data.raceChoice = race }) {
                            VStack(alignment: .leading, spacing: BL.Space.xs) {
                                Text(race.title).font(.headline).foregroundStyle(BL.textPrimary)
                                Text(race.summary).font(.subheadline.weight(.medium)).foregroundStyle(BL.textPrimary)
                                // The picked race says more about itself, so all three fit above the date.
                                if selected {
                                    Text(race.blurb).font(.subheadline).foregroundStyle(BL.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("Most plans run \(race.typicalWeeks).")
                                        .font(.footnote).foregroundStyle(BL.textSecondary)
                                }
                            }
                        }
                    }
                }

                if !setup.data.noRaceYet {
                    VStack(alignment: .leading, spacing: BL.Space.l) {
                        VStack(alignment: .leading, spacing: BL.Space.m) {
                            DatePicker("Race date", selection: $setup.data.raceDate, in: OBPlan.dateRange, displayedComponents: .date)
                                .font(.body.weight(.medium))
                                .frame(minHeight: 44)
                            Divider().overlay(BL.separator)
                            TextField("Race name (optional)", text: $setup.data.raceName)
                                .font(.body)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .frame(minHeight: 44)
                        }
                        .card()

                        HStack(alignment: .top, spacing: BL.Space.m) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title3)
                                .foregroundStyle(BL.textPrimary)
                                .accessibilityHidden(true)
                            Text(feedback)
                                .font(.subheadline)
                                .foregroundStyle(BL.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                VStack(alignment: .leading, spacing: BL.Space.s) {
                    OBToggleRow(title: "I have no race yet",
                                detail: "Skip the date. You get 12 weeks of mostly easy training to start with.",
                                isOn: $setup.data.noRaceYet)
                    JargonText(term: .base, label: "What is a base phase?", font: .subheadline, ink: BL.textSecondary)
                }
                .card()

                if setup.data.noRaceYet {
                    Text("You can pick a race later. The distance you chose above is the one you are working toward.")
                        .font(.subheadline)
                        .foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            // A date saved long ago may now be in the past. Move it to the earliest allowed day.
            let earliest = OBPlan.dateRange.lowerBound
            if setup.data.raceDate < earliest { setup.data.raceDate = earliest }
        }
    }

    /// Live read on the lead time, in plain words.
    private var feedback: String {
        let w = weeks
        let race = setup.data.raceChoice
        let range = race.obWeeksRange
        if w < 1 {
            return "Your race is less than 1 week away. That is too close for a full plan. Pick a later date, or choose the no race option above."
        }
        let away = "\(OBFormat.plural(w, "week", "weeks")) away"
        if w < range.lowerBound {
            var text = "Only \(away): the plan will be short and focused."
            if w < range.lowerBound - 3 && race != .sprint { text += " A shorter race may fit better." }
            return text
        }
        if w > 24 {
            return "\(away): plenty of time. Your plan covers the last 24 weeks before race day."
        }
        if w > range.upperBound {
            return "\(away): plenty of time, so the plan has a long, easy start."
        }
        return "\(away): a good fit for \(race.obPlanPhrase)."
    }
}
