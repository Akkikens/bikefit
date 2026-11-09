import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// The optional Strava link. The app talks only to the proxy named in Info.plist, never to Strava directly, and never
// holds a client id or secret. Tokens live in the Keychain. Nothing here runs when the proxy address is empty.

// MARK: Problems, in plain words

enum StravaProblem: Error, Equatable {
    case disabled, cancelled, denied, offline, expired, scopeMissing, busy, server, badResponse, storage, notConnected

    var message: String {
        switch self {
        case .disabled: "Strava is not turned on in this version of TriSpike."
        case .cancelled: "You closed the Strava sign in. Nothing was connected."
        case .denied: "Strava was not given permission, so nothing was connected. You can try again any time."
        case .offline: "You are offline. Try again when you have a connection."
        case .expired: "Your Strava connection ran out. Connect again to keep sharing."
        case .scopeMissing: "Strava did not allow adding workouts. Disconnect, connect again, and keep the box to upload your activities ticked."
        case .busy: "Strava is busy right now. Try again in a few minutes."
        case .server: "Strava could not take this workout. Try again later."
        case .badResponse: "The Strava connection sent back something TriSpike could not read. Try again."
        case .storage: "TriSpike could not save the connection on this phone."
        case .notConnected: "Connect Strava first."
        }
    }
}

// MARK: Transport

/// Sends one request. The real one is URLSession; tests pass a fake that never touches the network.
protocol StravaTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: StravaTransport {
    var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

// MARK: Sign in session

enum StravaAuthError: Error { case cancelled }

/// Opens the sign in page and returns the URL it ends on. The real one is ASWebAuthenticationSession.
protocol StravaAuthRunner {
    @MainActor func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

final class SystemWebAuthRunner: NSObject, StravaAuthRunner, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    @MainActor
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let s = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { [weak self] callback, error in
                self?.session = nil
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: StravaAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? StravaAuthError.cancelled)
                }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            if !s.start() {
                session = nil
                continuation.resume(throwing: StravaAuthError.cancelled)
            }
        }
    }

    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first.map { ASPresentationAnchor(windowScene: $0) } ?? ASPresentationAnchor()
    }
}

// MARK: Callback

enum StravaCallback: Equatable {
    /// The one-time handoff code to trade for tokens. No tokens ever arrive in the redirect.
    case handoff(String)
    case denied
    case failed

    /// Reads where the sign in ended: `trispike://strava#code=...&client_state=...` (query or fragment).
    /// The echoed `client_state` must be present and equal to the one the app sent. A result without it is refused,
    /// whatever else it carries, so a link opened by another app or page cannot sign the athlete in.
    static func parse(_ url: URL, expectedState: String) -> StravaCallback {
        guard url.scheme?.lowercased() == StravaConfig.callbackScheme, url.host?.lowercased() == StravaConfig.callbackHost else { return .failed }
        var values: [String: String] = [:]
        for source in [URLComponents(url: url, resolvingAgainstBaseURL: false)?.query,
                       URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment] {
            guard let source else { continue }
            var parts = URLComponents()
            parts.query = source
            for item in parts.queryItems ?? [] { if let v = item.value { values[item.name] = v } }
        }
        guard !expectedState.isEmpty, let returned = values["client_state"], returned == expectedState else { return .failed }
        if let error = values["error"], !error.isEmpty {
            return error == "access_denied" ? .denied : .failed
        }
        guard let code = values["code"], !code.isEmpty, code.count <= 2000 else { return .failed }
        return .handoff(code)
    }
}

/// The two secrets of one sign in: a nonce echoed back in the redirect, and a verifier that never leaves the app until
/// the exchange. The proxy only ever sees the verifier's SHA-256 (the challenge) while the redirect is in flight.
struct StravaSignInSecrets: Equatable {
    var state: String
    var verifier: String

