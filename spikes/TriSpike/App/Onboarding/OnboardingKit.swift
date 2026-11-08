import SwiftUI
import UIKit

// Shared pieces for the onboarding steps: page scaffold, choice card, day chips, toggle row,
// and the local plan preview math. Nothing here touches the network or the real plan engine.

// MARK: Page scaffold

/// One onboarding screen: a large clear headline, one plain sentence on why we ask, then the content.
struct OBPage<Content: View>: View {
    private let title: String
    private let why: String
    private let content: Content

    init(title: String, why: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.why = why
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BL.Space.xl) {
            VStack(alignment: .leading, spacing: BL.Space.s) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(why)
                    .font(.body)
                    .foregroundStyle(BL.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, BL.Space.l)
    }
}

/// Small caps section label.
struct OBSectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(BLFont.label)
            .foregroundStyle(BL.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: Choice card

/// A selectable card. Selection is shown by a filled check mark and a heavier edge, never by color alone.
struct OBChoiceCard<Content: View>: View {
    private let selected: Bool
    private let action: () -> Void
    private let content: Content

    init(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.selected = selected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: BL.Space.m) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? BL.accent : BL.textSecondary)
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityHidden(true)
            }
            .card()
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous)
                        .strokeBorder(BL.accent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: BL.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: Toggle row

/// A toggle with a title and one plain line under it.
struct OBToggleRow: View {
    var title: String
    var detail: String
    var symbol: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: BL.Space.m) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(BL.textPrimary)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(BL.textPrimary)
                    Text(detail).font(.subheadline).foregroundStyle(BL.textSecondary)
                }
            }
        }
        .tint(BL.accent)
        .frame(minHeight: 44)
    }
}

// MARK: Weekdays

enum OBDays {
    /// Monday first. Values are Calendar weekday numbers, 1 = Sunday.
    static let order = [2, 3, 4, 5, 6, 7, 1]
    static func short(_ day: Int) -> String {
        switch day { case 2: "Mon"; case 3: "Tue"; case 4: "Wed"; case 5: "Thu"; case 6: "Fri"; case 7: "Sat"; default: "Sun" }
    }
    static func full(_ day: Int) -> String {
        switch day { case 2: "Monday"; case 3: "Tuesday"; case 4: "Wednesday"; case 5: "Thursday"; case 6: "Friday"; case 7: "Saturday"; default: "Sunday" }
    }
}

/// Seven weekday chips, Monday first. 44 pt targets. Wraps to a grid at large text sizes.
struct OBDayChips: View {
    var selected: Set<Int>
    /// Days that can be toggled. Others are dimmed and inert.
    var enabled: Set<Int> = Set(OBDays.order)
    var onTap: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(OBDays.order, id: \.self) { chip($0) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                ForEach(OBDays.order, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ day: Int) -> some View {
        let on = selected.contains(day)
        let can = enabled.contains(day)
        return Button { onTap(day) } label: {
            Text(OBDays.short(day))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(on ? BL.onAccent : BL.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? BL.accent : BL.surface, in: RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BL.Radius.chip, style: .continuous)
                        .strokeBorder(BL.separator, lineWidth: on ? 0 : 1)
                )
                .opacity(can ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!can)
        .accessibilityLabel(OBDays.full(day))
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

// MARK: Race helpers

extension RaceChoice {
    /// Weeks of lead time that suit this race. Matches `typicalWeeks`.
    var obWeeksRange: ClosedRange<Int> {
        switch self { case .sprint: 8...12; case .olympic: 10...16; case .half: 14...24 }
    }
    /// "a Sprint plan", "an Olympic plan".
    var obPlanPhrase: String {
        switch self { case .sprint: "a Sprint plan"; case .olympic: "an Olympic plan"; case .half: "a half iron plan" }
    }
    /// "a Sprint race", "an Olympic race".
    var obRacePhrase: String {
        switch self { case .sprint: "a Sprint race"; case .olympic: "an Olympic race"; case .half: "a half iron (70.3) race" }
    }
    /// Hours a week below which the race gets tight, and above which it is more than most people need.
    var obHoursFloor: Int { switch self { case .sprint: 3; case .olympic: 5; case .half: 8 } }
    var obHoursCeiling: Int { switch self { case .sprint: 8; case .olympic: 10; case .half: 14 } }
}

// MARK: Number formatting and parsing

enum OBFormat {
    /// 105 -> "1:45"
    static func mmss(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// "1:45" -> 105. Returns nil for anything that is not minutes:seconds inside the range.
    static func parseMMSS(_ text: String, range: ClosedRange<Double>) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), m >= 0, (0..<60).contains(s) else { return nil }
        let total = Double(m * 60 + s)
        return range.contains(total) ? total : nil
    }

    static func parseWatts(_ text: String) -> Int? {
        guard let w = Int(text.trimmingCharacters(in: .whitespaces)), (50...600).contains(w) else { return nil }
        return w
    }

    /// 275 -> "4 h 35 min", 40 -> "40 min"
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }

    static func plural(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "\(n) \(one)" : "\(n) \(many)" }
}

// MARK: Plan preview, computed locally from the setup

struct OBPhase: Identifiable {
    let id: Int
    let term: Term
    let name: String
    let weeks: Int
    let blurb: String
    let opacity: Double
}

struct OBFirstWeekItem: Identifiable {
    let id: Int
    let day: Int
    let sport: Sport
    let name: String
    let minutes: Int
}

enum OBPlan {
    static var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        let far = cal.date(byAdding: .year, value: 3, to: tomorrow) ?? tomorrow
        return tomorrow...far
    }

