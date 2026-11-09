import XCTest
@testable import TriSpike

private final class FakeTransport: StravaTransport {
    enum Reply { case http(Int, String), fail(Error) }
    var replies: [Reply] = []
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.notConnectedToInternet) }
        switch replies.removeFirst() {
        case .fail(let e): throw e
        case .http(let code, let body):
            let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: code, httpVersion: nil, headerFields: nil)
            return (Data(body.utf8), response ?? HTTPURLResponse())
        }
    }
}

private final class FakeAuth: StravaAuthRunner {
    var result: Result<URL, Error> = .failure(StravaAuthError.cancelled)
    /// Builds the callback from the state the app sent.
    var make: ((String) -> URL)?
    private(set) var started: [URL] = []
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        started.append(url)
        if let make, let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "client_state" })?.value {
            return make(state)
        }
        return try result.get()
    }
}

@MainActor
final class StravaTests: XCTestCase {
    private let base = "https://proxy.example.com"
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var memory = MemorySecretStore()
    private var transport = FakeTransport()
    private var auth = FakeAuth()
    private var defaults = UserDefaults(suiteName: "trispike.strava.tests") ?? .standard

    override func setUp() {
        memory = MemorySecretStore(); transport = FakeTransport(); auth = FakeAuth()
        defaults.removePersistentDomain(forName: "trispike.strava.tests")
    }

    private func client(_ raw: String? = nil, now: Date? = nil) -> StravaClient {
        let when = now ?? t0
        return StravaClient(config: StravaConfig(rawBaseURL: raw ?? base), tokens: StravaTokenStore(store: memory),
                            transport: transport, auth: auth, log: StravaUploadLog(defaults: defaults),
                            now: { when }, makeSecrets: { StravaSignInSecrets(state: "nonce-1", verifier: "verifier-1") })
    }

    private func tokens(expiresIn: TimeInterval = 3600) -> StravaTokens {
        StravaTokens(accessToken: "access-A", refreshToken: "refresh-R", expiresAt: t0.addingTimeInterval(expiresIn), athleteName: "Sam")
    }

    private func upload() -> StravaUpload {
        StravaUpload(key: "s1|1", name: "Easy run, 30 min", sport: .run, isBrick: false, start: t0, elapsedSeconds: 1800)
    }

    private func callback(_ query: String) -> URL { URL(string: "trispike://strava?\(query)")! }

    // MARK: Config and URLs

    func testEmptyOrBadAddressTurnsTheFeatureOff() {
        for raw in [nil, "", "   ", "not a url", "http://example.com", "ftp://x.com", "https://", "https://u:p@x.com", "https://x.com?a=1"] {
            XCTAssertFalse(StravaConfig(rawBaseURL: raw).isEnabled, "\(raw ?? "nil")")
        }
        XCTAssertTrue(StravaConfig(rawBaseURL: "https://proxy.example.com/").isEnabled)
        XCTAssertTrue(StravaConfig(rawBaseURL: "http://localhost:3000").isEnabled)
        XCTAssertEqual(StravaConfig(rawBaseURL: " https://proxy.example.com// ").baseURL?.absoluteString, "https://proxy.example.com")
    }

    func testTheShippedPlistHasTheKeyAndItIsEmpty() {
        XCTAssertEqual(Bundle(for: StravaClient.self).object(forInfoDictionaryKey: StravaConfig.plistKey) as? String, "")
        XCTAssertFalse(StravaConfig.fromBundle(Bundle(for: StravaClient.self)).isEnabled)
    }

