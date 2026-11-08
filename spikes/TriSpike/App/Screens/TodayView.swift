import SwiftUI

struct TodayView: View {
    @Binding var playerSession: Session?
    @State private var synced = false
    @State private var path: [Session] = ProcessInfo.processInfo.arguments.contains("-screenDetail") ? [Demo.cssSwim] : []
    private let days = Demo.week
    private var session: Session { Demo.cssSwim }

    private static let dateFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f }()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    header
                    heroCard
                    actions
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "This week", trailing: "week \(Demo.currentWeek) of \(Demo.totalWeeks)")
                        WeekStrip(days: days) { day in
                            if let s = day.sessions.first { path.append(s) }
                        }
                    }
                    Text("Plans adapt by transparent rules. Every change says why.")
                        .font(.footnote)
                        .foregroundStyle(BL.textSecondary)
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.vertical, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0, playerSession: $playerSession) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Text(Self.dateFormat.string(from: Date()))
                .font(BLFont.meta)
                .foregroundStyle(BL.textSecondary)
            Text(session.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(BL.textPrimary)
                .accessibilityAddTraits(.isHeader)
            SportChip(sport: session.sport)
            Text(session.purpose)
                .font(BLFont.purpose)
                .foregroundStyle(BL.textPrimary)
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroCard: some View {
        Button { path.append(session) } label: {
            VStack(alignment: .leading, spacing: BL.Space.l) {
                ProfileView(steps: session.steps, mode: .structure, height: 56, showRepeats: true)
                HStack(alignment: .lastTextBaseline) {
                    Readout(label: "duration", value: "\(session.minutes)", unit: "min")
                    Spacer()
                    if let t = session.headlineTarget {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("target").font(BLFont.label).foregroundStyle(BL.textSecondary)
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(t.value).font(BLFont.largeValue).foregroundStyle(session.sport.ink)
                                Text(t.unit).font(BLFont.label).foregroundStyle(BL.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let r = session.reason {
                    Divider().overlay(BL.separator)
                    ReasonLine(text: r)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the session")
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: BL.Space.m) {
            if synced {
                Label("On your watch, scheduled 6:30", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BL.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                Button("Start on phone") { playerSession = session }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { synced = true }
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
