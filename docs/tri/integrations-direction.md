# Brickline integrations direction

Date: 2026-11-08. Decision memo for the owner, companion to `docs/specs/tri-spec.md` (sections 3, 4, 8, 9). Full notes with every URL: `integ-whoop.md`, `integ-oura.md`, `integ-garmin.md`, `integ-apple-health.md`, `integ-adaptation-science.md`, `integ-architecture.md` in this folder. Bracketed ids point at the fact check list. No credentials may ever enter this public repo [whoop:w18].

## 1. Verdict

Brickline integrates with Apple Watch, WHOOP, Oura and Garmin and adjusts each user's plan from their signals. "Integrates" means three depths.

**Ships in 1.0, no approvals, no server: the Apple Health path.** HealthKit is the only zero approval route and keeps the label at Data Not Collected [apple-health:f1]. An Apple Watch alone supports a transparent readiness model: HRV as SDNN [apple-health:f3], resting heart rate [apple-health:f4], sleep stages [apple-health:f5], workouts with dense heart rate [apple-health:f15]. Its weakness is accuracy (about 8 ms low, 28.88 percent error against a chest strap [apple-health:f30]), so the app reads only trends against the athlete's own baseline.

For the other three devices Health gives much less. Oura writes sleep with stages, heart rate and workouts, not HRV [oura:oura-19]. WHOOP writes heart rate only inside workouts or sleep, reportedly sleep duration without stages, and no HRV [whoop:w24, apple-health:f20, apple-health:f21]. Garmin writes workouts, heart rate and sleep stages, but per secondary sources no HRV or Body Battery [apple-health:f23, apple-health:f24, apple-health:f25]. In 1.0 these users get completion matching and sleep duration, not recovery signals.

**Needs vendor approval and a thin server: WHOOP and Oura APIs (1.1).** Technically easy, policy gated. Both start capped at 10 users [whoop:w13, oura:oura-5], their terms need written clarification (section 7), and WHOOP review has shown months of silence [whoop:w14]. They ship behind per vendor flags as a small beta, never marketed at scale.

**Blocked: Garmin's API.** Starter is push only with no history [garmin:g01], so Brickline would need a public receiver storing health payloads, which breaks Data Not Collected (analysis). The form is described as for businesses [garmin:g11]. The program closed from March and press says it reopened 2026-10-21, with no Garmin announcement found [garmin:g09, garmin:g08]. The agreement limits use to internal purposes and "format and display" and bars combining the API with other services [garmin:g13]. Pushing structured workouts needs the Training API, which Personal keys lack [garmin:g20]. Garmin users get the Health path and the phone player. Do not build a Garmin connector in 1.x.

## 2. Device by signal matrix

Cells read "via Apple Health / via vendor API". None means none found.

| Signal | Apple Watch | WHOOP | Oura | Garmin |
|---|---|---|---|---|
| Recovery score | None | None / recovery_score [whoop:w6] | None / readiness [oura:oura-7] | None / Body Battery only [garmin:g06, garmin:g18] |
| Sleep | Stages [apple-health:f5] | Duration only / stages [apple-health:f20, whoop:w8] | Stages / full [oura:oura-19, oura:oura-8] | Stages / sleep [apple-health:f23, garmin:g06] |
| HRV | SDNN [apple-health:f3] | None / rMSSD [apple-health:f21, whoop:w6] | None / average_hrv [oura:oura-8] | None / some devices [apple-health:f25, garmin:g18] |
| Resting heart rate | Daily [apple-health:f4] | API [whoop:w6] | Not listed / lowest_heart_rate proxy [oura:oura-8] | All day HR [apple-health:f24] |
| Workouts with HR | Dense [apple-health:f15] | In workouts / avg, max, zones [whoop:w24, whoop:w7] | 1 min HR / no samples [oura:oura-19, oura:oura-10] | High and low only [apple-health:f24] |
| Push workouts | WorkoutKit (spec 4.1) | None [whoop:w9] | None documented | Training API, approval only [garmin:g05] |
| Live HR | Yes | BLE, unverified [whoop:w25] | None found [oura:oura-21] | ANT+ unusable on iPhone [garmin:g24] |

Only Apple Watch fills every row with no approval. Live HR from other devices needs a Bluetooth permission string that breaks the spec's two string rule, so it waits. Never pool HRV across sources: Apple is SDNN, WHOOP and Oura are rMSSD [adaptation-science:f21, whoop:w6]. Keep one baseline per source.

