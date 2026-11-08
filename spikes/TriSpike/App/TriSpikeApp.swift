import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// While the app is in the foreground it speaks cues itself, so boundary notifications stay silent here.
    /// In the background they are delivered by the system with sound: the guaranteed cue path.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}

@main
struct TriSpikeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var player = PhonePlayer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(SpikeLog.shared)
                .task {
                    // Unattended run of every check that works without a watch, for the simulator and CI.
                    if ProcessInfo.processInfo.arguments.contains("-spikeSelfTest") {
                        SpikeLog.shared.clear()
                        Probes.capabilityMatrix()
                        Probes.composition()
                        await Probes.schedulerStatus()
                        SpikeLog.shared.record("selftest", "done", "\(SpikeLog.shared.entries.count) entries")
                    }
                    // Device run: everything except the real workouts and the locked player test, in one launch.
                    // Needs two taps on Allow (WorkoutKit scheduling, then Health).
                    if ProcessInfo.processInfo.arguments.contains("-spikeDeviceRun") {
                        SpikeLog.shared.clear()
                        Probes.capabilityMatrix()
                        Probes.composition()
                        await Probes.schedulerStatus()
                        await Probes.schedulerFullRun()
                        await Probes.healthReadBack()
                        SpikeLog.shared.record("selftest", "device run done", "\(SpikeLog.shared.entries.count) entries")
                    }
                    // Unattended 15 second player run: timing loop, cues, audio session, Live Activity.
                    if ProcessInfo.processInfo.arguments.contains("-spikePlayerSmoke") {
                        SpikeLog.shared.clear()
                        await player.start(name: "Smoke", sport: .run, steps: PhonePlayer.smokeTest, smoke: true)
                        try? await Task.sleep(for: .seconds(18))
                        SpikeLog.shared.record("selftest", "player smoke done", "running=\(player.isRunning)", pass: !player.isRunning)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                SpikeLog.shared.record("lifecycle", "scene", "active")
                player.resyncAfterForeground()
            case .background:
                SpikeLog.shared.record("lifecycle", "scene", "background")
            default:
                break
            }
        }
    }
}
