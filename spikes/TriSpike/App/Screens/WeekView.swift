import SwiftUI

struct WeekView: View {
    @Binding var playerSession: Session?
    @ScaledMetric(relativeTo: .body) private var dayColumn: CGFloat = 56
    @State private var path: [Session] = []
    @ObservedObject private var engine = EngineAdapter.shared
    private var days: [PlanDay] { Demo.week }
    private static let weekday: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d"; return f }()

    // Footer totals come from the plan, so they always agree with the rows above them.
    private var allSessions: [Session] { days.flatMap(\.sessions) }
    private var plannedMinutes: Int { allSessions.filter { $0.state != .skipped }.reduce(0) { $0 + $1.minutes } }
    private var doneSessions: [Session] { allSessions.filter { $0.state == .done } }
    private var doneMinutes: Int { doneSessions.reduce(0) { $0 + ($1.doneMinutes ?? $1.minutes) } }
    /// Sum of the engine's Load for the sessions done, so this screen and Session detail agree.
    private var loadSoFar: Int { doneSessions.reduce(0) { $0 + $1.loadPoints } }
    private var loadIsEstimated: Bool { doneSessions.contains { $0.loadEstimated } }
    private func hours(_ minutes: Int) -> String { String(format: "%.1f", Double(minutes) / 60) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                Text(Demo.weekLabel)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    if let begins = Demo.model.planBeginsOn {
                        Text("Your race plan starts on \(begins.formatted(.dateTime.day().month(.wide))). Until then, easy base weeks keep you moving.")
                            .font(.subheadline)
                            .foregroundStyle(BL.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    } else {
                        ArcBar()
                    }
                    VStack(alignment: .leading, spacing: BL.Space.s) {
                        WeekStrip(days: days) { day in
                            if let s = day.sessions.first { path.append(s) }
                        }
                        WeekStripKey()
                    }
                    VStack(spacing: 0) {
                        ForEach(days) { day in
                            if day.sessions.isEmpty {
                                restRow(day)
                            } else {
                                ForEach(day.sessions) { s in
                                    NavigationLink(value: s) { dayRow(day, s) }.buttonStyle(.plain)
                                }
                            }
                            if day.id != days.last?.id { Divider().overlay(BL.separator) }
                        }
                    }
                    .card()
                    ReadoutGrid(items: [
                        Readout(label: "planned", value: hours(plannedMinutes), unit: "hours"),
                        Readout(label: "done so far", value: hours(doneMinutes), unit: "hours"),
                        Readout(label: "Training load", value: "\(loadSoFar)", unit: "points", term: .load, estimated: loadIsEstimated),
                    ])
                    .card()
                }
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.top, BL.Space.s)
                .padding(.bottom, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .bottomEdgeSolid()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0, playerSession: $playerSession) }
        }
    }

    private func dayRow(_ day: PlanDay, _ s: Session) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BL.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.weekday.string(from: day.date))
                    .font(.body.weight(.medium))
                    .foregroundStyle(BL.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if day.isToday { Text("today").font(BLFont.label).foregroundStyle(BL.textPrimary) }
            }
            .frame(minWidth: dayColumn, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: s.sport.symbol()).foregroundStyle(s.sport.ink)
                    if let second = s.brickSecond {
                        Image(systemName: "arrow.right").imageScale(.small).foregroundStyle(BL.textSecondary)
                        Image(systemName: second.symbol()).foregroundStyle(second.ink)
                    }
                    Text(s.name).font(.body).foregroundStyle(BL.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ProfileView(steps: s.steps, mode: .state(s.state), height: 22)
                if s.state == .done, let done = s.doneMinutes {
                    Text("planned \(s.minutes) min, done \(done) min").font(BLFont.label).foregroundStyle(BL.textSecondary)
                } else if s.state == .skipped {
                    Text("skipped, left out of this week's totals").font(BLFont.label).foregroundStyle(BL.textSecondary)
                } else {
                    Text("\(s.minutes) min").font(BLFont.label).foregroundStyle(BL.textSecondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: stateSymbol(s.state))
                .font(.body)
                .foregroundStyle(BL.textPrimary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(day, s))
        .accessibilityHint("Opens the session")
    }

    private func rowLabel(_ day: PlanDay, _ s: Session) -> String {
        let sport = s.brickSecond.map { "\(s.sport.word) then \($0.word.lowercased())" } ?? s.sport.word
        let dayText = Self.weekday.string(from: day.date) + (day.isToday ? ", today" : "")
        let state: String
        switch s.state {
        case .done: state = s.doneMinutes.map { "done, \($0) minutes of \(s.minutes) planned" } ?? "done"
        case .skipped: state = "skipped, left out of this week's totals"
        case .planned: state = "planned, \(s.minutes) minutes"
        }
        return "\(dayText), \(sport), \(s.name), \(state)"
    }

    private func restRow(_ day: PlanDay) -> some View {
        HStack(spacing: BL.Space.m) {
            Text(Self.weekday.string(from: day.date)).font(.body.weight(.medium)).foregroundStyle(BL.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: dayColumn, alignment: .leading)
            Image(systemName: "moon.zzz").foregroundStyle(BL.textSecondary)
            Text("Rest").foregroundStyle(BL.textSecondary)
            Spacer()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func stateSymbol(_ s: SessionState) -> String {
        switch s { case .done: "checkmark.circle.fill"; case .planned: "circle"; case .skipped: "minus.circle" }
    }
}
