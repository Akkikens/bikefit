import Foundation

/// Where the optional Strava feature points, read from Info.plist key `TSStravaProxyBaseURL`.
/// Empty (the default) means the feature is off: nothing about Strava is shown and nothing is sent.
/// The app never holds a Strava client id or secret. A small proxy server does the sign in and forwards uploads.
struct StravaConfig: Equatable {
    static let plistKey = "TSStravaProxyBaseURL"
    /// The URL scheme the proxy sends the athlete back to after Strava's sign in. Registered in Info.plist.
    static let callbackScheme = "trispike"
    static let callbackHost = "strava"
    /// What the app asks Strava for (the proxy sets it): only adding the workouts the athlete chooses to share.
    static let scopes = "activity:write"

    var baseURL: URL?

    var isEnabled: Bool { baseURL != nil }

    /// The redirect the proxy sends the athlete back to: `trispike://strava`.
    static var redirectURI: String { "\(callbackScheme)://\(callbackHost)" }

    init(baseURL: URL?) { self.baseURL = baseURL }

    /// Builds the config from the raw plist string. Only a plain https address (or http on this machine, for testing)
    /// with a host is accepted; anything else leaves the feature off. A trailing slash is dropped.
    init(rawBaseURL: String?) {
        self.baseURL = Self.validated(rawBaseURL)
    }

    static func validated(_ raw: String?) -> URL? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return nil }
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        let local = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard scheme == "https" || (scheme == "http" && local) else { return nil }
        return url
    }

    /// The config from the app bundle.
    static func fromBundle(_ bundle: Bundle = .main) -> StravaConfig {
        StravaConfig(rawBaseURL: bundle.object(forInfoDictionaryKey: plistKey) as? String)
    }

    // MARK: Endpoints

    /// GET {base}/api/strava/start?client_state=<nonce>&code_challenge=<SHA-256 of the verifier, base64url>.
    /// The proxy sends the athlete to Strava, then back to `trispike://strava#code=<handoff>&client_state=<nonce>`.
    /// The app trades the handoff code and its verifier for the tokens at `exchangeURL`. Tokens never ride in the redirect.
    func startURL(state: String, challenge: String) -> URL? {
        guard let baseURL else { return nil }
        var parts = URLComponents(url: baseURL.appendingPathComponent("api/strava/start"), resolvingAgainstBaseURL: false)
        parts?.queryItems = [
            URLQueryItem(name: "client_state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
        ]
        return parts?.url
    }

    /// POST {base}/api/strava/exchange with `{"code", "code_verifier"}`
    var exchangeURL: URL? { baseURL?.appendingPathComponent("api/strava/exchange") }

    /// POST {base}/api/strava/deauthorize with the access token as a Bearer header
    var deauthorizeURL: URL? { baseURL?.appendingPathComponent("api/strava/deauthorize") }

    /// POST {base}/api/strava/refresh
    var refreshURL: URL? { baseURL?.appendingPathComponent("api/strava/refresh") }

    /// POST {base}/api/strava/upload
    var uploadURL: URL? { baseURL?.appendingPathComponent("api/strava/upload") }
}
