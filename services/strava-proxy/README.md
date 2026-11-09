# TRISPIKE Strava proxy

A small, stateless Vercel serverless project. It keeps the Strava client secret off the phone. The iOS app uses it to sign in with Strava, refresh tokens and send workouts to Strava.

It has no database, no analytics, no ads and no stored state. It never logs request bodies, codes or tokens. Tokens pass through memory and go straight back to the app.

## Routes

All routes live under `/api/strava/`.

| Route | Method | What it does |
| --- | --- | --- |
| `start` | GET | Redirects the browser sheet to Strava's authorize page. Scope: `activity:write` (adding activities, nothing that reads private ones). Required `client_state` (8 to 64 characters of letters, digits, dash, underscore) and `code_challenge` (43 character base64url SHA-256 of an app held verifier) are signed into the state. |
| `callback` | GET | Strava sends the user here. Checks the signed state (10 minute limit), swaps the code for tokens, then redirects to `trispike://strava#code=<handoff>&client_state=...`. The handoff code is the tokens sealed with AES-256-GCM (key derived from `STATE_SIGNING_KEY`), bound to the challenge, valid 2 minutes. No token is in the redirect. On failure the fragment is `error=invalid_state`, `access_denied`, `invalid_code`, `exchange_failed` or `upstream_unreachable`. |
| `exchange` | POST | JSON `{"code": "<handoff>", "code_verifier": "<verifier>"}`. Checks SHA-256(verifier) against the sealed challenge and returns `{access_token, refresh_token, expires_at, athlete?, scope}`. A wrong verifier, an expired or forged code, or a browser request is refused. |
| `refresh` | POST | JSON `{"refresh_token": "..."}`. Returns `{access_token, refresh_token, expires_at}`. Strava may rotate the refresh token, so the app must store the new one. A revoked or invalid refresh token (Strava answers 400 or 401) comes back as `401` so the app asks the athlete to connect again. |
| `upload` | POST | `Authorization: Bearer <user access token>`. JSON body, see below. |
| `upload?id=N` | GET | Same header. Checks whether a file upload has finished processing. |
| `deauthorize` | POST | `Authorization: Bearer <user access token>`. Revokes the app's access at Strava. |

The redirect carries only a short-lived handoff code, never the tokens. Custom URL schemes are not exclusive on iOS, so another app could catch the redirect, but the code is useless without the verifier that only the TRISPIKE app holds. The code is stateless, so it can be opened again inside its 2 minutes by whoever holds both the code and the verifier; the Strava tokens it carries are the athlete's own and the athlete can revoke them.

### Upload bodies

Manual activity (creates it with `POST /activities` at Strava):

```json
{ "kind": "manual", "name": "Brick: bike then run", "sport_type": "Ride",
  "start_date_local": "2026-05-01T07:30:00Z", "elapsed_time": 3600,
  "distance": 30000, "description": "optional", "trainer": false, "commute": false }
```

`elapsed_time` is whole seconds (1 to 172800). `distance` is meters. `sport_type` must be one of: Run, TrailRun, VirtualRun, Walk, Hike, Ride, GravelRide, MountainBikeRide, EBikeRide, VirtualRide, Swim, Rowing, Elliptical, Workout, WeightTraining, Yoga, Crossfit.

File upload (TCX, GPX or FIT, sent to Strava as multipart):

```json
{ "kind": "file", "data_type": "tcx", "file_base64": "...", "name": "optional",
  "description": "optional", "sport_type": "Run", "external_id": "trispike-2026-05-01-run",
  "trainer": false, "commute": false }
```

`data_type` is `fit`, `tcx` or `gpx`, optionally with `.gz`. The decoded file may be up to 3 MB; the whole request body may be up to about 4 MB (Vercel's own limit is about 4.5 MB). Strava processes files in the background, so poll `GET upload?id=<upload_id>` until `activity_id` is set or `error` is not null.

## Safety choices

- Four environment variables exist: `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STATE_SIGNING_KEY`, and the non-secret `PUBLIC_BASE_URL` (for example `https://trispike-strava.vercel.app`, no path). The redirect address sent to Strava comes from `PUBLIC_BASE_URL`. On Vercel with it unset, `start` refuses to run instead of trusting the Host header. Only a local run falls back to the Host header.
- CORS is closed. No `Access-Control-*` headers are sent, and POST routes refuse any request that carries an `Origin` header (a browser). The native app does not send one.
- Every input is validated (types, lengths, allowed values, base64, size caps). Errors are short and never echo secrets.
- The sign-in `state` is an HMAC-SHA256 signed value with a random nonce and a 10 minute expiry. It carries no user data. There is no server memory, so a state can be reused inside its 10 minutes; Strava's one-time `code` is what makes the exchange safe.
- Responses are `Cache-Control: no-store`.

## Rate limiting (release gate)

The service is stateless, so it has no counters of its own, and `start` and `callback` are open. Strava limits each app (default 100 requests per 15 minutes and 1,000 per day, shared by all users), so a flood could use up the quota and lock real athletes out. **Do not set `TSStravaProxyBaseURL` in a shipped build until this rule exists.** In the Vercel dashboard: Project, Firewall, Custom Rules, "Rate limit" on path starts with `/api/strava/`, for example 30 requests per minute per IP, and turn on bot protection. Check the box on the release list. An app shared secret is not used, because a secret inside the app binary is not a secret. App Attest could be added later if abuse shows up.

## Deploy (owner steps)

Deploy to the personal Vercel scope `akshays-projects-550d1f45`. Never use the `climb-together` team.

1. In this folder: `vercel link --scope akshays-projects-550d1f45` and pick a new project, for example `trispike-strava`.
2. In the Vercel dashboard for that project, Settings, Environment Variables, add these three for Production (and Preview if you want to test there). **Do not put the values in the repo, in a `.env` file you commit, or in the app.**
   - `STRAVA_CLIENT_ID`: from your Strava API settings page.
   - `STRAVA_CLIENT_SECRET`: from the same page.
   - `STATE_SIGNING_KEY`: a long random string, at least 32 characters. Make one with `openssl rand -base64 48`.
   - `PUBLIC_BASE_URL`: the deployment's public address, `https://` and the bare domain only. Not secret.
3. Deploy: `vercel deploy --prod --scope akshays-projects-550d1f45`.
4. In Strava, Settings, My API Application, set **Authorization Callback Domain** to the deployment's bare domain, for example `trispike-strava.vercel.app` (no `https://`, no path). The proxy sends `https://<that domain>/api/strava/callback` as the redirect.
5. In the app, open `https://<that domain>/api/strava/start?client_state=...&code_challenge=...` in `ASWebAuthenticationSession` with callback scheme `trispike`. Read `code` and `client_state` from the fragment of the returned URL, check `client_state`, then POST the code and the verifier to `/api/strava/exchange` and keep the tokens in the Keychain.

Rotating `STATE_SIGNING_KEY` only invalidates sign-ins that are in progress (states and handoff codes are minutes old at most).

## Privacy statement

This service does not store anything. It does not keep a database, logs of its own, analytics or any copy of your tokens, files or workouts. Your Strava tokens and any workout you send pass through it in memory only, to reach Strava, and are not written anywhere by this code. The hosting platform (Vercel) may keep ordinary request logs, such as time, route and status, for about an hour; the code never writes request bodies, codes or tokens to them. Only the secret and signing key you set as environment variables live on the server.

## Develop and test

```
npm test
```

Tests use Node's built-in `node:test` with a fake `fetch`. Node 20 or newer, no dependencies.
