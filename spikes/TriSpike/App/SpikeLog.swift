import Foundation
import os

/// One line per observation, kept in memory, mirrored to os_log, and written to Documents/spike-results.json
/// so results survive the session and can be shared from the app or read from the simulator container.
struct SpikeEntry: Codable, Identifiable {
    var id = UUID()
    var time = Date()
    var spike: String
    var check: String
    var result: String
    var pass: Bool?
}

@MainActor
final class SpikeLog: ObservableObject {
    static let shared = SpikeLog()
    @Published private(set) var entries: [SpikeEntry] = []
    private let logger = Logger(subsystem: "com.akkikens.trispike", category: "spike")

    func record(_ spike: String, _ check: String, _ result: String, pass: Bool? = nil) {
        let entry = SpikeEntry(spike: spike, check: check, result: result, pass: pass)
        entries.append(entry)
        let mark = pass.map { $0 ? "PASS" : "FAIL" } ?? "INFO"
        logger.log("SPIKE [\(spike, privacy: .public)] \(mark, privacy: .public) \(check, privacy: .public): \(result, privacy: .public)")
        save()
    }

    func clear() {
        entries = []
        save()
    }

    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("spike-results.json")
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
