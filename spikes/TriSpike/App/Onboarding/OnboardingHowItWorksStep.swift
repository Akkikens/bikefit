import SwiftUI

/// Step 1: three short cards on how the app works.
struct OnboardingHowItWorksStep: View {
    var body: some View {
        OBPage(title: "How Brickline works",
               why: "Three steps. Setup takes about 3 minutes, and you can change any answer later.") {
            VStack(spacing: BL.Space.cardGap) {
                card(symbol: "flag.checkered",
                     title: "Pick a race",
                     text: "Sprint, Olympic or half iron. Choose a date, or build general fitness first if you have no race yet.")
                card(symbol: "calendar",
                     title: "Get a plan that fits your week",
                     text: "Tell us your hours and days. Brickline spreads swim, bike and run sessions across them, with easier weeks built in.")
                card(symbol: "iphone",
                     title: "Follow it on your phone or watch",
                     text: "Each session shows what to do, for how long, and how hard it should feel. Wear a WHOOP, Garmin or any other band and it records while your phone guides you. Have an Apple Watch? You can send sessions to it too.")
            }
        }
    }

    private func card(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: BL.Space.l) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(BL.textPrimary)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BL.Space.xs) {
                Text(title).font(.headline).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
