# Oura integration notes (Oura API v2)

Researched 2026-11-08 for TriSpike (free iPhone triathlon app). Primary sources only unless marked THIRD PARTY. No dashes used as punctuation in this file; ranges use "to".

## Source map (what was actually read)

| Short name | URL | How read |
|---|---|---|
| Spec | https://cloud.ouraring.com/v2/static/json/openapi-1.43.json | Downloaded in full (468 KB). This is the file the live docs page loads (the docs HTML contains `spec-url="/v2/static/json/openapi-1.43.json"`). Older numbered files (1.28, 1.35) return 404. |
| Docs page | https://cloud.ouraring.com/v2/docs | Redoc shell only; content comes from the Spec above |
| Auth page | https://cloud.ouraring.com/docs/authentication | Fetched (summarised by the fetch tool, so exact quotes below are short) |
| Agreement | https://cloud.ouraring.com/legal/api-agreement | Downloaded as HTML and read as text directly: sections 1 to 6 and 9 read verbatim. Titled "Oura API and MCP Agreement", effective June 8, 2026 |
| Support: API | https://support.ouraring.com/hc/en-us/articles/4415266939155-The-Oura-API | Fetched |
| Support: Apple Health | https://support.ouraring.com/hc/en-us/articles/360025438734 | Fetched (shows "Last updated October 14, 2026") |
| Support: workouts | https://support.ouraring.com/hc/en-us/articles/42821224955795-Record-a-Workout-with-Oura | Fetched |
| Brand use page | https://ouraring.com/guidelines-for-commercial-use | Fetched |
| Brand PDF | https://static.ouraring.com/pdfs/Oura_BrandGuidelines_v1.pdf | Downloaded and text extracted with pdftotext (v1, October 2020, marked "Proprietary & Confidential") |
| Apple privacy | https://developer.apple.com/app-store/app-privacy-details/ | Fetched |
| Liftspark code | liftspark/backend/lib/providers.ts, liftspark/backend/api/oauth/[provider]/start.ts, liftspark/README.md, liftspark/PLAN.md | Read locally |

## 1. Bottom line for TriSpike

1. Oura is feasible and free, but the June 8, 2026 Agreement is the real constraint, more than the API itself. Read it before designing the data layer.
2. Cloud OAuth 2.0 authorization code flow only (personal access tokens retired). A client secret is required for the code exchange and refresh, so a native app needs a thin token proxy (the Liftspark Vercel backend pattern).
3. Webhooks exist but need a server that stores per-user mappings and tokens. That conflicts with "Data Not Collected". Recommended design: tokens in the iOS Keychain, backend as a stateless exchange and refresh proxy, data pulled on app open (and optionally in a background refresh), no webhooks.
4. The Agreement (3(m), 4(a)(x)) says API data "may not be stored or retained beyond the duration strictly necessary". How much history an on-device training-load model may keep is unresolved. Ask api-support@ouraring.com before building a rolling baseline.
5. AI/ML: using the Oura API to "prompt, or otherwise provide input or data to any AI Model or AI Platform" is prohibited (4(d)). "AI Model" is defined very broadly. Do not feed Oura data into any LLM or ML model, including on device. A deterministic rules engine is the safe path.
6. Never charge users for functionality "included in or related to" the Oura API (4(a)(xiii)). TriSpike is free now, which is fine, but any future paid tier must not gate Oura features without Oura's written consent.
7. Credentials may not be reused across apps (3(i)). TriSpike needs its own Oura API application and client id and secret; do not reuse Liftspark's.
8. Unapproved apps are capped at 10 users. No approval process is documented anywhere I could read (see open questions).
9. Apple Health is an alternative path for part of the data (sleep, heart rate, steps, workouts), but not for readiness, HRV, temperature or resting heart rate.

## 2. Authentication

Sources: Auth page, Spec (info.description, securitySchemes).

