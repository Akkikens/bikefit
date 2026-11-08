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
    @ScaledMetric(relativeTo: .subheadline) private var inset: CGFloat = 10
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
        .padding(.horizontal, inset)
        .padding(.vertical, 4)
        .frame(minHeight: 28)
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
    /// Value font. Pass `BLFont.largeValue` for a headline readout; place readouts of different sizes in an
    /// HStack aligned on `.firstTextBaseline` so their labels share one line.
    var valueFont: Font = BLFont.readoutValue
    var alignment: HorizontalAlignment = .leading
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 4) {
                Text(label).font(BLFont.label).foregroundStyle(BL.textSecondary)
                if estimated {
                    Text("est.").font(.caption2.weight(.semibold)).foregroundStyle(BL.warning)
                        .accessibilityLabel("estimated")
                }
            }
            // Value and unit stay on one line when they fit, and stack (unit under value) when the cell is narrow,
            // so a pace such as 1:45 /100m never breaks inside its own characters.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value).font(valueFont).foregroundStyle(ink).lineLimit(1).fixedSize()
                    if !unit.isEmpty { Text(unit).font(BLFont.unit).foregroundStyle(BL.textSecondary).lineLimit(1).fixedSize() }
                }
                VStack(alignment: alignment, spacing: 0) {
                    Text(value).font(valueFont).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
                    if !unit.isEmpty { Text(unit).font(BLFont.unit).foregroundStyle(BL.textSecondary).lineLimit(1) }
                }
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
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { row in
                GridRow {
                    ForEach(row..<min(row + columns, items.count), id: \.self) { i in
                        // Top aligned so every label in the row shares one baseline, whatever the value stacks to.
                        HStack(alignment: .top, spacing: 12) {
                            if i != row { Rectangle().fill(BL.separator).frame(width: 0.5) }
                            items[i]
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button {
            withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.2))) { expanded.toggle() }
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
            // Tap target: text height plus 24 pt (44 pt for one line) without changing the layout.
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .padding(.vertical, -12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(expanded ? rule : "rule hidden")
        .accessibilityHint(expanded ? "Hides the rule" : "Shows the rule")
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
                    // Rest days have nothing to open, so they are static rows rather than dead buttons.
                    if d.sessions.isEmpty {
                        DayRowCompact(day: d)
                    } else {
                        Button { onSelect(d) } label: { DayRowCompact(day: d) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the session")
                    }
                    if d.id != days.last?.id { Divider().overlay(BL.separator) }
                }
            }
            .card()
        } else {
            HStack(spacing: 0) {
                ForEach(days) { d in
                    if d.sessions.isEmpty {
                        DayCell(day: d).frame(maxWidth: .infinity)
                    } else {
                        Button { onSelect(d) } label: { DayCell(day: d) }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityHint("Opens the session")
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .cardSurface()
        }
    }
}

private let weekdayFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
private let dayNumberFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()
private let weekdayLongFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE d"; return f }()

struct DayCell: View {
    var day: PlanDay
    // Every metric scales with the weekday label so the cell grows as one unit instead of clipping.
    @ScaledMetric(relativeTo: .footnote) private var symbolSize: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var profileHeight: CGFloat = 22
    @ScaledMetric(relativeTo: .footnote) private var stackedHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .footnote) private var profileWidth: CGFloat = 34
    @ScaledMetric(relativeTo: .footnote) private var cellHeight: CGFloat = 78

    var body: some View {
        // Fixed slots (label, symbol, profile) so weekday, symbol and bar baseline line up across all seven cells.
        VStack(spacing: 0) {
            Text(weekdayFormatter.string(from: day.date))
                .font(BLFont.label)
                .foregroundStyle(day.isToday ? BL.textPrimary : BL.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: rowHeight)
            Group {
                if let s = day.sessions.first {
                    HStack(spacing: 3) {
                        Image(systemName: s.sport.symbol()).foregroundStyle(s.sport.ink)
                        if let b = s.brickSecond {
                            Image(systemName: "arrow.right")
                                .font(.system(size: symbolSize * 0.65, weight: .semibold))
                                .foregroundStyle(BL.textSecondary)
                            Image(systemName: b.symbol()).foregroundStyle(b.ink)
                        }
                    }
                } else {
                    Image(systemName: "moon.zzz").foregroundStyle(BL.textSecondary)
                }
            }
            .font(.system(size: symbolSize, weight: .medium))
            .frame(height: rowHeight)
            .padding(.top, 4)
            ZStack(alignment: .bottom) {
                Color.clear
                if day.sessions.isEmpty {
                    Circle().fill(BL.textSecondary).frame(width: 6, height: 6)
                } else {
                    VStack(spacing: 2) {
                        ForEach(day.sessions) { session in
                            ProfileView(steps: session.steps, mode: .state(session.state),
                                        height: day.sessions.count > 1 ? stackedHeight : profileHeight, compact: true)
                        }
                    }
                }
            }
            .frame(width: min(profileWidth, 40), height: profileHeight + 2)
            .padding(.top, 6)
        }
        .padding(.top, 6)
        // Air under the profile and the rest dot, so a hollow block never merges into the today outline.
        .padding(.bottom, 6)
        .frame(width: 44, alignment: .top)
        .frame(minHeight: cellHeight, alignment: .top)
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
        guard !day.sessions.isEmpty else { return "\(name), rest" + (day.isToday ? ", today" : "") }
        let parts = day.sessions.map { s -> String in
            let sport = s.brickSecond.map { "brick, \(s.sport.word) then \($0.word)" } ?? s.sport.word
            let state = s.state == .done ? "done" : s.state == .skipped ? "skipped" : "planned"
            return "\(sport), \(state)"
        }
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

    /// Position of the current week inside its phase, derived from `Demo.phases`.
    private var position: (phase: Phase, index: Int, length: Int) {
        var start = 1
        for (phase, length) in Demo.phases {
            if Demo.currentWeek < start + length { return (phase, Demo.currentWeek - start + 1, length) }
            start += length
        }
        let last = Demo.phases[Demo.phases.count - 1]
        return (last.0, last.1, last.1)
    }

    /// Where you are inside the phase, so the card adds a fact the navigation title does not already carry.
    private var subtitle: String {
        let p = position
        var s = "Week \(p.index) of \(p.length)"
        if Demo.testWeeks.contains(Demo.currentWeek) {
            s += ", test week"
        } else if Demo.recoveryWeeks.contains(Demo.currentWeek + 1) {
            s += ", recovery week next"
        } else if p.index == p.length,
                  let i = Demo.phases.firstIndex(where: { $0.0 == p.phase }), i + 1 < Demo.phases.count {
            s += ", \(Demo.phases[i + 1].0.rawValue) starts next week"
        }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(position.phase.rawValue.capitalized) phase").font(.headline).foregroundStyle(BL.textPrimary)
                    Text(subtitle).font(BLFont.meta).foregroundStyle(BL.textSecondary)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Demo.daysToRace)").font(BLFont.arcCountdown).foregroundStyle(BL.textPrimary)
                    Text("days").font(BLFont.unit).foregroundStyle(BL.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(position.phase.rawValue.capitalized) phase, week \(Demo.currentWeek) of \(Demo.totalWeeks), \(Demo.daysToRace) days to race")
            GeometryReader { geo in
                let w = geo.size.width
                let perWeek = w / CGFloat(Demo.totalWeeks)
                ZStack(alignment: .topLeading) {
                    Capsule().fill(BL.separator).frame(height: 4).offset(y: 18)
                    Capsule().fill(BL.accent).frame(width: perWeek * (CGFloat(Demo.currentWeek) - 0.5) * fillAmount, height: 4).offset(y: 18)
                    ForEach(Array(Demo.testWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.textSecondary).frame(width: 1, height: 10)
                            .offset(x: perWeek * (CGFloat(wk) - 0.5), y: 15)
                    }
                    ForEach(Array(Demo.recoveryWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.surface).frame(width: 1.5, height: 4)
                            .offset(x: perWeek * CGFloat(wk) - 0.75, y: 18)
                    }
                    Image(systemName: "triangle.fill").font(.system(size: 7)).foregroundStyle(BL.accent)
                        .offset(x: perWeek * (CGFloat(Demo.currentWeek) - 0.5) - 4, y: 27)
                    HStack(spacing: 0) {
                        ForEach(Demo.phases, id: \.0) { phase, weeks in
                            // 44 pt tall band: the word stays above the track, the transparent hit shape covers the track
                            // and marker beneath it. Width stays proportional to weeks, so height is what gives.
                            Button { selected = phase } label: {
                                Text(phase.rawValue)
                                    .font(BLFont.label)
                                    .foregroundStyle(phase == position.phase ? BL.textPrimary : BL.textSecondary)
                                    .frame(width: perWeek * CGFloat(weeks), height: 44, alignment: .topLeading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(phase.rawValue.capitalized) phase, \(weeks) weeks\(phase == position.phase ? ", current" : "")")
                            .accessibilityHint("Explains this phase")
                            .accessibilityAddTraits(phase == position.phase ? .isSelected : [])
                            .popover(isPresented: Binding(get: { selected == phase }, set: { if !$0 { selected = nil } })) {
                                Text(phaseSentence(phase)).font(.subheadline).padding().frame(maxWidth: 280)
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
            }
            .frame(height: 44)
            .padding(.bottom, -14)
        }
        .card()
        // Header reads once, then each phase band is its own element.
        .accessibilityElement(children: .contain)
        .onAppear {
            withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.6))) { fillAmount = 1 }
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
    @ScaledMetric(relativeTo: .footnote) private var numberWidth: CGFloat = 18
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)").font(BLFont.label).foregroundStyle(BL.textSecondary)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: numberWidth, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).font(.body).foregroundStyle(step.kind == .recovery ? BL.textSecondary : BL.textPrimary)
                Text(step.distance ?? duration(step.seconds)).font(.subheadline.monospacedDigit()).foregroundStyle(BL.textSecondary)
            }
            Spacer(minLength: 8)
            if let t = step.target {
                TargetText(raw: t, ink: step.kind == .recovery ? BL.textSecondary : step.sport.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.leading, indented ? 12 : 0)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }
}

/// A target such as "205 to 220 W" or "1:52 /100m": the numerals at body weight, the trailing unit small,
/// the same numeral-and-small-unit shape the Readouts use. Words such as "easy" stay plain.
struct TargetText: View {
    var raw: String
    var ink: Color

    private var split: (value: String, unit: String)? {
        guard let i = raw.lastIndex(of: " ") else { return nil }
        let value = String(raw[..<i])
        let unit = String(raw[raw.index(after: i)...])
        guard let last = value.last, last.isNumber, let first = unit.first, first.isLetter || first == "/" else { return nil }
        return (value, unit)
    }

    var body: some View {
        Group {
            if let s = split {
                Text("\(Text(s.value).font(.body.weight(.medium).monospacedDigit())) \(Text(s.unit).font(BLFont.unit))")
            } else {
                Text(raw).font(.body.weight(.medium))
            }
        }
        .foregroundStyle(ink)
        .accessibilityLabel(raw)
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
                    .font(.title2)
                    .foregroundStyle(BL.accent)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(text).font(.body).foregroundStyle(BL.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: done)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(done ? Text("Checked") : Text("Not checked"))
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
        .cardSurface(radius: 18)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trailing.map { "\(text), \($0)" } ?? text)
        .accessibilityAddTraits(.isHeader)
    }
}
