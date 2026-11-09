import SwiftUI
import BricklinePlanKit

/// Methods, then Connections: every device the athlete connected, what state it is in, what it is used for, and a way
/// to change devices. Recovery data comes from Apple Health and stays on the phone.
struct ConnectionsView: View {
    @ObservedObject private var setup = UserSetup.shared
    @ObservedObject private var readiness = ReadinessCoordinator.shared
    @ObservedObject private var engine = EngineAdapter.shared
    @ObservedObject private var strava = StravaClient.shared

    private var rows: [ReadinessPlainCopy.SourceRow] {
        let calendar = EngineBuilder.calendar()
        return ReadinessPlainCopy.sourceRows(
            data: setup.data, assessment: engine.model.readiness, nights: readiness.nights,
            today: Demo.today, calendar: calendar)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                Text(PrivacyCopy.connectionsIntro(stravaEnabled: strava.isEnabled))
                    .font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: BL.Space.s) {
                    SectionLabel(text: "Connected")
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            SourceRowView(row: row)
                            if index < rows.count - 1 { Divider().overlay(BL.separator) }
                        }
                    }
                    .card()
                }

                if setup.data.hasRecoverySource { healthCard }
                StravaCard()
                if setup.data.readinessSources.count > 1 { preferredCard }
                changeCard
            }
            .padding(.horizontal, BL.Space.gutter)
            .padding(.top, BL.Space.s)
            .padding(.bottom, BL.Space.l)
        }
        .background(BL.background.ignoresSafeArea())
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .task { await readiness.refreshAndSync() }
    }

    // MARK: Apple Health

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            SectionLabel(text: "Apple Health")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                Text(OnboardingDevicesStep.whyLine)
                    .font(.subheadline).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PrivacyCopy.health).font(.footnote).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CompactJargon(term: .hrv, label: "What is heart rate variability?", font: .subheadline, ink: BL.textSecondary, textHeight: 20)
                Button {
                    Task {
                        if readiness.state.healthAsked { await readiness.refreshAndSync() } else { await readiness.requestHealthAccess() }
                    }
                } label: {
                    Label(readiness.state.healthAsked ? "Check for new data" : "Allow Apple Health access", systemImage: "heart.text.square")
                }
                .buttonStyle(SecondaryButtonStyle())
                if let line = OnboardingDevicesStep.resultLine(asked: readiness.state.healthAsked, status: readiness.status) {
                    Text(line).font(.footnote).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
    }

    // MARK: Which device to use

    private var preferredCard: some View {
        let options = setup.data.recoveryOrder
        return VStack(alignment: .leading, spacing: BL.Space.s) {
            SectionLabel(text: "Which device to use")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                Text("With more than one device, TriSpike uses the first with enough recent nights, in this order: Oura, WHOOP, Apple Watch, Garmin. Each device keeps its own usual range, because their numbers are not comparable. Changing the device restarts the 14 night learning period.")
                    .font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Device for sleep and heart data", selection: Binding(
                    get: { readiness.state.preferredSource },
                    set: { readiness.setPreferred($0, today: Demo.today) })) {
                    Text("Automatic").tag(ReadinessSource?.none)
                    ForEach(options, id: \.self) { Text($0.displayName).tag(ReadinessSource?.some($0)) }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
            }
            .card()
        }
    }

    // MARK: Change devices

    private var changeCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            SectionLabel(text: "Change devices")
            VStack(spacing: 0) {
                ForEach(Array(DeviceSelection.displayOrder.enumerated()), id: \.element.id) { index, device in
                    Toggle(isOn: Binding(
                        get: { setup.data.devices.contains(device) },
                        set: { _ in change(device) })) {
                        HStack(spacing: BL.Space.m) {
                            Image(systemName: device.symbol).foregroundStyle(BL.textSecondary).frame(width: 24)
                                .accessibilityHidden(true)
                            Text(device.title).font(.body).foregroundStyle(BL.textPrimary)
                            if device.isBeta { BetaBadge() }
                        }
                    }
                    .tint(BL.accent)
                    .frame(minHeight: 44)
                    .padding(.vertical, 4)
                    if index < DeviceSelection.displayOrder.count - 1 { Divider().overlay(BL.separator) }
                }
            }
            .card()
            Text("Choosing Just my phone turns the other devices off. Turning off every device goes back to Just my phone.")
                .font(.footnote).foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func change(_ device: DeviceChoice) {
        let old = setup.data
        setup.toggleDevice(device)
        readiness.devicesChanged(from: old, to: setup.data, today: Demo.today)
        Task { await readiness.refreshAndSync() }
    }
}

private struct SourceRowView: View {
    var row: ReadinessPlainCopy.SourceRow

    var body: some View {
        HStack(alignment: .top, spacing: BL.Space.m) {
            Image(systemName: row.device.symbol).font(.title3).foregroundStyle(BL.textPrimary).frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: BL.Space.s) {
                    Text(row.device.title).font(.headline).foregroundStyle(BL.textPrimary)
                    if row.device.isBeta { BetaBadge() }
                }
                Label(row.state.label, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                Text(row.usedFor).font(.subheadline).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = row.note {
                    Text(note).font(.footnote).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch row.state {
        case .inUse: "checkmark.circle.fill"
        case .calibrating: "hourglass"
        case .paused: "pause.circle"
        case .notEnoughData: "questionmark.circle"
        case .standby: "checkmark.circle"
        case .notRead: "iphone"
        }
    }

    private var ink: Color {
        switch row.state {
        case .inUse, .standby: BL.success
        default: BL.textSecondary
        }
    }
}