    /// Whole weeks from today to the date, rounded down.
    static func weeksUntil(_ date: Date, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        return max(0, days / 7)
    }

    static let noRaceWeeks = 12

    /// Weeks shown in the preview: weeks to race clamped to 8 to 24, or a 12 week block with no race.
    static func planWeeks(_ d: SetupData) -> Int {
        d.noRaceYet ? noRaceWeeks : min(max(weeksUntil(d.raceDate), 8), 24)
    }

    /// Phase lengths in weeks. Roughly 45 percent base, 30 build, 15 peak, 10 taper. Taper is at least 1 week and peak at least 1.
    /// With no race there is one base phase. The demo plan reads the same numbers, so every screen agrees.
    static func phaseWeeks(total w: Int, noRace: Bool) -> [(Phase, Int)] {
        if noRace { return [(.base, w)] }
        let taper = max(1, Int((Double(w) * 0.10).rounded()))
        let base = Int((Double(w) * 0.45).rounded())
        let build = Int((Double(w) * 0.30).rounded())
        let peak = max(1, w - base - build - taper)
        return [(.base, base), (.build, build), (.peak, peak), (.taper, taper)]
    }

    static func phases(for d: SetupData) -> [OBPhase] {
        let w = planWeeks(d)
        let lengths = phaseWeeks(total: w, noRace: d.noRaceYet)
        if d.noRaceYet {
            return [OBPhase(id: 0, term: .base, name: "Base", weeks: w,
                            blurb: "Mostly easy swimming, riding and running to build a steady habit. When you pick a race, the plan grows from here.",
                            opacity: 0.45)]
        }
        let weeks = Dictionary(uniqueKeysWithValues: lengths.map { ($0.0, $0.1) })
        return [
            OBPhase(id: 0, term: .base, name: "Base", weeks: weeks[.base] ?? 0,
                    blurb: "Easy building. Mostly easy training that builds a steady habit.", opacity: 0.25),
            OBPhase(id: 1, term: .build, name: "Build", weeks: weeks[.build] ?? 0,
                    blurb: "Harder sessions are added. Your weekly time stays steady.", opacity: 0.5),
            OBPhase(id: 2, term: .peak, name: "Peak", weeks: weeks[.peak] ?? 0,
                    blurb: "Your biggest weeks, with sessions that feel like race day.", opacity: 0.75),
            OBPhase(id: 3, term: .taper, name: "Taper", weeks: weeks[.taper] ?? 0,
                    blurb: "Lighter weeks, so you arrive fresh.", opacity: 1.0)
        ]
    }

