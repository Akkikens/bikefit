import SwiftUI

/// Full screen phone player (spec section 6): always true black, readable at arm's length on a trainer.
struct PlayerView: View {
    var session: Session
    var smoke = false
    @EnvironmentObject private var player: PhonePlayer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var hero: CGFloat = 112
    @ScaledMetric(relativeTo: .body) private var profileHeight: CGFloat = 150
    @ScaledMetric(relativeTo: .title3) private var nextWidth: CGFloat = 56
    @State private var confirmEnd = false
    @State private var started = false

    private var heroSize: CGFloat { min(160, max(72, hero)) }
    private var compact: Bool { typeSize.isAccessibilitySize }
    private var index: Int { min(player.stepIndex, max(0, session.steps.count - 1)) }
    private var current: PlanStep? { session.steps.indices.contains(index) ? session.steps[index] : nil }
    private var next: PlanStep? { session.steps.indices.contains(index + 1) ? session.steps[index + 1] : nil }
    /// Paused dim. textPrimary survives 0.55 on black (5.61:1); textSecondary and sport ink need 0.8 to stay above 4.5:1 (5.03, 7.37, 8.08).
    private var dim: Double { player.isPaused ? 0.55 : 1 }
    private var dimSecondary: Double { player.isPaused ? 0.8 : 1 }
    private var sessionRemaining: TimeInterval { max(0, player.totalSeconds - player.elapsed) }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 20, paused: player.isPaused || !player.isRunning)) { _ in
            VStack(spacing: 0) {
                topBar.opacity(dimSecondary)
                Spacer(minLength: 12)
                centre
                Spacer(minLength: 12)
                // The ruler numerals are text, so the Profile dims with the secondary rows, not the primary ones.
                ProfileView(steps: session.steps, mode: .player(progress: player.elapsed),
                            height: compact ? 56 : min(profileHeight, 160), ruler: !compact, onBlack: true)
                    .opacity(dimSecondary)
                    .padding(.bottom, compact ? 16 : 8)
                if !compact {
                    ProfileLegend(steps: session.steps, onBlack: true)
                        .opacity(dimSecondary)
                        .padding(.bottom, 12)
                }
                nextRow.opacity(dimSecondary)
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
            // Voice cues already speak the step; only announce when they are off so VoiceOver users hear it once.
            guard !player.voiceOn else { return }
            if session.steps.indices.contains(i) {
                let step = session.steps[i]
                let place = cue(at: i) ?? "\(step.name), step \(i + 1) of \(session.steps.count)"
                let target = step.target.map { ", \($0)" } ?? ""
                AccessibilityNotification.Announcement("\(place), \(duration(step.seconds))\(target)").post()
            } else if i >= session.steps.count {
                AccessibilityNotification.Announcement("Session complete").post()
            }
        }
        .onChange(of: player.isRunning) { _, running in
            if !running, started { dismiss() }
        }
        .task {
            guard !started else { return }
            started = true
            await player.start(name: session.name,
                               sport: session.sport,
                               steps: session.steps.enumerated().map { i, s in
                                   PhonePlayer.Step(name: s.name, seconds: s.seconds, target: s.target, sport: s.sport, cue: cue(at: i))
                               },
                               engineID: session.engineID,
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
                Image(systemName: (current?.sport ?? session.sport).symbol())
                Text(session.name)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(BL.Player.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(session.brickSecond.map { "Brick, \(session.sport.word) then \($0.word), \(session.name)" }
                                ?? "\(session.sport.word), \(session.name)")
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
                .accessibilityLabel("Time left in step")
                .accessibilityValue(spokenRemaining)
                .accessibilityAddTraits(.updatesFrequently)
            Text("left in this step")
                .font(BLFont.label)
                .foregroundStyle(BL.Player.textSecondary)
                .opacity(dimSecondary)
                .accessibilityHidden(true)
            if let c = current {
                Text(c.name).font(BLFont.sessionName).foregroundStyle(BL.Player.textPrimary).opacity(dim)
                if let t = c.target {
                    Text(t).font(BLFont.largeValue).foregroundStyle(c.sport.playerInk).opacity(dimSecondary)
                        .multilineTextAlignment(.center)
                }
                Text(c.feel).font(.subheadline).foregroundStyle(BL.Player.textSecondary).opacity(dimSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(placeText), \(duration(sessionRemaining)) left")
                .font(Font.subheadline.weight(.semibold).lowercaseSmallCaps())
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(BL.Player.textSecondary)
                .opacity(dimSecondary)
                .accessibilityLabel("\(placeText), \(spokenSessionLeft) left in the session")
            if player.isPaused {
                Text("paused").font(BLFont.label).foregroundStyle(BL.Player.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Where the athlete is: the rep inside a set when there is one, otherwise the step count.
    private var placeText: String {
        repLabel(at: index) ?? "step \(index + 1) of \(session.steps.count)"
    }

    @ViewBuilder private var nextRow: some View {
        if let n = next {
            let name = cue(at: index + 1) ?? n.name
            // A step named "Steady hard run, 15 min" already says its length.
            let showDuration = !n.name.contains(duration(n.seconds))
            // "Next" has its own fixed column, so a name that wraps lines up under itself, not under the word Next.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Next").fontWeight(.semibold).frame(width: nextWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).fixedSize(horizontal: false, vertical: true)
                    let detail = [showDuration ? duration(n.seconds) : nil, n.target].compactMap { $0 }.joined(separator: " \u{00B7} ")
                    if !detail.isEmpty { Text(detail).monospacedDigit().font(.body) }
                }
                Spacer(minLength: 0)
            }
            .font(.title3)
            .foregroundStyle(BL.Player.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(["Next", name, duration(n.seconds), n.target].compactMap { $0 }.joined(separator: ", "))
        } else {
            Text("Last step").font(.title3).foregroundStyle(BL.Player.textSecondary)
        }
    }

    private var plate: some View {
        HStack(spacing: 28) {
            Button { Task { await player.skip(by: -1) } } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(index == 0 ? BL.Player.textSecondary.opacity(0.5) : BL.Player.textPrimary)
                    .animation(Motion(reduce: reduceMotion).animation(.easeInOut(duration: 0.2)), value: index == 0)
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
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(next == nil ? BL.Player.textSecondary.opacity(0.5) : BL.Player.textPrimary)
                    .animation(Motion(reduce: reduceMotion).animation(.easeInOut(duration: 0.2)), value: next == nil)
            }
            .accessibilityLabel("Next step")
            .disabled(next == nil)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .modifier(PlateBackground())
    }

    // MARK: Rep context

    /// Rep context for a step inside a repeat set, the way an athlete counts it.
    private struct Rep { var number: Int; var total: Int; var isRest: Bool }

    private func rep(at i: Int) -> Rep? {
        let steps = session.steps
        guard steps.indices.contains(i), let g = steps[i].group else { return nil }
        let works = steps.indices.filter { steps[$0].group == g && steps[$0].kind == .work }
        guard let first = works.first else { return nil }
        let total = steps[first].repeatCount ?? works.count
        let done = works.filter { $0 < i }.count
        if steps[i].kind == .work { return Rep(number: done + 1, total: total, isRest: false) }
        return done < total ? Rep(number: done + 1, total: total, isRest: true) : nil
    }

    /// Display line: "rep 3 of 8", or "rest, then rep 4 of 8" between reps. Nil outside a set.
    private func repLabel(at i: Int) -> String? {
        guard let r = rep(at: i) else { return nil }
        return r.isRest ? "rest, then rep \(r.number) of \(r.total)" : "rep \(r.number) of \(r.total)"
    }

    /// Phrase for voice, notifications and announcements: "Threshold, rep 2 of 2", "Rest, then rep 4 of 8". Nil outside a set.
    private func cue(at i: Int) -> String? {
        guard let r = rep(at: i), session.steps.indices.contains(i) else { return nil }
        let name = session.steps[i].name
        return r.isRest ? "\(name), then rep \(r.number) of \(r.total)" : "\(name), rep \(r.number) of \(r.total)"
    }

    // MARK: Formatting

    private func clock(_ s: TimeInterval) -> String {
        let total = Int(s.rounded(.up))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
                             : String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Same rounding as the numeral, so the spoken value matches what is on screen.
    private var spokenRemaining: String {
        let seconds = Int(player.stepRemaining.rounded(.up))
        let spoken = Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return player.isPaused ? "\(spoken), paused" : spoken
    }

    private var spokenSessionLeft: String {
        let minutes = Int((sessionRemaining / 60).rounded(.up))
        guard minutes > 0 else { return "less than a minute" }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
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
