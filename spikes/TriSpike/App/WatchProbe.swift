import Foundation
import WatchConnectivity

/// Reads the pairing state straight from the phone: is an Apple Watch paired, and is any watch app installed.
/// WorkoutScheduler.isSupported is a static capability flag and says nothing about a paired watch.
final class WatchProbe: NSObject, WCSessionDelegate {
    typealias Reading = (supported: Bool, paired: Bool, appInstalled: Bool, detail: String)
    private var continuation: CheckedContinuation<Reading, Never>?

    func read() async -> Reading {
        guard WCSession.isSupported() else { return (false, false, false, "WCSession not supported") }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            let session = WCSession.default
            session.delegate = self
            session.activate()
            // Activation normally completes in well under a second; do not wait forever.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self, let c = self.continuation else { return }
                self.continuation = nil
                let s = WCSession.default
                c.resume(returning: (true, s.isPaired, s.isWatchAppInstalled, "timeout, state \(s.activationState.rawValue)"))
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard let c = continuation else { return }
        continuation = nil
        c.resume(returning: (true, session.isPaired, session.isWatchAppInstalled,
                             "activation \(activationState.rawValue)\(error.map { ", error \($0)" } ?? "")"))
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}
