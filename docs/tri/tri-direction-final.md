# Brickline: final direction

Final direction for Akshay Kalapgar's triathlon app with the bike fit as an in-app module, 2026-11-06. It reconciles the synthesis, the 74-fact verification (64 confirmed, 9 corrected, 1 unsupported), the bike fit integration map, and the adversarial review (all fixes applied). Where inputs disagreed, the verified fact or the stricter fix wins. Working name Brickline, not yet cleared.

## 1. Verdict and one-liner

Modified go. Build the triathlon training app: plan brain, watch-native delivery, race window mode, no community in 1.0, native SwiftUI, Saddlemark shipping as the Bike Fit tab in 1.1. Start when the week 1 WorkoutKit spike passes and the owner signs off on the free, serverless posture.

One-liner: pick a race, get an honest swim, bike and run plan, and every session, pool swims included, lands natively in the stock Apple Watch Workout app. Free, private, no account.

The verified case. Runna proved the race-to-plan-to-watch model (35,585 US ratings; all ratings are US storefront, 2026-11-06) yet its triathlon plans cover only the run leg, and all tri-specific plan apps combined hold about 430 US ratings. Runna took a reported 120 to 150 people and roughly 8 to 10 million GBP; Strava bought it in April 2025. Subscription incumbents cannot chase a free niche, and Garmin Coach is free but hardware-locked and reportedly stops at Olympic. Free, private, Apple-native and watch-first is structurally unoccupied.

The caution: 430 combined ratings may mean the niche is small. Zwift (21,480) and TrainerRoad (21,439) prove heavy iOS spend next door, the app costs nothing to run, and Saddlemark stays a second shot on goal. Two failure modes: WorkoutKit misbehaving, retired in week 1; and Strava shipping Runna tri plans, answerable only with speed. The unsourced cofounder quote is dropped; what stands is that Runna has to date chosen not to build swim and bike coaching, a materially harder product. One framing fix: Saddlemark alone is not "a utility with no comeback loop" but a deliberately low-frequency instrument (two pushes a month, triggers a few times a year) on an unbuilt CV core with a week 2 kill decision; it sequences second and gains from an app with a weekly heartbeat.

## 2. The product

**Plan brain.** A deterministic template plus rules engine for Sprint, Olympic and 70.3. Benchmarks set zones: swim CSS from all-out 400 m and 200 m in one session with 5 to 10 minutes active recovery, pace per 100 m = (400 time minus 200 time) / 2, retest flow if the 200 is not faster; bike FTP as 95 percent of best 20 minute power (RPE fallback), retested every 4 to 6 weeks; run threshold pace. Load math uses the open Banister and Edwards constructions under original names, Load, Fitness, Form, because TSS, IF and NP are live TrainingPeaks trademarks. Adaptation is explainable: missed sessions drop rather than stack, ramps soften after repeated misses, a strain spike inserts an easy day, and every change states a one-line reason, the trust feature. Copy says coach-style plans that adapt by transparent rules, never "AI coach." Onboarding to full plan preview in under 3 minutes. The engine claims little because the verified science supports little (polarized training wins only on VO2peak; ACWR flags risk, not prediction).

**Watch delivery.** WorkoutKit pushes the coming week into the stock Watch Workout app with the app's icon and name, zero watchOS code. Sunday Sync is the ritual: the Watch shows only the coming 7 days (a display window, not a documented limit); the true horizon and runtime maxAllowedScheduledWorkoutCount are undocumented, week 1 spike material. Pool swims ship as real sets via watchOS 11 custom pool workouts with the distance-with-time goal; open water custom workouts do not exist in the API. Run paces ship as speed range alerts. Race day is an open-goal SwimBikeRunWorkout with transitions; per-leg intervals do not exist in the API, and open racing is correct advice anyway. The phone interval player is mandatory: no-watch and Garmin athletes close the loop through HealthKit.

**Race window.** From about T minus 21 days: a timeline of useful notifications (bike service due, carb load start, pack tonight, wake-up math), checklists, conservative pacing, and fueling with corrected numbers: for legs over 2.5 hours, 60 to 90 g carbohydrate per hour on the bike and 50 to 70 on the run; glucose absorption caps near 60 g/h and fructose raises the ceiling to about 90. Not-medical-advice framing throughout, which also keeps the app inside FDA's January 2026 general wellness guidance. The post-race debrief compares plan to actual splits and seeds the next race, the retention core.