- Personal access tokens: Spec says "personal access tokens were deprecated in December 2025 and are no longer available for use." OAuth2 only.
- V1 API: sunset. V2 "is the only available integration point" (Spec).
- Authorize URL: `https://cloud.ouraring.com/oauth/authorize`. Token URL: `https://api.ouraring.com/oauth/token`. (Spec securitySchemes.OAuth2.flows.authorizationCode, and Auth page.)
- Auth page also lists an alternative authorize URL for new clients, `https://developer.ouraring.com/authorize`, a universal link that can open the consent page inside the Oura app on supported mobile devices. Not tested.
- Revoke: `https://api.ouraring.com/oauth/revoke?access_token={access_token}` (Auth page; HTTP method not stated).
- Server-side flow (Auth page): authorize with `response_type=code` and `client_id` (required), optional `redirect_uri`, `state`, `scope`, `code_challenge`, `code_challenge_method`. Redirect returns `code` (and `state`); denial returns `error=access_denied`. Token POST uses `grant_type=authorization_code`, `code`, `redirect_uri` if sent, `code_verifier` if PKCE. Refresh uses `grant_type=refresh_token` and `refresh_token`.
- PKCE: supported in the server-side flow only; `code_challenge_method` must be `S256`; verifier 43 to 128 characters (Auth page). The Auth page does not say PKCE removes the need for `client_secret`; it lists `client_secret` as required unless HTTP Basic auth is used.
- Client secret: passed in the form body or as HTTP Basic (`client_id` as username, secret as password); content type `application/x-www-form-urlencoded`, UTF-8 (Auth page). Agreement 3(i): the client secret is confidential, "may not [be] share[d]... with any third party or use[d]... for more than one application or service".
- Client-side (implicit) flow: `response_type=token`, token returned in the URL fragment, no refresh token, token lifetime "currently set to 30 days", user must re-authenticate afterward (Auth page). It needs no secret. The page does not mention custom URL schemes or native apps, so whether an iOS app can use it with a registered redirect is unconfirmed.
- Refresh tokens are single use: each refresh invalidates the old refresh token and returns a new one (Auth page). Practical consequence: only one place (the device) may refresh; a refresh race or lost response can strand the user in a re-consent.
- Access token lifetime: sources disagree. Spec "Authentication Troubleshooting" says "typically 24 hours for Oura"; the Spec FAQ says tokens "typically last 30 days"; the Auth page gives only `expires_in`. Rely on `expires_in` in the token response.
- Authorization code validity: "valid for only 10 minutes" (Spec, Authentication Troubleshooting).
- Redirect URI: must exactly match a registered URI (an allowlist), URL-encoded; may be omitted if exactly one is registered, but include it (Auth page).
- Required header on API calls: `Authorization: Bearer <token>` plus a non-empty `User-Agent` (for example `YourAppName/1.0`); without it requests "may be rejected" with 403 (Spec and Auth page). Liftspark's `tokenRequest` does not set a User-Agent on the token POST; Node's fetch sends a default one, but set an explicit `User-Agent` for TriSpike to be safe.
- Gen3 and newer ring users without an active Oura Membership cannot access data through the API, and partner apps lose access to them (Support: API). A lapsed membership shows up as HTTP 403 (Spec response codes). TriSpike must treat 403 as "Oura paused, check membership or consent" rather than an error.
- Developer portal: new apps are created at `developer.ouraring.com`; the older portal `cloud.ouraring.com/oauth/applications` still edits existing apps (Support: API). The Spec still points to the older URL for registration.

### Scopes

Spec securitySchemes lists nine scopes (exact names and descriptions):

| Scope | Description in Spec |
|---|---|
| `email` | Email address of the user |
| `personal` | Personal information (gender, age, height, weight) |
| `daily` | Daily summaries of sleep, activity and readiness |
| `heartrate` | Time series heart rate for users |
| `workout` | Summaries for auto-detected and user entered workouts |
| `tag` | User entered tags |
| `session` | Guided and unguided sessions in the Oura app |
| `spo2` | SpO2 Average recorded during sleep |
| `heart_health` | Heart health data |

