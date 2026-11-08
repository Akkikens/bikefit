import SwiftUI

/// Step 5: how the athlete records workouts, plus gear that changes the plan.
struct OnboardingTrackerStep: View {
    @ObservedObject var setup: UserSetup

    var body: some View {
        OBPage(title: "How do you track workouts?",
               why: "This decides how sessions reach you. Pick what you wear while you train.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(spacing: BL.Space.cardGap) {
                    ForEach(TrackerChoice.allCases) { tracker in
                        OBChoiceCard(selected: setup.data.tracker == tracker, action: { setup.data.tracker = tracker }) {
                            HStack(alignment: .top, spacing: BL.Space.m) {
                                Image(systemName: tracker.symbol)
                                    .font(.title2)
                                    .foregroundStyle(BL.textPrimary)
                                    .frame(width: 32)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: BL.Space.xs) {
                                    Text(tracker.title).font(.headline).foregroundStyle(BL.textPrimary)
                                    Text(tracker.blurb).font(.subheadline).foregroundStyle(BL.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                Text(setup.canSendToWatch
                     ? "Each session will have a Send to watch button."
                     : "Sessions are followed on your phone, so there is no Send to watch button.")
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: BL.Space.m) {
                    OBSectionLabel(text: "Your gear")
                    VStack(alignment: .leading, spacing: BL.Space.m) {
                        OBToggleRow(title: "I have a power meter on my bike",
                                    detail: "Bike sessions can use power in watts. Without one, they use how hard it feels, such as being able to say a short sentence.",
                                    symbol: "bolt.fill",
                                    isOn: $setup.data.hasPowerMeter)
                        Divider().overlay(BL.separator)
                        OBToggleRow(title: "I have an indoor trainer",
                                    detail: "Lets Brickline offer indoor rides for bad weather and short evenings.",
                                    symbol: "figure.indoor.cycle",
                                    isOn: $setup.data.hasTrainer)
                    }
                    .card()
                }
            }
        }
    }
}
