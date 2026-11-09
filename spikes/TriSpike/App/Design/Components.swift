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
                Text("\(sport.word) then \(second.word.lowercased())")
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
        .accessibilityLabel(second == nil ? sport.word : "\(sport.word) then \(second!.word.lowercased())")
    }
}

// MARK: Readout: small caps label over a value and unit

/// A glossary link that sits in the layout at the height of its text. `JargonText` keeps a 44 pt tap area, which would
/// stretch small labels, so the extra height is trimmed from the layout and the tap area overflows into the free space.
struct CompactJargon: View {
    var term: Term
    var label: String? = nil
    var font: Font = BLFont.label
    var ink: Color = BL.textSecondary
    /// Height of one line of the text at the default size, in points.
    var textHeight: CGFloat = 18
    /// 1 at the default size, larger with Dynamic Type, so the trim follows the text.
    @ScaledMetric(relativeTo: .footnote) private var sizeScale: CGFloat = 1
    private var trim: CGFloat { max(0, (44 - textHeight * sizeScale) / 2) }
    var body: some View {
        JargonText(term: term, label: label, font: font, ink: ink)
            .padding(.vertical, -trim)
    }
}

struct Readout: View {
    var label: String
    var value: String
    var unit: String = ""
    var ink: Color = BL.textPrimary
    /// When set, the label opens the glossary entry for this word.
    var term: Term? = nil
    var estimated = false
    /// Value font. Pass `BLFont.largeValue` for a headline readout; place readouts of different sizes in an
    /// HStack aligned on `.firstTextBaseline` so their labels share one line.
    var valueFont: Font = BLFont.readoutValue
    var alignment: HorizontalAlignment = .leading
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 8) {
                if let term {
                    CompactJargon(term: term, label: label)
                } else {
                    Text(label).font(BLFont.label).foregroundStyle(BL.textSecondary)
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
            if estimated {
                CompactJargon(term: .estimated, label: "estimate", font: .caption2.weight(.semibold), ink: BL.warning)
            }
        }
        // A readout with a glossary link keeps its children, so VoiceOver can reach the link.
        .accessibilityElement(children: term == nil && !estimated ? .combine : .contain)
    }
}

