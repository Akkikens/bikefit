# WHOOP integration notes (TriSpike)

Research date: 2026-11-08. Scope: WHOOP developer platform, for a free iPhone triathlon app (TriSpike) that reads recovery and training signals and adapts the plan. Every fact below names the exact URL read. Items marked UNVERIFIED could not be confirmed from a primary source. No personal data about the owner is recorded here.

## 0. Bottom line

- Technically straightforward: OAuth 2.0 authorization code flow, read-only REST API v2, six read scopes, JSON, generous default rate limits. There is NO write API, so nothing (structured workouts, plans) can be pushed to WHOOP.
- The client secret must live on a server. The WHOOP docs say it must never be in a mobile app. The existing thin Vercel backend pattern (OAuth proxy that only exchanges codes and refreshes tokens) fits.
- The hard parts are policy, not code:
  1. A new app is capped at 10 connected WHOOP members until WHOOP approves a higher tier. Community reports in 2026 describe approval requests going unanswered for months.
  2. The API Terms (effective 2026-10-06) forbid "permanent copies" of WHOOP Data, bound caching by a cache header, define WHOOP Data to include "copies or derivatives", and forbid use of the API to "compete, directly or indirectly" with WHOOP. A training plan that adapts to WHOOP recovery sits close to the edge of two of these clauses and needs a written answer from WHOOP before launch.
  3. WHOOP brand rules say recommendations must not contradict WHOOP coaching and its metrics must not be renamed or recolored.
  4. Developer credentials, including the client ID, may not be embedded in open source projects. The TriSpike repo is public, so IDs and secrets live only in Vercel environment variables.
- Cheap fallback that needs no approval: WHOOP can write workouts and sleep to Apple Health (secondary sources), and TriSpike already reads HealthKit. That gives completed workouts but not the Recovery score.

## 1. Platform basics

- Developer platform home and overview: https://developer.whoop.com/docs/introduction and https://developer.whoop.com/docs/developing/overview
  - A WHOOP membership is required to develop an app (your WHOOP account is the developer login). Apps are registered in the dashboard at https://developer-dashboard.whoop.com. Up to 5 apps per account; more via "Open Request" then "App limit increase".
  - Each app has a Client ID and Client Secret.
- API access is free today: https://developer.whoop.com/api-terms-of-use/ (section 1, Pricing: "currently provided at no charge", WHOOP gives prior notice before charging). FAQ agrees: https://developer.whoop.com/docs/developing/support
- FAQ says "no sandbox is offered" (meaning no fake test data; every developer needs a real WHOOP device): https://developer.whoop.com/docs/developing/support . Do not confuse it with the "Sandbox tier" of the user cap below.
- Create-an-app page: https://developer.whoop.com/docs/developing/getting-started
  - At least one scope and at least one redirect URI are required. The redirect URI in the OAuth request must match the dashboard value exactly. Multiple allowed. Example forms shown include a custom scheme (`whoop://example/redirect`) and https.
  - Quote: the Client Secret "should never be exposed in a client, web, or mobile application" (paraphrase checked against the page; secret is server side only).
  - Team required: you are prompted to create a Team first.