    func testEndpointsAreBuiltFromTheBase() throws {
        let c = StravaConfig(rawBaseURL: base)
        let start = try XCTUnwrap(c.startURL(state: "abc123", challenge: "chal"))
        let parts = try XCTUnwrap(URLComponents(url: start, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.host, "proxy.example.com")
        XCTAssertEqual(parts.path, "/api/strava/start")
        let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(Set(items.keys), ["client_state", "code_challenge"], "the proxy reads exactly these two")
        XCTAssertEqual(items["client_state"], "abc123")
        XCTAssertEqual(items["code_challenge"], "chal")
        XCTAssertEqual(StravaConfig.scopes, "activity:write", "only adding activities is requested")
        XCTAssertEqual(c.exchangeURL?.absoluteString, "https://proxy.example.com/api/strava/exchange")
        XCTAssertEqual(c.deauthorizeURL?.absoluteString, "https://proxy.example.com/api/strava/deauthorize")
        XCTAssertEqual(c.refreshURL?.absoluteString, "https://proxy.example.com/api/strava/refresh")
        XCTAssertEqual(c.uploadURL?.absoluteString, "https://proxy.example.com/api/strava/upload")
        XCTAssertNil(StravaConfig(rawBaseURL: "").startURL(state: "x", challenge: "y"))
        XCTAssertFalse(start.absoluteString.lowercased().contains("secret"))
    }

    // MARK: Token store

    func testTokenStoreRoundTripsAndClears() {
        let store = StravaTokenStore(store: memory)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.save(tokens()))
        XCTAssertEqual(store.load(), tokens())
        store.clear()
        XCTAssertNil(store.load())
        XCTAssertNil(memory.data)
    }

    func testTokenStoreIgnoresGarbageAndReportsFailedWrites() {
        _ = memory.write(Data("not json".utf8))
        XCTAssertNil(StravaTokenStore(store: memory).load())
        memory.failWrites = true
        XCTAssertFalse(StravaTokenStore(store: memory).save(tokens()))
    }

    func testRefreshWindowHasAMargin() {
        XCTAssertFalse(tokens(expiresIn: 3600).needsRefresh(now: t0))
        XCTAssertTrue(tokens(expiresIn: 60).needsRefresh(now: t0))
        XCTAssertTrue(tokens(expiresIn: -5).needsRefresh(now: t0))
    }

    func testRealKeychainRoundTripWhenAvailable() throws {
        let store = StravaTokenStore(store: KeychainSecretStore(service: "com.akkikens.trispike.tests", account: "tokens-\(UUID().uuidString)"))
        defer { store.clear() }
        guard store.save(tokens()) else { throw XCTSkip("Keychain not available in this test host") }
        XCTAssertEqual(store.load(), tokens())
        store.clear()
        XCTAssertNil(store.load())
    }

    // MARK: Callback

    func testCallbackParsing() {
        XCTAssertEqual(StravaCallback.parse(callback("code=HANDOFF&client_state=s"), expectedState: "s"), .handoff("HANDOFF"))
        XCTAssertEqual(StravaCallback.parse(URL(string: "trispike://strava#code=HANDOFF&client_state=s")!, expectedState: "s"), .handoff("HANDOFF"), "fragment")
        XCTAssertEqual(StravaCallback.parse(callback("error=access_denied&client_state=s"), expectedState: "s"), .denied)
        XCTAssertEqual(StravaCallback.parse(callback("error=exchange_failed&client_state=s"), expectedState: "s"), .failed)
        XCTAssertEqual(StravaCallback.parse(callback("code=HANDOFF&client_state=other"), expectedState: "s"), .failed)
        XCTAssertEqual(StravaCallback.parse(callback("client_state=s"), expectedState: "s"), .failed, "no code")
        XCTAssertEqual(StravaCallback.parse(callback("code=HANDOFF&client_state=s"), expectedState: ""), .failed)
        XCTAssertEqual(StravaCallback.parse(URL(string: "https://evil.example/?code=H&client_state=s")!, expectedState: "s"), .failed)
        XCTAssertEqual(StravaCallback.parse(URL(string: "trispike://other?code=H&client_state=s")!, expectedState: "s"), .failed)
    }

