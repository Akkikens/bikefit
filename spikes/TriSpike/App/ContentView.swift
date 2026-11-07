import SwiftUI
import WorkoutKit

struct ContentView: View {
    @EnvironmentObject private var player: PhonePlayer
    @EnvironmentObject private var log: SpikeLog
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Week 1 gate for tri-spec section 11. Run the checks, then share the results file back.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Anywhere, including the simulator") {
                    run("Capability matrix and composition") {
                        Probes.capabilityMatrix()
                        Probes.composition()
                        await Probes.schedulerStatus()
                    }
                }

                Section("Needs iPhone with paired Apple Watch") {
                    run("1. Scheduler: week, horizon, count limit") { await Probes.schedulerFullRun() }
                    Text("Then open Workout on the watch: check each session's steps, names, pool swim sets and the race day multisport. Run one pool swim and one threshold run for real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    run("5. Health read back and workoutPlan link") { await Probes.healthReadBack() }
                }

                Section("6. Phone player, phone locked") {
                    if player.isRunning {
                        let step = player.steps[min(player.stepIndex, player.steps.count - 1)]
                        HStack {
                            Text(step.name).font(.headline)
                            Spacer()
                            Text(Duration.seconds(player.stepRemaining).formatted(.time(pattern: .minuteSecond)))
                                .font(.title2.monospacedDigit())
                        }
                        Button("Stop and save", role: .destructive) { Task { await player.stop(save: true) } }
                    } else {
                        Button("Quick test: 6 x 30 s") { Task { await player.start(name: "Quick test", steps: PhonePlayer.quickTest) } }
                        Button("Spec test: 30 min, lock the phone") { Task { await player.start(name: "Spec test", steps: PhonePlayer.specTest) } }
                        Text("Start, lock the phone, listen: every step change should speak or ding. Check the lock screen countdown. Unlock at the end and share results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Results (\(log.entries.count))") {
                    ShareLink(item: log.fileURL) { Label("Share results file", systemImage: "square.and.arrow.up") }
                    Button("Clear results", role: .destructive) { log.clear() }
                    ForEach(log.entries.reversed()) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(e.pass.map { $0 ? "PASS" : "FAIL" } ?? "INFO")
                                    .font(.caption2.bold())
                                    .foregroundStyle(e.pass == nil ? Color.secondary : (e.pass! ? Color.green : Color.red))
                                Text("\(e.spike): \(e.check)").font(.caption)
                            }
                            Text(e.result).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("TriSpike")
            .disabled(busy)
        }
    }

    private func run(_ title: String, _ action: @escaping @MainActor () async -> Void) -> some View {
        Button(title) {
            busy = true
            Task {
                await action()
                busy = false
            }
        }
    }
}