By validity, Oura nightly HRV agreement is highest (CCC 0.97 to 0.99), WHOOP 0.94, Garmin Fenix 6 0.87 [adaptation-science:f13]. Sleep duration is valid everywhere, stages are not (50 to 65 percent), so rules use duration only [adaptation-science:f15]. With several sources, default the recovery source by validity (Oura, WHOOP, Apple Watch), user overridable, and take workouts from Apple Watch when present.

## 3. The adjustment design

**Principles.** Deterministic, transparent, downward only: rules defer or soften, never add load or prescribe rest. HRV guided training gives small gains: modest, mostly non significant performance effects, with the reliable finding being fewer moderate and hard sessions for similar fitness [adaptation-science:f1, adaptation-science:f4]. Position it as safer, never faster. High HRV is ambiguous because it can rise in overreaching [adaptation-science:f8]. No rule is validated in triathletes, and every threshold below is a design choice to tune in the field.

**Baseline method.** Per source, take the mean and SD of the natural log of nightly values over the 35 nights before the latest 7; the signal is the latest 7 night mean. Averaging beats single nights, minimum 3 valid nights a week [adaptation-science:f7]. Apple's limited history API is iOS 27 only, so baselines must tolerate partial history [apple-health:f14].

New rules, continuing annex C (rules 1 to 8 exist):

