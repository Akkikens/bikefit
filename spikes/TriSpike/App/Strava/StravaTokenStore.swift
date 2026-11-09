import Foundation
import Security

/// What the app keeps after a Strava sign in. Lives in the Keychain only, never in UserDefaults, a file or a log.
struct StravaTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    /// First name shown on the Connections screen, if the proxy sent one.
    var athleteName: String?

    /// True when the access token is expired or about to be, with a safety margin.
    func needsRefresh(now: Date, margin: TimeInterval = 120) -> Bool {
        expiresAt.timeIntervalSince(now) < margin
    }
}

/// A place secrets can live. The real one is the Keychain; tests use an in memory one.
protocol SecretStore {
    func read() -> Data?
    @discardableResult func write(_ data: Data) -> Bool
    func delete()
}

/// The iOS Keychain, one generic password item. Readable after the first unlock, never synced or backed up to other devices.
struct KeychainSecretStore: SecretStore {
    var service: String
    var account: String

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    @discardableResult
    func write(_ data: Data) -> Bool {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// Memory only. For tests and previews.
final class MemorySecretStore: SecretStore {
    private(set) var data: Data?
    var failWrites = false
    func read() -> Data? { data }
    @discardableResult func write(_ data: Data) -> Bool {
        if failWrites { return false }
        self.data = data
        return true
    }
    func delete() { data = nil }
}

/// Saves and loads `StravaTokens` through a `SecretStore`.
struct StravaTokenStore {
    var store: SecretStore

    static func keychain() -> StravaTokenStore {
        StravaTokenStore(store: KeychainSecretStore(service: "com.akkikens.trispike.strava", account: "tokens"))
    }

    func load() -> StravaTokens? {
        guard let data = store.read() else { return nil }
        return try? Self.decoder.decode(StravaTokens.self, from: data)
    }

    @discardableResult
    func save(_ tokens: StravaTokens) -> Bool {
        guard let data = try? Self.encoder.encode(tokens) else { return false }
        return store.write(data)
    }

    /// Removes every Strava item from the Keychain.
    func clear() { store.delete() }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