- Support channel: dashboard support form and "Open Request" only (https://developer.whoop.com/docs/developing/support). The terms name apisupport@whoop.com for limit requests (https://developer.whoop.com/api-terms-of-use/ section 1, API Limitations) and security-notifications@whoop.com for incidents. A 2026 community post reports mail to developers@whoop.com bounced (https://www.community.whoop.com/t/app-approval-10-user-limit-submitted-jun-22-and-again-jul-29-no-response-in-64-days-soluno/16008), so prefer the dashboard form.

## 2. OAuth 2.0

Primary sources: https://developer.whoop.com/docs/developing/oauth , the machine readable spec https://api.prod.whoop.com/developer/doc/openapi.json , and the rendered reference https://developer.whoop.com/api .

- Authorization URL: `https://api.prod.whoop.com/oauth/oauth2/auth`
- Token URL (also used for refresh): `https://api.prod.whoop.com/oauth/oauth2/token`
- API base (OpenAPI `servers`): `https://api.prod.whoop.com/developer` , paths then start `/v2/...`
- Flow: authorization code. Send the access token as `Authorization: Bearer`. 401 on invalid or expired token.
- State: required CSRF value. The OAuth page states "The state parameter must be eight characters long if you need to generate it yourself." Ambiguous whether longer values are accepted. The Liftspark backend validates state as 16 to 128 base64url characters (liftspark/backend/lib/providers.ts, STATE regex). UNVERIFIED that WHOOP accepts that length. Test on the first real authorization.
- Access token lifetime: sample response shows `expires_in` 3600 seconds (OAuth page). The FAQ says refresh hourly.
- Refresh: POST to the token URL with `grant_type=refresh_token`, `refresh_token`, `client_id`, `client_secret`, `scope=offline`. Response has `access_token`, `expires_in`, `refresh_token`, `scope`, `token_type`.
  - Each refresh invalidates the previous access token AND the previous refresh token. With concurrent refreshes only the first succeeds. If the response is lost after WHOOP rotated the token, the user must reconnect. Implication: on device, serialize refreshes in one actor and persist the new refresh token before using it.
- `offline` scope is required to receive a refresh token at all (OAuth page and FAQ).
- Revocation: `DELETE /v2/user/access` (scope list empty, OAuth auth) revokes the user's access and stops webhooks for that user (OAuth page, OpenAPI). The OAuth page says to call it when a user disables your integration. FAQ: members need an easy way to disconnect and can also revoke inside the WHOOP app (https://developer.whoop.com/docs/developing/support).

### Scopes (exact names, from the OpenAPI securitySchemes)

| Scope | Grants |
|---|---|
| `read:recovery` | Recovery score, HRV, resting heart rate (plus SpO2 and skin temp fields) |
| `read:cycles` | Day strain, average and max heart rate over a physiological cycle, kilojoules, step count |
| `read:workout` | Workouts: strain, average and max heart rate, zones, sport name |
| `read:sleep` | Sleep performance and stages |
| `read:profile` | Name and email |
| `read:body_measurement` | Height, weight, max heart rate |
| `offline` | Refresh token (documented on the OAuth page, not listed in the OpenAPI scopes map) |

The Liftspark backend requests `offline read:recovery read:cycles read:workout read:sleep read:profile` (liftspark/backend/lib/providers.ts). Suggested for TriSpike: `offline read:recovery read:sleep read:cycles read:workout`, optionally `read:body_measurement` (WHOOP computed max heart rate could seed zones, but TriSpike has its own LTHR based zones). Skip `read:profile`: it returns email and name, which TriSpike does not need, and the docs tell developers to request only scopes they use (getting-started page).

### Can a native app use PKCE and skip the server?

- No. The secret is required in the refresh body (OAuth page) and the getting-started page forbids shipping it in a mobile app. A server (or serverless function) must hold it.
- PKCE is not mentioned anywhere on the WHOOP OAuth page, in the OpenAPI spec or in the getting-started page. Whether the authorization server accepts or enforces `code_challenge` is UNVERIFIED. The existing Liftspark proxy passes an S256 challenge through to WHOOP and treats it as mandatory for WHOOP (liftspark/backend/api/oauth/[provider]/start.ts). A third party integration guide hints at forwarding PKCE to WHOOP (https://poke.com/docs/developers/integrations/examples/whoop-integration) but does not state WHOOP enforces it. Test against a real WHOOP app before relying on it; the state check plus the secret remain the real protections either way.

## 3. Data: endpoints and fields (API v2)

Source for everything in this section: the OpenAPI spec https://api.prod.whoop.com/developer/doc/openapi.json (parsed directly; required and optional flags come from its `required` arrays) cross-checked with https://developer.whoop.com/api .

### Endpoints (all GET unless noted; all under `https://api.prod.whoop.com/developer`)

| Path | Scope | Notes |
|---|---|---|
| `/v2/recovery` | read:recovery | collection, paginated |
| `/v2/cycle/{cycleId}/recovery` | read:recovery | one recovery |
| `/v2/cycle`, `/v2/cycle/{cycleId}` | read:cycles | day strain |
| `/v2/cycle/{cycleId}/sleep` | none listed | new in v2 |
| `/v2/activity/sleep`, `/v2/activity/sleep/{sleepId}` | read:sleep | naps included with `nap: true` |
| `/v2/activity/workout`, `/v2/activity/workout/{workoutId}` | read:workout | |
| `/v2/user/profile/basic` | read:profile | |
| `/v2/user/measurement/body` | read:body_measurement | |
| `DELETE /v2/user/access` | any OAuth | revoke |
| `/v1/activity-mapping/{activityV1Id}` | none | one time v1 to v2 UUID lookup |
| `/v2/partner/...` | Trusted Partner client credentials | lab and service request integrations, not relevant |

Collections take `limit` (max 25, default 10), `start`, `end` (date-time) and `nextToken`; responses carry `next_token` (OpenAPI; pagination rules at https://developer.whoop.com/docs/developing/pagination). No history depth limit is documented. Collections are sorted newest first (https://developer.whoop.com/docs/tutorials/get-current-recovery-score). Errors listed: 400, 401, 429, 500.

There is no endpoint that writes anything for a regular OAuth app. No continuous or raw heart rate endpoint exists (FAQ: "Heart rate can only be streamed over Bluetooth Low Energy", https://developer.whoop.com/docs/developing/support).

### Recovery (`Recovery` and `RecoveryScore`)

- Required top level: `cycle_id` (int64), `sleep_id` (UUID), `user_id`, `created_at`, `updated_at`, `score_state` (`SCORED` | `PENDING_SCORE` | `UNSCORABLE`).
- `score` (present only when SCORED) required fields: `user_calibrating` (bool), `recovery_score` (float, 0 to 100 percent), `resting_heart_rate` (float, bpm), `hrv_rmssd_milli` (float, RMSSD in milliseconds).
- Optional: `spo2_percentage`, `skin_temp_celsius`. The spec says both are "Only present if the user is on 4.0 or greater".
- The recovery endpoint can 404 when a cycle has no recovery; treat it as "no recovery" (tutorial page above). Check `score_state` and `user_calibrating` before showing a score. Calibration "lasts a few days".
- Recovery bands per WHOOP: green 67 to 100, yellow 34 to 66, red 0 to 33 (https://developer.whoop.com/docs/whoop-101 and the brand PDF below).

### Cycle (`Cycle` and `CycleScore`)

- Required: `id` (int64), `user_id`, `created_at`, `updated_at`, `start`, `timezone_offset`, `score_state`. `end` is absent for the current cycle. `step_count` is nullable (added 2026-09-23, covered by `read:cycles`).
- `score` required: `strain` (float, 0 to 21 scale), `kilojoule`, `average_heart_rate` (int), `max_heart_rate` (int).
- A physiological cycle is not a calendar day; it can start and end mid day (https://developer.whoop.com/docs/developing/user-data/cycle). TriSpike's day boundaries must key off `start`, `end` and `timezone_offset`.

### Sleep (`Sleep`, `SleepScore`)

- Required: `id` (UUID), `cycle_id`, `start`, `end`, `timezone_offset`, `nap`, `score_state`, `created_at`, `updated_at`, `user_id`.
- `score` required: `stage_summary` and `sleep_needed`. `stage_summary` fields, all required, all milliseconds except counts: `total_in_bed_time_milli`, `total_awake_time_milli`, `total_no_data_time_milli`, `total_light_sleep_time_milli`, `total_slow_wave_sleep_time_milli`, `total_rem_sleep_time_milli`, `sleep_cycle_count`, `disturbance_count`. `sleep_needed`: `baseline_milli`, `need_from_sleep_debt_milli`, `need_from_recent_strain_milli`, `need_from_recent_nap_milli`.
- Optional: `respiratory_rate`, `sleep_performance_percentage`, `sleep_consistency_percentage` (the last two "may not be reported" with too little data), `sleep_efficiency_percentage`.

### Workout (`WorkoutV2`, `WorkoutScore`, `ZoneDurations`)

- Required: `id` (UUID), `start`, `end`, `timezone_offset`, `sport_name` (free string, example "running"; no enum in the spec), `score_state`, `user_id`, timestamps.
- `score` required: `strain`, `average_heart_rate`, `max_heart_rate` (bpm), `kilojoule`, `percent_recorded`, `zone_durations` with `zone_zero_milli` through `zone_five_milli` (milliseconds in WHOOP zones 0 to 5).
- Optional: `distance_meter` (only if distance data was sent to WHOOP), `altitude_gain_meter`, `altitude_change_meter`.
- `sport_id` and `v1_id` carry the note "Will not exist past 09/01/2025": use `sport_name` and the UUID `id`. The list of valid `sport_name` values is not in the spec (open question). Strength Trainer activities appear in the workout endpoint since 2024-05-01 (https://developer.whoop.com/docs/api-changelog).
- Important for matching: WHOOP zones are WHOOP's own heart rate zones (based on its max heart rate), not TriSpike's LTHR zones. Use `average_heart_rate`, `max_heart_rate`, and start/end to match against TriSpike sessions; do not mix WHOOP zone durations with TriSpike zone tables.

### Body and profile

- `/v2/user/measurement/body`: `height_meter`, `weight_kilogram`, `max_heart_rate` (WHOOP calculated), all required.
- `/v2/user/profile/basic`: `user_id`, `email`, `first_name`, `last_name`.

### Usable data per WHOOP's own brand guide

The brand PDF lists as usable: workouts (activity strain, type, average and max HR, zone durations), sleep (performance, consistency, efficiency, respiratory rate, stage durations), recovery (score, resting HR, HRV, skin temp, blood oxygen), cycle (day strain, energy), profile, body measurements. Source: https://developer.whoop.com/assets/files/WHOOP%20-%20Brand%20&%20Design%20Guidelines-bdea3554e94b4ea09e68695b1e8dc8e7.pdf (page 7).

## 4. Webhooks

Source: https://developer.whoop.com/docs/developing/webhooks/

- Events: `recovery.updated`, `recovery.deleted`, `workout.updated`, `workout.deleted`, `sleep.updated`, `sleep.deleted`. New records arrive as `updated`. No webhooks for day strain, cycles or body measurements.
- Payload: `user_id`, `id` (UUID in v2; for recovery it is the associated SLEEP UUID, not a cycle id), `type`, `trace_id` (dedupe). Payload carries identifiers only; call the API for the data.
- Signature: headers `X-WHOOP-Signature` and `X-WHOOP-Signature-Timestamp` (ms epoch). Compute base64(HMAC-SHA256(client secret, timestamp + raw body)).
- Config: HTTPS POST endpoint, set in the dashboard per app, each URL has a model version (v1 or v2, default v2). Retries: 5 over about an hour on non-2xx or timeout; respond 2xx within about a second and process async. Duplicates and misses happen; run a reconciliation poll.
- v1 webhooks are no longer published (changelog 2025-11-01 and the banner on every developer page).
- Fit for TriSpike: webhooks need a server endpoint that stores per-user mapping and then a way to wake the phone (APNs), which conflicts with the "no remote notifications, no accounts, Data Not Collected" posture in the spec (section 9). Recommended instead: poll from the phone on foreground and on background app refresh. A day of data is about 4 KB and plain polling is a handful of calls (FAQ), far below 100 requests per minute.

## 5. Rate limits

Source: https://developer.whoop.com/docs/developing/rate-limiting

- Default 100 requests per minute and 10,000 per day. Higher on request ("Open Request" then "Rate limit increase").
- Headers (IETF draft style): `X-RateLimit-Limit` (example `100, 100;window=60, 10000;window=86400`), `X-RateLimit-Remaining`, `X-RateLimit-Reset` (seconds). Over the limit returns 429.
- Not documented: whether limits are per app, per user or per key (the page uses all three words), any Retry-After header, whether rejected calls count, when the day window resets. UNVERIFIED.

## 6. API version, deprecations, changelog

- v2 launched 2025-07-01. v1 API "is no longer supported" and v1 webhooks removed (https://developer.whoop.com/docs/developing/v1-v2-migration , https://developer.whoop.com/docs/api-changelog). No explicit sunset date is given on the migration page. The OpenAPI spec contains only v2 paths plus the `/v1/activity-mapping` lookup.
- Use v2 only. Caveat: the "get current recovery" tutorial still shows `/developer/v1/` URLs, so docs are partly stale; trust the OpenAPI spec.
- v2 changes: UUID ids for sleep and workout, recovery webhook uses sleep UUID, cycle scores only when all data present (no fallback values), new `/v2/cycle/{cycleId}/sleep`, recovery activities included in workouts.
- Changelog highlights (https://developer.whoop.com/docs/api-changelog): 2026-09-23 `step_count` on cycles; 2025-11-01 webhook clarifications and v1 mapping API; 2025-08-01 recovery webhook id clarification; 2025-07-01 v2 launch; 2024-05-01 Strength Trainer in workouts; 2023-02-01 revoke endpoint; 2022-09-01 platform launch. No rate limit or scope changes are listed.
- WHOOP "may modify, remove or add portions of" the APIs in its sole discretion and has no obligation to keep compatibility or give support (terms section 1). Build the integration as optional and failure tolerant.

## 7. App approval and user caps

Source: https://developer.whoop.com/docs/developing/app-approval

- Tiers by connected members: Sandbox 10, Build 100, Growth 1,000, Scale 5,000, Production unlimited. Only the next tier up can be requested. From Build onward you need at least 50 percent of the current tier connected (for example 50 members on Build to request Growth). Sandbox can request Build at any time.
- To request: dashboard, open the app, "Open Request", "Request higher limits". Include designs and context. Manual review in order received. Vague answers are rejected; rejection emails list reasons.
- Prerequisites to request: read the API Terms, test with at least one WHOOP member, accurate App Name, contact emails and privacy policy URL, follow the WHOOP Design and Brand Guidelines.
- No review time is published. Contacting WHOOP staff outside the dashboard about a request is prohibited and can get the app disabled.
- Reality check from 2026 community posts (anecdotal, secondary):
  - One developer reports requests filed 2026-06-22 and 2026-07-29 with no human reply, then on 2026-09-04 WHOOP raised the limit to 100 and said that did "not constitute an integration review or approval"; the same developer was still waiting on a separate question in late October: https://www.community.whoop.com/t/app-approval-10-user-limit-submitted-jun-22-and-again-jul-29-no-response-in-64-days-soluno/16008
  - Another team reports two tier requests unacknowledged as of 2026-10-26: https://www.community.whoop.com/t/whoop-user-limit-tier-approval-submitted-twice-no-confirmation/16591
  - Terra summarizes the official position as no guaranteed review time: https://tryterra.co/blog/whoop-api-data-access-permissions-limitations-2026
- Implication: plan for the integration to ship behind a feature flag, working for at most 10 connected members (internal testers and a few TestFlight users) until WHOOP responds. Because Sandbox members must be real WHOOP owners, the owner needs a WHOOP device and membership to test at all.

## 8. Terms of use: storage, display, derived data, AI, competition, branding

Source: https://developer.whoop.com/api-terms-of-use/ , "Effective Date: October 6, 2026" (read verbatim from the page; section numbers follow the page). The date means the terms are about a month old; what changed is unknown. WHOOP may change them with notice and continued use equals acceptance (summary reading, section 9).

### Storing and displaying

- 4.2.2: Company will not "Scrape, build databases, or otherwise create permanent copies of WHOOP Data, or keep cached copies longer than permitted by the cache header". The page does not say what cache header values the API returns, and there is no retention period. UNVERIFIED what the API sends.
- 4.1: "WHOOP Data" includes user information, "WHOOP calculations and analysis", and "any copies or derivatives thereof".
- 7.1: on termination or discontinuation, delete cached or stored content that the terms permitted.
- 2.1: each End User must expressly authorize access, the app must let the End User access the data it collected via the API, and provide easily accessible support contact info.
- 2.3: provide and adhere to a privacy policy that says what is collected, used and shared. No transfer or disclosure of user information to third parties except as the terms, the user, the privacy policy and law allow.
- 2.4: WHOOP Data must be encrypted in transit and at rest (HTTPS); Company is fully responsible for End User information security; notify WHOOP of a security incident within 48 hours (security-notifications@whoop.com).
- 4.2.1 and 4.2.4: do not expose WHOOP Data to other users or third parties without explicit opt-in from the user, and do not "publicly display" or distribute WHOOP Data to a third party. Implication: share cards, plan share codes and race debrief images must not contain WHOOP derived values (recovery, HRV, strain) unless the athlete explicitly opts in per share.
- 3.1.2 and 3.1.3: no selling, renting or syndicating API materials, and no marketing, selling or licensing API data to third parties "even if an End User consents". 2.5: no use of WHOOP Data in advertisements without written consent.
- 3.2: "Developer credentials (such as passwords, keys, and client IDs)" must stay confidential and "may not be embedded in open-source projects". 1.4: do not share credentials across more than one application. Implications: TriSpike needs its own WHOOP app (not Liftspark's credentials), and neither client ID nor secret may be committed to this public repo; keep them in Vercel environment variables only.

### Derivative use, AI or ML

- 4.2.3: Company will not "Use any API or WHOOP Data to create, develop, test, train, fine-tune or improve any large language model or any other machine learning or artificial intelligence model, application, or system". TriSpike's adaptation is deterministic rules with no model training, which stays outside this clause, but note the clause says "test" and "improve" and covers any "application, or system", so keep WHOOP data out of any dataset used to tune the rules. Never send WHOOP data to an LLM service. Sending data to any third party is separately restricted by 2.3.
- 4.2.4: no "Copy, translate, modify, create a derivative work of" WHOOP Data to a third party (wording is tied to third party transfer). 4.1 still defines derivatives as WHOOP Data. Whether an on device computed adjustment ("lighter session today because Recovery is 28 percent") is a permitted use is not answered by the text; this is the first question for WHOOP.
- 3.1.12: no reverse engineering of any underlying algorithm or model from the APIs.

### Competition and coaching

- 3.1.16: Company may not "Use any API Materials to compete, directly or indirectly, with WHOOP or its products or services (including the WHOOP Platform) in any manner". 1.9: WHOOP can build competing products and the API is non exclusive.
- WHOOP sells Strain Target (a recommendation of exertion from recovery) and a Coach that can propose training plans (secondary sources: https://www.whoop.com/the-locker/strain-coach/ via search, and https://the5krunner.com/2023/09/27/whoop-coach-openai-chargpt/). A triathlon plan that adapts to recovery overlaps these conceptually. TriSpike's position: it adds multisport structured workouts and a race plan that WHOOP does not offer, and it does not replicate WHOOP's scores. Still ask WHOOP in writing.
- 3.1.10 and 3.1.11: no use of the APIs to design or support a "medical device" (US FDCA 201(h)(1) or equivalent) or to "offer, solicit, obtain, or provide any medical, legal, or other professional advice". 3.1.14(C): no use "in connection with any dangerous or high-risk activities" (triathlon open water is risky; TriSpike never schedules it as required, and the spec already forbids medical framing). TriSpike copy rules (fitness only, no diagnosis, no "AI coach") align; keep recovery driven changes phrased as training load suggestions, not health advice.
- 3.1.17: no disparaging WHOOP. 3.1.7: no unsolicited messaging.
- 1.8: no PHI use without WHOOP's written consent; 3.1.14(A) export control data bar. Not expected to matter.

### Branding and attribution

- Terms 5.1: no WHOOP trade names, trademarks, logos or other Brand Elements without written authorization, but a company may say it "utilizes WHOOP APIs to access applicable data from WHOOP products"; no statement implying partnership, sponsorship or endorsement without written consent. 5.2: no statement, press release or announcement referencing WHOOP or the APIs without WHOOP's prior written approval. 4.2.5: do not misrepresent the source of WHOOP Data. 5.3: WHOOP may use screenshots and the app name in its own promotion.
- Brand guide (7 page PDF, file dated July 2023): https://developer.whoop.com/assets/files/WHOOP%20-%20Brand%20&%20Design%20Guidelines-bdea3554e94b4ea09e68695b1e8dc8e7.pdf and the overview page https://developer.whoop.com/docs/developing/design-guidelines
  - Attribution: any WHOOP data must be communicated as such, with examples "Data by", "Imported from", "Powered by", and "Recommendations based on your WHOOP Recovery".
  - Logo: use only white or black, no distortion or rotation, do not place your own logo near WHOOP's visualized data, minimum widths 100 px (wordmark) and 30 px (puck).
  - Data use DOs: "Recommended Workout based on your WHOOP Recovery" with a recovery percentage is shown as acceptable.
  - Data use DONTs: rebrand or rename WHOOP proprietary metrics; switch focus from the score to the title; use other metrics for WHOOP scores; use different colors for the main scores; have recommendations that contradict WHOOP coaching (the example is a red recovery with "Give everything today!").
  - Colors for Recovery: green #16EC06 for 67 to 100, yellow #FFDE00 for 34 to 66, red #FF0026 for 0 to 33; Recovery blue #67AEE6; Strain #0093E7; Sleep #7BA1BB; teal #00F19F for calls to action.
  - Fonts: Proxima Nova for words, DINPro for numbers, with Helvetica Neue and Arial fallbacks (so not required to ship them).
- Whether a developer may use the logo files at all without separate written authorization is contradictory (the overview offers a logo ZIP; terms 5.1 requires written authorization). Treat as not allowed until confirmed; use plain text attribution only.

### Free app, no accounts

- Nothing in the terms or docs forbids a free app or an app with no accounts. Fees for added functionality are allowed (3.1.2). The only identity requirements are accurate registration info, privacy policy URL and support contact (app approval page, terms 1.2, 2.1, 2.3). The per user OAuth consent is the user's "account" with WHOOP, and the disconnect path must be easy. No source found that rejects free apps. UNVERIFIED that approval reviewers accept a no-account app.

## 9. Architecture notes for the TriSpike constraints (analysis, not from WHOOP)

- Reuse the Liftspark Vercel pattern (liftspark/backend/lib/providers.ts, api/oauth/[provider]/{start,callback,token,refresh}): the server only proxies the code exchange and the refresh, returns token fields, stores nothing. TriSpike needs its own WHOOP app, its own redirect URL (a custom scheme for TriSpike), and its own deployment or a per app provider config, because credentials may not be shared across applications (terms 1.4).
- All data calls go phone to `api.prod.whoop.com` directly using the access token in the Keychain, so the backend never sees WHOOP data. This supports the privacy story but is an inference: Apple's App Privacy "Data Not Collected" definition for a transient token proxy and for data flowing from a third party into the app has to be checked against Apple's definitions by the privacy workstream. It also adds the first network call to TriSpike, which the spec says does not exist in 1.0, and a client secret holding backend to operate.
- Polling plan: on foreground fetch the latest cycle recovery (`/v2/recovery?limit=3`), latest sleep, and workouts since last sync; refresh tokens lazily on 401 with a single flight refresher; background app refresh opportunistically.
- Adaptation inputs that map cleanly: `recovery_score` and `user_calibrating` (ignore while calibrating), `hrv_rmssd_milli` and `resting_heart_rate` against the athlete's own rolling baseline, `sleep_performance_percentage`, summed sleep stage time, day strain, workout average and max HR and duration. All adaptation changes must show a reason line and must not contradict the WHOOP recovery band (red recovery should never produce a "go hard" prompt).
- Retention: until WHOOP answers the cache question, store only a short rolling window plus the derived adjustment decisions, delete everything on disconnect (and call `DELETE /v2/user/access`), and keep WHOOP derived values off share cards and share codes.

## 10. Apple Health route (secondary sources, WHOOP's own page not read)

- WHOOP staff statement in a community thread (2025-08-25): WHOOP "will only write heart rate data into Apple Health if it's part of a workout or sleep session"; continuous heart rate is not exported: https://www.community.whoop.com/t/issue-with-apple-health-integration-data-not-syncing/7615
- A search summary of third party sources says WHOOP requests write access for activity energy, blood oxygen, heart rate, respiratory rate, resting heart rate, sleep and workouts, does not write HRV (RMSSD versus Apple's SDNN), and imports Apple Health activities into WHOOP: https://dcrainmaker.com/2022/02/whoops-health-integration.html , https://dcrainmaker.com/2022/04/exporting-health-actually.html , https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin . Not confirmed against WHOOP's own support article. Recovery and Strain scores are not documented as written to Apple Health.
- Consequence: for athletes who track with WHOOP, HealthKit completion matching (spec section 4.2) may work with no WHOOP API; recovery driven adaptation needs the API.

## 11. Heart rate broadcast over Bluetooth

- Official WHOOP support article "Heart Rate Broadcast": https://support.whoop.com/hc/en-us/articles/360023430193-Heart-Rate-Broadcast . The page requires a login from my fetch (HTTP 401), so I could only read a search engine summary of it, not the page itself. Per that summary: WHOOP uses Bluetooth Low Energy only; turn on "HR Broadcast" in the WHOOP app under Device Settings; connect to only one HR Broadcast enabled device at a time; real time broadcast requires third party apps that support BLE heart rate data (examples named: Strava, Zwift); the article is more than a year old.
- Developer FAQ confirms the API has no continuous heart rate and that live heart rate "can only be streamed over Bluetooth Low Energy": https://developer.whoop.com/docs/developing/support
- Standard Heart Rate Service (0x180D, measurement characteristic 0x2A37): not stated on any official page I could open. Secondary evidence: a community reverse engineering write-up says WHOOP 4.0 exposes the standard service while broadcast is on and is only discoverable then (https://www.mintlify.com/bWanShiTong/reverse-engineering-whoop-post/control/heart-rate-broadcast , page returned HTTP 410 on a direct fetch so I relied on the search result text); the Liftspark README lists "WHOOP or Garmin with heart-rate broadcast on" under standard Heart Rate Service 0x180D sensors (liftspark/README.md). Treat as UNVERIFIED until a real band is scanned with CoreBluetooth.
- Limits reported by users: single connection at a time, so a band broadcasting to a bike computer or Garmin watch cannot also feed the phone (https://forums.garmin.com/sports-fitness/cycling/f/edge-1040-series/420547/whoop-5-0-ble-connection-shows-0-bpm); a WHOOP 5.0 on a Garmin Edge showed 0 bpm until toggled; some WHOOP 5.0 or MG users report problems with ANT+ only Wahoo units (https://www.community.whoop.com/t/broadcast-heartrate-hr-not-working-with-wahoo-elemnt/6590/9); the older Strap 3.0 and 4.0 do not broadcast ANT+ (a third party converter exists: https://the5krunner.com/2023/12/28/whoop-broadcast-your-heart-rate-over-ant/). The broadcast is live only, with no history. It is off by default and app or firmware updates can switch it off (secondary).
- TriSpike impact: the phone interval player could show live heart rate from a broadcasting WHOOP, but this needs a Bluetooth purpose string (the spec says 1.0 has only the two HealthKit strings, section 9), the CoreBluetooth code, and has the single connection limit. Suggest deferring to 1.1 and using HealthKit afterwards in 1.0.

## 12. Open questions to put to WHOOP in writing (dashboard support or apisupport@whoop.com)

1. May an on device app compute and store training adjustments derived from WHOOP Recovery, HRV and sleep fields, and keep a rolling baseline (for example 28 days) locally? What does "permanent copies" and "cache header" mean for on device storage? What retention is acceptable?
2. Does a recovery aware training plan count as competing with Strain Target and Coach under 3.1.16?
3. May the App Store listing and in app copy say "Works with WHOOP" or "Data by WHOOP" in plain text, and may the logo or puck be used? Does 5.2 require approval of an App Store description that names WHOOP?
4. Is PKCE accepted by the authorization endpoint, and what state length is allowed?
5. Time to review Sandbox to Build and Build to Growth, and whether a free app without accounts is acceptable.
6. Is the 10 member cap counted per connected member currently authorized, and does revocation free a slot?
7. List of valid `sport_name` values (swim, bike, run, triathlon, brick types) and how multisport workouts appear.
