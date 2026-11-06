# Triathlon app synthesis: verdict and build plan

Prepared for Akshay Kalapgar, 2026-11-06. Inputs: five concept angles, three judge scorecards (summed totals: watch-first 118, plan-first 116, contrarian 115, race-first 108, community-first 80), and four research digests. Full sourced notes with every URL sit in /Users/akshay/Library/Application Support/Claude/side-session-notes/local_c85cdbc0-1f38-49fc-b269-ba1329e8beb6/ next to this file.

## 1. Direct answer

Yes: the triathlon app is a better lead bet than shipping Saddlemark alone, and the Saddlemark spec is worth more inside it than beside it. Saddlemark by itself is a few-times-a-year utility with no comeback loop and an unbuilt computer vision core. The triathlon app sits on a verified hole: Runna proved the race-to-plan-to-watch model (35,585 US ratings) yet still covers only the run leg of its "triathlon" plans, and every tri-specific plan app combined has under 450 US ratings. It also uses Akshay's strongest assets: HealthKit, the Watch work, CloudKit patterns, and the TRIMP engine.

Two parts of the original idea change. The Strava-like community does not ship in 1.0 (section 3). And the Liftspark React plus Capacitor shell is not reused; the app goes native SwiftUI, because the differentiator is an Apple platform API and the AGPL boundary falls exactly there (section 4).

What to build: one app merging the two top-scoring angles, plan-first's brain delivered through watch-first's wedge, with race-first's race window as the retention bridge and contrarian's positioning discipline. Working name Brickline, pending trademark checks; Taperline and Tricadence returned zero App Store results as fallbacks.

## 2. The recommended product

One-liner: pick a race, get an honest swim, bike and run plan, and every session, pool swims included, lands natively in the stock Apple Watch Workout app. Free, private, no account.

From plan-first (the brain): a deterministic template plus rules engine for Sprint, Olympic and 70.3. Benchmarks set zones (swim CSS from a 400/200 test, bike FTP or RPE fallback, run threshold pace), with scheduled test weeks and 4-week retests showing measurable improvement. Onboarding to a full plan preview in under 3 minutes. Adaptation is explainable, never a black box: missed sessions drop rather than stack, ramps soften after repeated misses, TRIMP strain spikes insert an easy day, and every change states a one-line reason. The coach judge called the stated reason the trust feature: if weeks slip, cut adaptation depth before the explanations. Copy says coach-style plans that adapt by transparent rules, never "AI coach." Load math uses the open Banister and Edwards formulas under original names (Load, Fitness, Form), since TSS, IF and NP are live TrainingPeaks trademarks.

From watch-first (the wedge): WorkoutKit scheduling pushes the coming week into the stock Watch Workout app with zero watchOS code to write. Sunday Sync is the ritual; the scheduler's 7-day window makes weekly the honest cadence. Pool swims ship as real sets via watchOS 11 goals, run paces ship as speed range alerts, and race day is an open-goal SwimBikeRunWorkout with transitions, which is correct racing advice anyway. The phone interval player is mandatory scope, not optional: it serves no-watch and Garmin athletes, whose completed workouts still close the loop through HealthKit.

From race-first (the retention bridge): a race window mode from about T minus 21 days. T-minus timeline with genuinely useful notifications (bike service due, carb load start, pack tonight, wake-up math backward from transition close), checklists, conservative pacing and fueling guidance (Jeukendrup carb tiers, clear not-medical-advice framing), and a post-race debrief that compares plan to actual splits and asks three questions whose answers seed the next race. Debrief into "pick your next race" is the best single retention idea in the brainstorm and matches the honest come-back-loop preference.

From contrarian (the discipline): complement rather than compete. A 20-week build is a trust purchase, so lead trust with Sprint and Olympic while 70.3 is the flagship wedge (the first 70.3 is the highest-intent moment in the sport and no free plan product exists there). Offline session and race plan share codes reuse the Breakthru codec so a club captain can distribute a plan with no server. Native SwiftUI throughout.

From community-first: nothing ships, but the pod design (invite-only groups of 2 to 12 training for the same race, recaps ranked on consistency, never speed) and its complete Guideline 1.2 moderation checklist are filed as the future social blueprint.

Bike fit: not in 1.0. The reviewed Saddlemark spec becomes the 1.1 marquee update, bundled with race-first's rebuild check for traveled bikes (before and after fit verification). That gives a strong post-launch beat and a Guideline 4.3 differentiator no competitor has. If the tri app stalls, the spec still works standalone, so sequencing it second loses nothing.

Non-goals for 1.0: full distance 140.6, any social graph or accounts, Strava, WHOOP, Oura or Garmin integrations, nutrition tracking, a custom watch app, open water structured workouts, iPad, Android, and any revenue. StoreKit 2 is scaffolded behind an OFF Info.plist flag per the house pattern; the Paid Apps Agreement stays unsigned.

## 3. The community question, plainly

Defer it. Do not build a feed, accounts, or pods in 1.0. The facts stack one way:

- Moderation duty: UGC triggers App Review 1.2 (filtering, reporting with timely responses, blocking, published contact), with 24-hour action windows cited in rejections. Hosted photos add NCMEC CSAM reporting, and EU DSA baseline hosting duties apply even to a micro enterprise. For one person this is a permanent unpaid on-call job.
- Privacy: public-database content is "collected" under Apple's definition, so App Privacy regresses from Data Not Collected to User Content plus Identifiers. That breaks the pipeline target and the trust wedge.
- Cost: servers cost money at zero allowed revenue (Supabase Pro is 25 dollars per month once the free tier pauses; CloudKit public database is near zero but current quotas are unpublished), and a moderated, server-backed social product drifts toward operating a business. A free serverless app is the defensible posture.
- Cold start: the product would be other people, and the people are on Strava, which bought Runna in April 2025 and sells the bundle at 149.99 dollars per year. Dick Costolo's funded Chorus died in 8 months. An empty feed is worse than no feed.