- The Auth page counts 8 scopes and does not list `heart_health`; it describes `heartrate` as "for Gen 3 users". The Spec is newer (version 1.43), so treat `heart_health` as real.
- Scopes are space separated; omitting `scope` requests all available scopes; the page recommends requesting only what is needed. The `scope` value echoed in the redirect is deprecated and may differ from what was requested, so do not rely on it (Auth page).
- The Spec does not map each endpoint to a scope. Tag descriptions name scopes for only some routes: Daily Activity ("The Daily Activity scope"), Heart Rate ("The Heart Rate data scope"), Personal Info ("personal info scope"; its `id` needs no scope), Sessions ("Sessions data scope"), Workout ("Workout data scope"). Mapping of the remaining endpoints is INFERRED, not confirmed: `daily_readiness`, `daily_sleep`, `sleep`, `daily_stress`, `daily_resilience`, `sleep_time` presumably need `daily`; `daily_spo2` presumably `spo2`; `vO2_max` and `daily_cardiovascular_age` presumably `heart_health`. Verify with sandbox or a real token before relying on it.
- Existing Liftspark Oura config requests `daily heartrate workout personal` (liftspark/backend/lib/providers.ts).
- Suggested TriSpike minimum: `daily` (readiness, sleep, activity). Add `workout` only if importing Oura-recorded workouts. Skip `email`, `tag`, `session`, `spo2`, `heart_health`, `personal` and `heartrate` unless a feature needs them (data minimisation is also required by Agreement 4(c)).

## 3. Endpoints and fields (Spec, base `https://api.ouraring.com`)

All GET unless noted. Date range queries use `start_date` and `end_date`; heart rate uses `start_datetime` and `end_datetime`. All list routes take `next_token` for pagination and most take `fields` (comma separated field selection; `daily_resilience` does not support field selection yet). Each collection route also has a `/{document_id}` single-document route. A `/v2/sandbox/usercollection/...` mirror exists for each data type with fake data and no Oura account; "The rate limit for the sandbox endpoints is shared with your rate limit on other data endpoints."

Paths: `/v2/usercollection/` + `daily_readiness`, `daily_sleep`, `sleep`, `daily_activity`, `workout`, `heartrate`, `daily_stress`, `daily_resilience`, `daily_spo2`, `daily_cardiovascular_age`, `vO2_max` (capital O in the path), `sleep_time`, `rest_mode_period`, `session`, `tag`, `enhanced_tag`, `ring_configuration`, `ring_battery_level`, `personal_info`.

### daily_readiness (PublicDailyReadiness)
- `id`, `day`, `timestamp`, `score` (integer or null; Spec says scores range 0 to 100 in general text and "[1, 100]" on contributors).
- `contributors` (each integer or null, range [1, 100]): `activity_balance`, `body_temperature`, `hrv_balance`, `previous_day_activity`, `previous_night`, `recovery_index`, `resting_heart_rate`, `sleep_balance`, `sleep_regularity`.
- `temperature_deviation` (degrees C, number or null), `temperature_trend_deviation` (degrees C, number or null).
- Note: no raw HRV or resting heart rate value here, only contributor scores (`hrv_balance`, `resting_heart_rate`).
- Readiness is calculated only after sleep data is processed, which needs the user to open the Oura app and sync (Spec, Data Model).

### daily_sleep (PublicDailySleep)
- `id`, `day`, `timestamp`, `score`, `contributors`: `deep_sleep`, `efficiency`, `latency`, `rem_sleep`, `restfulness`, `timing`, `total_sleep` (each integer or null, [1, 100]).

### sleep (PublicModifiedSleepModel; multiple periods per day possible)
- Heart rate and HRV: `average_heart_rate` (bpm, based on 30 second samples, "different from what is shown in the app"), `lowest_heart_rate` (integer; the usable resting heart rate proxy, same caveat), `average_hrv` (integer; Spec gives no unit in the field description), `heart_rate` and `hrv` (each a `PublicSample`: `interval` seconds, `items` array, `timestamp`), `average_breath` (breaths per minute).
- Durations in seconds: `total_sleep_duration`, `time_in_bed`, `awake_time`, `deep_sleep_duration`, `light_sleep_duration`, `rem_sleep_duration`, `latency`; `efficiency`, `restless_periods`, `bedtime_start`, `bedtime_end`, `day`, `period`, `type` (`deleted`, `sleep`, `long_sleep`, `late_nap`, `rest`), `sleep_phase_5_min`, `sleep_phase_30_sec`, `movement_30_sec`, `app_sleep_phase_5_min`, `sleep_algorithm_version` (`v1`, `v2`), `sleep_score_delta`, `readiness_score_delta`, `readiness` (nested score, contributors, temperature deviation), `low_battery_alert`.
- Temperature deviation is on readiness (above), not on `sleep`.

