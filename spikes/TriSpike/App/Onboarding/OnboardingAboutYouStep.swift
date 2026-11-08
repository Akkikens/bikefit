import SwiftUI

/// Step 4: experience, hours per week, training days, pool days.
struct OnboardingAboutYouStep: View {
    @ObservedObject var setup: UserSetup
    @State private var showMinimumNote = false

    var body: some View {
        OBPage(title: "Your experience and time",
               why: "Your experience and your free time decide how much training fits in your week.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                experience
                hours
                trainingDays
                poolDays
            }
        }
    }

    // MARK: Experience

    private var experience: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Your experience")
            VStack(spacing: BL.Space.cardGap) {
                ForEach(ExperienceChoice.allCases) { level in
                    OBChoiceCard(selected: setup.data.experience == level, action: { setup.data.experience = level }) {
                        VStack(alignment: .leading, spacing: BL.Space.xs) {
                            Text(level.title).font(.headline).foregroundStyle(BL.textPrimary)
                            Text(level.blurb).font(.subheadline).foregroundStyle(BL.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Text("Pick the easier option if you are unsure. You can change it later.")
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
        }
    }

    // MARK: Hours

    private var hours: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Time you can train")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                HStack(spacing: BL.Space.m) {
                    Text("\(setup.data.hoursPerWeek) hours per week")
                        .font(BLFont.readoutValue)
                        .foregroundStyle(BL.textPrimary)
                        .accessibilityHidden(true)
                    Spacer(minLength: BL.Space.s)
                    hoursButton(symbol: "minus", label: "Fewer hours", delta: -1)
                    hoursButton(symbol: "plus", label: "More hours", delta: 1)
                }
                .accessibilityElement(children: .contain)
                Text(hoursNote)
                    .font(.subheadline)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Plans run from 3 to 16 hours per week.")
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
            }
            .card()
        }
    }

    /// A 44 pt button that changes the weekly hours by one, inside the 3 to 16 range.
    private func hoursButton(symbol: String, label: String, delta: Int) -> some View {
        let next = setup.data.hoursPerWeek + delta
        let allowed = (3...16).contains(next)
        return Button {
            if allowed { setup.data.hoursPerWeek = next }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(allowed ? BL.textPrimary : BL.textSecondary.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(BL.background, in: RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous).strokeBorder(BL.separator, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
        .accessibilityLabel(label)
        .accessibilityValue("\(setup.data.hoursPerWeek) hours per week")
    }

    /// A plain note on what is realistic for this race.
    private var hoursNote: String {
        let h = setup.data.hoursPerWeek
        let race = setup.data.raceChoice
        if h < race.obHoursFloor {
            return "\(h) hours is on the light side for \(race.obRacePhrase). It can still work. The plan keeps to the essentials, and you may finish slower than you hoped."
        }
        if h > race.obHoursCeiling {
            return "That is more than most people need for \(race.obRacePhrase). A steady plan you can keep up beats a bigger one you drop."
        }
        return "A realistic amount for most people training for \(race.obRacePhrase). Pick the hours you can keep up on a normal week, not your best week."
    }

    // MARK: Days

    private var trainingDays: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Days you can train")
            OBDayChips(selected: setup.data.trainingDays, onTap: toggleTraining)
            Text(showMinimumNote
                 ? "Keep at least 1 day selected so there is something to plan around."
                 : "Pick every day you could train. Brickline will not use all of them, and it keeps some days free.")
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var poolDays: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Days you can get to a pool")
            OBDayChips(selected: setup.data.poolDays, enabled: setup.data.trainingDays, onTap: togglePool)
            Text(setup.data.poolDays.isEmpty
                 ? "No pool days picked. You will still get 1 swim a week, so pick a day if you can."
                 : "Swims are placed on these days. Only days you can train are available here.")
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleTraining(_ day: Int) {
        if setup.data.trainingDays.contains(day) {
            guard setup.data.trainingDays.count > 1 else {
                showMinimumNote = true
                return
            }
            setup.data.trainingDays.remove(day)
            setup.data.poolDays.remove(day)
        } else {
            setup.data.trainingDays.insert(day)
        }
        showMinimumNote = false
    }

    private func togglePool(_ day: Int) {
        guard setup.data.trainingDays.contains(day) else { return }
        if setup.data.poolDays.contains(day) {
            setup.data.poolDays.remove(day)
        } else {
            setup.data.poolDays.insert(day)
        }
    }
}