**Positioning.** Complement rather than compete. Sprint and Olympic build trust; 70.3 is the flagship wedge, stated precisely: MOTTIV's free tier keeps device connections behind its paywall, so no free product delivers a 70.3 plan to any watch, let alone natively. Offline share codes reuse the Breakthru codec so a club captain can distribute a plan with no server.

**Bike fit module placement.** As the integration map recommends: bike fit ships as its own plainly named Bike Fit tab, at 1.1. Not 1.0 (nine more weeks, two coupled kill gates, camera plus HealthKit on a first submission), not a 1.0.x, not standalone. The CV pipeline, saddle height card rules (never firing for TT and tri bikes), noise floor math, language rules and Methods screen transfer unchanged; the merge is budgeted at about 9 solo weeks against the standalone 12. One shared Bike entity owns Setup Card and training config; Pack and Rebuild Check keys off the race record's travel flag; the monthly drift check becomes a recovery week item; fit notifications become a per-module budget (two a month, quiet hours, cancelled on completion) in the app's one scheduler. Camera permission is requested only at first capture; onboarding never mentions the camera. Captures, joint tracks, pain tags and the change log stay on device permanently, excluded from any sync container, unit test enforced. The Saddlemark and Pedalmark names die; the bikefit repo archives into this repo's docs. The hedge stays live: if the tri app stalls the spec works standalone (question 10).

**Non-goals for 1.0.** Full distance 140.6, social graph or accounts, Strava, WHOOP, Oura or Garmin integrations, nutrition tracking, a custom watch app, open water structured workouts, iPad, Android, any revenue. StoreKit 2 scaffolded behind an OFF Info.plist flag per the house pattern; Paid Apps Agreement unsigned; no IAP products ever created.

## 3. What the fact check corrected

64 of 74 confirmed, 9 corrected, 1 unsupported. Every corrected or unsupported fact that changes a number or claim:

- **f20, unsupported, dropped.** The forum sentiment summary (TriDot ambassador-heavy, Hugo "laughably bad," Athletica overpriced) is not in the cited thread, which in places says the opposite. The synthesis did not rest a claim on it; competitor sentiment is treated as unknown.
- **f22, CSS.** Same session, 5 to 10 minutes active recovery; a 200 not faster than the 400 is an error condition prompting a retest, not an "invalid test."
- **f23, FTP.** Retest every 4 to 6 weeks, not 4 to 8; the plan's 4 week cadence sits inside the supported range.
- **f26, intervals.icu.** The trademark rationale for "Load" is a forum user claim and the formula is not on the cited page; the original-names rule stands anyway on f25 (TSS registered 2014, live, renewed 2024, with IF, NP, TP, TPU) and f27 (GoldenCheetah renames).
- **f30, TriDot.** TrainX has no stated 1 to 100 scale; EnviroNorm's factors are temperature, humidity, wind, elevation and elevation gain. Nothing strategic changes.
- **f34, fueling.** No Jeukendrup attribution; 60 to 90 g/h bike and 50 to 70 g/h run for legs over 2.5 hours; the 5 to 8 percent concentration claim is unsourced.
- **f40, CloudKit.** The 2015 ceiling is 1 PB asset storage plus 10 TB database storage (the two were conflated) and 200 TB monthly transfer; current quotas remain unpublished.
- **f42, Strava.** Over 95 percent free users powering engagement is confirmed; the source credits global reach and device integrations, not community network effects.
- **f47, 4.3(b).** Written appeals demonstrating differentiation have succeeded; no documented phone appeal has. If a spam rejection comes, appeal in writing.
- **f54, names.** Taperline: zero US results. Tricadence: four fuzzy matches, none named Tricadence, so the exact name is unused but "zero results" was wrong. TriPace: taken by two triathlon apps.

The adversarial review's remaining fixes (Runna's scale as reported ranges, TriDot's own August 2025 walk-away from Ironman, 1.2's "timely responses" wording, the DSA micro exemption's bounds) are folded into sections 1, 5 and 7.

## 4. Confirmed key numbers

Ratings are US storefront iTunes Search API counts, 2026-11-06. Prices verified this week.

