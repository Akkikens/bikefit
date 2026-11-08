import SwiftUI

struct MethodsView: View {
    @Binding var playerSession: Session?
    @Binding var playerSmoke: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    methodRow("Swim zones", "From CSS, your critical swim speed: an all out 400 m and 200 m. Pace per 100 m is the time difference divided by 2.")
                    methodRow("Bike zones", "From FTP, 95 percent of your best 20 minute power, or from a 30 minute heart rate test.")
                    methodRow("Run zones", "From a 30 minute time trial: threshold pace and the average heart rate of the last 20 minutes.")
                } header: { Text("How zones are set") }
                Section {
                    methodRow("Load", "Power based when you have it, heart rate zone time when you do not. Heart rate Load is less precise.")
                    methodRow("Fitness and Form", "Fitness is a 42 day average of Load. Form is Fitness minus the last 7 days.")
                    methodRow("Adaptation", "Eight written rules. Every change shows a reason line. Nothing is a black box.")
                } header: { Text("How the plan adapts") }
                Section {
                    NavigationLink {
                        LabView(playerSession: $playerSession, playerSmoke: $playerSmoke)
                    } label: {
                        Label("Lab", systemImage: "testtube.2")
                    }
                } header: { Text("Developer") } footer: {
                    Text("Diagnostics for the week 1 gate. Nothing here affects your plan.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(BL.background.ignoresSafeArea())
            .navigationTitle("Methods")
        }
    }

    private func methodRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.medium))
            Text(text).font(.subheadline).foregroundStyle(BL.textSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// The spike harness, styled as a settings style diagnostics screen (spec section 6, Lab).
struct LabView: View {
    @Binding var playerSession: Session?
    @Binding var playerSmoke: Bool
    @EnvironmentObject private var log: SpikeLog
    @State private var busy = false
    @State private var expanded: UUID?

    private let order = ["capability", "composition", "scheduler", "health", "player", "lifecycle", "selftest"]
    private let titles = ["capability": "WorkoutKit capability", "composition": "Codec round trips", "scheduler": "Scheduler",
                          "health": "HealthKit matching", "player": "Phone player", "lifecycle": "Lifecycle", "selftest": "Runs"]

    var body: some View {
        List {
            Section {
                labAction("Run simulator safe checks", "arrow.clockwise") {
                    Probes.capabilityMatrix()
                    Probes.composition()
                    await Probes.schedulerStatus()
                }
            } header: { Text("Anywhere") }

            Section {
                labAction("Scheduler: week, horizon, count", "applewatch") { await Probes.schedulerFullRun() }
                labAction("Health read back and plan link", "heart.text.square") { await Probes.healthReadBack() }
            } header: { Text("Needs a paired Apple Watch") } footer: {
                Text("Keep the phone unlocked and tap Allow. Then open Workout on the watch and check each session.")
            }

            Section {
                Button { playerSmoke = false; playerSession = .playerTest(PhonePlayer.quickTest, name: "Quick test") } label: {
                    Label("Quick test, 6 x 30 s", systemImage: "timer")
                }
                Button { playerSmoke = false; playerSession = .playerTest(PhonePlayer.specTest, name: "Spec test") } label: {
                    Label("Spec test, 30 min, lock the phone", systemImage: "lock")
                }
            } header: { Text("Phone player") } footer: {
                Text("Start, lock the phone, listen for a cue at every step change, check the lock screen countdown.")
            }

            ForEach(order.filter { k in log.entries.contains { $0.spike == k } }, id: \.self) { key in
                let rows = log.entries.filter { $0.spike == key }
                Section {
                    ForEach(rows) { e in resultRow(e) }
                } header: {
                    HStack {
                        Text(titles[key] ?? key)
                        Spacer()
                        Text(summary(rows)).monospacedDigit()
                    }
                }
            }

            Section {
                ShareLink(item: log.fileURL) { Label("Share results file", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) { log.clear() } label: { Label("Clear results", systemImage: "trash") }
            }
        }
        .navigationTitle("Lab")
        .disabled(busy)
        .overlay { if busy { ProgressView().controlSize(.large) } }
    }

    private func labAction(_ title: String, _ symbol: String, _ action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            busy = true
            Task { await action(); busy = false }
        } label: { Label(title, systemImage: symbol) }
    }

    private func resultRow(_ e: SpikeEntry) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { expanded = expanded == e.id ? nil : e.id }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: e.pass == true ? "checkmark.circle.fill" : e.pass == false ? "xmark.circle.fill" : "info.circle")
                    .foregroundStyle(e.pass == true ? BL.success : e.pass == false ? BL.destructive : BL.textSecondary)
                    .accessibilityLabel(e.pass == true ? "pass" : e.pass == false ? "fail" : "info")
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.check).font(BLFont.labMono).foregroundStyle(BL.textPrimary)
                    Text(e.result).font(BLFont.labMono).foregroundStyle(BL.textSecondary)
                        .lineLimit(expanded == e.id ? nil : 2)
                }
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func summary(_ rows: [SpikeEntry]) -> String {
        let pass = rows.filter { $0.pass == true }.count
        let fail = rows.filter { $0.pass == false }.count
        return fail > 0 ? "\(pass) pass, \(fail) fail" : (pass > 0 ? "\(pass) pass" : "\(rows.count) info")
    }
}
