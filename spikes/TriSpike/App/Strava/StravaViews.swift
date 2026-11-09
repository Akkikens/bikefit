import SwiftUI

/// Plain words about what the optional Strava link does. One place, so the screens and the tests read the same text.
enum StravaCopy {
    static let optional = "Strava is optional. TriSpike works the same without it, and nothing is sent unless you tap Share to Strava on a finished session."
    static let sent = "What is sent to Strava: the session name, the sport, when it started and how long it lasted. Nothing else. No heart rate, no sleep or health data and no location."
    static let permission = "TriSpike asks Strava for permission to add activities to your account. It only adds the workouts you choose to share."
    static let helper = "Sign in goes through a small TriSpike helper server, so the app never holds Strava's keys. The helper only passes your sign in and your workouts on to Strava."
    static let disconnect = "Disconnect asks Strava to end TriSpike's access and deletes the connection from this phone. If the request could not be sent, open Strava, then Settings, then My Apps, and remove TriSpike there."
    static let disconnectFailed = "The connection is deleted from this phone, but Strava could not be reached. To finish, open Strava, then Settings, then My Apps, and remove TriSpike."
    static var all: [String] { [optional, sent, permission, helper, disconnect, disconnectFailed] }
}

/// What the app says about privacy, and what changes when the optional Strava link is on.
enum PrivacyCopy {
    static func connectionsIntro(stravaEnabled: Bool) -> String {
        let base = "Your devices read to TriSpike through Apple Health, and that data stays on your phone. TriSpike has no account, no ads and no analytics."
        return stravaEnabled
            ? base + " The only thing that can leave your phone is a workout you choose to share to Strava."
            : base + " Nothing leaves your phone."
    }
    static let health = "Apple Health data is never sent to TriSpike servers. TriSpike does not collect it."
}

/// Methods, Connections: connect or disconnect Strava. Hidden when the proxy address is empty.
struct StravaCard: View {
    @ObservedObject var strava: StravaClient = .shared
    @State private var confirmDisconnect = false

    var body: some View {
        if strava.isEnabled {
            VStack(alignment: .leading, spacing: BL.Space.s) {
                SectionLabel(text: "Strava (optional)")
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    statusRow
                    Text(StravaCopy.optional).font(.subheadline).foregroundStyle(BL.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(StravaCopy.sent).font(.subheadline).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(StravaCopy.permission).font(.footnote).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(StravaCopy.helper).font(.footnote).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let p = strava.problem {
                        Label(p.message, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(BL.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if strava.lastDisconnectRevoked == false, !strava.isConnected {
                        Label(StravaCopy.disconnectFailed, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(BL.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    action
                    if strava.isConnected {
                        Text(StravaCopy.disconnect).font(.footnote).foregroundStyle(BL.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card()
            }
            .confirmationDialog("Disconnect Strava?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) { Task { await strava.disconnect() } }
                Button("Keep it connected", role: .cancel) {}
            } message: {
                Text("TriSpike asks Strava to end its access and deletes the connection from this phone. Workouts already on Strava stay there.")
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: BL.Space.m) {
            Image(systemName: "figure.run.circle").font(.title3).foregroundStyle(BL.textPrimary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Strava").font(.headline).foregroundStyle(BL.textPrimary)
                Label(statusText, systemImage: strava.isConnected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(strava.isConnected ? BL.success : BL.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch strava.state {
        case .off, .disconnected: "Not connected"
        case .connecting: "Connecting"
        case .connected(let name): name.map { "Connected as \($0)" } ?? "Connected"
        }
    }

    @ViewBuilder private var action: some View {
        if strava.isConnected {
            Button { confirmDisconnect = true } label: { Label("Disconnect Strava", systemImage: "xmark.circle") }
                .buttonStyle(SecondaryButtonStyle())
        } else {
            Button { Task { await strava.connect() } } label: { Label("Connect Strava", systemImage: "link") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(strava.state == .connecting)
        }
    }
}

/// After a finished session: share it to Strava. Hidden when the feature is off.
struct StravaShareButton: View {
    var upload: StravaUpload
    @ObservedObject var strava: StravaClient = .shared
    @State private var shared = false

    var body: some View {
        if strava.isEnabled {
            VStack(alignment: .leading, spacing: BL.Space.s) {
                if shared || strava.hasShared(upload) {
                    Label("Shared to Strava", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(BL.success)
                } else {
                    Button { Task { await send() } } label: {
                        Label(strava.isConnected ? "Share to Strava" : "Connect Strava and share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(strava.isUploading || strava.state == .connecting)
                    Text(StravaCopy.sent).font(.footnote).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let p = strava.problem {
                    Label(p.message, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(BL.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onAppear { strava.clearProblem() }
        }
    }

    private func send() async {
        if !strava.isConnected {
            guard await strava.connect() else { return }
        }
        shared = await strava.upload(upload)
    }
}
