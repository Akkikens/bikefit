# Strava link: what the TriSpike app expects from the proxy

The Strava link is optional and off by default. The app reads the proxy base URL from the Info.plist key
`TSStravaProxyBaseURL`. An empty value hides every Strava control and sends nothing. The app never holds a Strava
client id or client secret. Tokens live in the iOS Keychain only.

Scope requested: `activity:write` only (set by the proxy). The app only adds activities the athlete chooses to share, so it
asks for nothing that reads private activities. Add a read scope later only when a feature needs it, and change the
in-app permission copy in the same release.

## Endpoints

1. `GET {base}/api/strava/start?client_state=<nonce>&code_challenge=<challenge>`
   Opened in an ASWebAuthenticationSession (iOS 17.4+ `Callback.customScheme`). `client_state` is 8 to 64 characters of
   `[A-Za-z0-9_-]` (the app sends 32 hex characters). `code_challenge` is the 43 character base64url SHA-256 of a random
   verifier the app keeps in memory (PKCE style). Both are required. The proxy sends the athlete to Strava's authorize page
   with its own client id and signs both values into Strava's `state`.
2. `GET {base}/api/strava/callback` (called by Strava, server side). The proxy exchanges Strava's code with its client
   secret, seals the tokens into a one-time handoff code that is bound to the challenge and lasts 2 minutes, then redirects
   the session to `trispike://strava#code=<handoff>&client_state=<nonce>`. No token is ever in that redirect. On a refusal:
   `#error=access_denied&client_state=<nonce>` (any other `error` value is shown as a generic failure). The app requires
   `client_state` to be present and equal to the nonce it sent, for every result including errors. A callback without it is
   refused (`badResponse`) and the exchange is never called.
3. `POST {base}/api/strava/exchange` with JSON `{"code": "<handoff>", "code_verifier": "<verifier>"}`. The proxy checks that
   SHA-256(verifier) equals the challenge sealed in the code. Reply `200` with
   `{"access_token", "refresh_token", "expires_at", "athlete"?, "scope"}` (`athlete` is the first name). Another app that
   catches the custom scheme redirect only gets a code it cannot open, because it never saw the verifier.
4. `POST {base}/api/strava/refresh` with JSON `{"refresh_token": "..."}`. Reply `200` with JSON
   `{"access_token", "refresh_token"?, "expires_at"? or "expires_in"?}`. The proxy relays Strava's 400 or 401 for a revoked or
   invalid refresh token as `401`; the app then deletes the connection and says it ran out (`expired`).
5. `POST {base}/api/strava/upload` with header `Authorization: Bearer <athlete access token>` and JSON
   `{"kind": "manual", "name", "sport_type", "start_date_local", "elapsed_time", "description", "trainer"}`. The proxy forwards
   it to Strava's create activity endpoint with the athlete's own token. Reply `2xx` on success. `401` makes the app refresh
   once and retry; `403` is shown as a missing permission; `429` as busy; other failures as a generic error. The body shape is
   pinned by `services/strava-proxy/test/app-upload-fixture.json`, which the proxy tests send through the real validator and the
   app tests compare to `StravaUpload.body()`.
6. `POST {base}/api/strava/deauthorize` with `Authorization: Bearer <athlete access token>`. Disconnect calls it (best effort,
   after a refresh if the token ran out) and then deletes the Keychain item either way.

`sport_type` is `Swim`, `Ride`, `Run`, or `Workout` for a brick. Only the session name, the sport, the start time and the
elapsed seconds are sent. No heart rate, no Health data, no location, no distance.

## Privacy

Apple Health data stays on the phone. The app shows what is sent and that the link is optional. Disconnect asks Strava to revoke
the app's access (through `deauthorize`), then deletes the Keychain item and the list of shared sessions on the phone. If the
request cannot be sent, the app says so and points to Strava, Settings, My Apps.

## Before the flag goes on (owner steps)

- Rate limit the proxy in the Vercel Firewall (see the proxy README). It is a release gate, not an option.
- Use Strava's official Connect with Strava button asset and the Powered by Strava mark where Strava's brand rules ask for
  them. The current button is plain system styling on purpose, with no Strava marks.
- Set `PUBLIC_BASE_URL` on the proxy so the redirect address never comes from a request header.