    var challenge: String { Self.challenge(for: verifier) }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLString
    }

    /// Fresh random values. The nonce is 32 hex characters, which fits the proxy's `[A-Za-z0-9_-]{8,64}` rule.
    static func random() -> StravaSignInSecrets {
        var bytes = [UInt8](repeating: 0, count: 32)
        let ok = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess
        let verifier = ok ? Data(bytes).base64URLString : (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return StravaSignInSecrets(state: UUID().uuidString.replacingOccurrences(of: "-", with: ""), verifier: verifier)
    }
}

extension Data {
    var base64URLString: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: One workout to share

/// What gets sent to Strava for one finished session: the name, the sport, when it started and how long it lasted.
/// Nothing else. No heart rate, no health data, no location.
struct StravaUpload: Equatable {
    /// Identifies the session so it is never shared twice.
    var key: String
    var name: String
    var sport: Sport
    var isBrick: Bool
    var start: Date
    var elapsedSeconds: Int

    /// Strava's sport type. A brick (two sports in one session) goes up as a general workout.
    var sportType: String {
        if isBrick { return "Workout" }
        switch sport { case .swim: return "Swim"; case .bike: return "Ride"; case .run: return "Run" }
    }

    /// The phone player's bike sessions are indoor.
    var isTrainer: Bool { sport == .bike && !isBrick }

    static let description = "Recorded with TriSpike."

    /// The JSON the proxy receives.
    func body(timeZone: TimeZone = .current) -> [String: Any] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return [
            "kind": "manual",
            "name": name,
            "sport_type": sportType,
            "start_date_local": f.string(from: start),
            "elapsed_time": max(elapsedSeconds, 1),
            "description": Self.description,
            "trainer": isTrainer,
        ]
    }
}

/// Remembers which sessions were already shared, so a second tap never posts a duplicate.
struct StravaUploadLog {
    var defaults: UserDefaults = .standard
    private let key = "trispike.strava.shared.v1"

    func contains(_ id: String) -> Bool { Set(defaults.stringArray(forKey: key) ?? []).contains(id) }
    func add(_ id: String) {
        var all = Set(defaults.stringArray(forKey: key) ?? [])
        all.insert(id)
        defaults.set(Array(all.sorted().suffix(500)), forKey: key)
    }
    func clear() { defaults.removeObject(forKey: key) }
}

// MARK: Client

@MainActor
final class StravaClient: ObservableObject {
    enum State: Equatable {
        /// No proxy address in Info.plist. The feature is hidden.
        case off
        case disconnected
        case connecting
        case connected(name: String?)
    }

    static let shared = StravaClient(config: .fromBundle(), tokens: .keychain(), transport: URLSessionTransport(), auth: SystemWebAuthRunner())

    @Published private(set) var state: State
    @Published private(set) var problem: StravaProblem?
    @Published private(set) var isUploading = false
    /// After a disconnect: whether Strava confirmed the revoke. False means the request could not be sent.
    @Published private(set) var lastDisconnectRevoked: Bool?

    let config: StravaConfig
    private let tokens: StravaTokenStore
    private let transport: StravaTransport
    private let auth: StravaAuthRunner
    private let now: () -> Date
    private let makeSecrets: () -> StravaSignInSecrets
    private let log: StravaUploadLog

    init(config: StravaConfig, tokens: StravaTokenStore, transport: StravaTransport, auth: StravaAuthRunner,
         log: StravaUploadLog = StravaUploadLog(), now: @escaping () -> Date = Date.init,
         makeSecrets: @escaping () -> StravaSignInSecrets = { .random() }) {
        self.config = config
        self.tokens = tokens
        self.transport = transport
        self.auth = auth
        self.log = log
        self.now = now
        self.makeSecrets = makeSecrets
        if !config.isEnabled {
            state = .off
        } else if let t = tokens.load() {
            state = .connected(name: t.athleteName)
        } else {
            state = .disconnected
        }
    }