| Product | Price, USD | US ratings |
|---|---|---|
| Runna | 19.99/mo or 119.99/yr, only week 1 free; Strava bundle 149.99/yr, annual only | 35,585 |
| Zwift | 19.99/mo, 199.99/yr | 21,480 |
| TrainerRoad | 21.99/mo, 209.99/yr | 21,439 |
| TrainingPeaks Premium | 134.99/yr since 2025-04-02 | 12,770 |
| MOTTIV | free tier: one race, workout ads, no device connections; Premium 19.99/mo or 179.99/yr | 71 |
| TriDot | 14.99/mo (one Sprint or Olympic race) to 99/mo; coached typically 249/mo | 34 new plus 263 legacy |
| Athletica | 19.90/mo, 99 per 6 months, 189/yr | 41 |
| Humango | annual IAPs 79.99 and 169.99; top tier about 29/mo per a 2024 review | 21 |
| 80/20 Endurance | plans 54.95 (Sprint) to 99.95 (Full); Team 16.58/mo annual incl. TrainingPeaks Premium; free 12 week maintenance plan by code | not an app |
| Garmin Coach | free with a compatible watch; reportedly tops out at Olympic (verify) | n/a |

Tri-specific plan apps combined: about 430 US ratings (MOTTIV 71, TriDot 34 plus legacy 263, Athletica 41, Humango 21); the roster is only as complete as the searches, which surfaced nothing larger.

## 5. The community answer

Defer it. No feed, no accounts, no pods in 1.0:

- Moderation duty. UGC triggers Guideline 1.2 (filtering, reporting, blocking, published contact, removal until compliance); the written standard is "timely responses," with 24 hour expectations only in Apple communications. Hosted photos add NCMEC CSAM reporting, and DSA baseline hosting duties apply even to a micro enterprise: a permanent unpaid on-call job for one person.
- Privacy. Public-database content is "collected" under Apple's definition, regressing App Privacy from Data Not Collected to User Content plus Identifiers and breaking the trust wedge.
- Cost. Servers cost money at zero allowed revenue (Supabase Pro is 25 dollars per month once the free tier pauses; CloudKit public quotas are unpublished), and a moderated social product drifts toward running a business with real costs and duties and no income.
- Cold start. The product would be other people, and the people are on Strava, whose free users (over 95 percent) power its engagement engine; Chorus, Dick Costolo's funded social fitness app, died about 8 months after launch on user psychology. An empty feed is worse than no feed.

Borrow community instead: rendered share cards (zero backend, zero moderation), the offline share codes, and in 1.1 an optional write-only upload of completed workouts to the user's own Strava (FIT, TCX, GPX with activity:write). Verified hard edges: a user's data shows only to that user, compete-or-replicate apps are barred, and new API apps start at athlete capacity 1 with increases not guaranteed, so request capacity early and degrade gracefully. Nothing ever reads or analyzes Strava data. The pod design stays filed with the CKShare notes and the 1.2 checklist, waiting on real bandwidth. Garmin push stays a post-1.1 question (its program reportedly relaunched October 2026); Garmin athletes are served through HealthKit and the phone player from day one.

## 6. AGPL and reuse rules

Liftspark is built on AGPL openGym, so the boundary is drawn file by file:

