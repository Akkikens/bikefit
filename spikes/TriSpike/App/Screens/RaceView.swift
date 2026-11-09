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
    /// Only people who chose Apple Watch can send the race to a watch.
    @ObservedObject private var setup = UserSetup.shared

    // Transition estimates in seconds. The three legs plus these make the predicted finish.
    private static let t1: TimeInterval = 120
    private static let t2: TimeInterval = 60

    /// Race morning mode starts on race day. `-raceMorning` previews it for screenshots and testing.
    private static let previewRaceMorning = ProcessInfo.processInfo.arguments.contains("-raceMorning")
    private var isRaceMorning: Bool { (Demo.hasRace && Demo.daysToRace <= 0) || Self.previewRaceMorning }

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
                            shareSection
                        } else if !Demo.hasRace {
                            noRaceCard
                            courseCard
                            guideLink
                            fueling
                            shareSection
                        } else {
                            countdown
                            courseCard
                            guideLink
                            timeline
                            ForEach(Demo.checklists) { list in checklistCard(list) }
                            fueling
                            shareSection
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

    private func legSeconds(_ sport: Sport) -> TimeInterval {
        Demo.raceLegs.first { $0.sport == sport }?.seconds ?? 0
    }

    /// The legs with T1 and T2 between them as narrow hollow notches (recovery steps in the next leg's sport).
    private var profileSteps: [PlanStep] {
        let legs = Demo.raceLegs
        guard legs.count == 3 else { return legs }
        return [
            legs[0],
            PlanStep(sport: legs[1].sport, kind: .recovery, name: "Swim to bike transition", seconds: Self.t1, level: 1, target: nil),
            legs[1],
            PlanStep(sport: legs[2].sport, kind: .recovery, name: "Bike to run transition", seconds: Self.t2, level: 1, target: nil),
            legs[2],
        ]
    }

    // MARK: Guide and share

    /// The plain race day explainer and the beginner gear list.
    private var guideLink: some View {
        NavigationLink {
            RaceGuideView(race: setup.data.raceChoice)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.bubble").foregroundStyle(BL.textSecondary).frame(width: glyphWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("What to expect on race day").font(.headline).foregroundStyle(BL.textPrimary)
                    Text("The start, the changing areas, what to eat and wear, and what to bring.")
                        .font(.subheadline).foregroundStyle(BL.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(BL.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }

    /// A clean picture of the race to share. Made on the phone.
    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Share")
            ShareCardButton(data: ShareCards.race(
                name: Demo.raceName, race: setup.data.raceChoice, hasRace: Demo.hasRace, daysToRace: Demo.daysToRace,
                raceDate: raceDate, estimatedFinish: predicted, weekLabel: Demo.weekLabel), title: "Share race card")
        }
    }

    // MARK: No race yet

    private var noRaceCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.s) {
            Label("No race date yet", systemImage: "calendar.badge.plus")
                .font(.headline)
                .foregroundStyle(BL.textPrimary)
            Text("Your plan is \(Demo.totalWeeks) weeks of mostly easy training, and a new block starts when it ends. When you sign up for a race, choose Redo setup under Learn and setup to add the date. Below is what race day looks like for the distance you picked.")
                .font(.subheadline)
                .foregroundStyle(BL.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
                Text("\(daysWord) to go").font(BLFont.label).foregroundStyle(BL.textSecondary)
            }
            Text(raceDateText).font(BLFont.meta).foregroundStyle(BL.textSecondary)
            Text("Race starts \(Demo.raceStartLabel). Wake up at \(Demo.raceWakeLabel).").font(BLFont.meta).foregroundStyle(BL.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Demo.daysToRace) \(daysWord) to go. \(raceDateText). Race starts \(Demo.raceStartLabel). Wake up at \(Demo.raceWakeLabel).")
    }

    // MARK: Race day

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: BL.Space.l) {
            SectionLabel(text: "Race day", trailing: "finish about " + duration(predicted))
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
                            CompactJargon(term: .transition, label: i == 0 ? "Transition to bike" : "Transition to run", textHeight: 20)
                                .fixedSize()
                            Rectangle().fill(BL.separator).frame(height: 0.5).accessibilityHidden(true)
                            Text("about \(duration(seconds))")
                                .font(BLFont.label.monospacedDigit())
                                .foregroundStyle(BL.textSecondary)
                        }
                        .padding(.vertical, 6)
                        .frame(minHeight: 32)
                        .accessibilityElement(children: .contain)
                    }
                }
            }
            Text(Demo.raceModel.caveat)
                .font(.subheadline).foregroundStyle(BL.textSecondary)
            if !Demo.raceModel.typicalLegs.isEmpty {
                Text("Times for \(typicalWords) are typical for your level, not a prediction. A test turns them into your own.")
                    .font(.subheadline).foregroundStyle(BL.textSecondary)
            }
        }
        .card()
    }

    private var typicalWords: String {
        let names = [Sport.swim, .bike, .run].filter { Demo.raceModel.typicalLegs.contains($0) }.map { $0.word.lowercased() }
        switch names.count {
        case 0: return ""
        case 1: return "the " + names[0]
        case 2: return "the " + names.joined(separator: " and ")
        default: return "the swim, bike and run"
        }
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
                        Text(item.when).font(BLFont.label).foregroundStyle(BL.textSecondary)
                        Text(item.text).font(.body).foregroundStyle(BL.textPrimary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.when), \(item.text)\(item.done ? ", done" : "")")
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
                let rows = Demo.raceModel.fueling
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    fuelRow(row.sport, "\(row.sport.word), \(duration(row.seconds))", row.text)
                    if i < rows.count - 1 { Divider().overlay(BL.separator) }
                }
                Text(Demo.raceModel.stomachLine)
                    .font(.footnote).foregroundStyle(BL.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    Text("\(duration(TimeInterval(minutes * 60))) until the start").font(BLFont.meta).foregroundStyle(BL.textPrimary)
                }
                Text("Race starts \(Demo.raceStartLabel). Wake up at \(Demo.raceWakeLabel).").font(BLFont.meta).foregroundStyle(BL.textSecondary)
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
        let items = Demo.timeline.filter { $0.daysBefore == nil }
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
        if setup.canSendToWatch {
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
        } else {
            raceTrackingNote
        }
    }

    /// No watch to send to: say plainly how race day works with the way the athlete records.
    private var raceTrackingNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: setup.followDevice.symbol).font(.title3).foregroundStyle(BL.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Recording the race").font(BLFont.label).foregroundStyle(BL.textSecondary)
                Text(raceTrackingCopy).font(.subheadline).foregroundStyle(BL.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .cardSurface(radius: 18)
        .accessibilityElement(children: .combine)
    }

    private var raceTrackingCopy: String {
        switch setup.followDevice {
        case .whoop, .oura: "Your band records your heart rate. You will not carry your phone in the race, so learn your targets before the start."
        case .garmin, .otherWatch: "Your watch records the race. You will not carry your phone in the race, so learn your targets before the start."
        default: "You will not carry your phone in the race, so learn your targets before the start."
        }
    }
}
