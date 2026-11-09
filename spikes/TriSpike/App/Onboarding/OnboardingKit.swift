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
        switch self { case .superSprint, .sprint: 8...12; case .olympic: 10...16; case .half: 14...24 }
    }
    /// "a Sprint plan", "an Olympic plan".
    var obPlanPhrase: String {
        switch self { case .superSprint: "a super sprint plan"; case .sprint: "a Sprint plan"; case .olympic: "an Olympic plan"; case .half: "a half iron plan" }
    }
    /// "a Sprint race", "an Olympic race".
    var obRacePhrase: String {
        switch self { case .superSprint: "a super sprint race"; case .sprint: "a Sprint race"; case .olympic: "an Olympic race"; case .half: "a half iron (70.3) race" }
    }
    /// Hours a week below which the race gets tight, and above which it is more than most people need.
    var obHoursFloor: Int { switch self { case .superSprint: 3; case .sprint: 3; case .olympic: 5; case .half: 8 } }
    var obHoursCeiling: Int { switch self { case .superSprint: 6; case .sprint: 8; case .olympic: 10; case .half: 14 } }
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
    let isTest: Bool
}

/// The plan preview. Every number comes from the engine through `EngineAdapter.preview`, so the preview, Today and
/// Week agree: the same plan is built from the same answers.
@MainActor
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

    static func model(_ d: SetupData) -> EngineModel { EngineAdapter.shared.preview(for: d) }

    /// Weeks in the plan the engine builds for these answers.
    static func planWeeks(_ d: SetupData) -> Int { model(d).totalWeeks }

    /// Phase lengths in weeks, from the engine's plan.
    static func phaseWeeks(_ d: SetupData) -> [(Phase, Int)] { model(d).phases }

    static func phases(for d: SetupData) -> [OBPhase] {
        let list = phaseWeeks(d)
        if d.noRaceYet {
            return [OBPhase(id: 0, term: .base, name: "Base", weeks: planWeeks(d),
                            blurb: "Mostly easy swimming, riding and running to build a steady habit. When you pick a race, the plan grows from here.",
                            opacity: 0.45)]
        }
        func blurb(_ p: Phase) -> String {
            switch p {
            case .base: d.isGentleStart
                ? "Easy building. Only easy sessions, with no hard efforts yet, so your body gets used to training."
                : "Easy building. Mostly easy training that builds a steady habit."
            case .build: d.isGentleStart
                ? "Your sessions get a little longer. They stay easy or steady, with no hard efforts."
                : "Harder sessions are added. Your weekly time stays steady."
            case .peak: d.isGentleStart
                ? "Your biggest weeks, still easy or steady, to get you ready for race day."
                : "Your biggest weeks, with sessions that feel like race day."
            case .taper: "Lighter weeks, so you arrive fresh."
            }
        }
        func opacity(_ p: Phase) -> Double {
            switch p { case .base: 0.25; case .build: 0.5; case .peak: 0.75; case .taper: 1.0 }
        }
        return list.enumerated().map { i, entry in
            OBPhase(id: i, term: entry.0.glossaryTerm, name: entry.0.displayName, weeks: entry.1, blurb: blurb(entry.0), opacity: opacity(entry.0))
        }
    }

    /// Sessions in an average full week of the engine's plan.
    static func sessionsPerWeek(_ d: SetupData) -> Int { model(d).sessionsPerWeek }

    /// The sessions of the first week with at least three sessions, as the engine placed them.
    static func firstWeek(_ d: SetupData) -> [OBFirstWeekItem] {
        let m = model(d)
        let cal = m.calendar
        return m.firstWeekSessions.enumerated().map { i, s in
            let day = s.scheduledDate.map { cal.component(.weekday, from: $0) } ?? 2
            return OBFirstWeekItem(id: i, day: day, sport: s.sport, name: s.name, minutes: s.minutes, isTest: s.isTest)
        }
    }
}
