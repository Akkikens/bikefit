import SwiftUI
import UIKit

struct MethodsView: View {
    @Binding var playerSession: Session?
    @Binding var playerSmoke: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BL.Space.m) {
                    Text("Methods")
                        .font(.largeTitle.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: BL.Space.sectionGap) {
                        section("How zones are set") {
                            zoneRow(.swim, "Swim zones", "From CSS, your critical swim speed. Swim an all out 400 m and 200 m. Your pace per 100 m is the difference between the two times divided by\u{00A0}2.")
                            rule
                            zoneRow(.bike, "Bike zones", "From FTP, 95 percent of your best 20 minute power. Without a power meter, zones come from heart rate in a 30 minute all out test.")
                            rule
                            zoneRow(.run, "Run zones", "From a 30 minute time trial: threshold pace, and the average heart rate of the last 20 minutes.")
                        }
                        section("How the plan adapts") {
                            methodRow("Load", "Power based when you have it, heart rate zone time when you do not. Heart rate Load is less precise.")
                            rule
                            methodRow("Fitness and Form", "Fitness is a 42 day average of your daily Load, weighted toward recent days. Form is Fitness minus the same kind of average over just the last 7 days, using yesterday's numbers.")
                            rule
                            methodRow("Adaptation", "The plan changes by eight written rules. Every change shows a reason line, and you can expand it to read the rule.")
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

    /// A label over one card; the rows inside are separated by hairlines.
    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 0) { rows() }
                .card()
        }
    }

    private var rule: some View { Divider().overlay(BL.separator) }

    /// Zone rows carry the sport's symbol and color beside its word, like everywhere else in the app.
    private func zoneRow(_ sport: Sport, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: sport.symbol()).foregroundStyle(sport.ink).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(BL.textPrimary)
                Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

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