### daily_activity (PublicDailyActivity; a 24 hour period starting 4 a.m.)
- `score`, `steps`, `active_calories`, `total_calories`, `target_calories`, `equivalent_walking_distance` (m), `target_meters`, `meters_to_target`, `average_met_minutes`, `high_activity_met_minutes`, `medium_...`, `low_...`, `sedentary_met_minutes`, `high/medium/low_activity_time`, `sedentary_time`, `resting_time`, `non_wear_time` (seconds), `inactivity_alerts`, `class_5_min`, `met` (sample), `contributors`: `meet_daily_targets`, `move_every_hour`, `recovery_time`, `stay_active`, `training_frequency`, `training_volume`.

### workout (PublicWorkout)
- `id`, `activity` (string), `calories` (kcal, nullable), `distance` (meters, nullable), `day`, `start_datetime`, `end_datetime`, `intensity` (`easy`, `moderate`, `hard`), `label` (nullable), `source` (`manual`, `autodetected`, `confirmed`, `workout_heart_rate`, `live_third_party_heart_rate`, `live_oura_heart_rate`).
- No heart rate samples, zones or GPS on the workout object. For heart rate during a workout use the `heartrate` route filtered by time, where `source` includes `workout` and `live`.

### heartrate (time series; needs `heartrate`)
- Rows: `bpm`, `source` (`awake`, `workout`, `rest`, `sleep`, `live`, `session`), `timestamp`, `timestamp_unix` (ms). Params: `start_datetime`, `end_datetime`, `next_token`, `latest` (boolean, "If True, returns most recent sample"), `fields`.
- Tag description: "Heart rate is provided at 5-minute increments." Data syncs in the background periodically (Spec, Data Model), but only when the phone app syncs with the ring. Not a live stream.

### daily_stress, daily_resilience (both present)
- `daily_stress` (PublicDailyStress): `day`, `stress_high` (seconds in high stress zone, top quartile), `recovery_high` (seconds in high recovery zone), `day_summary` (`restored`, `normal`, `stressful`, nullable).
- `daily_resilience` (DailyResilienceModel): `day`, `level` (`limited`, `adequate`, `solid`, `strong`, `exceptional`), `contributors`: `sleep_recovery`, `daytime_recovery`, `stress` (each number in [0, 100]).

### Other routes that exist
- `vO2_max` (`vo2_max` integer, `day`, `timestamp`); `daily_cardiovascular_age` (`vascular_age` [18, 100], `pulse_wave_velocity` m/s); `daily_spo2` (`spo2_percentage` aggregates, `breathing_disturbance_index`); `sleep_time` (optimal bedtime window, `recommendation`, `status`); `rest_mode_period`; `session` (guided and unguided sessions: heart rate, HRV and motion samples, mood, type); `tag` and `enhanced_tag`; `ring_configuration` (color, design, firmware, hardware type, size); `ring_battery_level`; `personal_info` (`age`, `weight`, `height`, `biological_sex`, `email`).

### Data timing (Spec, Data Model and FAQ)
- Sleep, sleep time and readiness appear only after the user opens the Oura app and syncs the ring. Daily activity, daily stress and heart rate update periodically in the background.
- All timestamps ISO 8601 with timezone; date parameters are interpreted in the user's local timezone. Durations are seconds.
- Plan for gaps: users who do not sync or wear the ring produce nulls or missing days. Readiness for "today" is often unavailable until the user opens Oura.

## 4. Webhooks

Source: Spec, tag "Webhook Subscription Routes", FAQ.