    /// Average session is about 65 minutes. Never fewer than 3, never more than the days plus 2, at most 12.
    static func sessionsPerWeek(hours: Int, days: Int) -> Int {
        let estimate = Int((Double(hours) * 60 / 65).rounded())
        return min(12, min(max(estimate, 3), max(3, days + 2)))
    }

    /// A short list of plain named sessions for week one. All easy, about 80 percent of the weekly hours.
    static func firstWeek(_ d: SetupData) -> [OBFirstWeekItem] {
        let days = OBDays.order.filter { d.trainingDays.contains($0) }
        guard !days.isEmpty else { return [] }
        let count = sessionsPerWeek(hours: d.hoursPerWeek, days: days.count)

        // Sport order for the week. Swims are limited to the pool days you can reach.
        let cycle: [Sport] = [.swim, .bike, .run, .swim, .bike, .run, .bike, .run, .swim, .bike, .run, .bike]
        let poolDays = days.filter { d.poolDays.contains($0) }
        let swimCap = poolDays.isEmpty ? 1 : poolDays.count
        var sports: [Sport] = []
        var swims = 0
        var swapToBike = true
        for s in cycle.prefix(count) {
            if s == .swim {
                if swims < swimCap { swims += 1; sports.append(.swim) }
                else { sports.append(swapToBike ? .bike : .run); swapToBike.toggle() }
            } else {
                sports.append(s)
            }
        }
        let longRide: Int? = count >= 4 ? sports.lastIndex(of: .bike) : nil

        // Minutes: weights per session scaled to 80 percent of the weekly hours.
        func weight(_ i: Int) -> Double {
            if i == longRide { return 1.8 }
            switch sports[i] { case .swim: return 0.8; case .bike: return 1.1; case .run: return 0.9 }
        }
        let weights = (0..<count).map(weight)
        let totalWeight = weights.reduce(0, +)
        let weekMinutes = Double(d.hoursPerWeek) * 60 * 0.8
        let minutes: [Int] = weights.map { w in
            let raw = w / totalWeight * weekMinutes
            return max(20, Int((raw / 5).rounded()) * 5)
        }

        // Days: the long ride on a weekend day, swims on pool days, the rest spread out.
        var counts: [Int: Int] = [:]
        func pick(from candidates: [Int]) -> Int {
            if let free = candidates.first(where: { counts[$0, default: 0] == 0 }) { return free }
            if let free = days.first(where: { counts[$0, default: 0] == 0 }) { return free }
            return days.min(by: { counts[$0, default: 0] < counts[$1, default: 0] }) ?? days[0]
        }
        func rank(_ i: Int) -> Int { i == longRide ? 0 : (sports[i] == .swim ? 1 : 2) }
        var assigned = [Int](repeating: days[0], count: count)
        for i in (0..<count).sorted(by: { (rank($0), $0) < (rank($1), $1) }) {
            let candidates: [Int]
            if i == longRide { candidates = [7, 1].filter { days.contains($0) } }
            else if sports[i] == .swim { candidates = poolDays }
            else { candidates = days }
            let day = pick(from: candidates)
            assigned[i] = day
            counts[day, default: 0] += 1
        }

        // Names, in plain words.
        var seen: [Sport: Int] = [:]
        var items: [OBFirstWeekItem] = []
        for i in 0..<count {
            let sport = sports[i]
            let nth = seen[sport, default: 0]
            seen[sport] = nth + 1
            let name: String
            switch sport {
            case .swim: name = nth == 0 ? "Easy swim with technique drills" : "Easy swim, steady laps"
            case .bike: name = i == longRide ? "Long easy ride" : (nth == 0 ? "Easy ride" : "Comfortable ride")
            case .run: name = d.experience == .firstTimer ? "Easy run and walk" : "Easy run"
            }
            items.append(OBFirstWeekItem(id: i, day: assigned[i], sport: sport, name: name, minutes: minutes[i]))
        }
        return items.sorted {
            let a = OBDays.order.firstIndex(of: $0.day) ?? 0, b = OBDays.order.firstIndex(of: $1.day) ?? 0
            return a == b ? $0.id < $1.id : a < b
        }
    }
}
