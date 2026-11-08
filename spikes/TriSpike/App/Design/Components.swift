import SwiftUI

// MARK: Sport identity: color, symbol and word, always together

extension Sport {
    var ink: Color {
        switch self { case .swim: BL.swimInk; case .bike: BL.bikeInk; case .run: BL.runInk }
    }
    var fill: Color {
        switch self { case .swim: BL.swimFill; case .bike: BL.bikeFill; case .run: BL.runFill }
    }
    var playerInk: Color {
        switch self { case .swim: BL.Player.swimInk; case .bike: BL.Player.bikeInk; case .run: BL.Player.runInk }
    }
}

struct SportChip: View {
    var sport: Sport
    var second: Sport? = nil
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: sport.symbol())
            if let second {
                Image(systemName: "arrow.right").foregroundStyle(BL.textSecondary).imageScale(.small)
                Image(systemName: second.symbol()).foregroundStyle(second.ink)
                Text("Brick")
            } else {
                Text(sport.word)
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(sport.ink)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(sport.fill.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(second == nil ? sport.word : "Brick, \(sport.word) then \(second!.word)")
    }
}

// MARK: Readout: small caps label over a value and unit

struct Readout: View {
    var label: String
    var value: String
    var unit: String = ""
    var ink: Color = BL.textPrimary
    var estimated = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label).font(BLFont.label).foregroundStyle(BL.textSecondary)
                if estimated {
                    Image(systemName: "e.circle").font(.caption2).foregroundStyle(BL.warning)
                        .accessibilityLabel("estimated")
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(BLFont.readoutValue).foregroundStyle(ink)
                if !unit.isEmpty { Text(unit).font(BLFont.label).foregroundStyle(BL.textSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReadoutGrid: View {
    var items: [Readout]
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        let columns = type >= .accessibility1 ? 1 : (type >= .xxxLarge ? 2 : items.count)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { row in
                GridRow {
                    ForEach(row..<min(row + columns, items.count), id: \.self) { i in
                        HStack(spacing: 12) {
                            if i != row { Rectangle().fill(BL.separator).frame(width: 0.5) }
                            items[i]
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: ReasonLine: appears only when a rule changed something

struct ReasonLine: View {
    var text: String
    var rule: String = "Rule 3, zone nudge: three comparable sessions off target, max once per 2 weeks."
    @State private var expanded = false
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "arrow.triangle.branch").font(.footnote)
                    Text(text).font(BLFont.meta).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                if expanded {
                    Text(rule).font(.footnote).padding(.leading, 21)
                }
            }
            .foregroundStyle(BL.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Expands the rule")
    }
}

// MARK: Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(BL.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(BL.accent, in: RoundedRectangle(cornerRadius: BL.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(BL.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(BL.surface, in: RoundedRectangle(cornerRadius: BL.Radius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: BL.Radius.button, style: .continuous).strokeBorder(BL.textSecondary, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: Week strip

struct WeekStrip: View {
    var days: [PlanDay]
    var onSelect: (PlanDay) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        if type >= .accessibility1 {
            VStack(spacing: 0) {
                ForEach(days) { d in
                    Button { onSelect(d) } label: { DayRowCompact(day: d) }.buttonStyle(.plain)
                    if d.id != days.last?.id { Divider().overlay(BL.separator) }
                }
            }
            .card()
        } else {
            HStack(spacing: 0) {
                ForEach(days) { d in
                    Button { onSelect(d) } label: { DayCell(day: d) }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(BL.surface, in: RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous).strokeBorder(BL.separator, lineWidth: 0.5))
        }
    }
}

private let weekdayFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
private let dayNumberFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()
private let weekdayLongFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE d"; return f }()

struct DayCell: View {
    var day: PlanDay
    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayFormatter.string(from: day.date))
                .font(BLFont.label)
                .foregroundStyle(day.isToday ? BL.textPrimary : BL.textSecondary)
            if let s = day.sessions.first {
                Image(systemName: s.sport.symbol()).font(.system(size: 11, weight: .medium)).foregroundStyle(s.sport.ink)
                VStack(spacing: 2) {
                    ForEach(day.sessions) { session in
                        ProfileView(steps: session.steps, mode: .state(session.state), height: day.sessions.count > 1 ? 10 : 22)
                    }
                }
                .frame(width: 34)
            } else {
                Image(systemName: "moon.zzz").font(.system(size: 11, weight: .medium)).foregroundStyle(BL.textSecondary)
                Spacer().frame(height: 14)
                Circle().fill(BL.textSecondary).frame(width: 6, height: 6)
            }
        }
        .frame(width: 44, height: 72)
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(BL.accent, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel)
    }

    private var dayLabel: String {
        let name = weekdayLongFormatter.string(from: day.date)
        guard !day.sessions.isEmpty else { return "\(name), rest" }
        let parts = day.sessions.map { s in "\(s.sport.word), \(s.state == .done ? "done" : s.state == .skipped ? "skipped" : "planned")" }
        return ([name] + parts).joined(separator: ", ") + (day.isToday ? ", today" : "")
    }
}

struct DayRowCompact: View {
    var day: PlanDay
    var body: some View {
        HStack {
            Text(weekdayLongFormatter.string(from: day.date)).font(.body.weight(.medium))
            Spacer()
            Text(day.sessions.isEmpty ? "Rest" : day.sessions.map(\.sport.word).joined(separator: ", "))
                .foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

// MARK: ArcBar: the season with four phase bands

struct ArcBar: View {
    @State private var selected: Phase?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fillAmount: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build phase").font(.headline).foregroundStyle(BL.textPrimary)
                    Text("Week \(Demo.currentWeek) of \(Demo.totalWeeks)").font(BLFont.meta).foregroundStyle(BL.textSecondary)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Demo.daysToRace)").font(BLFont.arcCountdown).foregroundStyle(BL.textPrimary)
                    Text("days").font(BLFont.label).foregroundStyle(BL.textSecondary)
                }
            }
            GeometryReader { geo in
                let w = geo.size.width
                let perWeek = w / CGFloat(Demo.totalWeeks)
                ZStack(alignment: .topLeading) {
                    Capsule().fill(BL.separator).frame(height: 4).offset(y: 18)
                    Capsule().fill(BL.accent).frame(width: perWeek * (CGFloat(Demo.currentWeek) - 0.5) * fillAmount, height: 4).offset(y: 18)
                    ForEach(Array(Demo.testWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.textSecondary).frame(width: 1, height: 5)
                            .offset(x: perWeek * (CGFloat(wk) - 0.5), y: 10)
                    }
                    ForEach(Array(Demo.recoveryWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.surface).frame(width: 1.5, height: 4)
                            .offset(x: perWeek * CGFloat(wk) - 0.75, y: 18)
                    }
                    Image(systemName: "triangle.fill").font(.system(size: 7)).foregroundStyle(BL.accent)
                        .offset(x: perWeek * (CGFloat(Demo.currentWeek) - 0.5) - 4, y: 24)
                    HStack(spacing: 0) {
                        ForEach(Demo.phases, id: \.0) { phase, weeks in
                            Button { selected = phase } label: {
                                Text(phase.rawValue)
                                    .font(BLFont.label)
                                    .foregroundStyle(phase == .build ? BL.textPrimary : BL.textSecondary)
                                    .frame(width: perWeek * CGFloat(weeks), alignment: .leading)
                                    .frame(minHeight: 16)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(get: { selected == phase }, set: { if !$0 { selected = nil } })) {
                                Text(phaseSentence(phase)).font(.subheadline).padding().frame(maxWidth: 280)
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
            }
            .frame(height: 36)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Build phase, week \(Demo.currentWeek) of \(Demo.totalWeeks), \(Demo.daysToRace) days to race")
        .onAppear {
            if reduceMotion { fillAmount = 1 } else { withAnimation(.easeOut(duration: 0.6)) { fillAmount = 1 } }
        }
    }

    private func phaseSentence(_ p: Phase) -> String {
        switch p {
        case .base: "Base builds aerobic volume and technique, mostly easy."
        case .build: "Build adds threshold work in each sport while volume holds."
        case .peak: "Peak brings race specific sessions and the biggest bricks."
        case .taper: "Taper cuts volume, keeps some intensity, and locks the plan."
        }
    }
}

// MARK: Step row

struct StepRow: View {
    var number: Int
    var step: PlanStep
    var indented = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)").font(BLFont.label).foregroundStyle(BL.textSecondary).frame(width: 18, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).font(.body).foregroundStyle(step.kind == .recovery ? BL.textSecondary : BL.textPrimary)
                Text(step.distance ?? duration(step.seconds)).font(BLFont.rowNumeral).foregroundStyle(BL.textSecondary)
            }
            Spacer(minLength: 8)
            if let t = step.target {
                Text(t).font(.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(step.kind == .recovery ? BL.textSecondary : step.sport.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.leading, indented ? 12 : 0)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }
}

func duration(_ s: TimeInterval) -> String {
    let m = Int(s) / 60, sec = Int(s) % 60
    if m >= 60 { return "\(m / 60) h \(m % 60) min" }
    return sec == 0 ? "\(m) min" : String(format: "%d:%02d", m, sec)
}

// MARK: Checklist row

struct ChecklistRow: View {
    var text: String
    @Binding var done: Bool
    var body: some View {
        Button {
            done.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(BL.accent)
                    .contentTransition(.symbolEffect(.replace))
                Text(text).font(.body).foregroundStyle(BL.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: done)
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

// MARK: Watch card: what the watch will actually show

struct WatchCard: View {
    var line: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "applewatch").font(.title3).foregroundStyle(BL.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("On your watch").font(BLFont.label).foregroundStyle(BL.textSecondary)
                Text(line).font(.subheadline).foregroundStyle(BL.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 72)
        .background(BL.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(BL.separator, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

// MARK: Section label

struct SectionLabel: View {
    var text: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(text).font(BLFont.label).foregroundStyle(BL.textSecondary)
            Spacer()
            if let trailing { Text(trailing).font(BLFont.label.monospacedDigit()).foregroundStyle(BL.textSecondary) }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