struct ReadoutGrid: View {
    var items: [Readout]
    /// Most readouts in one row. Four across is too tight for a pace with its unit.
    var maxColumns: Int? = nil
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        let columns = type >= .accessibility1 ? 1 : (type >= .xxxLarge ? 2 : min(items.count, maxColumns ?? items.count))
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
    var rule: String = "Why this changed: when three similar sessions all go better or worse than the target, the plan moves the target a little. It does this at most once every 2 weeks."
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
        .accessibilityValue(expanded ? rule : "explanation hidden")
        .accessibilityHint(expanded ? "Hides the explanation" : "Shows the explanation")
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

/// What the marks in the week strip mean: solid is done, outline is planned, crossed out is skipped, a dot is a rest day.
struct WeekStripKey: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BL.Space.l) { items; Spacer(minLength: 0) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 6) { items }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key: solid means done, outline means planned, crossed out means skipped, a dot means a rest day.")
    }

    @ViewBuilder private var items: some View {
        item("Done") { RoundedRectangle(cornerRadius: 2).fill(BL.textSecondary).frame(width: 14, height: 10) }
        item("Planned") { RoundedRectangle(cornerRadius: 2).strokeBorder(BL.textSecondary, lineWidth: 1.5).frame(width: 14, height: 10) }
        item("Skipped") {
            ZStack {
                RoundedRectangle(cornerRadius: 2).strokeBorder(BL.textSecondary, lineWidth: 1.5)
                Path { p in p.move(to: CGPoint(x: 0, y: 10)); p.addLine(to: CGPoint(x: 14, y: 0)) }.stroke(BL.textSecondary, lineWidth: 1.5)
            }.frame(width: 14, height: 10)
        }
        item("Rest day") { Circle().fill(BL.textSecondary).frame(width: 6, height: 6).frame(width: 14, height: 10) }
    }

    private func item<G: View>(_ text: String, @ViewBuilder glyph: () -> G) -> some View {
        HStack(spacing: 6) {
            glyph().accessibilityHidden(true)
            Text(text).font(.caption.weight(.medium)).foregroundStyle(BL.textSecondary)
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
            let sport = s.brickSecond.map { "\(s.sport.word) then \($0.word.lowercased())" } ?? s.sport.word
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
            Text(day.sessions.isEmpty ? "Rest" : day.sessions.map(\.chipWord).joined(separator: ", "))
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
        "Week \(position.index) of \(position.length) in this phase"
    }

    /// The one special thing about this week or the next, as an explained term.
    private var note: (term: Term, label: String)? {
        let p = position
        if Demo.testWeeks.contains(Demo.currentWeek) { return (.testWeek, "This is a test week") }
        if Demo.recoveryWeeks.contains(Demo.currentWeek + 1) { return (.recoveryWeek, "Next week is a recovery week") }
        if p.index == p.length,
           let i = Demo.phases.firstIndex(where: { $0.0 == p.phase }), i + 1 < Demo.phases.count {
            let next = Demo.phases[i + 1].0
            return (next.glossaryTerm, "Next week starts the \(next.rawValue) phase")
        }
        return nil
    }

    private var headerLabel: String {
        var s = "\(position.phase.displayName) phase, week \(Demo.currentWeek) of \(Demo.totalWeeks), \(position.index) of \(position.length) in this phase"
        if let note { s += ", \(note.label.lowercased())" }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    CompactJargon(term: position.phase.glossaryTerm, font: .headline, ink: BL.textPrimary, textHeight: 24)
                    Text(subtitle).font(BLFont.meta).foregroundStyle(BL.textSecondary)
                    if let note {
                        CompactJargon(term: note.term, label: note.label, font: BLFont.meta, ink: BL.textSecondary, textHeight: 20)
                    }
                }
                Spacer()
                if Demo.hasRace {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Demo.daysToRace)").font(BLFont.arcCountdown).foregroundStyle(BL.textPrimary)
                        Text(Demo.daysToRace == 1 ? "day to race" : "days to race").font(BLFont.unit).foregroundStyle(BL.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(Demo.daysToRace) \(Demo.daysToRace == 1 ? "day" : "days") to race")
                }
            }
            GeometryReader { geo in
                let w = geo.size.width
                let perWeek = w / CGFloat(Demo.totalWeeks)
                ZStack(alignment: .topLeading) {
                    Capsule().fill(BL.separator).frame(height: 4).offset(y: 18)
                    Capsule().fill(BL.accent).frame(width: perWeek * (CGFloat(Demo.currentWeek) - 0.5) * fillAmount, height: 4).offset(y: 18)
                    ForEach(Array(Demo.testWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.textSecondary).frame(width: 2, height: 14)
                            .offset(x: perWeek * (CGFloat(wk) - 0.5) - 1, y: 13)
                    }
                    ForEach(Array(Demo.recoveryWeeks), id: \.self) { wk in
                        Rectangle().fill(BL.surface).frame(width: 2.5, height: 4)
                            .offset(x: perWeek * CGFloat(wk) - 1.25, y: 18)
                    }
                    Image(systemName: "triangle.fill").font(.system(size: 7)).foregroundStyle(BL.accent)
                        .offset(x: perWeek * (CGFloat(Demo.currentWeek) - 0.5) - 4, y: 27)
                    HStack(spacing: 0) {
                        ForEach(Demo.phases, id: \.0) { phase, weeks in
                            // 44 pt tall band: the word stays above the track, the transparent hit shape covers the track
                            // and marker beneath it. Width stays proportional to weeks, so height is what gives.
                            Button { selected = phase } label: {
                                // A band too narrow for its word (a one week taper) shows no word; the key below names every phase.
                                Text(perWeek * CGFloat(weeks) >= 40 ? phase.rawValue : "")
                                    .font(BLFont.label)
                                    .lineLimit(1)
                                    .foregroundStyle(phase == position.phase ? BL.textPrimary : BL.textSecondary)
                                    .frame(width: perWeek * CGFloat(weeks), height: 44, alignment: .topLeading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(phase.glossaryTerm.title), \(weeks) weeks\(phase == position.phase ? ", current" : "")")
                            .accessibilityHint("Explains this part of the plan")
                            .accessibilityAddTraits(phase == position.phase ? .isSelected : [])
                            .popover(isPresented: Binding(get: { selected == phase }, set: { if !$0 { selected = nil } })) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(phase.glossaryTerm.title).font(.headline)
                                    Text(phase.glossaryTerm.short).font(.subheadline)
                                    Text("\(weeks) weeks of your \(Demo.totalWeeks) week plan").font(.footnote).foregroundStyle(BL.textSecondary)
                                }
                                .padding().frame(maxWidth: 280, alignment: .leading)
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
            }
            .frame(height: 44)
            .padding(.bottom, -14)
            legend
            phaseKey
        }
        .card()
        // Header reads once, then each phase band and glossary link is its own element.
        .accessibilityElement(children: .contain)
        .onAppear {
            withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.6))) { fillAmount = 1 }
        }
    }

    /// Says what the marks on the bar mean, with each name explained.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BL.Space.l) { testKey; recoveryKey; Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 0) { testKey; recoveryKey }
        }
    }

    /// Each phase named in plain words, with its length. The name is tappable for the longer explanation.
    private var phaseKey: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Divider().overlay(BL.separator)
            Grid(alignment: .leading, horizontalSpacing: BL.Space.m, verticalSpacing: BL.Space.s) {
                ForEach(Demo.phases, id: \.0) { phase, weeks in
                    GridRow(alignment: .firstTextBaseline) {
                        CompactJargon(term: phase.glossaryTerm, label: phase.displayName, font: .subheadline.weight(.semibold), ink: BL.textPrimary, textHeight: 20)
                            .fixedSize()
                            .gridColumnAlignment(.leading)
                        Text("\(weeks == 1 ? "1 week" : "\(weeks) weeks"), \(phase.plainLine)")
                            .font(.subheadline)
                            .foregroundStyle(BL.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var testKey: some View {
        HStack(spacing: 6) {
            Rectangle().fill(BL.textSecondary).frame(width: 2, height: 14).accessibilityHidden(true)
            CompactJargon(term: .testWeek, label: "Test week", font: .caption.weight(.medium))
        }
    }

    private var recoveryKey: some View {
        HStack(spacing: 6) {
            ZStack {
                Rectangle().fill(BL.textSecondary).frame(width: 14, height: 4)
                Rectangle().fill(BL.surface).frame(width: 2.5, height: 4)
            }
            .accessibilityHidden(true)
            CompactJargon(term: .recoveryWeek, label: "Recovery week", font: .caption.weight(.medium))
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

/// A target such as "205 to 220 watts" or "1:52 per 100 m": the numerals at body weight, the trailing unit small,
/// the same numeral-and-small-unit shape the Readouts use. Words such as "easy" stay plain.
struct TargetText: View {
    var raw: String
    var ink: Color

    /// Longest first, so " per 100 m" is matched before " m".
    private static let units = [" per 100 m", " per km", " watts", " min", " km", " m", " s"]

    private var split: (value: String, unit: String)? {
        for u in Self.units where raw.hasSuffix(u) {
            let value = String(raw.dropLast(u.count))
            guard let last = value.last, last.isNumber else { continue }
            return (value, String(u.dropFirst()))
        }
        return nil
    }

    /// Units as VoiceOver should say them.
    private var spoken: String {
        raw.replacingOccurrences(of: " per 100 m", with: " per 100 meters")
            .replacingOccurrences(of: " per km", with: " per kilometer")
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
        .accessibilityLabel(spoken)
    }
}

/// Times with their unit, never a bare "1:45": "15 s", "40 min", "1 min 45 s", "1 h 10 min".
func duration(_ s: TimeInterval) -> String {
    let total = max(0, Int(s.rounded()))
    let h = total / 3600, m = total % 3600 / 60, sec = total % 60
    if h > 0 { return m == 0 ? "\(h) h" : "\(h) h \(m) min" }
    if m == 0 { return "\(sec) s" }
    return sec == 0 ? "\(m) min" : "\(m) min \(sec) s"
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

// MARK: Watch card: what the watch will actually show (Apple Watch only)

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

// MARK: Follow card: how the athlete follows a session when there is no Apple Watch

struct FollowCard: View {
    var tracker: DeviceChoice

    /// One plain paragraph per way of tracking. No watch means no "Send to watch" anywhere; the phone guides the session.
    static func copy(for tracker: DeviceChoice) -> String {
        switch tracker {
        case .whoop:
            return "This app guides the session with voice cues on your phone. Your WHOOP keeps recording on its own. TriSpike reads your sleep and recovery from it through Apple Health, never your workout."
        case .oura:
            return "This app guides the session with voice cues on your phone. Your Oura ring keeps recording on its own."
        case .garmin:
            return "This app guides the session with voice cues on your phone. Start your recording on your Garmin as usual."
        case .otherWatch:
            return "This app guides the session with voice cues on your phone. Start your recording on your own device as usual."
        case .phoneOnly:
            return "Voice cues on your phone. No gear needed."
        case .appleWatch:
            return "Send this session to your watch, or follow it on your phone with voice cues."
        }
    }

    /// A short version for tight places, such as under the Start button.
    static func short(for tracker: DeviceChoice) -> String {
        switch tracker {
        case .whoop: return "Voice cues on your phone guide the session. Your WHOOP keeps recording on its own. Sleep and recovery come in through Apple Health."
        case .oura: return "Voice cues on your phone guide the session. Your Oura ring keeps recording on its own."
        case .garmin, .otherWatch: return "Voice cues on your phone guide the session. Your watch keeps recording on its own."
        case .phoneOnly: return "Voice cues on your phone. No gear needed."
        case .appleWatch: return "Follow it on your phone with voice cues, or send it to your watch."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tracker.symbol).font(.title3).foregroundStyle(BL.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("How you will follow this").font(BLFont.label).foregroundStyle(BL.textSecondary)
                Text(Self.copy(for: tracker)).font(.subheadline).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
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
