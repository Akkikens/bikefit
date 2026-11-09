# TriSpike integration architecture: connecting accounts while keeping privacy honest

Research date: 2026-11-08. Scope: how TriSpike (free iPhone triathlon app, SwiftUI and SwiftData, no accounts, App Privacy target "Data Not Collected") connects to Garmin, Apple Watch (via HealthKit), WHOOP, Oura and Strava, using the thin Vercel backend pattern from the Liftspark repo. Every fact names the URL it came from. Items marked UNVERIFIED could not be confirmed from a primary source. No personal data about the owner is recorded here (this repo is public).

Sibling notes with the vendor detail: integ-whoop.md, integ-oura.md, integ-apple-health.md in this folder. This note covers the architecture that joins them.

## 0. Bottom line

1. All four OAuth vendors need a client secret at the token endpoint, so a server is unavoidable for sign-in: WHOOP (secret in the refresh body, PKCE never mentioned), Oura (PKCE supported but secret still required unless HTTP Basic is used), Garmin (PKCE S256 required AND client_secret required), Strava (no PKCE documented, secret required). PKCE does not remove the secret for any of them. See section 4.
2. The Liftspark backend is already a stateless exchange and refresh proxy: no database, no KV, no logging statements, hashed in-memory rate limit buckets only. It can be copied almost as is into a new TriSpike project (own Vercel project, own vendor registrations). Six concrete changes are listed in section 2. It has never been exercised against live WHOOP or Oura (their keys are not set); only Strava was deployed as of 2026-11-04.
3. Tokens live in the iOS Keychain; the phone calls vendor data APIs directly. The server never sees health data, only one-time codes and tokens in flight.
4. "Data Not Collected" is defensible for a pass through proxy under Apple's own wording (data "immediately discarded after servicing the request" need not be disclosed), but there is one real uncertainty: Vercel keeps request logs for 1 hour on Hobby, and those logs include the request path, search params and (for the filter feature) IP address and user agent. Apple Developer Technical Support has said informally that server logs can make a "read only" request count as collection. Treat the label as defensible but not guaranteed, minimise what is logged, and say so in the privacy policy and App Review notes. See section 5.
5. Garmin cannot be done statelessly. Starter access is push only (Garmin calls a server endpoint), so a server must receive and hold data until the phone fetches it. That is collection by Apple's definition. Garmin also looks closed to a solo free app in practice (business program, capacity limited, paused most of 2026 per secondary reports). Recommendation: no Garmin API in 1.x; Garmin users are served through Apple Health (workouts, heart rate, sleep, steps) plus later FIT import. See sections 4 and 10.
6. Webhooks are not usable without a stateful server that maps vendor user ids to device push tokens. Poll from the phone: on foreground, one BGAppRefreshTask, and HealthKit background delivery wakes. See section 6.
7. Build in phases: phase 0 Apple Health only (no server, label unchanged), phase 1a proxy plus WHOOP, Oura and Strava write only upload (label defended, policy and consent additions), phase 1b Garmin only if a stateful relay is ever accepted (label changes), see section 10.

## 1. What exists in the Liftspark backend (read 2026-11-08)

Files read: <repos>/liftspark/backend/{package.json, tsconfig.json, .gitignore, .env.example, lib/providers.ts, lib/http.ts, api/config.ts, api/fdc/search.ts, api/oauth/[provider]/{start,callback,token,refresh}.ts, api/strava/{token,refresh}.ts}, plus <repos>/liftspark/{README.md, PLAN.md, PRIVACY.md, APPSTORE.md}, the client <repos>/liftspark/app/src/lib/integrations.js and the native sheet <repos>/liftspark/app/ios/App/App/WebAuthPlugin.swift. All backend commits are by the repo's sole author, so the code can be reused in TriSpike; package.json declares AGPL-3.0-or-later, so choose the licence of the copy deliberately.

### 1.1 Endpoints

| Route | Method | What it does |
|---|---|---|
| /api/config | GET | Returns `{strava, whoop, oura, fdc}` booleans: whether a client id and secret (or FDC key) are set. Public, CDN cached 300 s, CORS `*`. No per user data. |
| /api/oauth/:provider/start | GET | Validates `state` (16 to 128 base64url chars) and, for WHOOP and Oura, an S256 `code_challenge` (43 chars); 302 to the vendor authorize URL with the proxy's client id, `redirect_uri` = `<PUBLIC_BASE_URL>/api/oauth/<id>/callback`, `response_type=code`, scope, state, challenge. Strava gets `approval_prompt=auto` and no PKCE. |
| /api/oauth/:provider/callback | GET | Vendor redirects here with `code`, `state`, `error`, `scope`; each is regex validated and forwarded as a 302 to `liftspark://oauth/<id>?...` where the system sign-in sheet hands it to the app. |
| /api/oauth/:provider/token | POST JSON `{code, code_verifier}` | Strict body checks (JSON only, 4096 bytes max, code regex, verifier required for WHOOP and Oura), then POSTs form encoded to the vendor token URL with `client_id`, `client_secret`, `grant_type=authorization_code`, `redirect_uri`. Returns only whitelisted fields (`access_token, refresh_token, expires_at, expires_in, token_type, scope`, plus a Strava athlete first name or a `user_name`). |
| /api/oauth/:provider/refresh | POST JSON `{refresh_token}` | Same guards; vendor refresh grant; same whitelisted response. |
| /api/strava/token, /api/strava/refresh | POST | Re-exports of the generic handlers. |
| /api/fdc/search | GET | USDA FoodData Central proxy for Liftspark food search. Not needed in TriSpike. |

Provider definitions (lib/providers.ts): strava authorize `https://www.strava.com/oauth/mobile/authorize`, token `https://www.strava.com/oauth/token`, scope `activity:write,read`; whoop authorize `https://api.prod.whoop.com/oauth/oauth2/auth`, token `https://api.prod.whoop.com/oauth/oauth2/token`, scope `offline read:recovery read:cycles read:workout read:sleep read:profile`; oura authorize `https://cloud.ouraring.com/oauth/authorize`, token `https://api.ouraring.com/oauth/token`, scope `daily heartrate workout personal`. A provider is "configured" only when both its id and secret env vars are set; unconfigured providers answer 404.

### 1.2 Secrets and environment variables (backend/.env.example)