- Recommended by Oura as the preferred way to consume data; "We have not had customers hit rate limits with webhooks properly implemented." Notifications arrive "approximately 30 seconds after data syncs from the mobile app."
- Routes: `GET`/`POST /v2/webhook/subscription`, `GET`/`PUT`/`DELETE /v2/webhook/subscription/{id}`, `PUT /v2/webhook/subscription/renew/{id}`. Auth for these is the headers `x-client-id` and `x-client-secret` (app credentials), not a user token.
- Create body: `callback_url`, `verification_token`, `event_type` (`create`, `update`, `delete`), `data_type` (enum: `tag`, `enhanced_tag`, `workout`, `session`, `sleep`, `daily_sleep`, `daily_readiness`, `daily_activity`, `daily_spo2`, `sleep_time`, `rest_mode_period`, `ring_configuration`, `daily_stress`, `daily_cardiovascular_age`, `daily_resilience`, `vo2_max`). One subscription per event_type and data_type combination. The subscription model has an `expiration_time`, hence the renew route (the renewal cadence is not stated in the Spec text I read).
- Verification: Oura sends GET to the callback with `verification_token` and `challenge`; the endpoint must return `{"challenge": "..."}`.
- Delivery: POST with headers `x-oura-signature` and `x-oura-timestamp`; body `event_type`, `data_type`, `object_id`, `event_time`, `user_id`. Signature is HMAC SHA256 over `timestamp + body` using the client secret, hex uppercased. Respond with 2xx within 10 seconds. 10 retries on 4xx, 5xx or timeout; Oura retries "for about an hour". Returning 410 cancels the subscription.
- Implication for TriSpike: a webhook receiver is app-level, so it receives events for all users with `user_id` and `object_id`, and the server would need the user's token to fetch the data. That means storing tokens and data identifiers server side, which collides with the "Data Not Collected" target and with the Agreement's retention limits. Skip webhooks for 1.x. Revisit only if the app ever gets a real account system.

## 5. Rate limits

- Spec FAQ: "The Oura API is limited to 5000 requests per 5-minute period."
- Spec Rate Limits section (newer text): two layers, a per-access-token limit and a per-application limit that caps aggregate traffic across all of an application's end-user tokens. A 429 carries `Retry-After` (seconds), `X-RateLimit-Limit`, `X-RateLimit-Window`, `X-RateLimit-Reset` (Unix epoch seconds), `X-RateLimit-Tier` (which layer fired). No numbers are given in that section, and Oura says to "Contact us" at api-support@ouraring.com for higher limits. The 5000 per 5 minutes figure may be outdated or may be only one of the layers; treat it as unconfirmed.
- Agreement 3(d): limits "may be modified by Oura at any time with or without notice"; evasion can lead to blocking.
- Design: batch by date range (one request per data type per sync, not per day); Oura suggests 1 to 3 month spans for history; honour `Retry-After`; exponential backoff on 429.

## 6. App registration, approval and user cap

- Quote (Spec): "API Applications are limited to 10 users before requiring approval from Oura. There is no limit once an application is approved." Users "must provide consent to share each data type an API Application has access to."
- FAQ: "the Oura API is free to use for both personal and commercial applications. However, API applications accessing more than 10 users require approval from Oura."
- Neither the Spec, Auth page, Support article nor Agreement describes how to apply for approval. The Spec points to api-support@ouraring.com for higher limits. The Agreement 4(e) says Oura may revoke access for any app that "is not providing added benefit to Users" or is "not in the best interests of Oura or Users", at sole discretion, so approval criteria are subjective.
- Practical: the first 10 connected users are the beta cohort. Do not market the Oura connection until approval is requested.

## 7. Agreement terms that bind TriSpike (read directly, effective June 8, 2026)

URL: https://cloud.ouraring.com/legal/api-agreement. Section numbers are from the document. "User Data" is defined to include data "derived from or based upon" Oura data, so computed readiness adjustments are covered.

### Storage and retention
- 3(m): data from the Oura API "may not be stored or retained beyond the duration strictly necessary." (The no-storage-at-all rule applies to the MCP Server and to Aggregators; the API is "strictly necessary" only.) 4(a)(x) prohibits retaining data "beyond the periods specified in this Agreement".
- 4(c): data minimisation; request only necessary data and promptly delete data no longer needed.
- 5(f): on a user's deletion request, delete their User Data within 72 hours and retain nothing; on opt out or revoked consent, stop all processing immediately; also delete data if the user cancels the app subscription. This means TriSpike needs an in-app "disconnect Oura and erase Oura data" action that really wipes local Oura-derived data, plus a documented path for a deletion request by email.
- 4(a)(xx): do not aggregate, cache or store geographic location or other User Data via the API. TriSpike does not request location data (not in any scope read).
- Gray area to resolve with Oura: an on-device rolling window (for example 7 to 28 days of daily readiness) to compute a baseline or trend. "Strictly necessary" is undefined.

