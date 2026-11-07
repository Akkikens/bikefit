import ActivityKit
import Foundation

/// Live Activity state for the phone interval player (spec annex E, background behavior item 5).
/// The countdown is rendered by the system from `stepEnd`, so it stays correct while the app is suspended.
struct PlayerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepName: String
        var stepIndex: Int
        var stepCount: Int
        var stepStart: Date
        var stepEnd: Date
    }

    var sessionName: String
}
