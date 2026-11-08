import SwiftUI

/// Full screen phone player (spec section 6): always true black, readable at arm's length on a trainer.
struct PlayerView: View {
    var session: Session
    var smoke = false
    @EnvironmentObject private var player: PhonePlayer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var hero: CGFloat = 112
    @State private var confirmEnd = false
    @State private var started = false

    private var heroSize: CGFloat { min(160, max(72, hero)) }
    private var index: Int { min(player.stepIndex, max(0, session.steps.count - 1)) }
    private var current: PlanStep? { session.steps.indices.contains(index) ? session.steps[index] : nil }
    private var next: PlanStep? { session.steps.indices.contains(index + 1) ? session.steps[index + 1] : nil }
    private var dim: Double { player.isPaused ? 0.55 : 1 }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 20, paused: player.isPaused || !player.isRunning)) { _ in
            VStack(spacing: 0) {
                topBar.opacity(dim)
                Spacer(minLength: 12)
                centre
                Spacer(minLength: 12)
                ProfileView(steps: session.steps, mode: .player(progress: player.elapsed), height: 120, ruler: true, onBlack: true)
                    .opacity(dim)
                    .padding(.bottom, 16)
                nextRow.opacity(dim)
                    .padding(.bottom, 20)
                plate
            }
            .padding(.horizontal, BL.Space.gutter)
            .padding(.bottom, 8)
        }
        .background(BL.playerBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .medium), trigger: player.stepIndex)
        .onChange(of: player.stepIndex) { _, i in
            if session.steps.indices.contains(i) {
                AccessibilityNotification.Announcement("\(session.steps[i].name), \(duration(session.steps[i].seconds))").post()
            }
        }
        .onChange(of: player.isRunning) { _, running in
            if !running, started { dismiss() }
        }
        .task {
            guard !started else { return }
            started = true
            await player.start(name: session.name,
                               steps: session.steps.map { .init(name: $0.name, seconds: $0.seconds, target: $0.target) },
                               smoke: smoke)
        }
        .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save") { Task { await player.stop(save: !player.smoke) } }
            Button("Keep going", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button { confirmEnd = true } label: {
                Image(systemName: "xmark").font(.title3.weight(.semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("End session")
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: session.sport.symbol())
                Text(session.name)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(BL.Player.textSecondary)
            .accessibilityElement(children: .combine)
            Spacer()
            Button { player.voiceOn.toggle() } label: {
                Image(systemName: player.voiceOn ? "speaker.wave.2" : "speaker.slash")
                    .font(.title3).frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(player.voiceOn ? "Voice cues on" : "Voice cues off")
        }
        .foregroundStyle(BL.Player.textPrimary)
    }

    private var centre: some View {
        VStack(spacing: 10) {
            Text(clock(player.stepRemaining))
                .font(BLFont.hero(heroSize))
                .kerning(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(BL.Player.textPrimary)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .accessibilityLabel("\(Int(player.stepRemaining)) seconds left in this step")
            if let c = current {
                Text(c.name).font(BLFont.sessionName).foregroundStyle(BL.Player.textPrimary).opacity(dim)
                if let t = c.target {
                    Text(t).font(BLFont.largeValue).foregroundStyle(c.sport.playerInk).opacity(dim)
                }
            }
            Text("step \(index + 1) of \(session.steps.count)")
                .font(BLFont.label)
                .foregroundStyle(BL.Player.textSecondary)
                .opacity(dim)
            if player.isPaused {
                Text("paused").font(BLFont.label).foregroundStyle(BL.Player.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var nextRow: some View {
        if let n = next {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right")
                Text(n.name)
                Spacer()
                Text(duration(n.seconds)).monospacedDigit()
                if let t = n.target { Text(t).monospacedDigit().foregroundStyle(n.sport.playerInk) }
            }
            .font(.title3)
            .foregroundStyle(BL.Player.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next, \(n.name), \(duration(n.seconds))")
        } else {
            Text("Last step").font(.title3).foregroundStyle(BL.Player.textSecondary)
        }
    }

    private var plate: some View {
        HStack(spacing: 28) {
            Button { Task { await player.skip(by: -1) } } label: {
                Image(systemName: "backward.end.fill").font(.title2).frame(width: 64, height: 64)
            }
            .accessibilityLabel("Previous step")
            .disabled(index == 0)
            Button {
                if player.isPaused { Task { await player.resume() } } else { player.pause() }
            } label: {
                Image(systemName: player.isPaused ? "play.fill" : "pause.fill")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(BL.Player.onAccent)
                    .frame(width: 72, height: 72)
                    .background(BL.Player.accent, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(player.isPaused ? "Resume" : "Pause")
            Button { Task { await player.skip(by: 1) } } label: {
                Image(systemName: "forward.end.fill").font(.title2).frame(width: 64, height: 64)
            }
            .accessibilityLabel("Next step")
            .disabled(next == nil)
        }
        .foregroundStyle(BL.Player.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 88)
        .modifier(PlateBackground())
    }

    private func clock(_ s: TimeInterval) -> String {
        let total = Int(s.rounded(.up))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
                             : String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Liquid Glass on iOS 26, solid elevated surface on iOS 18.
private struct PlateBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: BL.Radius.plate, style: .continuous))
        } else {
            content.background(BL.Player.plate, in: RoundedRectangle(cornerRadius: BL.Radius.plate, style: .continuous))
        }
    }
}

extension Session {
    /// Player test sessions for the Lab: same steps as the spike's quick and spec tests.
    static func playerTest(_ steps: [PhonePlayer.Step], name: String) -> Session {
        Session(sport: .run, name: name, purpose: "Player test.",
                steps: steps.enumerated().map { i, s in
                    PlanStep(sport: .run, kind: s.name.lowercased().contains("easy") || s.name.lowercased().contains("cool") ? .recovery : (i == 0 ? .warm : .work),
                             name: s.name, seconds: s.seconds,
                             level: s.name.lowercased().contains("easy") ? 1 : (s.name.lowercased().contains("warm") || s.name.lowercased().contains("cool") ? 2 : 4),
                             target: nil)
                },
                watchLine: "Phone only.")
    }
}
