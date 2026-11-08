import SwiftUI
import UIKit

struct MethodsView: View {
    @Binding var playerSession: Session?
    @Binding var playerSmoke: Bool
    @ObservedObject private var setup = UserSetup.shared
    @State private var confirmRedo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    Text("Learn and setup")
                        .font(.largeTitle.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                        setupCard
                        glossaryLink
                        section("How your effort ranges are set") {
                            introRow
                            rule
                            swimRow
                            rule
                            bikeRow
                            rule
                            runRow
                        }
                        section("How the plan adapts") {
                            loadRow
                            rule
                            fitnessFormRow
                            rule
                            methodRow("Changes to your plan", "The plan changes by eight written rules. Every change shows a reason line, and you can expand it to read the rule.")
                        }
                        section("How your weeks are laid out") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your plan moves through stages")
                                    .font(.headline).foregroundStyle(BL.textPrimary)
                                Text("Most of the time you train steadily. A lighter week and a short test week are added along the way. Tap a word to read more.")
                                    .font(.subheadline).foregroundStyle(BL.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            ForEach(phaseTerms) { term in
                                rule
                                termRow(term)
                            }
                        }
                        #if DEBUG
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Developer")
                            NavigationLink {
                                LabView(playerSession: $playerSession, playerSmoke: $playerSmoke)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "testtube.2").foregroundStyle(BL.textSecondary).frame(width: 24)
                                    Text("Lab").font(.headline).foregroundStyle(BL.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(BL.textSecondary)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .card()
                            Text("Developer diagnostics. Nothing here affects your plan.")
                                .font(.footnote)
                                .foregroundStyle(BL.textSecondary)
                        }
                        #endif
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

    // MARK: Your setup

    private var phaseTerms: [Term] { [.base, .build, .peak, .taper, .recoveryWeek, .testWeek] }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Your setup")
            VStack(spacing: 0) {
                setupRow(symbol: "flag.checkered", label: "Race", value: raceValue, details: raceDetails)
                rule
                setupRow(symbol: "clock", label: "Training time", value: hoursValue, details: [daysDetail])
                rule
                setupRow(symbol: setup.data.tracker.symbol, label: "How you track", value: setup.data.tracker.title, details: [setup.data.tracker.blurb])
                Button { confirmRedo = true } label: {
                    Label("Redo setup", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 12)
                .accessibilityHint("Clears your answers and starts setup again")
            }
            .card()
        }
        .confirmationDialog("Redo your setup?", isPresented: $confirmRedo, titleVisibility: .visible) {
            Button("Start setup again", role: .destructive) { setup.reset() }
            Button("Keep my setup", role: .cancel) {}
        } message: {
            Text("This clears your answers and walks you through setup again.")
        }
    }