    /// A callback that carries no echoed state must be refused, even when it carries tokens or a code. This is the
    /// login forgery case: another app or page opens trispike://strava with someone else's tokens.
    func testCallbackWithoutTheEchoedStateIsAlwaysRefused() {
        let forged = [
            "access_token=a&refresh_token=r&expires_at=1800003600",
            "code=HANDOFF",
            "access_token=a&refresh_token=r&expires_in=600&state=s",
            "error=access_denied",
        ]
        for query in forged {
            XCTAssertEqual(StravaCallback.parse(callback(query), expectedState: "s"), .failed, query)
            XCTAssertEqual(StravaCallback.parse(URL(string: "trispike://strava#\(query)")!, expectedState: "s"), .failed, query)
        }
    }

    /// The exact fragment the proxy builds (see services/strava-proxy test "callback seals the tokens...").
    func testTheProxysRealCallbackShapeIsAccepted() {
        let url = URL(string: "trispike://strava#code=AbC_dEf-123&client_state=0123456789abcdef0123456789abcdef")!
        XCTAssertEqual(StravaCallback.parse(url, expectedState: "0123456789abcdef0123456789abcdef"), .handoff("AbC_dEf-123"))
    }

    func testSignInSecretsFitTheProxyRules() {
        let a = StravaSignInSecrets.random(), b = StravaSignInSecrets.random()
        XCTAssertNotEqual(a, b)
        XCTAssertNotNil(a.state.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression))
        XCTAssertNotNil(a.verifier.range(of: "^[A-Za-z0-9_-]{43,128}$", options: .regularExpression))
        XCTAssertNotNil(a.challenge.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression))
        // RFC 7636 appendix B example.
        XCTAssertEqual(StravaSignInSecrets.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    // MARK: Connect states

    func testDisabledClientIsOffAndNeverTouchesTheNetwork() async {
        let c = client("")
        XCTAssertEqual(c.state, .off)
        XCTAssertFalse(c.isEnabled)
        let ok = await c.connect()
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .disabled)
        let up = await c.upload(upload())
        XCTAssertFalse(up)
        XCTAssertTrue(auth.started.isEmpty)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    private let exchangeReply = "{\"access_token\":\"a\",\"refresh_token\":\"r\",\"expires_at\":1800003600,\"athlete\":\"Sam\",\"scope\":\"activity:write\"}"

    func testConnectTradesTheHandoffCodeForTokensWithTheVerifier() async throws {
        auth.make = { [self] state in callback("code=HANDOFF&client_state=\(state)") }
        transport.replies = [.http(200, exchangeReply)]
        let c = client()
        XCTAssertEqual(c.state, .disconnected)
        let ok = await c.connect()
        XCTAssertTrue(ok)
        XCTAssertEqual(c.state, .connected(name: "Sam"))
        XCTAssertNil(c.problem)
        XCTAssertEqual(StravaTokenStore(store: memory).load()?.accessToken, "a")
        let started = try XCTUnwrap(auth.started.first?.absoluteString)
        XCTAssertTrue(started.contains("client_state=nonce-1"))
        XCTAssertTrue(started.contains("code_challenge=\(StravaSignInSecrets.challenge(for: "verifier-1"))"))
        XCTAssertFalse(started.contains("verifier-1"), "the verifier itself never travels in the start link")
        let req = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(req.url?.path, "/api/strava/exchange")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(req.httpBody)) as? [String: String])
        XCTAssertEqual(body, ["code": "HANDOFF", "code_verifier": "verifier-1"])
    }

    func testAFailedExchangeSavesNothing() async {
        auth.make = { [self] state in callback("code=HANDOFF&client_state=\(state)") }
        transport.replies = [.http(400, "{\"error\":\"invalid_code\"}")]
        let c = client()
        let ok = await c.connect()
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .badResponse)
        XCTAssertNil(memory.data)
    }

    func testCancelledDeniedAndBadCallbackLeaveNothingSaved() async {
        let c = client()
        auth.result = .failure(StravaAuthError.cancelled)
        var ok = await c.connect()
        XCTAssertFalse(ok); XCTAssertEqual(c.problem, .cancelled); XCTAssertEqual(c.state, .disconnected)
        auth.make = { [self] state in callback("error=access_denied&client_state=\(state)") }
        ok = await c.connect()
        XCTAssertEqual(c.problem, .denied); XCTAssertEqual(c.state, .disconnected)
        auth.make = nil
        auth.result = .success(callback("garbage=1"))
        ok = await c.connect()
        XCTAssertEqual(c.problem, .badResponse)
        auth.result = .success(callback("access_token=a&refresh_token=r&expires_in=60&client_state=WRONG"))
        ok = await c.connect()
        XCTAssertFalse(ok); XCTAssertEqual(c.problem, .badResponse)
        auth.result = .success(callback("access_token=a&refresh_token=r&expires_in=600"))
        ok = await c.connect()
        XCTAssertFalse(ok); XCTAssertEqual(c.problem, .badResponse, "tokens in a callback with no state are never accepted")
        XCTAssertNil(memory.data)
        XCTAssertTrue(transport.requests.isEmpty, "a refused callback never reaches the exchange")
        for p in [StravaProblem.cancelled, .denied, .badResponse] { XCTAssertFalse(p.message.isEmpty) }
    }

    func testStorageFailureIsReported() async {
        auth.make = { [self] state in callback("code=HANDOFF&client_state=\(state)") }
        transport.replies = [.http(200, exchangeReply)]
        memory.failWrites = true
        let c = client()
        let ok = await c.connect()
        XCTAssertFalse(ok); XCTAssertEqual(c.problem, .storage); XCTAssertEqual(c.state, .disconnected)
    }

    func testDisconnectAsksStravaToRevokeThenDeletesTheKeychainItemsAndTheSharedList() async throws {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.http(201, "{}"), .http(200, "{\"ok\":true}")]
        let c = client()
        XCTAssertEqual(c.state, .connected(name: "Sam"))
        let ok = await c.upload(upload())
        XCTAssertTrue(ok)
        XCTAssertTrue(c.hasShared(upload()))
        let revoked = await c.disconnect()
        XCTAssertTrue(revoked)
        let req = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(req.url?.path, "/api/strava/deauthorize")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer access-A")
        XCTAssertNil(memory.data)
        XCTAssertEqual(c.state, .disconnected)
        XCTAssertFalse(c.hasShared(upload()))
        XCTAssertEqual(c.lastDisconnectRevoked, true)
    }

    func testDisconnectStillClearsThePhoneWhenStravaCannotBeReached() async {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.fail(URLError(.notConnectedToInternet))]
        let c = client()
        let revoked = await c.disconnect()
        XCTAssertFalse(revoked)
        XCTAssertNil(memory.data)
        XCTAssertEqual(c.state, .disconnected)
        XCTAssertEqual(c.lastDisconnectRevoked, false)
    }

    func testDisconnectRefreshesAnExpiredTokenBeforeRevoking() async {
        StravaTokenStore(store: memory).save(tokens(expiresIn: 5))
        transport.replies = [.http(200, "{\"access_token\":\"access-B\",\"refresh_token\":\"refresh-S\",\"expires_at\":1800007200}"), .http(200, "{}")]
        let c = client()
        let revoked = await c.disconnect()
        XCTAssertTrue(revoked)
        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/api/strava/refresh", "/api/strava/deauthorize"])
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer access-B")
        XCTAssertNil(memory.data)
    }

    func testRevokedRefreshTokenEndsDisconnectedWithExpired() async {
        // The proxy turns Strava's 400 for a revoked refresh token into a 401. The app must delete the dead tokens.
        for status in [400, 401] {
            StravaTokenStore(store: memory).save(tokens(expiresIn: 5))
            transport.replies = [.http(status, "{\"error\":\"strava_error\"}")]
            let c = client()
            let ok = await c.upload(upload())
            XCTAssertFalse(ok)
            XCTAssertEqual(c.problem, .expired, "\(status)")
            XCTAssertEqual(c.state, .disconnected)
            XCTAssertNil(memory.data)
        }
    }

    // MARK: Upload

    func testUploadSendsOnlyTheSessionBasicsWithABearerToken() async throws {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.http(201, "{\"id\":1}")]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertTrue(ok)
        let req = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.absoluteString, "https://proxy.example.com/api/strava/upload")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer access-A")
        XCTAssertFalse(req.url?.absoluteString.contains("access-A") ?? true, "tokens never travel in the URL")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(req.httpBody)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["kind", "name", "sport_type", "start_date_local", "elapsed_time", "description", "trainer"])
        XCTAssertEqual(body["kind"] as? String, "manual", "the proxy requires a kind")
        XCTAssertEqual(body["sport_type"] as? String, "Run")
        XCTAssertEqual(body["elapsed_time"] as? Int, 1800)
        XCTAssertEqual(body["name"] as? String, "Easy run, 30 min")
        XCTAssertEqual(body["trainer"] as? Bool, false)
        XCTAssertFalse(String(data: try XCTUnwrap(req.httpBody), encoding: .utf8)?.contains("refresh") ?? true)
        let again = await c.upload(upload())
        XCTAssertTrue(again)
        XCTAssertEqual(transport.requests.count, 1, "a session is never posted twice")
    }

    /// The proxy test suite validates services/strava-proxy/test/app-upload-fixture.json. This keeps the app body in step with it.
    func testUploadBodyMatchesTheSharedProxyFixture() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("services/strava-proxy/test/app-upload-fixture.json")
        guard let data = try? Data(contentsOf: fixtureURL) else { throw XCTSkip("fixture not readable from this test host") }
        let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let body = upload().body()
        XCTAssertEqual(Set(body.keys), Set(fixture.keys))
        XCTAssertEqual(body["kind"] as? String, fixture["kind"] as? String)
        XCTAssertEqual(body["sport_type"] as? String, fixture["sport_type"] as? String)
        XCTAssertEqual(body["elapsed_time"] as? Int, fixture["elapsed_time"] as? Int)
        XCTAssertEqual(body["description"] as? String, fixture["description"] as? String)
    }

    func testSportTypes() {
        func type(_ s: Sport, brick: Bool = false) -> String {
            StravaUpload(key: "k", name: "n", sport: s, isBrick: brick, start: t0, elapsedSeconds: 60).sportType
        }
        XCTAssertEqual(type(.swim), "Swim"); XCTAssertEqual(type(.bike), "Ride"); XCTAssertEqual(type(.run), "Run")
        XCTAssertEqual(type(.bike, brick: true), "Workout")
        XCTAssertTrue(StravaUpload(key: "k", name: "n", sport: .bike, isBrick: false, start: t0, elapsedSeconds: 1).isTrainer)
        XCTAssertEqual(StravaUpload(key: "k", name: "n", sport: .run, isBrick: false, start: t0, elapsedSeconds: 0).body()["elapsed_time"] as? Int, 1)
    }

    func testAnExpiringTokenIsRefreshedFirstAndSaved() async throws {
        StravaTokenStore(store: memory).save(tokens(expiresIn: 30))
        transport.replies = [.http(200, "{\"access_token\":\"access-B\",\"refresh_token\":\"refresh-S\",\"expires_at\":1800007200}"), .http(201, "{}")]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertTrue(ok)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/strava/refresh")
        let refreshBody = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(transport.requests[0].httpBody)) as? [String: String])
        XCTAssertEqual(refreshBody, ["refresh_token": "refresh-R"])
        XCTAssertEqual(transport.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer access-B")
        XCTAssertEqual(StravaTokenStore(store: memory).load()?.refreshToken, "refresh-S")
    }

    func testARefusedTokenIsRefreshedOnceThenRetried() async {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.http(401, ""), .http(200, "{\"access_token\":\"access-B\",\"expires_in\":3600}"), .http(201, "{}")]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertTrue(ok)
        XCTAssertEqual(StravaTokenStore(store: memory).load()?.refreshToken, "refresh-R", "the old refresh token stays when none comes back")
    }

    func testExpiredConnectionIsDeletedAndSaysSo() async {
        StravaTokenStore(store: memory).save(tokens(expiresIn: 10))
        transport.replies = [.http(401, "{}")]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .expired)
        XCTAssertEqual(c.state, .disconnected)
        XCTAssertNil(memory.data)
        XCTAssertTrue(StravaProblem.expired.message.contains("Connect again"))
    }

    func testStillRefusedAfterARefreshMeansTheConnectionIsGone() async {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.http(401, ""), .http(200, "{\"access_token\":\"b\",\"expires_in\":3600}"), .http(401, "")]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .expired)
        XCTAssertNil(memory.data)
    }

    func testOfflineKeepsTheConnection() async {
        StravaTokenStore(store: memory).save(tokens())
        transport.replies = [.fail(URLError(.notConnectedToInternet))]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .offline)
        XCTAssertEqual(c.state, .connected(name: "Sam"))
        XCTAssertNotNil(memory.data)
        XCTAssertFalse(c.hasShared(upload()))
        XCTAssertTrue(StravaProblem.offline.message.lowercased().contains("offline"))
    }

    func testOfflineDuringRefreshKeepsTheConnection() async {
        StravaTokenStore(store: memory).save(tokens(expiresIn: 5))
        transport.replies = [.fail(URLError(.timedOut))]
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .offline)
        XCTAssertNotNil(memory.data)
    }

    func testServerAnswersMapToPlainProblems() async {
        let cases: [(Int, StravaProblem)] = [(403, .scopeMissing), (429, .busy), (500, .server), (422, .server)]
        for (code, expected) in cases {
            StravaTokenStore(store: memory).save(tokens())
            transport.replies = [.http(code, "{}")]
            let c = client()
            let ok = await c.upload(upload())
            XCTAssertFalse(ok, "\(code)")
            XCTAssertEqual(c.problem, expected, "\(code)")
            XCTAssertNotNil(memory.data, "\(code) keeps the connection")
        }
    }

    func testUploadWithoutAConnectionAsksToConnect() async {
        let c = client()
        let ok = await c.upload(upload())
        XCTAssertFalse(ok)
        XCTAssertEqual(c.problem, .notConnected)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    // MARK: Copy

    func testStravaAndPrivacyCopyIsHonestAndDashFree() {
        for s in StravaCopy.all + [PrivacyCopy.health, PrivacyCopy.connectionsIntro(stravaEnabled: true), PrivacyCopy.connectionsIntro(stravaEnabled: false)] {
            XCTAssertFalse(s.contains("\u{2014}") || s.contains("\u{2013}"), s)
        }
        XCTAssertTrue(StravaCopy.optional.contains("optional"))
        XCTAssertTrue(StravaCopy.sent.contains("session name"))
        XCTAssertTrue(StravaCopy.sent.contains("No heart rate"))
        XCTAssertTrue(StravaCopy.disconnect.contains("Disconnect"))
        XCTAssertTrue(StravaCopy.permission.contains("add activities"))
        XCTAssertFalse(StravaCopy.permission.contains("read"), "only adding activities is asked for")
        XCTAssertFalse(PrivacyCopy.connectionsIntro(stravaEnabled: false).contains("Strava"), "Strava is not mentioned while it is off")
        XCTAssertTrue(PrivacyCopy.connectionsIntro(stravaEnabled: true).contains("Strava"))
        XCTAssertTrue(PrivacyCopy.health.contains("never sent"))
        for p in [StravaProblem.disabled, .cancelled, .denied, .offline, .expired, .scopeMissing, .busy, .server, .badResponse, .storage, .notConnected] {
            XCTAssertFalse(p.message.contains("\u{2014}") || p.message.contains("\u{2013}"), p.message)
        }
    }
}
