import SwiftUI

/// The Brickline shell: four tabs, the player as a full screen cover (design spec section 6).
struct ContentView: View {
    enum Tab: String { case today, week, race, methods }

    @State private var tab: Tab = ContentView.launchTab
    @State private var playerSession: Session? = ContentView.launchPlayer
    @State private var playerSmoke = ContentView.hasFlag("-screenPlayer")

    var body: some View {
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
                .tabItem { Label("Methods", systemImage: "book.closed") }
                .tag(Tab.methods)
        }
        .tint(BL.accent)
        .fullScreenCover(item: $playerSession) { s in
            PlayerView(session: s, smoke: playerSmoke)
        }
    }

    /// Launch arguments for screenshots: -screen today|week|race|methods (any case), -screenPlayer.
    /// Read once at process start, so a screenshot run must be a cold launch per frame.
    /// Also accepts the value from UserDefaults, which registers `-screen week` from the launch arguments.
    private static var launchTab: Tab {
        let args = ProcessInfo.processInfo.arguments
        var raw: String?
        if let i = args.firstIndex(where: { $0.lowercased() == "-screen" }), i + 1 < args.count { raw = args[i + 1] }
        raw = raw ?? UserDefaults.standard.string(forKey: "screen")
        let value = raw?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        return Tab(rawValue: value) ?? .today
    }

    /// Case insensitive presence check for a flag argument such as -screenPlayer.
    static func hasFlag(_ name: String) -> Bool {
        let wanted = name.lowercased()
        return ProcessInfo.processInfo.arguments.contains { $0.lowercased() == wanted }
            || UserDefaults.standard.bool(forKey: String(name.drop(while: { $0 == "-" })))
    }

    private static var launchPlayer: Session? {
        hasFlag("-screenPlayer") ? Demo.thresholdRun : nil
    }
}
