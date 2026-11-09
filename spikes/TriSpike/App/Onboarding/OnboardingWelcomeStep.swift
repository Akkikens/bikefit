import SwiftUI

/// Step 0: what TriSpike does, in three lines.
struct OnboardingWelcomeStep: View {
    var body: some View {
        OBPage(title: "Train for a triathlon, in plain words.",
               why: "TriSpike is a training plan for swim, bike and run. It tells you what to do each day, for how long, and how hard.") {
            VStack(alignment: .leading, spacing: BL.Space.xl) {
                HStack(spacing: BL.Space.xl) {
                    ForEach(Sport.allCases) { sport in
                        Image(systemName: sport.symbol())
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(sport.ink)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: BL.Space.l) {
                    line("flag.checkered", "Pick a race and a date.")
                    line("calendar", "Get a plan that fits the days and hours you have.")
                    line("iphone", "Follow each session on your phone.")
                }
                .card()

                VStack(alignment: .leading, spacing: BL.Space.xs) {
                    Text("Free. Private. No account.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BL.textPrimary)
                    Text("Everything you enter stays on this iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(BL.textSecondary)
                }
            }
        }
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BL.Space.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(BL.textPrimary)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(BL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