### AI and ML
- 4(a)(iii), 4(a)(iv), 6(g): no training, fine tuning, evaluation datasets, embeddings or "persistent representations" from User Data; 6(g) makes training a material breach.
- 4(d): "You shall not use, and shall not permit any third party to use, the Oura API to develop, train, fine-tune, evaluate, prompt, or otherwise provide input or data to any AI Model or AI Platform." LLM use is allowed only through Oura's MCP Server (non-Aggregators), and MCP data may not be stored or cached (3(m)).
- "AI Model" is defined as "any artificial intelligence system, machine learning model, neural network, large language model, or other computational intelligence system". That would plausibly include Apple's on-device Foundation Models and any ML-based readiness regression. Keep the plan adjuster a transparent rule set (thresholds on scores and deviations). Whether simple statistical baselines count as "computational intelligence" is a question for Oura.
- 9(h): Oura may audit systems for compliance with 5 business days notice, specifically including AI training prohibitions.

### Sharing, consent, privacy
- 4(a)(vi) and 5(j): no disclosure of User Data to third parties without express user consent and not beyond what the Agreement permits.
- "Aggregator" (section 1) is broad: any party (including a User) that provides User Data "or any data or information derived therefrom" to a third party "for enabling, facilitating, supporting, or enhancing a third party's products, services, platforms, or applications". Aggregators face 3(e), 3(f), 4(b), no storage or caching, no analysis or benefit. If TriSpike forwards Oura-derived adjustments to Garmin Connect, Apple Watch workouts or WHOOP, Oura could argue TriSpike is an Aggregator. Needs a written answer from Oura before shipping cross-provider features that carry Oura-derived values off the phone. Apple Watch workout scheduling on the same phone is likely a lesser concern but still unconfirmed.
- 4(a)(v): combining or correlating Oura data with other sources to create or maintain a database about a User needs User Consent first. Add explicit consent text when the same plan engine uses several providers.
- 5(a): consent must be specific, informed, unambiguous, and you must tell users how to revoke it. 5(c): a conspicuous privacy policy explaining collect, store, use, disclose, retain and delete. 5(b): do not interfere with Oura's consent screens.
- 5(e): the developer is solely responsible for outputs and recommendations and must present them in a way that is "not inaccurate, misleading, or deceptive". Add wording that readiness is Oura's score and TriSpike's adjustment is a suggestion.
- 5(g): use User Data only for a function directly relevant to the Authorized Purpose.
- 5(i): the app's own terms must not conflict with the Agreement and must disclaim warranties for third-party providers. (The Agreement has no dedicated medical disclaimer; the general "as is" disclaimer is in 10(a).)

### Commercial
- 4(a)(xiii): "charging Users in any manner for access to or use of the MCP Server or any services or functionality included in or related to the MCP Server, Oura API, or Oura Platform" is a Prohibited Use without Oura's prior written consent.
- 4(a)(vii), 4(a)(viii): no advertising, marketing, targeting or promoting using Oura data.
- 3(h): Oura may start charging developers for API use, with notice.
- 4(a)(ix) and the preamble: no building products that compete with or merely replicate Oura's own. TriSpike's triathlon planning does not replicate an Oura Readiness score, but do not ship a re-derived readiness or sleep score that mimics Oura's algorithms (4(a)(xi) bars reverse engineering scoring methodologies).
- 4(e): Oura can revoke or suspend access at its sole discretion with no liability. 3(c): Oura can change or discontinue the API with or without notice. 3(p): no SLA.

### Credentials and security
- 3(i): the client id and secret are for one application only. TriSpike needs its own registration; Liftspark's Oura app cannot be reused.
- 9(a): "comprehensive" security measures including encryption in transit and at rest, access controls and MFA for systems processing the data, incident response, and so on. 9(b): report a Data Incident to Oura within 24 hours. These obligations are phrased for any developer. For a design where the backend sees only tokens in transit and the phone holds data in the Keychain and protected storage, the surface is small, but write the policy down.
- 3(l), 9(h): Oura may monitor use and audit.
- 4(g) and others apply only to MCP use or are not relevant.

### Branding (see section 9 for assets)
- 6(e): a limited, revocable licence to use Oura's name and logos "only as described in Oura's Branding Guidelines"; do not use the Oura name or a confusingly similar mark in the app name, icon, logo or branding of the app; update to the latest marks if Oura changes them.
- 4(f): no advertising or statements suggesting Oura approves or endorses the app, and no press releases mentioning Oura, without written consent.
- 4(a)(xix): do not remove or alter Oura notices or marks.
- 6(f): Oura gets a licence to promote the integration and use the app's name and logo.

