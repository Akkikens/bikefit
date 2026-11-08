import SwiftUI

struct TodayView: View {
    @Binding var playerSession: Session?
    @EnvironmentObject private var player: PhonePlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var type
    @ScaledMetric(relativeTo: .body) private var profileHeight: CGFloat = 56
    @State private var synced = false
    @State private var path: [Session] = ProcessInfo.processInfo.arguments.contains("-screenDetail") ? [Demo.cssSwim] : []
    private let days = Demo.week

    /// Today's session comes from the plan, not from a fixed reference.
    private var session: Session { days.first(where: { $0.isToday })?.sessions.first ?? Demo.cssSwim }

    private static let dateFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f }()

    /// What the phone player recorded for today's session, once it has ended.
    private var result: PhonePlayer.Result? {
        guard let r = player.lastResult, r.name == session.name else { return nil }
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
        switch changesThisWeek {
        case 0: return "No changes this week."
        case 1: return "One change this week. The session says why."
        default: return "\(changesThisWeek) changes this week. Each session says why."
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    header
                    VStack(alignment: .leading, spacing: BL.Space.m) {
                        heroCard
                        if !pinsActions { actions }
                    }
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
                if pinsActions {
                    actions
                        .padding(.horizontal, BL.Space.gutter)
                        .padding(.vertical, BL.Space.s)
                        .background(BL.background)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0, playerSession: $playerSession) }
        }
    }

    /// Pinned only while there are buttons to press; the finished-session summary scrolls with the page.
    private var pinsActions: Bool { type.isAccessibilitySize && result == nil }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Text(Self.dateFormat.string(from: Date()))
                .font(BLFont.meta)
                .foregroundStyle(BL.textSecondary)
            SportChip(sport: session.sport, second: session.brickSecond)
            Text(session.name)
                .font(BLFont.sessionName)
                .foregroundStyle(BL.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(session.purpose)
                .font(BLFont.purpose)
                .foregroundStyle(BL.textPrimary)
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: !type.isAccessibilitySize)
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
        case "/100m": return "per 100 meters"
        case "/km": return "per kilometer"
        case "W": return "watts"
        default: return unit
        }
    }

    private var heroLabel: String {
        var s = "\(session.name), \(lead.label) \(lead.value) \(spoken(lead.unit))"
        if let t = session.headlineTarget { s += ", target \(t.value) \(spoken(t.unit))" }
        return s
    }

    /// The reason line is a sibling of the card button, never nested in it, so VoiceOver reaches both
    /// and a tap on the reason expands the rule instead of opening the session.
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            Button { path.append(session) } label: {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    ProfileView(steps: session.steps, mode: result == nil ? .structure : .state(.done), height: profileHeight, showRepeats: true)
                    readouts
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(heroLabel)
            .accessibilityHint("Opens the session")
            if let r = session.reason {
                Divider().overlay(BL.separator)
                ReasonLine(text: r)
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
                    Text("target").font(BLFont.label).foregroundStyle(BL.textSecondary)
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
                    Readout(label: "load", value: "\(Session.loadEstimate(minutes: done))", estimated: true),
                ])
                .card()
                Text(resultNote)
                    .font(.footnote)
                    .foregroundStyle(BL.textSecondary)
            }
            .transition(.opacity)
        } else {
            VStack(spacing: BL.Space.m) {
                if synced {
                    Label("On your watch, scheduled \(Demo.sessionTime)", systemImage: "checkmark.circle.fill")
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
    }

    // MARK: Week

    /// The strip and the engine note read as one unit, so the note follows the strip at a short gap.
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: BL.Space.m) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "This week", trailing: "week \(Demo.currentWeek) of \(Demo.totalWeeks)")
                WeekStrip(days: days) { day in
                    if let s = day.sessions.first { path.append(s) }
                }
            }
            Text(engineNote)
                .font(.footnote)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
