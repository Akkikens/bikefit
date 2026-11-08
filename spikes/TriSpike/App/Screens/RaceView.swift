import SwiftUI

struct RaceView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var hero: CGFloat = 112
    @ScaledMetric(relativeTo: .body) private var profileHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var glyphWidth: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Checklist ticks survive relaunch. One record per ticked item, keyed by list title and item text
    /// (not index) so editing or reordering a list never moves a tick onto a different item.
    @AppStorage("race.checked") private var checkedRaw = ""
    @State private var sentToWatch = false

    // Transition estimates in seconds. The three legs plus these make the predicted finish.
    private static let t1: TimeInterval = 120
    private static let t2: TimeInterval = 60

    /// Race morning mode starts on race day. `-raceMorning` previews it for screenshots and testing.
    private static let previewRaceMorning = ProcessInfo.processInfo.arguments.contains("-raceMorning")
    private var isRaceMorning: Bool { Demo.daysToRace <= 0 || Self.previewRaceMorning }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    Text(Demo.raceName)
                        .font(.largeTitle.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                        if isRaceMorning {
                            morningClock
                            morningTimeline
                            if let list = Demo.checklists.first(where: { $0.title == "Race morning" }) {
                                checklistCard(list)
                            }
                            morningSentence
                            morningAction
                        } else {
                            countdown
                            courseCard
                            timeline
                            ForEach(Demo.checklists) { list in checklistCard(list) }
                            fueling
                        }
                    }
                }
                .padding(.horizontal, BL.Space.gutter)
                .padding(.top, BL.Space.s)
                .padding(.bottom, BL.Space.l)
            }
            .background(BL.background.ignoresSafeArea())
            .bottomEdgeSolid()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Numbers computed from the plan

    private var predicted: TimeInterval {
        Demo.raceLegs.reduce(0) { $0 + $1.seconds } + Self.t1 + Self.t2
    }

    private var raceDate: Date {
        Demo.calendar.date(byAdding: .day, value: Demo.daysToRace, to: Demo.today) ?? Demo.today
    }

    private var raceDateText: String {
        raceDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var daysWord: String { Demo.daysToRace == 1 ? "day" : "days" }

    private func hm(_ s: TimeInterval) -> String {
        let m = Int(s.rounded()) / 60
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    private func legSeconds(_ sport: Sport) -> TimeInterval {
        Demo.raceLegs.first { $0.sport == sport }?.seconds ?? 0
    }

    /// The legs with T1 and T2 between them as narrow hollow notches (recovery steps in the next leg's sport).
    private var profileSteps: [PlanStep] {
        let legs = Demo.raceLegs
        guard legs.count == 3 else { return legs }
        return [
            legs[0],
            PlanStep(sport: legs[1].sport, kind: .recovery, name: "T1", seconds: Self.t1, level: 1, target: nil),
            legs[1],
            PlanStep(sport: legs[2].sport, kind: .recovery, name: "T2", seconds: Self.t2, level: 1, target: nil),
            legs[2],
        ]
    }

    // MARK: Countdown

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Demo.daysToRace)")
                    .font(BLFont.hero(min(160, max(72, hero))))
                    .kerning(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(BL.textPrimary)
                Text(daysWord).font(BLFont.label).foregroundStyle(BL.textSecondary)
            }
            Text(raceDateText).font(BLFont.meta).foregroundStyle(BL.textSecondary)
            Text("Start \(Demo.raceStart), wake \(Demo.raceWake)").font(BLFont.meta).foregroundStyle(BL.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Demo.daysToRace) \(daysWord) to race. \(raceDateText). Start \(Demo.raceStart), wake \(Demo.raceWake).")
    }

    // MARK: Race day

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.l) {
            SectionLabel(text: "Race day", trailing: "predicted " + hm(predicted))
            ProfileView(steps: profileSteps, mode: .structure, height: profileHeight, ruler: true)
            VStack(spacing: 0) {
                ForEach(Array(Demo.raceLegs.enumerated()), id: \.offset) { i, leg in
                    HStack(spacing: 12) {
                        Image(systemName: leg.sport.symbol(openWater: leg.sport == .swim))
                            .foregroundStyle(leg.sport.ink)
                            .frame(width: glyphWidth)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(leg.name).font(.body)
                            Text(duration(leg.seconds)).font(.subheadline).foregroundStyle(BL.textSecondary)
                        }
                        Spacer(minLength: 8)
                        if let t = leg.target {
                            TargetText(raw: t, ink: leg.sport.ink)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(legLabel(leg))
                    if i < Demo.raceLegs.count - 1 {
                        let seconds = i == 0 ? Self.t1 : Self.t2
                        HStack(spacing: 8) {
                            Text(i == 0 ? "t1" : "t2").font(BLFont.label).foregroundStyle(BL.textSecondary)
                            Rectangle().fill(BL.separator).frame(height: 0.5)
                            Text(duration(seconds))
                                .font(BLFont.label.monospacedDigit())
                                .foregroundStyle(BL.textSecondary)
                        }
                        .frame(minHeight: 24)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Transition \(i == 0 ? "one" : "two"), about \(duration(seconds))")
                    }
                }
            }
            Text("Targets are ranges. On a hilly or windy course they can be off by several percent, so go by feel\u{00A0}first.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .card()
    }

    private func legLabel(_ leg: PlanStep) -> String {
        var parts = [leg.sport.word, leg.name, duration(leg.seconds)]
        if let t = leg.target { parts.append("target " + t) }
        return parts.joined(separator: ", ")
    }

    // MARK: Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Timeline")
            timelineRows(Demo.timeline).card()
        }
    }

    private func timelineRows(_ items: [Demo.TimelineItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: item.done ? "checkmark.circle.fill" : item.symbol)
                        .frame(width: glyphWidth)
                        .foregroundStyle(item.done ? BL.accent : BL.textPrimary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.tMinus.lowercased()).font(BLFont.label).foregroundStyle(BL.textSecondary)
                        Text(item.text).font(.body).foregroundStyle(BL.textPrimary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.tMinus), \(item.text)\(item.done ? ", done" : "")")
                if i < items.count - 1 { Divider().overlay(BL.separator) }
            }
        }
    }

    // MARK: Checklists

    private var checkedKeys: Set<String> {
        Set(checkedRaw.split(separator: "\n").map(String.init))
    }

    private func key(_ list: Demo.Checklist, _ item: String) -> String {
        list.title + "\u{1F}" + item
    }

    private func isChecked(_ list: Demo.Checklist, _ item: String) -> Bool {
        checkedKeys.contains(key(list, item))
    }

    private func setChecked(_ list: Demo.Checklist, _ item: String, _ on: Bool) {
        var keys = checkedKeys
        let k = key(list, item)
        if on { keys.insert(k) } else { keys.remove(k) }
        checkedRaw = keys.sorted().joined(separator: "\n")
    }

    private func checklistCard(_ list: Demo.Checklist) -> some View {
        let keys = checkedKeys
        let done = list.items.filter { keys.contains(key(list, $0)) }.count
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: list.title, trailing: "\(done) of \(list.items.count)")
            VStack(spacing: 0) {
                ForEach(Array(list.items.enumerated()), id: \.offset) { i, item in
                    ChecklistRow(text: item, done: Binding(
                        get: { isChecked(list, item) },
                        set: { on in setChecked(list, item, on) }))
                    if i < list.items.count - 1 { Divider().overlay(BL.separator).padding(.leading, 34) }
                }
            }
            .card()
        }
    }

    // MARK: Fueling

    private var fueling: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Fueling")
            VStack(alignment: .leading, spacing: BL.Space.m) {
                fuelRow(.swim, "Swim, \(duration(legSeconds(.swim)))", "Nothing needed. Breakfast carries you.")
                Divider().overlay(BL.separator)
                fuelRow(.bike, "Bike, \(duration(legSeconds(.bike)))", "About 30 to 45 g carbohydrate per hour. Practice it in training.")
                Divider().overlay(BL.separator)
                fuelRow(.run, "Run, \(duration(legSeconds(.run)))", "Fluids to thirst. A gel at the start is optional.")
            }
            .card()
        }
    }

    private func fuelRow(_ sport: Sport, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: sport.symbol()).foregroundStyle(sport.ink).frame(width: glyphWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Race morning

    /// The clock, the time left to the start, and the one line of logistics.
    private var morningClock: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.date, format: Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(BLFont.hero(min(160, max(72, hero))))
                    .kerning(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(BL.textPrimary)
                    .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
                if let minutes = minutesUntilStart(from: context.date) {
                    Text("\(duration(TimeInterval(minutes * 60))) to start").font(BLFont.meta).foregroundStyle(BL.textPrimary)
                }
                Text("Start \(Demo.raceStart), wake \(Demo.raceWake)").font(BLFont.meta).foregroundStyle(BL.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Whole minutes until the start gun today, or nil once it has passed or the start time cannot be read.
    private func minutesUntilStart(from now: Date) -> Int? {
        let parts = Demo.raceStart.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let start = Demo.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) else { return nil }
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes > 0 ? minutes : nil
    }

    private var morningTimeline: some View {
        let items = Demo.timeline.filter { !$0.tMinus.hasPrefix("T minus") }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Timeline")
            timelineRows(items.isEmpty ? Demo.timeline : items).card()
        }
    }

    private var morningSentence: some View {
        Text("Your targets are ranges. Start easy and let the effort build.")
            .font(.body)
            .foregroundStyle(BL.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var morningAction: some View {
        VStack(spacing: BL.Space.m) {
            if sentToWatch {
                Label("On your watch", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BL.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.2))) { sentToWatch = true }
                } label: {
                    Label("Send race to watch", systemImage: "applewatch")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .sensoryFeedback(.success, trigger: sentToWatch)
    }
}
