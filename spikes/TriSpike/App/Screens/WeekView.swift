import SwiftUI

struct WeekView: View {
    @Binding var playerSession: Session?
    private let days = Demo.week
    private static let weekday: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d"; return f }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                    ArcBar()
                    WeekStrip(days: days)
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
                    HStack {
                        Readout(label: "planned", value: "7.4", unit: "h")
                        Spacer()
                        Readout(label: "done so far", value: "1.1", unit: "h")
                        Spacer()
                        Readout(label: "load", value: "118")
                    }
                    .card()
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.vertical, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .navigationTitle("Week \(Demo.currentWeek) of \(Demo.totalWeeks)")
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0, playerSession: $playerSession) }
        }
    }

    private func dayRow(_ day: PlanDay, _ s: Session) -> some View {
        HStack(alignment: .center, spacing: BL.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.weekday.string(from: day.date))
                    .font(.body.weight(.medium))
                    .foregroundStyle(day.isToday ? BL.textPrimary : BL.textSecondary)
                if day.isToday { Text("today").font(BLFont.label).foregroundStyle(BL.textPrimary) }
            }
            .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: s.sport.symbol()).foregroundStyle(s.sport.ink)
                    if let second = s.brickSecond {
                        Image(systemName: "arrow.right").imageScale(.small).foregroundStyle(BL.textSecondary)
                        Image(systemName: second.symbol()).foregroundStyle(second.ink)
                    }
                    Text(s.name).font(.body).foregroundStyle(BL.textPrimary)
                }
                ProfileView(steps: s.steps, mode: .state(s.state), height: 22)
                if s.state == .done, let done = s.doneMinutes {
                    Text("planned \(s.minutes) min, done \(done) min").font(BLFont.label).foregroundStyle(BL.textSecondary)
                } else if s.state == .skipped {
                    Text("skipped, dropped from the week").font(BLFont.label).foregroundStyle(BL.textSecondary)
                } else {
                    Text("\(s.minutes) min").font(BLFont.label).foregroundStyle(BL.textSecondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: stateSymbol(s.state))
                .font(.system(size: 17))
                .foregroundStyle(BL.textPrimary)
                .accessibilityLabel(s.state == .done ? "done" : s.state == .skipped ? "skipped" : "planned")
        }
        .padding(.vertical, BL.Space.m)
        .contentShape(Rectangle())
    }

    private func restRow(_ day: PlanDay) -> some View {
        HStack(spacing: BL.Space.m) {
            Text(Self.weekday.string(from: day.date)).font(.body.weight(.medium)).foregroundStyle(BL.textSecondary)
                .frame(width: 56, alignment: .leading)
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