- **Rule 9, calibration gate.** No rule fires before 14 valid nights, with fewer than 3 valid nights in the last 7 rules are off, and a source change restarts calibration. Strong principle, weak numbers.
- **Rule 10, defer a hard session.** If the 7 night HRV mean is below baseline minus 0.5 SD (the smallest worthwhile change in Vesterinen [adaptation-science:f4]), today's quality session moves to the next free day, else becomes easy. Apple Watch HRV alone cannot trigger it [adaptation-science:f14]. Moderate evidence.
- **Rule 11, swap to easy.** Two consecutive mornings below baseline minus 1 SD (Kiviniemi's threshold [adaptation-science:f5]) plus a second signal (resting heart rate 1 SD or more up, or check-in 2 or lower of 5) turns today's quality session easy at about 80 percent duration. Moderate to weak; the combined objective plus subjective protocol had the largest benefit [adaptation-science:f6], and subjective measures are as sensitive [adaptation-science:f10].
- **Rule 12, sleep note.** 6 hours or less and 1 hour or more under your median adds a note only. Short sleep costs performance about 7.56 percent, but nothing shows restructuring helps [adaptation-science:f16]. Weak to moderate.
- **Rule 13, guardrails.** At most 2 plan changes per rolling 7 days across rules 10 to 12; every change is advisory with a one tap Keep planned session; three overrides in 14 days goes note only; no sync for 48 hours goes silent; taper stays locked.

**Check-in.** One optional tap, 1 to 5. It is the only input for users with no device, where two mornings at 2 or lower offers an easy swap (weak evidence, labelled so in Methods).

**Reason line style.** One sentence for the change, then the two facts, no cause, no medical words:
- "Today's intervals became an easy run. Your HRV has been below your usual range two mornings running and resting heart rate is up. Tap to keep the original."
- "Moved Thursday's tempo to Friday. Your 7 night HRV is below your usual range."
Illness, alcohol and training all move these signals and the cause cannot be identified [adaptation-science:f9], so the app never names one.

**Never done.** No vendor scores as inputs (opaque, and no independent evidence that acting on them helps [adaptation-science:f17]). No SpO2 or skin temperature, dropped at parse [whoop:w6]; no disease language, keeping to FDA general wellness guidance [adaptation-science:f23]. No LLM, no on device Foundation Models, no vendor data in any tuning [whoop:w16, oura:oura-14, garmin:g14]. No vendor values on share cards or share codes without per share opt in (WHOOP terms 4.2.1 and 4.2.4). A WHOOP red recovery must never prompt a harder session [whoop:w21], which downward only rules guarantee.

## 4. Architecture and privacy

**Phase 0, no server.** HealthKit read only, label stays Data Not Collected, the policy says nothing leaves the phone, Info.plist keeps two HealthKit strings. Empty states never say "denied" because read status is hidden [apple-health:f13]. Observer queries only signal change, so compute on app open plus a background refresh and treat delivery as a hint [apple-health:f10, apple-health:f11, apple-health:f12].

**Phase 1a, WHOOP and Oura.** A stateless Vercel proxy that only swaps codes and refreshes tokens; the phone then calls vendors directly. A server is unavoidable because the client secret is needed at the token endpoint and must not be in a mobile app [whoop:w4].
- Own Vercel project and own vendor registrations; credentials cannot be shared across apps or embedded in open source [whoop:w18, oura:oura-16].
- Port Liftspark's pattern (whitelisted token fields, no storage) [architecture:f36, oura:oura-24]. It never ran live for WHOOP or Oura, so expect fixes.
- Tokens in the Keychain, AfterFirstUnlockThisDeviceOnly [architecture:f32]. Single flight refresh on device, persist the new token first, since refresh rotates and concurrent refreshes fail [whoop:w3, oura:oura-3].
- Pull on app open plus one background task. No webhooks: they need a server, user database and APNs [whoop:w11, oura:oura-12, architecture:f29].
- Cache with a hard TTL, default 7 days, until vendors answer in writing. Nothing in CloudKit, share codes or exports.
- Disconnect revokes at the vendor (WHOOP DELETE /v2/user/access [architecture:f15], Oura revoke [architecture:f20]), purges Keychain and cache, retries offline. Oura requires deletion within 72 hours [oura:oura-13].
- Minimum scopes: WHOOP offline, read:recovery, read:sleep, no read:profile [whoop:w2]; Oura daily.

**Label stance and honest uncertainty.** Phase 0: Data Not Collected, firm. Phase 1a: defensible, since Apple says a token or data sent and not retained need not be disclosed [architecture:f1, oura:oura-23]. The uncertainty is real: Vercel Hobby keeps request logs of path, search params and user agent for 1 hour [architecture:f7], and an Apple DTS engineer said servers logging IP and user agent can make a request count as collection, while noting he cannot speak for App Review [architecture:f3]. Mitigate: no application logging, avoid the callback hop that puts the code in a query string [architecture:f36], no analytics, disclose host logs in the policy and review notes, and be ready to update the label. Hobby is non commercial, which a free app fits [architecture:f6]. Phase 2 (stateful relay) would need a rewritten label and is not planned.

## 5. Onboarding and UI changes

**Step 6 becomes Connect your devices**, multi select: Apple Watch, WHOOP, Oura, Garmin, another watch or band, just my phone. Apple Health permission is requested here with a why. WHOOP and Oura rows show Beta and appear only when their flag is on. Send to watch still exists only for Apple Watch.

**Today readiness line**, under the session, with named components, not vendor scores: "HRV on track. Resting heart rate normal. Sleep 7h 10m." or "Learning your baseline, night 9 of 14." Attribution: "Data by WHOOP" [whoop:w21]; Garmin sourced data "Garmin [device model]" near the title [garmin:g12]. Plain text vendor names only, no logos until written approval [whoop:w19, oura:oura-22].

**Methods, Connections screen**, one row per source. Copy by state:
- Not connected: "Connect to adjust your plan from your sleep and HRV. Disconnect any time."
- Calibrating: "Learning your baseline, night 9 of 14. No plan changes yet."
- Connected: "Connected. Last synced 6:40 am."
- Data is old: "No new data for 2 days. Plan changes are paused."
- Needs reconnect: "Sign in again to keep adjusting your plan."
- No room: "This connection cannot take more people right now."
- Disconnect: "Removes the connection and deletes saved readings from this phone."

**By device combination:**
- **None:** phone player, check-in variant of rule 11, no readiness line.
- **Apple Watch only:** full flow, rule 10 off, rule 11 needs the second signal.
- **WHOOP only:** Health gives completion and sleep duration; connected adds HRV, resting heart rate, sleep. Phone player.
- **Garmin only:** Health sleep duration, heart rate, workouts; rule 12 and check-in rule 11 only. Phone player with a card on following the session on the Garmin.
- **Apple Watch plus Oura (or WHOOP):** vendor is the recovery source, Apple Watch does workouts and delivery. Screen says "Recovery from Oura, workouts from Apple Watch".
- **Garmin plus Oura or WHOOP:** vendor API for recovery, Garmin workouts via Health.

## 6. Phased plan and effort

Estimates are my judgment for one developer, not sourced.

**Week 1 spike (3 to 4 days).** Real device matrix: what each source writes to Health, original workout times, background delivery, whether WorkoutScheduler can replace a same day session.

**Phase 0, in 1.0 (about 3 weeks added).** HealthKit reader, per source baselines, Sources screen, onboarding step, Today line, rules 9 to 13 with reason lines and non trapping tests. If time is short cut rules 10 and 12 first.

**Phase 1a, 1.1 (about 4 to 5 weeks).** Proxy, Swift OAuth with a refresh actor, WHOOP and Oura connectors, TTL cache, Connections states, revoke and purge, proxy tests, policy update. Ships OFF by flag; WHOOP has no fake data sandbox, so review notes explain the disabled connections.

**Phase 1b, Garmin:** not planned. **Phase 2:** stateful relay only with demand and a new label.

**Vendor applications to file now** (free):
1. **WHOOP:** create the app at developer.whoop.com, Sandbox 10 members [whoop:w13]. Needs a WHOOP device and membership [whoop:w23]. Request Build only when about half the slots are used [architecture:f16]. The developers@whoop.com address bounced for another developer [whoop:w14].
2. **Oura:** register at developer.ouraring.com [oura:oura-20]; 10 users before approval [oura:oura-5]; write to api-support@ouraring.com; ask branduse@ouraring.com before any logo [oura:oura-22].
3. **Garmin:** program page at developer.garmin.com/gc-developer-program/overview/ [garmin:g01]. Do not apply until the entity question is answered; Personal keys are for your own data [garmin:g04].
4. **Apple:** none; add the background delivery entitlement [apple-health:f10].

## 7. Risks and open questions

Decisions for you:
1. Accept WHOOP and Oura as 10 user betas for months, Garmin API off the roadmap?
2. Buy or borrow a WHOOP and an Oura, since both need real devices.
3. Whether to form an entity for Garmin Starter. This may have legal, tax or work authorization implications needing qualified advice.
4. Comfort with Data Not Collected for the proxy given the log uncertainty.

Written answers needed before connectors go on:
- **WHOOP:** is a rolling local baseline a "permanent copy" or "derivative" [whoop:w15]? Does a recovery aware plan compete with Strain Target or Coach [whoop:w17]? Are PKCE and a long state accepted [whoop:w5]? What changed in the 2026-10-06 terms?
- **Oura:** what "strictly necessary" retention allows [oura:oura-13]; whether a rule engine is an "AI Model" [oura:oura-14]; whether feeding adjustments to another service makes Brickline an Aggregator [oura:oura-17], so keep them inside Brickline; whether a future paid tier needs consent [oura:oura-15]; Oura may revoke access at its discretion [oura:oura-18].
- **Garmin:** which agreement text applies [garmin:g15], approval time, blending with other sources [garmin:g13].
- **Apple:** whether guideline 5.1.1(ix) applies (assumed no with wellness wording).
- **Unknown:** vendor bundle ids (detect at runtime), exact vendor naming rules.

## Corrections applied

- whoop:w9: only DELETE /v2/user/access exists for users; no health data write endpoint. whoop:w12: v1 webhooks removed; v1 REST shutdown not stated. whoop:w14: automated receipts only, one support reply pointed to a bouncing address.
- oura:oura-1: cite the openapi-1.43.json file. oura:oura-4: missing User-Agent "may be rejected", not 403. oura:oura-11: heart rate not named as background sync. oura:oura-15: charging ban verified for the MCP Server only.
- garmin:g07: push and ping/pull not Enterprise only, backfill is. g09: reopening press reported, repo claim dropped. g11: "individuals to Personal" is inference. g15: older PDF dated 2023-10-04. g16, g17, g19, g22, g24, g26: narrowed per fact check.
- apple-health:f25, f26, f29, f33: Garmin sleep score "advised not to rely on"; Vitals says "multiple metrics"; Ultra 4 not in newsroom article; Athlytic article omits resting heart rate.
- adaptation-science:f2 (only the RMSSD subgroup is 0.50, pooled is 0.15), f21, f22 (Humango is third party).
- architecture:f3: DTS engineer did not defer to App Review. f6, f9, f36: limits from the functions page, 30 day wait "in most cases", "persists nothing" covers app code only.
