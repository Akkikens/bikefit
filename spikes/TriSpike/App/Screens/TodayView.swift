import SwiftUI

struct TodayView: View {
    @Binding var playerSession: Session?
    @EnvironmentObject private var player: PhonePlayer
    /// How the athlete tracks workouts decides whether "Send to watch" exists at all.
    @ObservedObject private var setup = UserSetup.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var type
    @ScaledMetric(relativeTo: .body) private var profileHeight: CGFloat = 56
    @State private var synced = false
    @State private var confirmEase = false
    @ObservedObject private var engine = EngineAdapter.shared
    @State private var path: [Session] = ProcessInfo.processInfo.arguments.contains("-screenDetail") ? (Demo.smokeSession.map { [$0] } ?? []) : []
    private var days: [PlanDay] { Demo.week }

    /// Today's sessions come from the engine's plan. A rest day has none.
    private var todaySessions: [Session] { days.first(where: { $0.isToday })?.sessions ?? [] }
    private var isRestDay: Bool { todaySessions.isEmpty }
    /// The session the hero card shows: today's first one, or the next one on a rest day (only read for its name).
    private var session: Session { todaySessions.first ?? Demo.nextSession ?? Session(sport: .run, name: "Rest day", purpose: "", steps: [], watchLine: "") }

    private static let dateFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f }()

    /// What the phone player recorded for today's session, once it has ended.
    private var result: PhonePlayer.Result? {
        guard let r = player.lastResult, r.name == session.name, r.engineID == session.engineID else { return nil }
        return r
    }
    private var doneMinutes: Int? { result.map { Int(($0.seconds / 60).rounded()) } }

    /// Plain confirmation, only claiming what actually happened: finished or ended early, and whether Health has it.
    private var resultNote: String {
        let ended = result?.completed == true ? "" : "Ended early. "
        return ended + (result?.saved == true ? "Saved to Health." : "Not saved to Health.")
    }

    /// Sessions in the week that a rule changed. The reason line on a session is the signal.
    private var changesThisWeek: Int { days.flatMap(\.sessions).filter { $0.reason != nil }.count }
    private var engineNote: String {
        if let problem = Demo.planProblem { return problem }
        switch changesThisWeek {
        case 0: return "Your plan has no changes this week."
        case 1: return "Your plan has one change this week. The session says why."
        default: return "Your plan has \(changesThisWeek) changes this week. Each session says why."
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    if isRestDay {
                        restHeader
                    } else {
                        header
                        VStack(alignment: .leading, spacing: BL.Space.m) {
                            heroCard
                            if !pinsActions { actions }
                            alsoToday
                        }
                    }
                    readinessSection
                    weekSection
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.top, BL.Space.s)
                .padding(.bottom, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .bottomEdgeSolid()
            // At the largest sizes the buttons would sit screens down, so they stay on screen above the tab bar.
            .safeAreaInset(edge: .bottom) {
                if pinsActions && !isRestDay {
                    actions
                        .padding(.horizontal, BL.Space.gutter)
                        .padding(.vertical, BL.Space.s)
                        .background(BL.background)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await ReadinessCoordinator.shared.refreshAndSync() }
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0, playerSession: $playerSession) }
        }
    }

    /// Pinned only while there are buttons to press; the finished-session summary scrolls with the page.
    private var pinsActions: Bool { type.isAccessibilitySize && result == nil }

    // MARK: Rest day

    /// Rest day (design spec section 5): a moon chip, the words "Rest day", one sentence, and where the next session is.
    private var restHeader: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Text(Self.dateFormat.string(from: Date()))
                .font(BLFont.meta)
                .foregroundStyle(BL.textSecondary)
            Label("Rest", systemImage: "moon.zzz")
                .font(BLFont.label)
                .foregroundStyle(BL.textSecondary)
            Text("Rest day")
                .font(BLFont.sessionName)
                .foregroundStyle(BL.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("No session today. Your body gets stronger while it rests.")
                .font(BLFont.purpose)
                .foregroundStyle(BL.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let next = Demo.nextSession {
                Button { path.append(next) } label: {
                    HStack(spacing: BL.Space.s) {
                        Image(systemName: next.sport.symbol()).foregroundStyle(next.sport.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next: \(Demo.dayName(of: next) ?? "this week")").font(BLFont.label).foregroundStyle(BL.textSecondary)
                            Text(next.name).font(.body).foregroundStyle(BL.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(BL.textSecondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .card()
                .accessibilityHint("Opens the session")
            }
        }
    }

    /// A second session on the same day gets its own row under the main one.
    @ViewBuilder private var alsoToday: some View {
        let others = Array(todaySessions.dropFirst())
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: BL.Space.s) {
                SectionLabel(text: "Also today")
                ForEach(others) { other in
                    Button { path.append(other) } label: {
                        HStack(spacing: BL.Space.s) {
                            Image(systemName: other.sport.symbol()).foregroundStyle(other.sport.ink)
                            Text(other.name).font(.body).foregroundStyle(BL.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text("\(other.minutes) min").font(BLFont.label).foregroundStyle(BL.textSecondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .card()
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Text(Self.dateFormat.string(from: Date()))
                .font(BLFont.meta)
                .foregroundStyle(BL.textSecondary)
            HStack(alignment: .center, spacing: BL.Space.s) {
                SportChip(sport: session.sport, second: session.brickSecond)
                Spacer(minLength: BL.Space.s)
                // Swims lead with distance below, so the time is said here: the first thing to know is how long it takes.
                if session.showsDistance && result == nil {
                    Label("about \(session.minutes) min", systemImage: "clock")
                        .font(BLFont.meta)
                        .foregroundStyle(BL.textSecondary)
                        .accessibilityLabel("About \(session.minutes) minutes")
                }
            }
            Text(session.name)
                .font(BLFont.sessionName)
                .foregroundStyle(BL.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let idea = session.idea {
                CompactJargon(term: idea, label: session.ideaLabel, font: BLFont.meta, ink: BL.textSecondary, textHeight: 20)
            }
            Text(session.purpose)
                .font(BLFont.purpose)
                .foregroundStyle(BL.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Hero card

    /// The left readout: what the athlete did once the player ended, distance for a swim, else time.
    private var lead: (label: String, value: String, unit: String) {
        if let done = doneMinutes { return ("done", "\(done)", "min") }
        if session.showsDistance, let m = session.totalMeters { return ("distance", "\(m)", "m") }
        return ("duration", "\(session.minutes)", "min")
    }

    /// Units as VoiceOver should say them.
    private func spoken(_ unit: String) -> String {
        switch unit {
        case "min": return "minutes"
        case "m": return "meters"
        case "per 100 m": return "per 100 meters"
        case "per km": return "per kilometer"
        default: return unit
        }
    }

    private var heroLabel: String {
        var s = "\(session.name), \(lead.label) \(lead.value) \(spoken(lead.unit))"
        if let t = session.headlineTarget { s += ", \(session.targetLabel) \(t.value) \(spoken(t.unit))" }
        return s
    }

    /// The reason line is a sibling of the card button, never nested in it, so VoiceOver reaches both
    /// and a tap on the reason expands the rule instead of opening the session.
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Button { path.append(session) } label: {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    ProfileView(steps: session.steps, mode: result == nil ? .structure : .state(.done), height: profileHeight, showRepeats: true)
                    if result == nil { ProfileLegend(steps: session.steps) }
                    readouts
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(heroLabel)
            .accessibilityHint("Opens the session")
            if let r = session.reason {
                Divider().overlay(BL.separator)
                if let rule = session.reasonRule { ReasonLine(text: r, rule: rule) } else { ReasonLine(text: r) }
            }
        }
        .card()
    }

    /// Both labels share one line and both values share one baseline: the labels sit in their own row,
    /// the values in a second row aligned on the last text baseline.
    private var readouts: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 2) {
            GridRow {
                Text(lead.label).font(BLFont.label).foregroundStyle(BL.textSecondary)
                if session.headlineTarget != nil {
                    Text(session.targetLabel).font(BLFont.label).foregroundStyle(BL.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            GridRow(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(lead.value).font(BLFont.readoutValue).foregroundStyle(BL.textPrimary)
                    Text(lead.unit).font(BLFont.unit).foregroundStyle(BL.textSecondary)
                }
                if let t = session.headlineTarget {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(t.value).font(BLFont.largeValue).foregroundStyle(session.sport.ink)
                        Text(t.unit).font(BLFont.unit).foregroundStyle(BL.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        if let done = doneMinutes {
            VStack(alignment: .leading, spacing: BL.Space.m) {
                ReadoutGrid(items: [
                    Readout(label: "planned", value: "\(session.minutes)", unit: "min"),
                    Readout(label: "done", value: "\(done)", unit: "min"),
                    Readout(label: "Training load", value: "\(session.loadPoints)", unit: "points", term: .load, estimated: session.loadEstimated),
                ])
                .card()
                Text(resultNote)
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
                if let card = shareData { ShareCardButton(data: card) }
                if let upload = stravaUpload { StravaShareButton(upload: upload) }
            }
            .transition(.opacity)
        } else if setup.canSendToWatch {
            watchActions
        } else {
            phoneActions
        }
    }

    /// Apple Watch: sending the session to the wrist is the main action, the phone is the alternative.
    private var watchActions: some View {
        VStack(spacing: BL.Space.m) {
            if synced {
                Label("On your watch, scheduled \(Demo.sessionTimeLabel)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BL.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                Button("Start on phone") { playerSession = session }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.2))) { synced = true }
                } label: {
                    Label("Send to watch", systemImage: "applewatch")
                }
                .buttonStyle(PrimaryButtonStyle())
                .sensoryFeedback(.success, trigger: synced)
                Button { playerSession = session } label: {
                    Label("Start on phone", systemImage: "iphone")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    /// WHOOP, Garmin, another device or phone only: there is no watch to send to, so the phone guides the session.
    private var phoneActions: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Button { playerSession = session } label: {
                Label("Start on phone", systemImage: "iphone")
            }
            .buttonStyle(PrimaryButtonStyle())
            Text(FollowCard.short(for: setup.followDevice))
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Share

    /// The share card for the session just finished: only what is on this screen.
    private var shareData: ShareCardData? {
        guard let r = result, let done = doneMinutes else { return nil }
        let others = days.flatMap(\.sessions).filter { $0.state == .done && $0.engineID != session.engineID }
        let minutes = others.reduce(0) { $0 + ($1.doneMinutes ?? 0) } + done
        return ShareCards.session(
            name: session.name, sport: session.sport, brickSecond: session.brickSecond, minutes: done,
            finishedInFull: r.completed, distanceMeters: session.showsDistance ? session.totalMeters : nil,
            target: session.headlineTarget, targetEstimated: session.targetsEstimated,
            weekDoneMinutes: minutes, weekDoneSessions: others.count + 1, weekLabel: Demo.weekLabel, date: r.startedAt ?? Date())
    }

    /// What Strava would receive for the session just finished.
    private var stravaUpload: StravaUpload? {
        guard let r = result else { return nil }
        let start = r.startedAt ?? Date().addingTimeInterval(-r.seconds)
        return StravaUpload(
            key: (session.engineID ?? session.name) + "|" + String(Int(start.timeIntervalSince1970)),
            name: session.name, sport: session.sport, isBrick: session.brickSecond != nil,
            start: start, elapsedSeconds: Int(r.seconds.rounded()))
    }

    // MARK: Ease the week

    private var hasSessionsLeft: Bool { days.contains { $0.sessions.contains { $0.state == .planned } } }

    @ViewBuilder private var easeControl: some View {
        if engine.model.weekEased {
            VStack(alignment: .leading, spacing: BL.Space.s) {
                Label("You made the rest of this week easier.", systemImage: "leaf")
                    .font(.subheadline.weight(.medium)).foregroundStyle(BL.textPrimary)
                Button("Undo, go back to the plan") { engine.undoEaseCurrentWeek() }
                    .font(.subheadline).foregroundStyle(BL.accent).frame(minHeight: 44)
            }
        } else if hasSessionsLeft {
            Button { confirmEase = true } label: { Label("This week feels too hard", systemImage: "leaf") }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Makes the sessions you have not done yet this week easier")
        }
    }

    // MARK: Readiness

    /// One plain line about last night. Hidden when no connected device can supply sleep or heart data.
    @ViewBuilder private var readinessSection: some View {
        let m = engine.model
        if let line = ReadinessPlainCopy.line(assessment: m.readiness, event: m.readinessEvent, kept: m.readinessKept,
                                              hasSources: setup.data.hasRecoverySource) {
            ReadinessLineView(model: line) {
                ReadinessCoordinator.shared.keepPlannedSession(on: Demo.today)
            }
        }
    }

    // MARK: Week

    /// The strip and the engine note read as one unit, so the note follows the strip at a short gap.
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "This week", trailing: Demo.weekLabel)
                WeekStrip(days: days) { day in
                    if let s = day.sessions.first { path.append(s) }
                }
            }
            Text(engineNote)
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            easeControl
        }
        .confirmationDialog("Make the rest of this week easier?", isPresented: $confirmEase, titleVisibility: .visible) {
            Button("Make it easier") { engine.easeCurrentWeek() }
            Button("Keep the plan", role: .cancel) {}
        } message: {
            Text(EaseWeek.confirmMessage)
        }
    }
}
