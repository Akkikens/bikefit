import SwiftUI

/// The Brickline shell: four tabs, the player as a full screen cover (design spec section 6).
struct ContentView: View {
    enum Tab: String { case today, week, race, methods }

    @State private var tab: Tab = ContentView.launchTab
    @State private var playerSession: Session? = ContentView.launchPlayer
    @State private var playerSmoke = ProcessInfo.processInfo.arguments.contains("-screenPlayer")

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

    /// Launch arguments for screenshots: -screen today|week|race|methods, -screenPlayer.
    private static var launchTab: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count, let t = Tab(rawValue: args[i + 1]) { return t }
        return .today
    }

    private static var launchPlayer: Session? {
        ProcessInfo.processInfo.arguments.contains("-screenPlayer") ? Demo.thresholdRun : nil
    }
}