`PUBLIC_BASE_URL` (used to build redirect_uri; falls back to the request origin), `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `WHOOP_CLIENT_ID`, `WHOOP_CLIENT_SECRET`, `OURA_CLIENT_ID`, `OURA_CLIENT_SECRET`, `FDC_API_KEY` (food search only), `ALLOWED_ORIGINS` (extra browser origins for a self hosted web build). `.gitignore` contains `.vercel` and `.env*`. There is no vercel.json, no cron, no middleware.

### 1.3 What it stores and logs

- Persists nothing: no database, KV, blob or file writes. grep for `console.` in api/ and lib/ returns nothing, so it writes no application logs.
- In memory only: a fixed window rate limit keyed by a SHA-256 hash of `scope:ip`, 22 chars, at most 10,000 buckets, 20 requests per minute on /api/oauth/*, 60 per minute on /api/fdc/*; and a 500 entry memo of FDC answers. Resets on cold start and is not shared between instances (the code comments say so and recommend a Vercel Firewall rule).
- Responses to the app are `Cache-Control: no-store`; vendor error bodies are never forwarded (fixed `{error}` strings); success responses are filtered to the token field whitelist, so profile data in a vendor token response is dropped.
- Host level: Vercel itself keeps runtime logs (see section 7). Liftspark's PRIVACY.md and APPSTORE.md already disclose "short-lived request logs" for the FDC route and claim "keeps no database".

### 1.4 Client side flow (Liftspark, Capacitor and JS; reference for the Swift port)

integrations.js: generate `state` (32 random chars) and a 64 char verifier, S256 challenge; open `<BACKEND>/api/oauth/<id>/start?...` in ASWebAuthenticationSession (callback scheme `liftspark`, `prefersEphemeralWebBrowserSession = false`); check the returned URL is `liftspark://oauth/<id>` and `state` matches; POST code and verifier to /token; save `{access_token, refresh_token, expires_at, athlete}` as JSON in the iOS Keychain (secureSet, key `liftspark.oauth.<provider>`); refresh when under 120 s from expiry; the vendor data calls (WHOOP v2, Oura v2, Strava activities) go straight from the phone with `Authorization: Bearer`. `/api/config` is fetched only from Devices & Health, Import, the workout summary, WHOOP or Oura setup and food search, not on every launch.

### 1.5 Gaps found while reading (fix in the TriSpike copy)

1. `disconnect` only deletes the Keychain item (`secureRemove`); it does not call any vendor revoke endpoint. WHOOP says to revoke on disable, Garmin requires the deregistration call, Strava has a revoke endpoint (section 4 and 9).
2. `/callback` carries the one time `code` in the query string. Vercel runtime logs expose "Search Params" per request (retained 1 hour on Hobby), so codes and states sit in host logs for up to an hour. The codes are single use and short lived but this weakens "we never see it". Avoid the callback hop where a vendor accepts a custom scheme redirect (WHOOP examples include `whoop://example/redirect`; Oura, Strava and Garmin rules in section 4).
3. PKCE is treated as mandatory for WHOOP, but WHOOP's docs never mention PKCE. If WHOOP ignores `code_challenge`, the verifier protects nothing for WHOOP; the remaining defences are the `state` check and ASWebAuthenticationSession's own rule that only the calling app's session receives the callback.
4. `tokenRequest` collapses 400, 401 and 403 into one "Provider refused the request". The app cannot tell `invalid_grant` (user must reconnect) from `invalid_client` (our bug) or a capacity refusal. Pass through an allowlisted OAuth `error` code string only.
5. Token requests are form encoded; WHOOP's refresh example is JSON. UNVERIFIED that WHOOP accepts form encoding (standard OAuth servers do). Test on the first real token exchange.
6. Docs conflict: PLAN.md (item 6) says the Strava keys were deployed on 2026-11-04 and `/api/config` reports `strava: true`; APPSTORE.md says to keep all provider keys unset for 1.0. WHOOP and Oura apps are not yet registered per PLAN.md. So WHOOP and Oura paths are untested live.
7. Strava scope `activity:write,read` includes `read`; TriSpike's write only design needs `activity:write` only (whether Strava's authorize step accepts that alone is UNVERIFIED).
8. In memory rate limiting is best effort. Hobby allows exactly one WAF rate limit rule per project (section 7).

## 2. What changes for a new bundle id (TriSpike)

Use a separate Vercel project (suggested name `trispike-api`), not the Liftspark one. Reasons: vendor credentials may not be shared across applications (Oura Agreement 3(i); WHOOP API Terms 1.4 and 3.2 per integ-whoop.md), vendor user caps and approvals are per registered app, redirect URIs and callback domains are per app, and a TriSpike incident should not touch Liftspark.

| Item | Liftspark | TriSpike change |
|---|---|---|
| Callback scheme | `liftspark://oauth/<id>` hard coded in api/oauth/[provider]/callback.ts | `trispike://oauth/<id>` (or the final bundle based scheme); register the URL type in Info.plist; keep the provider check in the app |
| PUBLIC_BASE_URL and redirect URIs | liftspark-api.vercel.app, `/api/oauth/<id>/callback` | New domain; register exactly this redirect URI in each vendor dashboard (Strava also needs the callback domain set) |
| CORS and ALLOWED_ORIGINS | WebView origin `capacitor://localhost` | Not needed: a SwiftUI app using URLSession sends no Origin header and the code already lets null Origin through. Remove the browser origin allowance or keep it empty. |
| /api/fdc and FDC_API_KEY | Food search | Delete the route, the env var and the `fdc` key in /api/config |
| /api/config | Called on several screens | Drop it, or call it only when the user opens the Connections screen. TriSpike's rule is no network calls unless the user connects something; ship per provider availability as compile time or Info.plist flags (same pattern as the StoreKit flag) and flip each ON when the vendor approves capacity. |
| Provider scopes | WHOOP `offline read:recovery read:cycles read:workout read:sleep read:profile`; Oura `daily heartrate workout personal`; Strava `activity:write,read` | WHOOP `offline read:recovery read:sleep read:cycles` (+ `read:workout` only if used); Oura `daily` (+ `workout` only if used); Strava `activity:write` only. Minimum scopes are also required by Oura Agreement 4(c) per integ-oura.md. |
| Env vars | as 1.2 | `PUBLIC_BASE_URL`, `STRAVA_CLIENT_ID/SECRET`, `WHOOP_CLIENT_ID/SECRET`, `OURA_CLIENT_ID/SECRET`; later `GARMIN_CLIENT_ID/SECRET` only if Garmin is ever approved. Ids and secrets only in Vercel, never in the public repo (WHOOP API Terms 3.2 and Oura 3(i) bar embedding credentials in open source, per sibling notes). |
| Tests | none for the backend | Add unit tests for validators, a grep test that fails on `console.`, and a test that the token response whitelist drops unknown fields |

Native client work (new, in Swift): ASWebAuthenticationSession with a presentation anchor; CryptoKit SHA256 for S256; Keychain wrapper; a single flight refresh actor; the data calls. Liftspark's integrations.js is the logic reference.

## 3. Recommended architecture: stateless OAuth proxy, tokens in Keychain, data direct from the phone

```
iPhone (TriSpike)                      Proxy (Vercel function)                 Vendor
-------------------                     -----------------------                 ------
1 make state + PKCE verifier/challenge
2 ASWebAuthenticationSession -------->  GET /api/oauth/whoop/start?state&challenge
                                         302 to vendor authorize (adds client_id) ---> user signs in, consents
3 <------------- trispike://oauth/whoop?code&state (via /callback hop or direct custom scheme)
4 check state
5 POST /api/oauth/whoop/token {code, verifier} ---> adds client_secret, POST token ---> {access, refresh, expires}
6 <--- whitelisted token JSON (not stored, not logged)
7 write tokens to Keychain (AfterFirstUnlockThisDeviceOnly)
8 GET vendor API with Bearer token  ---------------------------------------------->  data comes straight to the phone
9 near expiry: POST /api/oauth/whoop/refresh {refresh_token} ---> new tokens, rotated ---> persist BEFORE use
```

Rules that keep it honest:

- The proxy holds exactly one secret per vendor (the client secret) and nothing per user. No database, no KV, no cache of responses, no log drain, no `console.*`, no analytics, no request body logging.
- The proxy never calls a vendor data endpoint. Only token endpoints (and Strava revoke, section 9).
- Tokens: Keychain item per provider with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Apple recommends this level for items that background work must read, and items with it do not migrate to a new device (https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly, read via the JSON feed https://developer.apple.com/tutorials/data/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly.json). The default (unlocked only) would break background refresh; the Always level is not recommended (https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility). No iCloud Keychain sync for these items.
- Rotating refresh tokens force single flight refresh. WHOOP: each refresh returns a new refresh token and the old one stops working; with concurrent refreshes only the first succeeds (https://developer.whoop.com/docs/developing/oauth). Oura: refresh token is single use (https://cloud.ouraring.com/docs/authentication). Strava: once a new refresh token is returned the older one is invalidated immediately (https://developers.strava.com/docs/authentication/). Garmin: a new refresh token is returned every time a new access token is issued (https://developerportal.garmin.com/sites/default/files/OAuth2PKCE.pdf). So: one Swift actor owns refresh; write the new refresh token to Keychain before using the new access token; background tasks and the foreground app never refresh concurrently; no refresh from widgets or extensions. If a refresh response is lost after the vendor rotated, the stateless proxy cannot recover it: the user reconnects. Map `invalid_grant` to a calm "Reconnect WHOOP" state.
- Errors: fixed vocabulary only; never show vendor text.
- ASWebAuthenticationSession: Apple says the OS shows a modal that names the domain being authenticated with and asks whether to proceed, and that the session makes sure only the calling app's session receives the callback even if several apps register the same URL scheme (https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession, read via https://developer.apple.com/tutorials/data/documentation/authenticationservices/aswebauthenticationsession.json). The domain shown will be the proxy domain, so use a domain that says TriSpike. iOS 17.4 added `ASWebAuthenticationSession.Callback` with `customScheme(_:)` and `https(host:path:)` (https://developer.apple.com/tutorials/data/documentation/authenticationservices/aswebauthenticationsession/callback.json lists introducedAt 17.4 for iOS). TriSpike's minimum is iOS 18, so an https callback is available; whether it needs an associated domain and apple-app-site-association file on the proxy domain is UNVERIFIED. Default to the custom scheme.
- Leave `prefersEphemeralWebBrowserSession` false (the default): the user is usually already signed in at WHOOP or Strava in Safari, and the app cannot read the sheet's cookies anyway.

Alternatives considered and rejected: (1) ship the client secret in the app (WHOOP states it must never be in a mobile app; trivially extractable); (2) a third party aggregator that stores vendor data (it becomes a "third-party partner" under Apple's definition and defeats Data Not Collected; not researched further); (3) a stateful TriSpike account and database (breaks the product's no accounts premise; kept as phase 2 only).

## 4. Per vendor: PKCE, native client without a secret, tokens, revoke, push

| | WHOOP | Oura | Garmin | Strava |
|---|---|---|---|---|
| Authorize URL | https://api.prod.whoop.com/oauth/oauth2/auth | https://cloud.ouraring.com/oauth/authorize (newer alternative for new clients: https://developer.ouraring.com/authorize) | https://connect.garmin.com/oauth2Confirm | https://www.strava.com/oauth/authorize ; mobile: https://www.strava.com/oauth/mobile/authorize (iOS: use ASWebAuthenticationSession if the Strava app is not installed) |
| Token URL | https://api.prod.whoop.com/oauth/oauth2/token | https://api.ouraring.com/oauth/token | https://connectapi.garmin.com/di-oauth2-service/oauth/token | https://www.strava.com/oauth/token |
| PKCE | Not mentioned in OAuth page, API reference or overview (UNVERIFIED whether accepted) | Supported, S256 only, verifier required if challenge was sent | Required: code_challenge and S256 are "required" in the authorize request; code_verifier "required" at token | Not mentioned in the authentication doc (UNVERIFIED) |
| Secret needed without a server | Yes (refresh example sends client_id and client_secret) | Yes, `client_secret` "Required if not using Basic Authorization"; docs silent on whether PKCE removes it | Yes, `client_secret` "required" on code exchange and on refresh | Yes: token exchange takes client_secret, "should never be shared" |
| Native client allowed to skip the server | No documented public client mode | No documented public client mode (a client side implicit flow exists but gives no refresh token and a 30 day token, so monthly re-consent) | No | No |
| Redirect URI rules | Must match dashboard value; custom scheme example `whoop://example/redirect` | Registered URIs are an exact match allowlist; custom schemes not mentioned | `redirect_uri` is optional in the authorize request | "Must be within the callback domain specified by the application"; localhost and 127.0.0.1 allowed (so an https hop through the proxy domain is needed) |
| State | "must be eight characters long if you need to generate it yourself" (Liftspark sends 16 to 128; UNVERIFIED accepted) | Optional, random recommended | Optional | n/a read |
| Access token life | 3600 s sample | `expires_in` returned (server flow value not stated; 30 days for the client side flow) | 86400 s | 6 hours |
| Refresh | Needs `offline` scope; rotates | Single use, rotates | New refresh token each time; `refresh_token_expires_in` 7775998 s (about 90 days) in the sample; the same PDF also says "Access tokens expire three months after they are created", an internal inconsistency | Rotates, invalidates the old one |
| Revoke (who can call it) | `DELETE https://api.prod.whoop.com/developer/v2/user/access` with the user's bearer token: phone can call it, no secret | `https://api.ouraring.com/oauth/revoke?access_token={token}` (HTTP method not stated on the page): phone can call it, no secret | `DELETE https://apis.garmin.com/wellness-api/rest/user/registration` with bearer: phone can call; Garmin says it "must be called" if the app offers a Delete My Account or Disconnect mechanism | New `POST https://www.strava.com/oauth/revoke` (recommended from 2026-06-01, the only endpoint from 2027-06-01) needs HTTP Basic with client id and secret: needs a proxy route. Legacy `POST https://www.strava.com/oauth/deauthorize?access_token=` takes only the access token until 2027-06-01. |
| Server push | Webhooks: `workout|sleep|recovery.updated|deleted`, HTTPS POST with ids only, HMAC header, 5 retries over about 1 hour; docs still recommend a reconciliation poll | Webhook subscription routes (`/v2/webhook/subscription`, renew route) authenticated with app credentials headers | Push only for Starter (Garmin calls partner endpoints); ping or pull only on Enterprise | Webhook events API, one subscription per app, 2 second response limit, 3 attempts, includes deauthorization events |
| User cap for a new app | Sandbox tier 10 members; Build 100, Growth 1,000, Scale 5,000, Production unlimited; each step after Build needs 50 percent of the current tier connected; manual review | 10 users before Oura approval; no limit after | Starter "limited" (a press figure of 1,000 is UNVERIFIED), unverified label until review | Single athlete (own account only) until upgrade to 10 from the API dashboard, then review beyond 10 |
| Rate limits (app level) | 100 per minute, 10,000 per day default | See integ-oura.md | n/a | 200 per 15 min and 2,000 per day overall, reads 100 and 1,000; 400 and 4,000 at the 10 athlete tier |

URLs read for the table: https://developer.whoop.com/docs/developing/oauth ; https://developer.whoop.com/api ; https://developer.whoop.com/docs/developing/webhooks ; https://developer.whoop.com/docs/developing/app-approval ; https://developer.whoop.com/docs/developing/rate-limiting ; https://developer.whoop.com/docs/developing/getting-started ; https://cloud.ouraring.com/docs/authentication ; https://cloud.ouraring.com/docs (10 user limit) ; https://cloud.ouraring.com/v2/static/json/openapi-1.43.json (limited to 10 users before approval; webhooks route list; sandbox endpoints `/v2/sandbox/usercollection/*`) ; https://developerportal.garmin.com/sites/default/files/OAuth2PKCE.pdf (text extracted locally with pdftotext) ; https://developer.garmin.com/gc-developer-program/overview/ ; https://developer.garmin.com/gc-developer-program/personal/personal-faq/ ; https://developers.strava.com/docs/authentication/ ; https://developers.strava.com/docs/getting-started/ ; https://developers.strava.com/docs/rate-limits/ ; https://developers.strava.com/docs/webhooks/.

Takeaways:
- A proxy is mandatory for every OAuth vendor; the design in section 3 is the minimum.
- Revocation and deregistration for WHOOP, Oura and Garmin are phone side calls with the user's bearer token. Only Strava's new revoke needs the secret, so the proxy needs one extra route, `POST /api/oauth/strava/revoke {token}`, which forwards with Basic auth and stores nothing.
- Capacity is the real constraint, not Vercel: 10 WHOOP members, 10 Oura users, 1 Strava athlete (10 after a self service upgrade) until each vendor approves. The app must hide or label each connection until its vendor has capacity. Community reports of long WHOOP approval waits are in integ-whoop.md.
- Garmin, for the record: the Personal tier is "not intended for commercial applications serving multiple end users", pull only, key expiry 30, 90, 180 days or a year, no refresh tokens (https://developer.garmin.com/gc-developer-program/personal/personal-faq/). Business Starter is "Push only", "Historical Data: Not included", user capacity "Limited"; Enterprise adds push or ping/pull and unlimited users (https://developer.garmin.com/gc-developer-program/overview/). Secondary reports: the program was closed to new applicants for about seven months and reopened on 21 October 2026, Starter apps carry an "unverified" label until reviewed, and applicants need a public website and privacy policy (https://openwearables.io/blog/garmin-connect-developer-program-reopened and https://the5krunner.com/2026/10/22/garmin-personal-api/). Garmin's own pages do not say Starter requires a legal entity (UNVERIFIED either way).
- Garmin data access for any non personal user requires a public endpoint that Garmin pushes to, which is stateful. See sections 5 and 10.

## 5. Apple App Privacy, 5.1.2 and 5.1.3 applied to the proxy

### 5.1 Apple's wording (read 2026-11-08)

Source: https://developer.apple.com/app-store/app-privacy-details/

- Definition (paraphrased): data is collected when it is transmitted off the device so that you or your third party partners can access it for longer than needed to service that request in real time. The additional guidance on the same page words it as sending data off the device and storing it in readable form for longer than the request takes to service.
- Transient server data (paraphrased): an authentication token or IP address sent on a server call and not retained, or data sent to your servers and immediately discarded after servicing the request, does not need to be disclosed.
- On device processing: data processed only on the device is not collected and need not be disclosed.
- Third parties: "'Third-party partners' refers to analytics tools, advertising networks, third-party SDKs, or other external vendors whose code you've added to your app." You must include their practices. Apple's own collection is not your responsibility.
- Optional disclosure requires all four conditions (paraphrased): not used for tracking; not used for third party advertising, your own marketing or other purposes; collection only in infrequent cases that are not part of primary functionality and are optional for the user; and the data is entered by the user in the app, it is clear what is collected, the user's name or account name is prominently shown in the submission form, and the user affirmatively chooses to provide it each time. Meeting only some means it must be disclosed.
- Health and fitness data: the page lists categories (HealthKit data under Health, Motion and Fitness API under Fitness) and gives no health specific carve out.
- App Store Connect help (https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/): answering "No, we do not collect data from this app" applies only if neither you nor third party partners collect data; "You should answer in the most comprehensive and inclusive way"; a privacy policy URL is required. The page does not address data sent to a service the user chooses (such as their own Strava account).

### 5.2 Applying it

| Flow | Leaves the device? | Held by developer or partner? | Label effect |
|---|---|---|---|
| Phase 0, HealthKit reads | No | No | None; Data Not Collected holds (spec section 9) |
| OAuth code and token exchange via proxy | Yes: one time code, verifier, tokens, IP, request time | Not by TriSpike. Vercel request logs keep path, search params, status, user agent for 1 hour on Hobby (https://vercel.com/docs/logs/runtime and https://vercel.com/docs/limits). Tokens and verifiers travel in POST bodies; runtime logs list path and search params, not bodies, and the function never logs them. | Defensible as "immediately discarded after servicing the request"; one uncertainty below |
| Vendor API calls phone -> WHOOP, Oura | Requests go to the vendor, data comes back to the phone | Vendor holds its own data; no TriSpike server in the path | None for TriSpike (inbound only); vendor policies govern the vendor side. Tell the user. |
| Strava upload phone -> Strava | Yes, a workout file leaves the phone to Strava | Strava holds it, at the user's explicit direction; not through TriSpike servers | Not addressed by Apple's page. Apple's optional criteria need "infrequent" and "not primary functionality" plus per upload consent showing the account name; a per upload consent screen can meet the last condition. Spec section 9 already commits to verify before shipping and to drop the feature or change the label if it cannot hold. |
| Garmin push | Yes: Garmin calls a TriSpike endpoint | Yes: must be stored until the phone fetches | Collected. Health and Fitness, linked to an identifier, app functionality. Label changes. |

The one genuine uncertainty: Vercel's retention of request metadata for 1 hour. An Apple DTS engineer replied on the forums that a read only request is not necessarily "no collection" because a server "might, for example, store the IP address of the client, the user agent string, and so on in its own internal logging", and that the question for App Review is theirs to answer (https://developer.apple.com/forums/thread/790810). Apple's own page says an IP address that is "not retained" need not be disclosed, and a one hour platform log is retention of a sort. Which Privacy Label category Apple would want for logged IP addresses is not stated on the page I read. So the honest status is: Data Not Collected is probably still defensible if the proxy keeps nothing of its own, but it is not guaranteed, and App Review is the only judge.

Mitigations (cheap):
1. Keep the project on Hobby (runtime logs 1 hour, no log drains) and never add `console.*`; add a CI test for it.
2. Avoid the callback hop where possible so codes never appear in search params (section 1.5).
3. No Vercel Analytics or Speed Insights on the proxy project.
4. Say it in plain words in the privacy policy and in the App Review notes (section 10 wording), including that the host keeps standard request logs for about an hour.
5. Pre decide the fallback: if Apple disagrees, update the label (not remove the feature) and ship the connection behind the flag until the label is changed in App Store Connect.

### 5.3 Review Guidelines that apply (https://developer.apple.com/app-store/review/guidelines/)

- 5.1.1(i): privacy policy link in App Store Connect and in the app; must explain what is collected, how, all uses, retention, deletion and revoking consent. It also asks you to confirm that "any third party with whom an app shares user data" gives equal protection to what the policy states. The page text I read cut off after 5.2.5, so later items were not read.
- 5.1.1(iii) data minimisation: request only data relevant to core functionality (supports minimum scopes).
- 5.1.2(i) (paraphrased): you may not use, transmit or share someone's personal data without their permission, must clearly disclose where it is shared with third parties, and need explicit permission first. The same item also limits sharing of data collected from apps to improving the app or serving advertising; my reading is that this targets data the developer collects, not a user directed export, but it is a reason to keep the Strava upload explicitly user initiated and consented. UNVERIFIED how App Review treats it.
- 5.1.3(i) (paraphrased): health, fitness and medical data, including HealthKit and Motion and Fitness, may not be used or disclosed to third parties for advertising, marketing or use-based data mining beyond improving health management or health research, and then only with permission; you must disclose the specific health data you collect from the device. TriSpike reads HealthKit data for training features only; the policy lists the exact types.
- 5.1.3(ii): no false or inaccurate data written into HealthKit and no personal health information in iCloud. So WHOOP, Oura and Garmin derived signals never go into HealthKit and never into CloudKit or share codes (spec section 9 already bans HealthKit derived data in iCloud).
- 2.5.1: HealthKit "should be used for health and fitness purposes and integrate with the Health app".
- 4.8 Login Services: applies to third party login that "set[s] up or authenticate[s] the user's primary account"; TriSpike has no account and vendors are data connections, so no Sign in with Apple obligation. The guideline also exempts "a client for a specific third-party service" (https://developer.apple.com/app-store/review/guidelines/).
- 5.1.1(v) account deletion applies if the app supports account creation; TriSpike does not.
- App Review must be able to test the connection: WHOOP has no fake data sandbox (integ-whoop.md); Oura offers `/v2/sandbox/usercollection/*` endpoints (OpenAPI 1.43) but they still require an authorized token. Ship vendor connections OFF by flag in the first review (the Info.plist flag pattern) or provide a screen recording plus a demo path in the review notes; never block review on a ring.

### 5.4 Consent UX that satisfies both Apple and the vendors

- Connect screen before the system sheet states: what TriSpike will read from the vendor (exact fields), why (adjust today's session), that the phone talks to the vendor directly, that TriSpike's small sign-in helper handles the one time code and tokens in transit and keeps nothing, and how to disconnect.
- Strava upload consent screen per upload: shows the activity name, sport, date and which fields travel (distance, duration, heart rate, power, route as present) and the Strava account name; two buttons. Oura Agreement 5(a) wants consent that is "specific, informed, unambiguous" and says how to revoke; WHOOP terms 2.1 want "expressly authorized by each end user" (per integ-oura.md and https://developer.whoop.com/api-terms-of-use/).
- HealthKit limited authorization: Apple lets people grant only a recent window of history, and the app "can't distinguish between full access and denied access" for specific types (https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data, read via the JSON feed). So phase 0 must handle thin or empty data without assuming denial, and say "no data yet" calmly.

## 6. Webhooks versus polling for a phone app

Vendor push options all need a public HTTPS endpoint, and every one of them delivers ids or full payloads for all of an app's users, not for one phone:

- WHOOP webhooks carry `user_id`, `id`, `type`, `trace_id` (a change notice, not the data); retried 5 times over about 1 hour; the docs recommend a periodic reconciliation fetch anyway (https://developer.whoop.com/docs/developing/webhooks).
- Oura webhooks are recommended by Oura ("Webhook notifications come approximately 30 seconds after data syncs from the mobile app") but need app credential headers and per data type subscriptions that expire and must be renewed (https://cloud.ouraring.com/v2/static/json/openapi-1.43.json; third party summary of the create call at https://hookdeck.com/webhooks/platforms/guide-to-oura-webhooks-features-and-best-practices, not verified against Oura's page).
- Strava webhooks: one subscription per app, 200 within 2 seconds, up to three attempts (https://developers.strava.com/docs/webhooks/).
- Garmin: Starter is push only (https://developer.garmin.com/gc-developer-program/overview/).

To wake a phone from such an event you would need: a database mapping vendor user id to device push token and to the vendor access token (so the server can fetch what changed), an APNs key, and a sender. Apple: background notifications (`content-available: 1`, `apns-push-type: background`, `apns-priority: 5`) are low priority, delivery is not guaranteed, they may be throttled, and senders should not exceed two or three per hour; the app then gets up to 30 seconds (https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app via https://developer.apple.com/tutorials/data/documentation/usernotifications/pushing-background-updates-to-your-app.json). That is a stateful design: it fails "Data Not Collected" and Oura's "strictly necessary" retention language. Not for 1.x.

Phone side polling plan (no backend):
1. Foreground: on app open and on opening Today, if the last successful fetch for a provider is older than a threshold (suggest 3 hours) then fetch. WHOOP: recovery, sleep, cycle; Oura: `daily_readiness`, `daily_sleep`; both a handful of requests per day per user. Straight against 100 per minute and 10,000 per day (WHOOP), 200 per 15 minutes and 2,000 per day (Strava): at one sync per user per day of about 4 calls, WHOOP's daily cap would support thousands of users (my arithmetic, assumes the cap is app wide, which the page does not state outright).
2. Morning BGAppRefreshTask: Apple says app refresh tasks are for "small bits of information", the system "decides the best time to launch your background task" and provides up to 30 seconds (https://developer.apple.com/tutorials/data/documentation/backgroundtasks/choosing-background-strategies-for-your-app.json); no guarantee of timing, and the user can switch Background App Refresh off. Treat as best effort.
3. HealthKit background delivery as a wake signal: `enableBackgroundDelivery` needs the background delivery entitlement on iOS 15 and later and wakes the app when samples of the type are saved or deleted, at most once per period (some iOS sample types are capped at hourly); observer queries must be set up at app launch and the update handler's completion handler must be called, or after three failures HealthKit stops sending background updates (https://developer.apple.com/tutorials/data/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:).json and https://developer.apple.com/documentation/healthkit/hkobserverquery). Idea to test on a real device: when the user's WHOOP or Oura app writes last night's sleep into Apple Health, the observer wakes TriSpike, which can then fetch the vendor's recovery with the Keychain token. How long that wake lasts is not stated on the pages I read (UNVERIFIED, test). Not supported on the Simulator.
4. Always show "as of <time>" on any vendor derived card so a stale value is honest.

## 7. Vercel Hobby: limits, terms, cold start, secrets

Sources: https://vercel.com/docs/plans/hobby , https://vercel.com/docs/limits , https://vercel.com/docs/limits/fair-use-guidelines , https://vercel.com/docs/functions/limitations , https://vercel.com/docs/fluid-compute , https://vercel.com/docs/logs/runtime , https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting , https://vercel.com/docs/environment-variables/sensitive-environment-variables (all read 2026-11-08).

- Terms: "Hobby teams are restricted to non-commercial personal use only." Commercial use is any deployment "used for the purpose of financial gain of anyone involved in any part of the production of the project, including a paid employee or consultant writing the code" with examples: requesting or processing payment, advertising a product or service for sale, receiving payment to create, update or host the site, affiliate linking, advertisements. "Asking for Donations does not fall under commercial usage." A free app with no revenue and no ads fits. If TriSpike ever turns revenue on (the StoreKit flag), the proxy must move to Pro (developer seats $20 per user per month per the Hobby page).
- Included usage per month: 1,000,000 function invocations, 4 CPU hours of Active CPU, 360 GB hours provisioned memory, 100 GB Fast Data Transfer, 10 GB Fast Origin Transfer. Over limits: "you will have to wait until 30 days have passed before you can use the feature again." So an overrun means the sign-in helper stops for up to 30 days.
- Function limits: 300 s max duration on Hobby, 2 GB memory, 4.5 MB request and response body, 250 MB bundle, auto scales to 30,000 concurrency. Irrelevant for a token swap except as headroom.
- My capacity estimate (assumptions stated, not measured): each user needs about 3 requests to connect and about 1 to 2 refreshes a day. At 2 requests per user per day, the 1,000,000 invocation cap supports roughly 16,000 daily users; the Active CPU cap (4 hours) is the likelier ceiling, and at an assumed 30 ms CPU per request it supports roughly 8,000 daily users. Both are far above what vendor caps (10 users each to start) allow, so vendor approval is the binding limit, not Vercel.
- Cold start: Fluid compute is on by default for new projects since 2025-04-23 and offers "automatic bytecode optimization" and "function pre-warming on production deployments"; bytecode caching applies to production only and the first request is not cached. The page gives no millisecond numbers. Runtime logs now show the function start type, so measure after deploy. The sign-in flow can absorb a cold start because the user is looking at a vendor consent page; the token exchange should show a progress state and use the existing 10 s upstream timeout.
- Logs: Hobby runtime logs are retained 1 hour; log details include request path, search params, user agent, region and function metadata. Log drains are not available on Hobby (Pro only), which is good for this design.
- Rate limiting: WAF rate limiting is available on Hobby with one rule per project (counting keys IP and JA4, fixed window, window 10 s to 10 minutes) inside a total of 3 custom firewall rules; counters are tracked per region. Create one rule on `/api/oauth/` at about 20 requests per minute per IP and keep the in memory limiter as a second layer.
- Secrets: use the Secret type for client secrets (write only after saving; build logs redact a Secret value of 32 characters or longer; Secrets are allowed in Development). Use Config type for client ids if wanted. Never commit `.env*` (already gitignored in Liftspark). Optional team policy "Separate Production Secret Values". Rotate a vendor secret in the vendor dashboard and re-enter it in Vercel; the app needs no update because it never holds the secret.
- Project hygiene: TriSpike proxy in its own project, personal scope, no analytics, no drains, Deployment Protection must not block the public endpoints that the app calls (verify after the first deploy that unauthenticated POSTs from a device succeed).

## 8. Strava: the single player rule and write only upload

Sources: https://developers.strava.com/docs/getting-started/ , https://developers.strava.com/docs/authentication/ , https://developers.strava.com/docs/uploads/ , https://developers.strava.com/docs/rate-limits/ , https://developers.strava.com/guidelines/ , https://www.strava.com/legal/api (effective 2026-06-01).

- Single player mode: "New apps start in single-player mode, so only your own account can connect." A Strava subscription is a prerequisite for creating an app. Self service upgrade from the API Settings Dashboard raises capacity to 10 athletes (overall 400 per 15 minutes and 4,000 per day, reads 200 and 2,000). "Scaling beyond 10 athletes requires app review" via the Developer Program form, with screenshots of everywhere Strava data and the "Connect with Strava" button appear; increased access is "not a guarantee". Rate limit page says apps with under 100 users should not need increases (use webhooks, throttle backfill).
- Therefore: at launch the Strava connection works for the owner only until the upgrade to 10; users 11 and beyond need review. Graceful behaviour: Strava off by flag in store builds until the athlete capacity exists; if the vendor refuses (the proxy maps 400, 401, 403 to "Provider refused"), show "Strava is not available to more people yet" instead of an error. What exact error Strava returns when the athlete limit is hit is UNVERIFIED.
- Agreement (effective 2026-06-01): data from a user "can only be displayed or disclosed in your Developer Application to that user"; no sharing of user data with other users or third parties without explicit consent; "may not create applications that compete with or replicate Strava functionality"; Section 7.1 allows an app to "include the option to upload activities or information"; on termination permanently delete Strava API Materials and data; the page states no storage duration and no AI/ML clause, and mentions no "single player" term (that term is from the getting started guide). Because TriSpike never reads Strava data except the upload status, display and storage restrictions are nearly moot; keep it that way.
- Write only: scope `activity:write` ("manual activities, uploads, and editing activities the app can see"). Upload is `POST https://www.strava.com/api/v3/uploads` multipart with a FIT, TCX or GPX file (gzip allowed); JSON uploads are accepted only for WeightTraining, HighIntensityIntervalTraining, Workout and Crossfit, so run, ride and swim need a TCX or FIT file built on device. Processing is asynchronous: poll `GET /api/v3/uploads/:id` no faster than once a second; mean processing under 2 seconds; duplicates are rejected with a message like "duplicate of activity ...". Set a unique `external_id` per workout for idempotency. Reading the upload status is the only Strava read; do not call activity endpoints.
- Rate limits for uploads: they count toward the overall limit, not the read limit.
- Brand: use the "Connect with Strava" button (48 px at 1x, orange or white) linking to the OAuth URL; "Powered by Strava" or "Compatible with Strava" wording exactly; "View on Strava" link styling if linking back; never put "Strava" in the app name or use Strava logos as the icon.
- Revocation: new revoke endpoint needs the secret (proxy route), legacy deauthorize takes an access token only and works until 2027-06-01. Strava sends an `athlete` webhook with `authorized: false` on deauthorization, but without a server the phone only learns about it via a 401 on the next call; with no stored Strava data this is harmless.
- Privacy: file leaves the phone for Strava only after the per upload consent screen (section 5.4). HealthKit derived heart rate or route in the file counts as sharing health data with a third party at the user's direction (5.1.3(i) read in section 5.3).

## 9. Minimal on device data model, deletion and disconnect

Stores: SwiftData for non secret state, Keychain for credentials. Neither is part of CloudKit sync, share codes, or exports (spec section 9; enforce with the schema unit test the spec already requires, extended to these types).

```
enum Provider { appleHealth, whoop, oura, strava, garmin }          // garmin reserved, unused in 1.x
enum ConnState { notConnected, connected, needsReconnect, revokePending }

IntegrationConnection            // at most one row per provider
  provider: Provider (unique)
  state: ConnState
  connectedAt: Date?
  lastAttemptAt: Date?           // last time we tried to sync
  lastSuccessAt: Date?           // drives "as of" labels and staleness
  lastError: ErrorCode?          // our own enum (reconnect, rateLimited, offline, capacity, vendorDown); never vendor text
  requestedScopes: [String]      // what we asked for; echoed scope values are unreliable (Oura says so)
  accountLabel: String?          // optional display name the token response happened to carry; omit if unneeded

DailySignal                      // cache, unique on (provider, dayKey, kind)
  provider: Provider
  dayKey: String                 // local calendar day as the vendor defines it, "2026-11-08"
  kind: SignalKind               // hrvMs, restingHr, sleepMinutes, vendorRecoveryPct, vendorReadinessPct, ...
  value: Double
  state: scored | pending | unscorable   // WHOOP score_state values: SCORED, PENDING_SCORE, UNSCORABLE
  fetchedAt: Date
  expiresAt: Date                // hard TTL, purged on launch and in the background task
```

Keychain (one item per provider, key `trispike.oauth.<provider>`): JSON `{access, refresh, expiresAt}`; accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; not synchronizable. Nothing else is persisted from a vendor: no raw JSON responses, no names, no emails (do not request `read:profile` or Oura `personal`/`email`).

Retention rules to set per provider as constants so they can be tightened or zeroed without a migration: WHOOP API Terms 4.2(2) bar "permanent copies" and cached copies "longer than permitted by the cache header" and 2.4(ii) asks for encryption at rest; Oura Agreement 3(m) says API data "may not be stored or retained beyond the duration strictly necessary" and 5(f) requires deletion within 72 hours of a deletion request and stopping processing on opt out (https://developer.whoop.com/api-terms-of-use/ and https://cloud.ouraring.com/legal/api-agreement). Neither says what an on device rolling baseline may keep. Until each vendor answers in writing (integ-whoop.md and integ-oura.md list the questions), default to a short TTL (suggest 7 days of raw daily values, long enough for a 7 day baseline), store derived adjustments only as plain reason lines ("Recovery was below your usual, so Thursday's hard run became easy") that keep a band, not the number, and keep the engine able to run on a 0 day cache. The device encryption at rest requirement is met by iOS Data Protection on the SwiftData file (set file protection to complete until first user authentication or stricter) - UNVERIFIED that this satisfies WHOOP 2.4(ii); ask.

### 9.1 Disconnect (user taps Disconnect and erase)

1. Mark `revokePending`.
2. Call the vendor revoke: WHOOP `DELETE /v2/user/access`; Oura `oauth/revoke`; Garmin `DELETE .../user/registration` (if ever); Strava proxy route `/api/oauth/strava/revoke` (or legacy deauthorize before 2027-06-01).
3. On success or on a definitive 401 or 400 from the vendor (already revoked): delete the Keychain item, delete all `DailySignal` rows for the provider, clear cached adaptation inputs that came from it, set the row to `notConnected`, and make the engine fall back to Apple Health or no signal. Show what was deleted.
4. If offline or the vendor errors (5xx): keep only the Keychain token needed to retry, delete all cached signals immediately (stop processing now, as Oura 5(f) wants), keep state `revokePending`, retry on next launch with backoff, and show "Disconnected on this phone. Finishing with <vendor> when you are back online. You can also remove TriSpike in <vendor> settings" with the vendor's connected apps location.
5. Never leave the user connected on the vendor side silently: WHOOP says revoke when the user disables the integration, and revoking also stops WHOOP webhooks for that user.

### 9.2 Vendor side revoke discovered later

If a refresh returns `invalid_grant` or a data call returns 401 after a refresh, the user revoked at the vendor (or the token chain broke). Set `needsReconnect`, purge that provider's cached signals right away (the user withdrew consent), and offer Reconnect.

### 9.3 Reset everything and app deletion

Reset everything: run 9.1 for every connected provider, then delete the store. App deletion: the SwiftData store goes with the app, but Keychain items can outlive an uninstall on iOS (widely reported, not verified against an Apple page here, UNVERIFIED). Guard with a first launch marker stored outside the Keychain: if the marker is absent but Keychain items exist, delete them and best effort revoke. Using `ThisDeviceOnly` also keeps tokens out of device backups restored elsewhere.

### 9.4 What the adaptation engine sees

A single internal `ReadinessInput` struct: day, per source optional values (HRV ms, resting HR, sleep minutes, vendor recovery or readiness percent), `asOf`, and `source`. Rules prefer vendor recovery bands when present and fresh, else Apple Health derived values, else nothing, and every adjustment prints the reason line naming its source. Missing data never blocks a session; consistent with spec section 3.3 (transparent rules, reason lines).

## 10. Phased build and disclosures

### Phase 0 (1.0): Apple Health only, no server

- Build: HealthKit reads for resting heart rate, HRV (SDNN), sleep, workouts, plus WorkoutKit delivery (spec sections 4 and 9). Observer queries and background delivery for wakes. No network calls, no proxy.
- What it covers: what each device's own app writes to Health. Per secondary sources (https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin dated 2026-08-11, which cites vendor support pages, and Oura's own article https://support.ouraring.com/hc/en-us/articles/360025438734): Oura exports active energy, heart rate in one minute intervals, respiratory rate, sleep with stages, steps, workouts and routes, weight and height, but not HRV, readiness or resting heart rate by name; WHOOP writes heart rate, resting heart rate, respiratory rate, SpO2, sleep, steps, active energy and workouts but states it "does not export HRV data to Apple Health at this time" and does not write Recovery or Strain; Garmin writes heart rate, sleep, steps, active energy and workouts but not Body Battery or Training Readiness, and its sync is one way. So phase 0 gives completed workouts and sleep for all three, resting heart rate for WHOOP, HRV only from Apple Watch, and none of the proprietary scores. The WHOOP/Oura/Garmin official support pages for WHOOP and Garmin were not read directly (UNVERIFIED), see integ-apple-health.md.
- Label: Data Not Collected. Policy: everything stays on the phone; list the HealthKit types read; never used for advertising or sold; not in iCloud; "If you wear a WHOOP, Oura or Garmin, TriSpike can use what that device's app saves to Apple Health. TriSpike does not connect to those companies."
- Info.plist: the HealthKit purpose strings only (spec section 9).

### Phase 1a (1.1 or later): stateless proxy, WHOOP and Oura read, Strava write only

- Build: the TriSpike proxy (section 2), Swift sign-in and Keychain, polling (section 6), disconnect and erase (section 9), per provider flags OFF until the vendor grants capacity (section 4), Strava upload with per upload consent.
- Label: still targeted Data Not Collected with the section 5 uncertainty documented; add App Review notes that explain the helper, that it stores nothing, and that connections are optional. If App Review disagrees, update the label before release.
- Privacy policy additions (plain words, no dashes in copy):
  1. What connecting does: you sign in on the vendor's own page; TriSpike never sees your vendor password.
  2. The helper: "TriSpike uses a small server function to exchange the one time sign-in code for access tokens, because the vendors require a secret that cannot be stored in an app. It does not store tokens or health data. The host, Vercel, keeps standard request logs (time, address, page and result) for about an hour." Name the host.
  3. Tokens are kept in your iPhone Keychain. Health data is fetched directly from the vendor to your phone.
  4. What is read per vendor (exact fields), what is cached on the phone and for how long, and that it is never put in iCloud, share codes or backups.
  5. Strava: only the workout you choose is sent, only when you confirm; TriSpike does not read your Strava data.
  6. How to disconnect and what that deletes; where to revoke at each vendor.
  7. Not used for advertising, marketing, data mining, AI model training (WHOOP 4.2(3), Oura 4(a)(iii) and 6(g)), not sold.
  8. That vendor privacy policies govern the vendor's own copy of your data.
- Vendor onboarding: each vendor wants the privacy policy URL set in its dashboard before limit increases (WHOOP app approval page) and the brand rules followed (WHOOP, Strava).

### Phase 1b: Garmin (not recommended for 1.x)

- Required: Garmin Starter approval (reopened 2026-10-21 per secondary reports; push only; limited capacity), a public HTTPS endpoint that receives Garmin pushes, a datastore holding pushed data keyed by Garmin user id until the phone fetches, and a way to pair a phone to a Garmin user id (an install id). That is a stateful backend with an identifier: label becomes Health and Fitness plus Identifiers, linked to the user, app functionality; policy gains retention, deletion and a server side delete path; Garmin's `DELETE user/registration` must be called on disconnect.
- Alternatives that keep the label: Apple Health import (phase 0); FIT file import from Files; Garmin BLE heart rate broadcast for live sessions; Garmin Personal tier is for the developer's own data only, so it cannot ship.

### Phase 2 (only if justified by retention data): stateful relay for webhooks and silent push

- Needs a small database with encrypted tokens or event ids, APNs, deletion and export endpoints, a DPA with the host, retention TTLs of days, and a rewritten label and policy. Not before there is evidence that foreground and background polling is too stale.

## 11. Hardening checklist for the proxy (before any vendor goes live)

- Validate: provider allowlist; `state`, `code`, `code_verifier`, `refresh_token` regexes (Garmin code and token formats UNVERIFIED, test `OPAQUE` length limits); JSON content type and size caps; fixed error strings.
- Keep: no `console.*`, no body logging, whitelist response fields, `Cache-Control: no-store`, 10 s upstream timeout, 429 passthrough with Retry-After.
- Add: allowlisted OAuth `error` passthrough (section 1.5), Strava revoke route, `redirect_uri` consistent between authorize and token if the direct custom scheme variant is used.
- Vercel: one WAF rate limit rule on `/api/oauth/`; Deployment Protection off for the public routes; Secrets for client secrets; no Analytics, no Speed Insights.
- Test live against WHOOP, Oura and Strava once each app is registered; record in the repo what worked (form encoding for WHOOP, PKCE acceptance, state length, custom scheme redirects, Strava `activity:write` alone).
- Remember that the repo is public: no ids, secrets, tokens, test accounts or owner details in commits.

## 12. Open questions

1. Does Apple App Review accept "Data Not Collected" for a pass through helper hosted on a platform that keeps request logs for 1 hour? Which Privacy Label category would apply to logged IP addresses if not? (Only App Review can answer; add to review notes and consider asking Apple Developer Support before 1.1.)
2. Does WHOOP's authorization server accept and enforce PKCE `code_challenge`? Does the token endpoint accept `application/x-www-form-urlencoded` for the code exchange and refresh? Is state of 16 to 128 characters accepted?
3. Do Oura, Strava and Garmin accept a custom scheme redirect URI directly (no proxy callback hop)? Strava's "callback domain" rule suggests not.
4. Does Oura require the new authorize URL https://developer.ouraring.com/authorize for new OAuth clients, and what HTTP method does `oauth/revoke` take?
5. What does Strava return when the athlete capacity is reached, and does `activity:write` work as the only scope (without `read`) on the mobile authorize endpoint?
6. Garmin: is Starter really open to an individual without a legal entity, what is the real user cap, does Training API workout import work with a phone side call using the user's bearer token (docs page for the Training API returned 404), and what does "unverified app" do to new user connections? Official Garmin Activity API and Health API pages returned 404 at the URLs tried.
7. Garmin token lifetimes: the PDF says both a 24 hour access token with a roughly 90 day refresh token and "Access tokens expire three months after they are created".
8. What cache or retention is acceptable on device for WHOOP data (cache header values unknown) and Oura data ("strictly necessary")? Written answers from api support at each vendor are needed before storing any baseline longer than a few days.
9. Does iOS Data Protection at rest satisfy WHOOP's "encrypted at rest" clause for a SwiftData store?
10. Does an ASWebAuthenticationSession `.https(host:path:)` callback need an associated domain and an apple-app-site-association file on the proxy domain?
11. How long does a HealthKit background delivery wake give the app, and does it reliably follow vendor app writes (test on device)?
12. Do Keychain items survive app deletion on current iOS, and what is the best first launch cleanup?
13. Exact Vercel cold start latency on Hobby for this function (measure after deploy), and whether a Hobby project's runtime log retention applies to `Search Params` as displayed.
14. Is a per upload Strava consent screen enough for the optional disclosure criteria, or does Apple expect Strava to be listed anyway?
15. Does Oura's webhook subscription cadence matter at all (not needed unless phase 2)?

## 13. URL index (read 2026-11-08)

Apple: https://developer.apple.com/app-store/app-privacy-details/ ; https://developer.apple.com/app-store/review/guidelines/ ; https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/ ; https://developer.apple.com/forums/thread/790810 ; https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession (JSON feed https://developer.apple.com/tutorials/data/documentation/authenticationservices/aswebauthenticationsession.json and .../aswebauthenticationsession/callback.json) ; https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:) (JSON feed) ; https://developer.apple.com/documentation/healthkit/hkobserverquery ; https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data ; https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app ; https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app ; https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility ; https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly . (The HTML doc pages render client side; text was read from the same paths under https://developer.apple.com/tutorials/data/documentation/.)

WHOOP: https://developer.whoop.com/docs/developing/oauth ; https://developer.whoop.com/api ; https://developer.whoop.com/docs/developing/webhooks ; https://developer.whoop.com/docs/developing/getting-started ; https://developer.whoop.com/docs/developing/overview ; https://developer.whoop.com/docs/developing/app-approval ; https://developer.whoop.com/docs/developing/rate-limiting ; https://developer.whoop.com/docs/developing/user-data/recovery ; https://developer.whoop.com/api-terms-of-use/ .

Oura: https://cloud.ouraring.com/docs ; https://cloud.ouraring.com/docs/authentication ; https://cloud.ouraring.com/legal/api-agreement (OURA API AND MCP AGREEMENT, effective June 8, 2026) ; https://cloud.ouraring.com/v2/static/json/openapi-1.43.json ; https://support.ouraring.com/hc/en-us/articles/360025438734 ; https://hookdeck.com/webhooks/platforms/guide-to-oura-webhooks-features-and-best-practices (search snippet only).

Garmin: https://developer.garmin.com/gc-developer-program/overview/ ; https://developer.garmin.com/gc-developer-program/personal/personal-faq/ ; https://developer.garmin.com/gc-developer-program/enterprise/program-faq/ ; https://developerportal.garmin.com/sites/default/files/OAuth2PKCE.pdf ; secondary: https://openwearables.io/blog/garmin-connect-developer-program-reopened ; https://the5krunner.com/2026/10/22/garmin-personal-api/ ; search snippet pages for push behaviour at https://developerportal.garmin.com/developer-programs/connect-api and https://developer.garmin.com/gc-developer-program/enterprise/activity-api (not opened).

Strava: https://developers.strava.com/docs/getting-started/ ; https://developers.strava.com/docs/authentication/ ; https://developers.strava.com/docs/uploads/ ; https://developers.strava.com/docs/rate-limits/ ; https://developers.strava.com/docs/webhooks/ ; https://developers.strava.com/guidelines/ ; https://www.strava.com/legal/api .

Vercel: https://vercel.com/docs/plans/hobby ; https://vercel.com/docs/limits ; https://vercel.com/docs/limits/fair-use-guidelines ; https://vercel.com/docs/functions/limitations ; https://vercel.com/docs/fluid-compute ; https://vercel.com/docs/logs/runtime ; https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting ; https://vercel.com/docs/environment-variables/sensitive-environment-variables .

Apple Health coverage (secondary): https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin .

Local: <repos>/liftspark/{README.md, PLAN.md, PRIVACY.md, APPSTORE.md, backend/**, app/src/lib/integrations.js, app/ios/App/App/WebAuthPlugin.swift} ; <repos>/bikefit/docs/specs/tri-spec.md sections 3, 4, 8, 9 ; sibling notes integ-whoop.md, integ-oura.md.