    var isEnabled: Bool { config.isEnabled }
    var isConnected: Bool { if case .connected = state { return true }; return false }
    func hasShared(_ upload: StravaUpload) -> Bool { log.contains(upload.key) }
    func clearProblem() { problem = nil }

    // MARK: Connect and disconnect

    /// Opens Strava's sign in. Returns true when the connection was saved.
    @discardableResult
    func connect() async -> Bool {
        guard config.isEnabled else { problem = .disabled; return false }
        let secrets = makeSecrets()
        guard let url = config.startURL(state: secrets.state, challenge: secrets.challenge) else { problem = .disabled; return false }
        problem = nil
        lastDisconnectRevoked = nil
        state = .connecting
        let callbackURL: URL
        do {
            callbackURL = try await auth.authenticate(url: url, callbackScheme: StravaConfig.callbackScheme)
        } catch StravaAuthError.cancelled {
            return fail(.cancelled)
        } catch {
            return fail(.cancelled)
        }
        switch StravaCallback.parse(callbackURL, expectedState: secrets.state) {
        case .handoff(let code):
            switch await exchange(code: code, verifier: secrets.verifier) {
            case .failure(let p): return fail(p)
            case .success(let t):
                guard tokens.save(t) else { return fail(.storage) }
                state = .connected(name: t.athleteName)
                return true
            }
        case .denied:
            return fail(.denied)
        case .failed:
            return fail(.badResponse)
        }
    }

    private struct ExchangeBody: Decodable {
        var access_token: String
        var refresh_token: String
        var expires_at: Double?
        var expires_in: Double?
        var athlete: String?
    }