## 8. What Oura writes to Apple Health, and live heart rate

Source: https://support.ouraring.com/hc/en-us/articles/360025438734 (page shows "Last updated October 14, 2026").

Oura writes to Apple Health (as listed on that page):
- Active energy (active calories only, excluding BMR)
- Heart rate (one minute intervals)
- Height and weight
- Mindful Minutes (only if "Save Mindful Minutes to Health" is on)
- Respiratory rate (average nighttime value)
- Sleep (duration, start and end times, stages)
- Steps
- Workout routes and workouts (manual, Activity Heart Rate, or Automatic Activity Detection)

The page does not list HRV, body temperature, SpO2 or resting heart rate as written to Health, so Apple Health will not give TriSpike Oura's readiness score, HRV, temperature deviation or resting heart rate. (THIRD PARTY: a web search summary said HRV is not written; Oura's own Apple Health list is the reason I trust that conclusion.) The page also says Oura imports from Health: active and resting energy, blood pressure, body fat and lean mass, cardio fitness, date of birth, sex, height, weight, heart rate, respiratory rate, sleep, steps, workout routes and workouts. Units are not listed. Reading these through HealthKit needs no Oura API terms at all, but it is also bounded by whatever Oura chooses to write, and data lands later or not at all if the user disables the Health sync.

Live heart rate during workouts:
- Oura's Live Activity Tracking (start from the + menu on the Today tab) shows pace and distance from GPS and "live heart rate from third-party monitors"; it "replaces" the earlier Record Workout Heart Rate feature (Support: workouts, https://support.ouraring.com/hc/en-us/articles/42821224955795-Record-a-Workout-with-Oura). The page does not say whether the Oura ring itself shares live heart rate with other apps, and I found no Oura documentation of a Bluetooth heart rate broadcast.
- The API only exposes heart rate after the app syncs, at 5 minute resolution, with `source` values `live` and `workout` marking samples (Spec). It is not suitable for live coaching during a session.
- Conclusion: for live heart rate in TriSpike use Apple Watch or a BLE chest strap or armband, not Oura. Oura contributes pre-workout readiness and post-workout summaries only.

## 9. Brand and attribution

