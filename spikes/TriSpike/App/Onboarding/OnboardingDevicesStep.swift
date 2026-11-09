import SwiftUI

/// Step 6: which devices the athlete wears, plus gear that changes the plan, plus the Apple Health permission.
/// Cards are multi select. "Just my phone" stands alone.
struct OnboardingDevicesStep: View {
    @ObservedObject var setup: UserSetup
    @ObservedObject private var readiness = ReadinessCoordinator.shared

    var body: some View {
        OBPage(title: "Connect your devices",
               why: "Pick everything you wear while you train. It decides how sessions reach you and where your sleep and heart data can come from. You can change it later under Learn and setup.") {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                VStack(spacing: BL.Space.cardGap) {
                    ForEach(DeviceSelection.displayOrder) { device in
                        OBChoiceCard(selected: setup.data.devices.contains(device), action: { setup.toggleDevice(device) }) {
                            HStack(alignment: .top, spacing: BL.Space.m) {
                                Image(systemName: device.symbol)
                                    .font(.title2)
                                    .foregroundStyle(BL.textPrimary)
                                    .frame(width: 32)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: BL.Space.xs) {
                                    HStack(spacing: BL.Space.s) {
                                        Text(device.title).font(.headline).foregroundStyle(BL.textPrimary)
                                        if device.isBeta { BetaBadge() }
                                    }
                                    Text(device.blurb).font(.subheadline).foregroundStyle(BL.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if device.isBeta {
                                        Text("Coming soon: a direct connection.")
                                            .font(.footnote.weight(.semibold)).foregroundStyle(BL.textSecondary)
                                    }
                                }
                            }
                        }
                        .accessibilityHint(device == .phoneOnly ? "Clears the other devices" : "Turns this device on or off")
                    }
                }

                Text(setup.canSendToWatch
                     ? "Each session will have a Send to watch button."
                     : "Sessions are followed on your phone, so there is no Send to watch button.")
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                healthSection

                VStack(alignment: .leading, spacing: BL.Space.m) {
                    OBSectionLabel(text: "Your gear")
                    VStack(alignment: .leading, spacing: BL.Space.m) {
                        OBToggleRow(title: "I have a power meter on my bike",
                                    detail: "Bike sessions can use power in watts. Without one, they use how hard it feels, such as being able to say a short sentence.",
                                    symbol: "bolt.fill",
                                    isOn: $setup.data.hasPowerMeter)
                        Divider().overlay(BL.separator)
                        OBToggleRow(title: "I have an indoor trainer",
                                    detail: "Lets TriSpike offer indoor rides for bad weather and short evenings.",
                                    symbol: "figure.indoor.cycle",
                                    isOn: $setup.data.hasTrainer)
                    }
                    .card()
                }
            }
        }
    }

    // MARK: Apple Health

    @ViewBuilder private var healthSection: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            OBSectionLabel(text: "Apple Health")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                Text(setup.data.hasRecoverySource ? Self.whyLine : Self.phoneOnlyLine)
                    .font(.subheadline)
                    .foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if setup.data.hasRecoverySource {
                    CompactJargon(term: .hrv, label: "What is heart rate variability?", font: .subheadline, ink: BL.textSecondary, textHeight: 20)
                    Button {
                        Task {
                            if readiness.state.healthAsked { await readiness.refresh() } else { await readiness.requestHealthAccess() }
                        }
                    } label: {
                        Label(readiness.state.healthAsked ? "Check for data again" : "Allow Apple Health access", systemImage: "heart.text.square")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    if let result = Self.resultLine(asked: readiness.state.healthAsked, status: readiness.status) {
                        Text(result).font(.footnote).foregroundStyle(BL.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
        }
    }

    static let whyLine = "TriSpike reads your sleep, resting heart rate and heart rate variability from Apple Health, and saves the workouts you record with the phone player. It all stays on your phone. You choose what to share in the sheet that opens, and you can skip this and allow it later."
    static let phoneOnlyLine = "With just your phone there is no sleep or heart data to read. When you finish a session in the phone player, Apple Health asks if it can save the workout."

    /// What to say after the permission sheet. Health never says whether a read was allowed, so the line only reports what was found.
    static func resultLine(asked: Bool, status: ReadinessCoordinator.ReadStatus) -> String? {
        guard asked else { return nil }
        switch status {
        case .read(let nights) where nights > 0:
            return "Found \(nights) nights of data from your devices."
        case .read:
            return "No nights found yet. If you chose Don't Allow, you can turn it on in the Health app under Sharing."
        case .unavailable:
            return "Apple Health is not available on this device."
        case .failed:
            return "Apple Health could not be read just now. Try again later."
        case .idle, .reading:
            return nil
        }
    }
}

/// A small label for features that are still early.
struct BetaBadge: View {
    var body: some View {
        Text("Beta")
            .font(.caption2.weight(.bold))
            .foregroundStyle(BL.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(BL.textSecondary, lineWidth: 1))
            .accessibilityLabel("Beta")
    }
}