    private func setupRow(symbol: String, label: String, value: String, details: [String]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(BL.textSecondary).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(BL.textSecondary)
                Text(value).font(.headline).foregroundStyle(BL.textPrimary)
                ForEach(details, id: \.self) { line in
                    Text(line).font(.subheadline).foregroundStyle(BL.textSecondary)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var distanceTitle: String {
        let choice = setup.data.raceChoice
        return choice == .half ? choice.title : "\(choice.title) triathlon"
    }

    private var raceValue: String {
        if setup.data.noRaceYet { return "No race picked yet" }
        let name = setup.data.raceName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? distanceTitle : name
    }

    private var raceDetails: [String] {
        if setup.data.noRaceYet { return ["You are training without a race date."] }
        var lines: [String] = []
        if !setup.data.raceName.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(distanceTitle) }
        lines.append(setup.data.raceChoice.summary)
        lines.append(raceDateLine)
        return lines
    }

    private var raceDateLine: String {
        let date = setup.data.raceDate
        let text = date.formatted(.dateTime.day().month(.wide).year())
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days < 0 { return text }
        if days == 0 { return "\(text), race day is today" }
        if days < 14 { return "\(text), \(days) \(days == 1 ? "day" : "days") to go" }
        return "\(text), \(days / 7) weeks to go"
    }

    private var hoursValue: String {
        let h = setup.data.hoursPerWeek
        return "\(h) \(h == 1 ? "hour" : "hours") per week"
    }

    private var daysDetail: String {
        let n = setup.data.trainingDays.count
        return "\(n) training \(n == 1 ? "day" : "days") a week"
    }

    // MARK: Glossary

    private var glossaryLink: some View {
        NavigationLink {
            GlossaryList()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed").foregroundStyle(BL.textSecondary).frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glossary").font(.headline).foregroundStyle(BL.textPrimary)
                    Text("Plain meanings for every training word in the app.")
                        .font(.subheadline).foregroundStyle(BL.textSecondary)
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

    // MARK: Effort ranges

    private var introRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            JargonText(term: .zone, label: "Effort ranges, also called zones", font: .headline)
            Text("Each sport gets an easy range, a steady range and a hard range. They come from one short hard test per sport. Until you test, the app starts you on a guess and labels it as one.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var swimRow: some View {
        sportRow(.swim, "Swim paces") {
            JargonText(term: .css, label: "Set from your CSS, critical swim speed", font: .subheadline.weight(.medium))
            Text("Swim 400 m as fast as you can, rest 5 to 10 minutes, then swim 200 m as fast as you can. Your pace per 100 m is the gap between the two times, divided by\u{00A0}2. For example, 6:40 and 3:10 is a gap of 3:30, so your pace is 1:45 per 100 m.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
    }

    private var bikeRow: some View {
        sportRow(.bike, "Bike effort") {
            JargonText(term: .ftp, label: "Set from your FTP, functional threshold power", font: .subheadline.weight(.medium))
            Text("Ride 20 minutes as hard as you can keep steady. Your FTP is 95 percent of your average power. For example, 215 w for 20 minutes gives an FTP of 204 w. No power meter? Ranges come from your heart rate in a 30 minute hard test instead.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
    }

    private var runRow: some View {
        sportRow(.run, "Run paces") {
            JargonText(term: .threshold, label: "Set from your threshold pace", font: .subheadline.weight(.medium))
            Text("Run 30 minutes as hard as you can keep steady. Your average pace, for example 5:00 per km, is your threshold pace. Your average heart rate over the last 20 minutes sets your heart rate ranges.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
    }

    /// A sport row carries the sport's symbol and color beside its word, like everywhere else in the app.
    private func sportRow<Content: View>(_ sport: Sport, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: sport.symbol()).foregroundStyle(sport.ink).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline).foregroundStyle(BL.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                content()
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Plan adapts

    private var loadRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            JargonText(term: .load, label: "Load", font: .headline)
            Text("One number for how much a session asks of your body. It comes from power when you have a power meter, and from time spent in each heart rate range when you do not. The heart rate version is less precise.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fitnessFormRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BL.Space.xl) {
                    JargonText(term: .fitness, label: "Fitness", font: .headline)
                    JargonText(term: .form, label: "Form", font: .headline)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 0) {
                    JargonText(term: .fitness, label: "Fitness", font: .headline)
                    JargonText(term: .form, label: "Form", font: .headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Fitness is your average daily Load over the last 42 days, counting recent days more. It rises when you train steadily. Form is Fitness minus the same kind of average over just the last 7 days, using yesterday's numbers. Higher Form means you are fresher.")
                .font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Weeks

    private func termRow(_ term: Term) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            JargonText(term: term, font: .headline)
            Text(term.short).font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    /// A label over one card; the rows inside are separated by hairlines.
    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 0) { rows() }
                .card()
        }
    }

    private var rule: some View { Divider().overlay(BL.separator) }

    private func methodRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundStyle(BL.textPrimary)
            Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}


private struct LabGroup: Identifiable {
    var key: String
    var title: String
    var id: String { key }
}

/// The spike harness, styled as a settings style diagnostics screen (spec section 6, Lab).
/// Stock grouped List, mono rows, no Profiles and no sport color. Colors come from the BL tokens,
/// so Increase Contrast raises secondary text and separators with no extra work here.
struct LabView: View {
    @Binding var playerSession: Session?
    @Binding var playerSmoke: Bool
    @EnvironmentObject private var log: SpikeLog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var busy = false
    @State private var expanded: UUID?
    @State private var copied = false

    /// The four groups the spec names. They always show, with "Not run" until a check records a row.
    private let coreGroups: [LabGroup] = [
        LabGroup(key: "capability", title: "WorkoutKit"),
        LabGroup(key: "scheduler", title: "Scheduler"),
        LabGroup(key: "health", title: "HealthKit matching"),
        LabGroup(key: "composition", title: "Codec"),
    ]
    /// Extra logs from the phone player and the app itself. Shown only once they have rows.
    private let extraGroups: [LabGroup] = [
        LabGroup(key: "player", title: "Phone player log"),
        LabGroup(key: "lifecycle", title: "Lifecycle"),
        LabGroup(key: "selftest", title: "Runs"),
    ]

    var body: some View {
        List {
            Section {
                Text("Developer diagnostics. Nothing here affects your plan.")
                    .font(.subheadline)
                    .foregroundStyle(BL.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section {
                perform("Scheduler: week, horizon, count", "applewatch") { await Probes.schedulerFullRun() }
                perform("Health read back and plan link", "heart.text.square") { await Probes.healthReadBack() }
            } header: {
                labHeader("Needs a paired Apple Watch")
            } footer: {
                Text("Keep the phone unlocked and tap Allow. Then open Workout on the watch and check each session.")
            }
            .listRowBackground(BL.surface)
            .listRowSeparatorTint(BL.separator)

            Section {
                Button { playerSmoke = false; playerSession = .playerTest(PhonePlayer.quickTest, name: "Quick test") } label: {
                    Label("Quick test, 6 x 30 s", systemImage: "timer")
                }
                Button { playerSmoke = false; playerSession = .playerTest(PhonePlayer.specTest, name: "Spec test") } label: {
                    Label("Spec test, 30 min, lock the phone", systemImage: "lock")
                }
            } header: {
                labHeader("Phone player")
            } footer: {
                Text("Start, lock the phone, listen for a cue at every step change, check the lock screen countdown.")
            }
            .listRowBackground(BL.surface)
            .listRowSeparatorTint(BL.separator)

            ForEach(coreGroups) { group in
                resultSection(group.key, group.title, alwaysShow: true)
            }
            ForEach(extraGroups) { group in
                resultSection(group.key, group.title, alwaysShow: false)
            }

            Section {
                Button { copyResults() } label: {
                    Label(copied ? "Copied" : "Copy results", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(log.entries.isEmpty)
                .opacity(log.entries.isEmpty ? 0.4 : 1)
                .sensoryFeedback(trigger: copied) { _, isCopied in isCopied ? .success : nil }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                ShareLink(item: log.fileURL) { Label("Share results file", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) { log.clear() } label: { Label("Clear results", systemImage: "trash") }
            }
            .listRowBackground(BL.surface)
            .listRowSeparatorTint(BL.separator)
        }
        .scrollContentBackground(.hidden)
        .background(BL.background.ignoresSafeArea())
        .navigationTitle("Lab")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { runAll() } label: { Label("Run all", systemImage: "arrow.clockwise") }
                    .disabled(busy)
                    .accessibilityHint("Runs the checks that work on any device")
            }
        }
        .disabled(busy)
        .overlay { if busy { ProgressView().controlSize(.large) } }
    }

    // MARK: Actions

    /// Run all: the checks that need no hardware, so they work in the simulator and on any phone.
    private func runAll() {
        run {
            Probes.capabilityMatrix()
            Probes.composition()
            await Probes.schedulerStatus()
        }
    }

    private func run(_ action: @escaping @MainActor () async -> Void) {
        guard !busy else { return }
        busy = true
        Task {
            await action()
            busy = false
        }
    }

    private func perform(_ title: String, _ symbol: String, _ action: @escaping @MainActor () async -> Void) -> some View {
        Button { run(action) } label: { Label(title, systemImage: symbol) }
    }

    private func copyResults() {
        UIPasteboard.general.string = resultsText
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    /// Plain text of every row, one line each, for pasting into a note or a message.
    private var resultsText: String {
        let header = "Lab results, \(Date().formatted(date: .abbreviated, time: .standard)), iOS \(UIDevice.current.systemVersion)"
        let lines = log.entries.map { e -> String in
            let mark = e.pass.map { $0 ? "PASS" : "FAIL" } ?? "INFO"
            return "[\(e.spike)] \(mark) \(e.check): \(e.result)"
        }
        return ([header] + lines).joined(separator: "\n")
    }

    // MARK: Results

    @ViewBuilder
    private func resultSection(_ key: String, _ title: String, alwaysShow: Bool) -> some View {
        let rows = log.entries.filter { $0.spike == key }
        if !rows.isEmpty || alwaysShow {
            Section {
                if rows.isEmpty {
                    Text("Not run")
                        .font(BLFont.labMono)
                        .foregroundStyle(BL.textSecondary)
                        .frame(minHeight: 44, alignment: .leading)
                } else {
                    ForEach(rows) { e in resultRow(e) }
                }
            } header: {
                labHeader(title, trailing: rows.isEmpty ? nil : summary(rows))
            }
            .listRowBackground(BL.surface)
            .listRowSeparatorTint(BL.separator)
        }
    }

    private func labHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing { Text(trailing).monospacedDigit() }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(BL.textSecondary)
        .textCase(nil)
    }

    private func resultRow(_ e: SpikeEntry) -> some View {
        let isOpen = expanded == e.id
        return Button {
            withAnimation(Motion(reduce: reduceMotion).animation(.easeOut(duration: 0.2))) {
                expanded = isOpen ? nil : e.id
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: e.pass == true ? "checkmark.circle.fill" : e.pass == false ? "xmark.circle.fill" : "info.circle")
                    .foregroundStyle(e.pass == true ? BL.success : e.pass == false ? BL.destructive : BL.textSecondary)
                    .accessibilityLabel(e.pass == true ? "pass" : e.pass == false ? "fail" : "info")
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.check).font(BLFont.labMono).foregroundStyle(BL.textPrimary)
                    Text(e.result).font(BLFont.labMono).foregroundStyle(BL.textSecondary)
                        .lineLimit(isOpen ? nil : 2)
                    if isOpen {
                        Text(e.time.formatted(date: .omitted, time: .standard))
                            .font(BLFont.labMono).foregroundStyle(BL.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Shows less" : "Shows the full result")
    }

    private func summary(_ rows: [SpikeEntry]) -> String {
        let pass = rows.filter { $0.pass == true }.count
        let fail = rows.filter { $0.pass == false }.count
        return fail > 0 ? "\(pass) pass, \(fail) fail" : (pass > 0 ? "\(pass) pass" : "\(rows.count) info")
    }
}