Borrow community instead: rendered share cards (zero backend, zero moderation), the offline share codes above, and in 1.1 an optional write-only auto-upload of completed workouts to the user's own Strava account, which the upload API allows. Never build features that read or analyze Strava data: the single player rule and the feed replication ban make that a dead end. Pods wait for real bandwidth.

## 4. Liftspark reuse under AGPL

Liftspark is built on AGPL openGym, so the line is:

- Clean to reuse (solely Akshay's copyright, relicensable by him): the native plugins (HealthKit, BLE heart rate, the Watch app with HKWorkoutSession, Live Activity, CloudKit sync), the Edwards TRIMP strain and zones engine, and the thin Vercel OAuth proxy. Run a per-file git history audit before lifting any file, to confirm sole authorship.
- Not reusable in a closed app: the openGym-derived React UI and data model. Shipping them makes the whole new app AGPL; one bundled Capacitor process gives no separation argument, since the FSF treats linking as derivative.
- The clean move is also the right product move: go native SwiftUI (two of the three judges corrected the stack independently), port the TRIMP engine from TypeScript to Swift once with its tests, treat the plugin code as reference, and write the UI fresh. The only genuinely new native surface is WorkoutKit composition and scheduling, pure Swift with no bridge.
- The Vercel proxy and its envs stay parked in 1.0 to preserve Data Not Collected; they are ready for the 1.1 Strava upload.

## 5. Build shape, 12 to 16 solo weeks

- Week 1, gate: Xcode spikes on WorkoutScheduler reliability and its runtime max scheduled count, pool swim custom workouts, SwimBikeRunWorkout behavior, and speed range alerts as pace. The differentiator rests on unverified API behavior; retire that risk first.
- Weeks 1 to 4: plan engine in pure Swift: phases with 3 plus 1 loading blocks, microcycles from available days and pool days, zones from benchmarks. Fully unit tested, no trapping asserts in tested paths.
- Weeks 4 to 6: onboarding to plan preview, Today card with a one-paragraph why, calendar, drag-to-reschedule with week recompute.
- Weeks 6 to 8: WorkoutKit delivery and Sunday Sync; phone interval player fallback.
- Weeks 8 to 10: HealthKit completion matching, TRIMP port, adaptation rules with stated reasons, Monday preview and Sunday recap notifications.
- Weeks 10 to 12: race window mode, race day multisport push, post-race debrief.
- Weeks 12 to 14: template QA with real test weeks, share cards and codes, CloudKit private sync, polish, 1320x2868 screenshots, Vercel site with privacy and support pages on the personal scope.
- Weeks 15 to 16: buffer, Fable end-to-end review, fixes, Akshay's go, submit.

Cut order if slipping: 70.3 moves to 1.1 first, then CloudKit sync, then adaptation depth. Never cut the explanation line or the phone player.

## 6. Top eight open questions for Akshay

1. Posture: is a free, serverless hobby app with StoreKit dormant behind the OFF flag the right shape for now?
2. Week 1 spikes: does WorkoutKit scheduling actually behave (count limit, sync reliability, pool swim goals, multisport)? This is the go or no-go gate.
3. Does private-database CloudKit sync definitively keep the Data Not Collected label? If unclear, is he willing to drop sync from 1.0?
4. Name: does Brickline clear USPTO TESS (a Brickline Greenway exists in St. Louis) and App Store search, or fall back to Taperline or Tricadence?
5. Template credibility: can he get a certified coach or two or three experienced triathletes to review the Sprint, Olympic and 70.3 templates before launch?
6. Scope: is 70.3 in 1.0 worth the QA load, and will he hold the cut list if weeks slip?
7. Positioning facts: verify in Garmin Connect that Garmin Coach stops at Olympic (currently a forum report), and recheck whether Runna is still run-only near launch.
8. Saddlemark: final call on 1.1 marquee module versus standalone app, made at 1.0 submission.

## 7. Verdict

Modified go. Build the triathlon training app as described: plan brain, watch-native delivery, race window mode, no community, native SwiftUI, Saddlemark as the 1.1 beat.

The numbers behind it: Runna charges 19.99 dollars per month or 119.99 per year (149.99 bundled with Strava), holds 35,585 US ratings, took more than 120 people and over 8 million GBP to build, and still sells only the run leg of triathlon. The tri-specific field is tiny and paywalled: MOTTIV has 71 US ratings after five years and a 200k subscriber YouTube funnel (Premium 19.99 per month or 179.99 per year; the free tier has no device sync), TriDot runs 14.99 to 249 per month and just lost its Ironman partnership, Athletica is 189 per year with 41 ratings, Humango sells 79.99 to 169.99 annual IAPs with 21 ratings, TrainingPeaks Premium is 134.99 per year with 12,770 ratings, and 80/20 static plans cost 54.95 to 99.95. Garmin Coach is free but hardware-locked and reportedly stops at Olympic. Free, private, Apple-native and watch-first is structurally unoccupied, and no subscription incumbent can copy it without breaking its own business model.

The honest caution: under 450 combined ratings may also mean the tri plan niche is small. Zwift (21,480 ratings) and TrainerRoad (21,439) show endurance athletes on iOS spend heavily, so the demand exists next door; the hedge is that this build costs nothing to run, reuses most of its hard parts, and leaves Saddlemark intact as a second shot on goal. The two real failure modes are WorkoutKit not behaving, retired in week 1, and Strava shipping Runna triathlon plans, where speed is the only answer and Runna's own cofounder said they skipped tri because it is complicated. If the week 1 spike passes, start building.