    /// Trades the one-time handoff code and the app's own verifier for the tokens.
    private func exchange(code: String, verifier: String) async -> Result<StravaTokens, StravaProblem> {
        guard let url = config.exchangeURL else { return .failure(.disabled) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code, "code_verifier": verifier])
        do {
            let (data, response) = try await transport.send(request)
            switch response.statusCode {
            case 200..<300:
                guard let body = try? JSONDecoder().decode(ExchangeBody.self, from: data), !body.access_token.isEmpty, !body.refresh_token.isEmpty else {
                    return .failure(.badResponse)
                }
                let expires: Date
                if let at = body.expires_at, at > 0 { expires = Date(timeIntervalSince1970: at) }
                else if let secs = body.expires_in, secs > 0 { expires = now().addingTimeInterval(secs) }
                else { return .failure(.badResponse) }
                let name = body.athlete.flatMap { $0.isEmpty ? nil : String($0.prefix(40)) }
                return .success(StravaTokens(accessToken: body.access_token, refreshToken: body.refresh_token, expiresAt: expires, athleteName: name))
            case 429: return .failure(.busy)
            case 400, 401, 403: return .failure(.badResponse)
            default: return .failure(.server)
            }
        } catch {
            return .failure(Self.problem(for: error))
        }
    }

    /// Ends the connection. First asks Strava, through the proxy, to revoke the app's access (best effort: a refresh
    /// happens first when the token ran out). Then, whatever happened, deletes every Keychain item and the list of
    /// shared sessions from this phone. Returns true when Strava confirmed the revoke.
    @discardableResult
    func disconnect() async -> Bool {
        var revoked = false
        if config.isEnabled, tokens.load() != nil, let url = config.deauthorizeURL {
            if case .success(let token) = await validAccessToken() {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                if let (_, response) = try? await transport.send(request), (200..<300).contains(response.statusCode) { revoked = true }
            }
        }
        tokens.clear()
        log.clear()
        problem = nil
        state = config.isEnabled ? .disconnected : .off
        lastDisconnectRevoked = revoked
        return revoked
    }

    @discardableResult
    private func fail(_ p: StravaProblem) -> Bool {
        problem = p
        state = config.isEnabled ? (tokens.load().map { .connected(name: $0.athleteName) } ?? .disconnected) : .off
        return false
    }

    // MARK: Tokens

    /// A token that is good to use now, refreshed through the proxy when it is about to run out.
    func validAccessToken() async -> Result<String, StravaProblem> {
        guard config.isEnabled else { return .failure(.disabled) }
        guard let current = tokens.load() else { return .failure(.notConnected) }
        if !current.needsRefresh(now: now()) { return .success(current.accessToken) }
        return await refresh(current)
    }

    private func refresh(_ current: StravaTokens) async -> Result<String, StravaProblem> {
        guard let url = config.refreshURL else { return .failure(.disabled) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": current.refreshToken])
        do {
            let (data, response) = try await transport.send(request)
            switch response.statusCode {
            case 200..<300:
                guard let fresh = Self.parseRefresh(data, previous: current, now: now()) else { return .failure(.badResponse) }
                guard tokens.save(fresh) else { return .failure(.storage) }
                state = .connected(name: fresh.athleteName)
                return .success(fresh.accessToken)
            case 400, 401, 403:
                // Strava no longer accepts this connection. Delete it so the app does not keep trying.
                tokens.clear()
                state = .disconnected
                problem = .expired
                return .failure(.expired)
            case 429: return .failure(.busy)
            default: return .failure(.server)
            }
        } catch {
            return .failure(Self.problem(for: error))
        }
    }

    private struct RefreshBody: Decodable {
        var access_token: String
        var refresh_token: String?
        var expires_at: Double?
        var expires_in: Double?
    }

    static func parseRefresh(_ data: Data, previous: StravaTokens, now: Date) -> StravaTokens? {
        guard let body = try? JSONDecoder().decode(RefreshBody.self, from: data), !body.access_token.isEmpty else { return nil }
        let expires: Date
        if let at = body.expires_at, at > 0 { expires = Date(timeIntervalSince1970: at) }
        else if let secs = body.expires_in, secs > 0 { expires = now.addingTimeInterval(secs) }
        else { return nil }
        let refresh = (body.refresh_token?.isEmpty == false ? body.refresh_token : nil) ?? previous.refreshToken
        return StravaTokens(accessToken: body.access_token, refreshToken: refresh, expiresAt: expires, athleteName: previous.athleteName)
    }

    static func problem(for error: Error) -> StravaProblem {
        guard let urlError = error as? URLError else { return .server }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
            return .offline
        default:
            return .server
        }
    }

    // MARK: Upload

    /// Sends one finished session to Strava through the proxy. Returns true when Strava has it.
    /// A session already shared returns true without sending anything.
    @discardableResult
    func upload(_ workout: StravaUpload) async -> Bool {
        guard config.isEnabled, let url = config.uploadURL else { problem = .disabled; return false }
        if log.contains(workout.key) { return true }
        problem = nil
        isUploading = true
        defer { isUploading = false }
        var retried = false
        while true {
            let token: String
            switch await validAccessToken() {
            case .success(let t): token = t
            case .failure(let p):
                if p != .expired { problem = p }
                return false
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try? JSONSerialization.data(withJSONObject: workout.body())
            do {
                let (_, response) = try await transport.send(request)
                switch response.statusCode {
                case 200..<300:
                    log.add(workout.key)
                    return true
                case 401:
                    // The token was refused. Refresh once and try again; a second refusal means the connection is gone.
                    if !retried, let current = tokens.load() {
                        retried = true
                        switch await refresh(current) {
                        case .success: continue
                        case .failure(let p):
                            if p != .expired { problem = p }
                            return false
                        }
                    }
                    tokens.clear()
                    state = .disconnected
                    problem = .expired
                    return false
                case 403:
                    problem = .scopeMissing
                    return false
                case 429:
                    problem = .busy
                    return false
                default:
                    problem = .server
                    return false
                }
            } catch {
                problem = Self.problem(for: error)
                return false
            }
        }
    }
}