- Brand PDF (https://static.ouraring.com/pdfs/Oura_BrandGuidelines_v1.pdf), v1 October 2020, marked "Proprietary & Confidential": wordmark colours (Helsinki Blue in most cases, Oura Black "when sharing with partners", white on dark backgrounds), clear space, minimum sizes, logo don'ts (do not recolour, stretch, apply effects, outline, add elements, or use the blue on dark backgrounds), and a "Partnership Lockups" system (horizontal lockup; partner logo matched to the cap height of the "A"). It contains no "Works with Oura" or "Powered by Oura" wording and no explicit instructions on API data attribution that I could extract as text; the slides may carry diagrams I could not read.
- Brand use page (https://ouraring.com/guidelines-for-commercial-use): commercial use of Oura Brand Features requires Oura's written permission, which can be rejected or withdrawn; Oura may review materials that use the marks; the "ŌURA", "OURA" and "Ō" marks belong to Oura Health Oy; contact branduse@ouraring.com.
- There is tension between 6(e) (a licence to use the marks as per the guidelines) and the commercial-use page (written permission). Resolve by emailing branduse@ouraring.com before putting any Oura logo in the app or the App Store listing. Until then use plain text "Oura" in a neutral factual way such as "Connect Oura" and never in the app name, icon or screenshots' branding, and never imply endorsement (4(f)).

## 10. Fit with the Liftspark backend (reuse notes)

From liftspark/backend/lib/providers.ts, api/oauth/[provider]/start.ts, README.md and PLAN.md:
- The Oura provider is already wired: authorize `https://cloud.ouraring.com/oauth/authorize`, token `https://api.ouraring.com/oauth/token`, scope `daily heartrate workout personal`, env `OURA_CLIENT_ID` and `OURA_CLIENT_SECRET`, PKCE S256 required, redirect `.../api/oauth/oura/callback`. `tokenRequest` returns only token fields, never provider bodies, and never stores anything. PLAN.md item 6 notes the WHOOP and Oura apps still need registering with the callback `https://<backend>/api/oauth/<provider>/callback`.
- For TriSpike: fork or deploy a separate instance with its own `OURA_CLIENT_ID` and secret (Agreement 3(i)), narrow the scope string, add an explicit `User-Agent` on the token POST, and keep the backend free of request-body logging (the callback URL carries the authorization `code` in its query string).
- Apple's definition of "collect" (https://developer.apple.com/app-store/app-privacy-details/): transmitting data off device so it can be accessed "for a period longer than what is necessary to service the transmitted request in real time"; Apple says that if "an authentication token or IP address is sent on a server call and not retained, or if data is sent to your servers then immediately discarded after servicing the request, you do not need to disclose this." So a stateless exchange and refresh proxy does not by itself force a data type onto the privacy label, provided hosting logs do not retain tokens. Health data pulled directly from Oura to the phone and kept on device is "processed only on device".

## 11. Suggested design (for the synthesiser to challenge)

1. Opt in screen with specific consent text, a link to the privacy policy, and a clear "Disconnect and erase Oura data" control (5(a), 5(f)).
2. OAuth via ASWebAuthenticationSession through the stateless proxy; tokens in the Keychain; scope `daily` only to start.
3. On app open (and optionally a daily background refresh), one request each for `daily_readiness` and `daily_sleep` (and `sleep` for `lowest_heart_rate` and `average_hrv` if allowed) for the last few days; honour 429 headers.
4. Store only the minimum on device (see open question on retention); no analytics, no third party SDK, no LLM.
5. Plan adjuster: deterministic rules (for example readiness score and temperature deviation flags lower intensity; sustained low `hrv_balance` or `recovery_index` contributors suggest an easier day), always labelled a suggestion, always user overridable.
6. Handle null score, missing days, 401 (refresh once, then re-consent), 403 (membership or consent), 429 (back off).
7. Keep Oura data out of any cross-provider export or push to Garmin or WHOOP until Oura confirms that is not "Aggregator" behaviour.

## 12. Open questions (could not confirm from primary sources)

1. How does an app apply for approval beyond 10 users, what are the criteria and timeline? Only api-support@ouraring.com is named (for higher rate limits).
2. What does "strictly necessary" retention mean in 3(m) for an on-device rolling baseline of 7 to 28 days of readiness, sleep and HRV values?
3. Does a rule based, non-ML plan adjuster fall under "AI Model" or "computational intelligence system" in 4(d)? Does Apple's on-device Foundation Models count?
4. Does passing Oura derived values to another provider (Garmin push, WHOOP or Apple Watch workout scheduling) make TriSpike an "Aggregator" under section 1 and 3(e)?
5. Is `client_secret` optional when PKCE is used, and are custom URL scheme redirects or the client-side (implicit) flow allowed for a native app? The Auth page is silent. If the implicit flow is allowed, a secretless, backendless design with a 30 day token might be possible, at the cost of monthly re-consent.
6. Real access token lifetime: 24 hours (troubleshooting text) or 30 days (FAQ) or whatever `expires_in` says?
7. Rate limit numbers: is 5000 requests per 5 minutes still current, and what is the per-application layer limit for an unapproved app?
8. Which scope covers which endpoint (`sleep`, `daily_stress`, `daily_resilience`, `sleep_time`, `vO2_max`, `daily_cardiovascular_age`)? What exactly does `heart_health` cover? Test in the sandbox with a real token.
9. What is the webhook subscription `expiration_time` cadence and how often must `renew` be called?
10. Brand usage: are logos or the word "Oura" allowed in a free third party app UI and App Store listing, and what attribution wording, if any, does Oura require for API data? The 2020 PDF is the only guideline available and is marked confidential; contact branduse@ouraring.com.
11. Future paid features: does 4(a)(xiii) bar a TriSpike premium tier if Oura integration stays free for everyone? Likely needs Oura's written consent or a strict separation; ask before any monetisation (TriSpike is currently no revenue by design).
12. Does the Oura Membership requirement (Gen3 and newer) apply to Gen 4 and later rings in the same way, and how does the API signal a lapsed membership (403 only)?
13. Does the Oura ring or app expose any BLE heart rate broadcast for use by third party apps during workouts? Nothing found.
