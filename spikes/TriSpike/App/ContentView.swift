import SwiftUI

/// The Brickline shell: onboarding on first launch, then four tabs, with the player as a full screen cover (design spec section 6).
struct ContentView: View {
    enum Tab: String { case today, week, race, methods }

    @ObservedObject private var setup = UserSetup.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: Tab
    @State private var playerSession: Session?
    @State private var playerSmoke: Bool
    /// Set by -screenOnboarding N. While non nil, onboarding shows even if setup is already done.
    @State private var forcedOnboardingStep: Int?
    /// Set by -screenGlossary <term>. Presented over the Today tab.
    @State private var glossaryTerm: Term?

    init() {
        let launch = LaunchConfig.shared
        _tab = State(initialValue: launch.tab)
        _playerSmoke = State(initialValue: launch.playerSmoke)
        _playerSession = State(initialValue: launch.playerSmoke ? Demo.thresholdRun : nil)
        _forcedOnboardingStep = State(initialValue: launch.onboardingStep)
        _glossaryTerm = State(initialValue: launch.glossaryTerm)
    }

    private var showOnboarding: Bool {
        forcedOnboardingStep != nil || !setup.data.hasOnboarded
    }

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingFlow(initialStep: forcedOnboardingStep ?? 0, onFinish: { finishOnboarding() })
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .background(BL.background.ignoresSafeArea())
        // A cross fade, or an instant swap under Reduce Motion.
        .animation(Motion(reduce: reduceMotion).animation(.easeInOut(duration: 0.4)), value: showOnboarding)
    }

    private var mainTabs: some View {
        TabView(selection: $tab) {
            TodayView(playerSession: $playerSession)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)
            WeekView(playerSession: $playerSession)
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(Tab.week)
            RaceView()
                .tabItem { Label("Race", systemImage: "flag.checkered") }
                .tag(Tab.race)
            MethodsView(playerSession: $playerSession, playerSmoke: $playerSmoke)
                .tabItem { Label("Learn", systemImage: "book.closed") }
                .tag(Tab.methods)
        }
        .tint(BL.accent)
        .fullScreenCover(item: $playerSession) { s in
            PlayerView(session: s, smoke: playerSmoke)
        }
        .sheet(item: $glossaryTerm) { term in
            GlossarySheet(term: term)
        }
    }

    /// Setup is saved by the flow itself in normal use. Setting it here too makes the gate safe either way.
    private func finishOnboarding() {
        setup.data.hasOnboarded = true
        Demo.startPlan()
        forcedOnboardingStep = nil
        tab = .today
    }

    /// Case insensitive presence check for a flag argument such as -screenPlayer.
    static func hasFlag(_ name: String) -> Bool {
        LaunchArgs.hasFlag(name)
    }
}

// MARK: Launch arguments

/// Reads launch arguments and the matching UserDefaults keys (a `-key value` launch pair registers in UserDefaults).
enum LaunchArgs {
    /// Case insensitive presence check for a flag such as -screenPlayer.
    static func hasFlag(_ name: String) -> Bool {
        let wanted = name.lowercased()
        return ProcessInfo.processInfo.arguments.contains { $0.lowercased() == wanted }
            || UserDefaults.standard.bool(forKey: String(name.drop(while: { $0 == "-" })))
    }

    /// The value after `-name`, from the launch arguments first and UserDefaults second. Nil when there is none.
    static func value(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        let wanted = name.lowercased()
        var raw: String?
        if let i = args.firstIndex(where: { $0.lowercased() == wanted }), i + 1 < args.count, !args[i + 1].hasPrefix("-") {
            raw = args[i + 1]
        }
        raw = raw ?? UserDefaults.standard.string(forKey: String(name.drop(while: { $0 == "-" })))
        let trimmed = raw?.trimmingCharacters(in: .whitespaces)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// Lowercase letters and digits only, so "recovery-week", "Recovery Week" and "recoveryWeek" all match.
    static func normalized(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

/// Every screenshot launch argument, read once at process start (a screenshot run must be a cold launch per frame).
/// Creating it also applies the arguments that change saved setup, in this order: -resetSetup, -tracker, -skipOnboarding.
///
///   -screen today|week|race|methods   open that tab
///   -screenPlayer                     open the phone player on the demo threshold run
///   -screenDetail                     handled by TodayView
///   -screenOnboarding N               show onboarding at step N (0 based), even if setup is done
///   -screenGlossary <term>            glossary sheet for a Term raw value, over Today
///   -tracker appleWatch|whoop|garmin|otherWatch|phoneOnly
///   -resetSetup                       clear setup, so onboarding shows
///   -skipOnboarding                   go straight to the tabs. Saves hasOnboarded = true, which is harmless on a test device.
///
/// -screen, -screenPlayer, -screenDetail and -screenGlossary also skip onboarding, so existing screenshot commands keep working.
@MainActor
final class LaunchConfig {
    static let shared = LaunchConfig()

    let tab: ContentView.Tab
    let playerSmoke: Bool
    let onboardingStep: Int?
    let glossaryTerm: Term?

    private init() {
        let setup = UserSetup.shared

        // Tab.
        let tabValue = LaunchArgs.value("-screen")?.lowercased() ?? ""
        let requestedTab = ContentView.Tab(rawValue: tabValue)
        tab = requestedTab ?? .today

        // Player.
        playerSmoke = LaunchArgs.hasFlag("-screenPlayer")

        // Onboarding step.
        var step: Int?
        if let v = LaunchArgs.value("-screenOnboarding") {
            step = max(0, Int(v) ?? 0)
        } else if LaunchArgs.hasFlag("-screenOnboarding") {
            step = 0
        }
        onboardingStep = step

        // Glossary term.
        if let v = LaunchArgs.value("-screenGlossary") {
            let wanted = LaunchArgs.normalized(v)
            glossaryTerm = Term.allCases.first { LaunchArgs.normalized($0.rawValue) == wanted }
        } else {
            glossaryTerm = nil
        }

        // Saved setup changes.
        if LaunchArgs.hasFlag("-resetSetup") {
            setup.reset()
            Demo.clearPlanStart()
        }
        if let v = LaunchArgs.value("-tracker") {
            let wanted = LaunchArgs.normalized(v)
            if let chosen = TrackerChoice.allCases.first(where: { LaunchArgs.normalized($0.rawValue) == wanted }) {
                setup.data.tracker = chosen
            }
        }
        // Frames of the later steps are taken as if the safety note was already read.
        if let step, step > 2 { setup.data.acknowledged = true }
        let skips = LaunchArgs.hasFlag("-skipOnboarding")
            || requestedTab != nil
            || playerSmoke
            || LaunchArgs.hasFlag("-screenDetail")
            || glossaryTerm != nil
        if skips && step == nil && !setup.data.hasOnboarded {
            setup.data.hasOnboarded = true
        }
    }
}