1. Reusable (solely Akshay's copyright, relicensable per the GNU FAQ): the native plugins (HealthKit, BLE heart rate, the Watch app, Live Activity, CloudKit sync), the Edwards TRIMP engine, and the thin Vercel OAuth proxy. Gate: a per-file git audit confirming sole authorship first.
2. Not reusable: the openGym-derived React UI and data model; combined works fall under the whole-combination rule and modifications stay AGPL. The FSF one-work view is the right planning assumption though untested in court, and the stronger point stands: App Store terms are held incompatible with the AGPL (the VLC precedent), so even open sourcing the new app would not help.
3. Port, do not wrap: native SwiftUI throughout; port the TRIMP engine from TypeScript to Swift once, with tests; plugin code is reference; the UI is written fresh. The only new native surface is WorkoutKit, pure Swift. The Vercel proxy stays parked in 1.0, ready for the 1.1 Strava upload.
4. Trademark hygiene: Load, Fitness, Form over open formulas; TSS, IF and NP never in app, metadata or site; one merged forbidden-word unit test covers them, "AI coach," and the fit module's language rules.

## 7. Build shape

1.0 is 16 planned solo weeks, 12 to 14 with the cut list; no 12 week path exists without cuts.

- Week 1, gate: Xcode spikes on WorkoutScheduler reliability, runtime maxAllowedScheduledWorkoutCount, the real scheduling horizon, pool swim custom workouts, SwimBikeRunWorkout behavior, speed range alerts as pace. The differentiator rests on unverified API behavior.
- Weeks 1 to 4: plan engine in pure Swift: 3 plus 1 loading blocks, microcycles, zones from benchmarks. Fully unit tested, no trapping asserts.
- Weeks 4 to 8: onboarding to plan preview, Today card with a one-paragraph why, calendar, drag-to-reschedule; then WorkoutKit delivery, Sunday Sync, the phone interval player.
- Weeks 8 to 10: HealthKit completion matching, TRIMP port, adaptation rules with stated reasons, Monday preview and Sunday recap notifications.
- Weeks 10 to 12: race window mode, race day multisport push, post-race debrief.
- Weeks 12 to 14: template QA, share cards and codes, polish, 1320x2868 screenshots, the Vercel site (personal scope) with privacy and support pages. CloudKit private sync builds only if the Data Not Collected question resolves before week 12; otherwise it moves to 1.1 per the spec's A36 decision; local SwiftData is the system of record either way.
- Weeks 14 to 16: buffer, Fable end-to-end review, fixes, Akshay's go, submit.

Cut order, revised: adaptation depth first (rules shrink, the explanation line stays), then 70.3 to 1.1, a positioning cut: without it 1.0 overlaps free Garmin Coach's reported range, so messaging shifts to pool swims and race day on the watch, and 70.3 ships in the first update. Never cut the explanation line or the phone player; CloudKit sync is conditional, not a cut.

1.1, with the bike fit module placed:

- During the 1.0 App Review wait, run the Saddlemark bench (the spec's weeks 1 to 2, spike code). Kill criteria bind: pooled SEM of knee flexion at max extension above 2.2 degrees, or a 10 mm saddle move reported as Changed in fewer than 8 of 10 trials, stops the module.
- Pass: about 7 to 8 further weeks after 1.0 ships, the second beat roughly two months post launch. Fail: 1.1 ships a prepared fallback beat (slipped 70.3, the Strava upload, Carry, PDF export); nothing about bike fit is announced until the bench passes. If 1.0's cut list was exercised, the slipped scope ships first in a small release.
- Review posture: one binary now holds HealthKit, WorkoutKit and a camera, so the 1.1 review notes say in one line that video is processed on device and deleted at once, and link the methods page. The branch stays separable so a module rejection cannot block training fixes; the module never ships dark behind a flag. Upside: 4.3 spam risk falls.
- Module ship gates: bench numbers in the Methods screen; golden clip within 1 degree on two iOS versions; forbidden-word scan and Info.plist tripwires green; sync schema exclusion test green; no trapping test paths, named simulator shut down after; Fable review of the whole 1.1; App Privacy re-confirmed; Akshay's explicit go.

## 8. Open questions, merged and deduplicated

1. Posture: is the owner comfortable that a free, serverless app with StoreKit dormant stays a hobby project?
2. Week 1 spike: does WorkoutKit behave (max count, horizon, sync reliability, pool goals, multisport, pace alerts)? The go or no-go gate.
3. CloudKit private sync: does it keep Data Not Collected and clear 5.1.3(ii) (no personal health information in iCloud)? Until both answer yes, sync stays out; fit artifacts stay out permanently regardless.
4. Name: does Brickline clear USPTO Trademark Search (TESS is retired) and App Store search, given the St. Louis Brickline Greenway? Fallbacks: Taperline or Tricadence; TriPace is taken.
5. Template credibility: will a certified coach or a few experienced triathletes review the templates before launch?
6. Scope: is 70.3 in 1.0 worth the QA load, and will the revised cut order hold if weeks slip?
7. Positioning watch: verify Garmin Coach's Olympic ceiling in Garmin Connect; recheck Runna's run-only status near launch.
8. Bench: do the kill criteria pass during the review wait, and is the fallback 1.1 beat chosen before the bench starts?
9. Strava capacity: when is the API app registered, and what does the 1.1 upload do if capacity stays at 1?
10. Standalone hedge: if Saddlemark is ever spun back out, rerun its name clearance and pricing snapshot first; both go stale.

## 9. Immediate next steps

1. Week 1 spikes, on a named simulator shut down after: schedule and sync through WorkoutScheduler; read maxAllowedScheduledWorkoutCount at runtime; probe scheduling beyond 7 days; build one pool swim custom workout with the distance-with-time goal; build one open-goal SwimBikeRunWorkout; test speed range alerts as run pace. Findings become the go or no-go record.
2. Owner sign off this week on the free, serverless posture: no revenue, no ads SDK, no analytics, no server, StoreKit dormant.
3. Name checks before anything ships in repo, site or metadata: Brickline through USPTO Trademark Search and App Store search; hold Taperline and Tricadence as fallbacks; do not use TriPace.
4. Line up template reviewers; run the per-file git audit on the Liftspark files slated for reuse; calendar the Saddlemark bench for the App Review wait with kill criteria and the fallback beat written down first.

Verification counts: {"confirmed":64,"unsupported":1,"corrected":9}
