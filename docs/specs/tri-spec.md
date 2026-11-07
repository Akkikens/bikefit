# Brickline: triathlon training on iPhone and Apple Watch

Product spec, version 0.2, 2026-11-06. Author: Akshay Kalapgar with a Fable research, brainstorm and verification pass (four research sweeps, five product angles, three judges, 74 key facts checked: 64 confirmed, 9 corrected, 1 unsupported; direction and sources in docs/tri) and a Fable review of version 0.1 (five lenses, 48 confirmed findings applied). Engineering detail lives in tri-annex.md; numbers quoted here are convenience copies and the annex tables are canonical. The bike fit module is specified by bikefit-spec.md plus docs/tri/tri-bikefit-integration.md. Working name only; see section 14. Spec only, no code yet.

## 1. Intent and the why

Runna proved the model: pick a race, get a plan built by coaches and adapted by rules, follow every session on your watch. It holds 35,585 US ratings, grew to a reported 120 to 150 people on roughly 8 to 10 million GBP raised, and sold to Strava in April 2025 (B1, B3, B4). Its "triathlon" plans still cover only the run leg (B2). Every triathlon specific plan app combined holds about 430 US ratings, and all of them paywall the essentials: MOTTIV keeps device sync behind 19.99 USD a month, TriDot runs 14.99 to 99 USD a month self serve (about 249 with a coach) and itself walked away from its Ironman partnership in August 2025, Athletica is 189 USD a year, TrainingPeaks Premium is 134.99 (B5 to B8). Garmin Coach is free but needs a Garmin watch and reportedly stops at Olympic distance (B10). Nobody owns the first triathlon the way Couch to 5K owns the first 5K, and no product is Apple Watch first.

Brickline is the missing shape: pick a race, get an honest swim, bike and run plan, and every session, pool swims included, lands natively in the stock Apple Watch Workout app. Free, private, no account. The plan engine is deterministic templates plus transparent rules, never "AI coach" theater. The reviewed Saddlemark bike fit spec ships inside it as the Bike Fit tab in 1.1, a feature no competitor at any price has.

Why Akshay: it reuses his hardest won assets (HealthKit and Watch experience from Liftspark, his heart rate load engine, the share card pattern, the Breakthru share codec), it costs nothing to run, and the two constraints that hurt everyone else, free and private, are ones he has to honor anyway.

## 2. Target users and jobs

Day one user: an age group (amateur) triathlete or aspiring one with an iPhone, training for a Sprint, Olympic or 70.3, the half iron distance. Three personas in priority order: the first timer who signed up for a sprint or Olympic and is scared of the swim; the first 70.3 athlete, the highest intent moment in the sport, who signs up 6 to 9 months out and today chooses between a 50 to 100 USD static TrainingPeaks style plan (B11) and a 39 plus USD a month subscription; and the Apple Watch triathlete who is tired of being a second class citizen in a Garmin world.

Jobs:

1. I have a race date and no plan. Give me one that fits my hours and days.
2. Tell me exactly what today's workout is, on my wrist, without me building intervals by hand.
3. I missed Tuesday. Fix the week without making me feel behind.
4. Race week is chaos. Tell me what to do each day, what to pack, how to pace and fuel.
5. After the race: what happened, and what is next?

Not the target in 1.0: full distance 140.6 athletes (expectation liability, 1.1 at the earliest), data maximalists with human coaches (TrainingPeaks owns them), Android and iPad, children (adult framing throughout).

## 3. The training engine

### 3.1 Benchmarks and zones

Three field tests anchor everything, each with a guided flow, a retest cadence and an RPE fallback (rate of perceived exertion, a simple 1 to 10 feel scale) so a plan never blocks on gear:

- Swim: CSS (critical swim speed) from an all out 400 m and 200 m in one session with 5 to 10 minutes active recovery; pace per 100 m is (400 time minus 200 time) divided by 2; if the 200 is not faster the app explains and offers a retest (B24). Swim zones are app defined offsets from CSS (annex A), stated as such because no standard exists.
- Bike: FTP (functional threshold power, roughly the highest power an athlete can hold for about an hour) as 95 percent of best 20 minute average power with the standard clearing effort (B23); heart rate zones from a 30 minute LTHR (lactate threshold heart rate) test when no power source exists.
- Run: threshold pace and LTHR from the 30 minute time trial protocol (average heart rate of the final 20 minutes), validated against lab testing (B25).

Retests rotate: test weeks sit on block boundaries, at most two sports test per test week, so each sport retests about every 6 weeks, inside the supported range (annex A). Zone tables and all formulas are in annex A; every scheme is printed on the Methods screen with its source.

### 3.2 Plans

A session is a planned unit of training; a workout is what the watch, phone player or HealthKit records. Plans are template plus rules, coach shaped, fully deterministic. Distances: Sprint, Olympic, 70.3. Lengths 8 to 24 weeks, chosen from the race date; phases split roughly 40 to 50 percent base, 30 build, 15 peak, 5 to 10 taper (the wind down before the race), in 3 plus 1 loading blocks with a recovery week each fourth week (B38). Weekly hours fit what the athlete declares: Sprint 4 to 7, Olympic 6 to 10, 70.3 8 to 14, with peak weeks 20 to 30 percent above average and recovery weeks 30 to 40 percent below (B38). Intensity is polarized, meaning mostly easy with a little very hard: roughly 80 percent of session time easy, and quality sessions capped per week in total by level, first timer 2, intermediate 3, experienced 4, with at most 2 in any one sport; the Methods screen says plainly that polarized training's proven superiority is limited to VO2 peak outcomes (B27). One 10 to 20 minute transition run follows a key ride weekly in build and peak; this ride then run pairing is a brick, triathlon's signature workout, which teaches the legs the bike to run switch, scaling toward race specific formats for 70.3 (B28). Beginner run plans offer run walk intervals, framed honestly: similar finish times, less post race soreness, shown in marathon runners and applied here as a comfort and adherence option (B31). Taper parameterizes by distance, about 1 week Sprint to 2 weeks, up to 3, for 70.3 (app parameter inside the B38 span), cutting volume while keeping some intensity. The full parameter table with per distance values is annex B.

Every session has a name, a purpose sentence, structured steps, and a pool alternative for any open water session; open water is never required (section 6).

### 3.3 Adaptation, transparent rules only

The engine does exactly what Runna documents, as deterministic rules, and every change states a one line reason, the reason line, the trust feature (B39):

- A skipped session may move to a later free day in the same week, except a day already holding a quality session, and never creates a second quality day; with no slot it drops.
- Three or more misses in 14 days, or a missed week, triggers a realignment prompt: resume where you are, or compress (annex C rule 2).
- Consistent over or under performance across completed sessions nudges paces one step, ignoring outliers.
- Feeling unwell caps the plan to easy sessions for up to 14 days.
- Ramp control: a load week's planned load may not exceed 110 percent of the most recent load week, recovery weeks excluded from the comparison and template designed peak and taper weeks exempt by construction, so the cap polices adaptation and athlete edits, not the plan's own shape. Framed as a sane default, never as injury prevention, because the one randomized trial found no injury reduction (B30). An acute spike in load (7 day over 28 day ratio above about 1.5) inserts an easy day and says why, labelled a caution heuristic because the research consensus rejects it as a predictor (B32).
- Taper is locked: no added intensity inside race week.

The full rule table with thresholds is annex C. Copy says coach style plans that adapt by transparent rules. The words AI coach never appear.

### 3.4 Load, honest names

Session load is computed from power when present (intensity squared times hours times 100 against FTP) with a heart rate fallback built on time in LTHR anchored zones, evolved from Liftspark's TRIMP engine (training impulse, a heart rate based load score), surfaced as Load. A 42 day exponential average of daily Load surfaces as Fitness, a 7 day average is kept internal as Fatigue, and Form surfaces as Fitness minus Fatigue using yesterday's values (B26, formulas in annex D). TSS, IF, NP, TP and TPU are registered TrainingPeaks trademarks and never appear in the app, metadata or site (B22); a unit test enforces the ban.

## 4. Delivery: the watch and the phone

### 4.1 WorkoutKit, the wedge

Every planned session becomes a structured workout in the stock Apple Watch Workout app, with Brickline's icon and name, via WorkoutKit scheduling (B12). No watchOS code ships in 1.0. Pool swims are real sets using watchOS 11 custom pool swim workouts with the distance with time goal; the stock app converts distances if the pool length differs (B13). Run intervals carry pace as speed range alerts; bike intervals carry power or heart rate alerts; every goal and alert is gated per device by the runtime supports APIs, because Apple publishes no static capability list (B12). Open water custom workouts do not exist in the API, one more reason pool alternatives are first class (B13). Race day is an open goal SwimBikeRunWorkout with automatic transitions; per leg intervals are not expressible in the API, and racing on feel with a plan memorized is the correct advice anyway (B14).

Sunday Sync is the ritual: once a week the app pushes the coming week to the watch and shows what landed. The scheduler's true horizon and its maximum scheduled workout count are undocumented and must be read at runtime; the week 1 spike (section 11) retires this risk before anything else is built (B15). The full session to WorkoutKit mapping, per sport alert types and fallbacks, is annex E.

### 4.2 The phone player and the HealthKit loop

A phone interval player (big timer, current step, next step, voice cues) is mandatory scope: it serves athletes with no watch and Garmin athletes, whose completed workouts still arrive through HealthKit. It keeps working with the screen locked through the background model in annex E. Completion matching reads HealthKit workouts (all types including swimBikeRun with per activity statistics, lap and stroke data for swims, cycling power, routes) and matches them to planned sessions by type, time and duration, with a manual match fallback (B16, B17). The player saves its own finished workouts to HealthKit with share permission scoped to the workout type, never writing fabricated data (B19); everything else stays read only.

### 4.3 What is deliberately not built

No custom Watch app in 1.0: the stock Workout app's swim set detection and multisport transitions (B41) are better than anything a solo dev can write, and WorkoutKit makes the custom app unnecessary for delivery. The Liftspark Watch app stays in reserve for a future live coaching mode. No Garmin, Wahoo, Suunto or COROS integrations in 1.0: all gate behind applications, most requiring a business entity, and Garmin's program paused for much of 2026 and reportedly relaunched in October; the Garmin Starter application is filed early but nothing depends on it (B21).

## 5. The race window and the debrief

From about T minus 21 days (T minus 10 for Sprint) the app shifts into race mode; the full timeline lives in annex F:

- A T minus timeline of genuinely useful notifications: bike service due, carb load start, pack tonight, wake up math from the start time. Notification volume follows annex H, which caps the race window additions.
- Checklists: packing by discipline, transition bag, race morning. The Pack and Rebuild Check from the bike fit module keys off this race record's travel flag once the module ships.
- Pacing: conservative target ranges from the athlete's own zones by distance, never single splits; on hilly or windy long course races flat calculators can run 15 to 25 minutes off, and the card says so (annex F).
- Fueling, keyed to each leg's expected duration: under about 75 minutes, fluids to thirst and no carbohydrate target; about 1.25 to 2.5 hours, roughly 30 g per hour scaling toward 60; over 2.5 hours, 60 to 90 g per hour on the bike and 50 to 70 g on the run, with the glucose fructose mechanism explained and the warning that taking more than the duration needs mainly raises stomach trouble (B29). Fluids by thirst with an optional sweat rate test; no sodium prescriptions, because no primary consensus figure was verified. All framed as published guidance to practice in training, never medical advice.
- Race morning screen: timeline, checklist, a calm tone, no data. No weather in 1.0: WeatherKit is a network service to Apple and would break the section 9 no network rule; it becomes a candidate only if it clears that rule and the Data Not Collected label (annex F stays the controlling text).

The post race debrief is the retention core: planned versus actual splits from the HealthKit multisport workout, what went well, one thing to change, and a prompt to pick the next race, which starts the next plan. Between seasons the app goes quiet except a monthly maintenance nudge the athlete opts into.

## 6. Language, safety and credibility rules

- Framing: fitness, endurance and training. Forbidden anywhere in app, metadata or site: diagnose, treat, doctor, injury, illness, prevention claims, named conditions, medical grade, clinical, AI coach, and the TrainingPeaks marks (B22, B33). Exemptions live in one Safety.strings file, exactly three strings (annex K): the onboarding acknowledgement, the unwell mode line, and the open water safety card. A unit test scans all strings, metadata and site copy against the full list with only those exemptions.
- Onboarding acknowledgement: the exact text lives in annex K and is the canonical copy; it covers not medical advice, the doctor check before starting a new program, and the stop conditions. This is the industry standard set and keeps the app inside FDA general wellness policy, which names exercise and endurance improvement as wellness uses (B33).
- Open water: never scheduled as required; every swim has a pool equivalent; any open water session the athlete opts into carries the fixed annex K safety card (swim with others, tow float, know the venue, cold water caution). The app never claims supervision.
- Credibility: at least one certified coach or several experienced triathletes review the three template families before launch, named in the Methods screen with permission; the Methods screen carries every formula, source and limitation, the same pattern as the bike fit Methods screen.
- Honest marketing: the listing leads with what is unique (every sport on your watch natively, free, private, and later the camera bike fit), never comparative claims, no competitor names (B19, guideline 2.3 discipline carried over from the bike fit spec).

## 7. User flow

1. First launch. What it does, the acknowledgement, what happens to data (stays on the phone), adult framing. No account.
2. Pick a race: distance, date, name it. Or "no race yet, build me a base block".
3. About you: experience level, weekly hours, available days, pool days, gear (watch yes or no, power meter, trainer, and optionally your bike: name and type). Benchmarks now or from recent efforts: the app can seed zones from a recent hard HealthKit workout per the annex A seeding rules, clearly labelled Estimated until a test is done.
4. Plan preview in under 3 minutes from first launch: the whole arc, this week in detail, hours per week, test weeks marked. Accept or adjust hours and days.
5. Today card: the session, its purpose sentence, its steps, one tap to send to watch (or it is already there from Sunday Sync), the phone player button, and the reason line when adaptation changed anything.
6. Week and season views: calendar, drag to reschedule inside the week with instant recompute, phase bar showing where you are in the arc.
7. Completion: workouts arrive from HealthKit and match automatically; the session card shows planned versus done; Load, Fitness and Form update; Monday preview and Sunday recap notifications summarize (annex H).
8. Benchmarks: scheduled test weeks with guided test flows; a measurable improvement card after each retest.
9. Race window and debrief per section 5.
10. Share: a rendered share card per workout and per race (zero backend), and a plan share code so a club captain or coach can hand a plan to a friend, the Breakthru codec pattern, offline, no server. Failure paths for every step in annex G.

## 8. MVP scope and non goals

1.0 ships: Sprint, Olympic and 70.3 template families with the rule engine; benchmarks and zones; WorkoutKit delivery with Sunday Sync; the phone interval player; HealthKit completion loop; Load, Fitness, Form; adaptation with reason lines; a minimal Bike record (name, type, service notes) in the gear layer, feeding the race window's bike service reminder and serving as the shared entity the 1.1 Bike Fit tab extends (integration map section 2.1); race window, race day multisport push and debrief; share cards and plan share codes; Methods, privacy and support screens; StoreKit 2 scaffold behind an OFF flag (section 10). iOS 18 minimum (the pool swim goal and step name APIs are iOS 18 on the phone side); iPhone only; SwiftUI, SwiftData, no network calls, no accounts.

Non goals for 1.0: full distance 140.6; any social graph, feed, accounts or community (an empty feed is worse than none, and the people are already on Strava, B36, B37); Strava, Garmin, Wahoo, Suunto, COROS integrations; nutrition logging; a custom Watch app; open water structured workouts; strength plans (Liftspark exists); coach marketplace; iPad, Android; CloudKit sync unless the privacy question resolves first (section 9); any revenue.

1.1, in order: the Bike Fit tab from the Saddlemark spec, gated by its own bench kill criteria run during the 1.0 review wait (integration map: about 9 solo weeks total, the 2 week bench during the review wait and about 7 to 8 weeks after 1.0 ships; shared Bike entity, Pack and Rebuild Check keyed to races, fit notifications inside the shared budget); write only Strava upload of completed workouts (FIT or TCX with activity write scope, capacity requested early, graceful at capacity 1, never reading Strava data, B20; ships only if the privacy label question in section 9 clears); 70.3 if it was cut; CloudKit private sync if cleared; the Garmin Starter integration if approved (B21).

## 9. Data and privacy

- All processing on device. No network calls in 1.0; the only traffic is the App Store. No third party SDKs, analytics, ads, accounts or remote notifications.
- App Privacy label: Data Not Collected, under Apple's definition that on device processing is not collection (B18). Crash logs arrive only through Apple's opt in.
- HealthKit: read authorization per type, plus share (write) authorization for the workout type only, requested the first time the athlete starts a phone player session and used solely to save workouts the player records; all other access stays read only. Used only for training features, stated in the description (B19, guideline 2.5.1). HealthKit derived data never goes to iCloud: guideline 5.1.3(ii) bars personal health information in iCloud, so any future sync container excludes workouts, benchmarks, zones and anything derived from HealthKit, enforced by a schema unit test (B19). That leaves plan skeletons and race records as the only sync candidates, which is why sync is a 1.1 question, not a 1.0 feature.
- The 1.1 Strava upload sends completed workouts off device at the user's explicit direction. Before it ships: verify against Apple's optional disclosure criteria whether Data Not Collected holds, and add an explicit per upload consent screen naming what is sent, per guideline 5.1.2(i); if the label cannot hold, the feature is dropped or the label is updated before release.
- Notifications are local only and need no purpose string; Info.plist purpose strings in 1.0 are the two HealthKit strings only. The camera string arrives with the Bike Fit tab in 1.1, scoped to that tab exactly as the bike fit spec defines.
- The privacy policy follows the annex I checklist, on the Vercel personal scope site and in the app.

## 10. Monetization

Recommendation: free with no revenue for now.

Built but gated off: StoreKit 2 scaffold behind an Info.plist boolean shipping false, read once at launch, the Wingline pattern, final key name follows the app name. No Paid Apps Agreement, no products created. While off, which is every 1.0 build: no plan limits, no Pro labels, no locked controls, no purchases row; a unit test asserts the key is false.

If ever on: a Pro tier (multiple concurrent races, full distance plans, deeper adaptation, bike fit history depth) priced against Runna's 119.99 a year and MOTTIV's 179.99, with everything a free user had grandfathered. Never ads, never analytics.

## 11. Validation and quality plan

Week 1 spikes, the go or no go gate, on device:

- WorkoutScheduler: authorization, schedule and sync reliability, the runtime maximum scheduled count, behavior past 7 days.
- One custom pool swim workout with the distance with time goal, run on a real watch in a pool if at all possible.
- One open goal SwimBikeRunWorkout end to end.
- Speed range alerts as run pace targets; power and heart rate alerts on bike steps.
- The supports API results for a goal only pool swim on an older watch, simulated or, failing that, documented as unverifiable; the watchOS 10 tier claim stays out of positioning until a device confirms it.
- One 30 minute phone player session with the phone locked throughout: cues heard at every step boundary, the Live Activity countdown correct, on a real device.
- HealthKit read back of each, including per activity statistics.

Findings become a written go or no go record. Stop criteria: scheduling proves unreliable (sessions missing or duplicated on the watch in normal use), or pool swim sets cannot be expressed, in which case the product falls back to phone player first and the watch wedge claim is dropped from all positioning before any code is written on top of it.

Plan quality: golden plan fixtures per distance, level and hours (full generated plans checked into tests with expected session counts, hours, ramp rates and taper shape); property tests that no generated week ever exceeds the load week over load week ramp cap, the quality session caps, or the 80 percent easy distribution tolerance, and that the taper lock holds; the coach review of section 6; and a live test: Akshay trains on a generated plan for at least four weeks before submission, starting no later than week 10 of the build (section 15).

## 12. Risks and open questions

Risk register (likelihood, impact, mitigation):

- WorkoutKit misbehaves in the field (medium, fatal to the wedge). Week 1 spike; phone player fallback already mandatory scope.
- Strava ships Runna triathlon plans (medium, high). Speed; the free private positioning and bike fit module stay differentiated even then; Runna's own help pages still say run only (B2).
- The tri plan niche is genuinely small, about 430 combined US ratings (certain, medium). The app costs nothing to run, reuses assets, and the bike fit module widens the audience to all cyclists later.
- Guideline 4.3 spam rejection in a template heavy category (low, medium). Lead metadata with what no other app has; if rejected, reply in Resolution Center with a written explanation of what is unique and, if needed, ship a differentiating change and resubmit; the documented approvals followed differentiation changes, not appeals by any channel (B19).
- Open water incident involving a user (low, high). Section 6 posture: never required, safety card, disclaimers; no supervision claims.
- Template credibility attacked by coaches (medium, medium). Named reviewer, Methods screen with sources, transparent rules instead of AI claims.

Open questions for Akshay:

1. Owner sign off on the free, serverless posture before launch.
2. Week 1 spike outcomes, the gate.
3. Name: Brickline through USPTO search (a Brickline Greenway exists in St. Louis) and full App Store browse; fallbacks Taperline (zero results) and Tricadence (B40).
4. Coach reviewer: who, and on what terms?
5. Is 70.3 in 1.0 worth the QA load? Current answer yes as the flagship wedge; cut order says adaptation depth goes first if weeks slip.
6. CloudKit sync: does plan only sync (no HealthKit derived data) keep Data Not Collected? Apple is silent; ship local only until answered.
7. Garmin Starter application timing and whether approval ever arrives (B21).
8. Bike fit bench scheduling during the review wait, and the fallback 1.1 beat if it fails.
9. Race day multisport delivery on older watches: the multisport type exists from watchOS 9 (B41), but capability is gated by the supports APIs and the older watch setting (annex E), not by reading the paired watchOS version, which iOS does not expose. Week 1 spike covers it.
10. Liftspark file audit: which files are solely Akshay's, confirmed per file from git history, before any port (B34).
11. Strava upload versus the Data Not Collected label: same verification as the CloudKit question, resolved before 1.1.

## 13. Go or no go

Verdict: modified go, same as the direction document. Build it if the week 1 spike passes.

| Product | Price, USD | US ratings |
|---|---|---|
| Runna | 19.99/mo or 119.99/yr; Strava bundle 149.99/yr | 35,585 |
| Zwift | 19.99/mo, 199.99/yr | 21,480 |
| TrainerRoad | 21.99/mo, 209.99/yr | 21,439 |
| TrainingPeaks Premium | 134.99/yr | 12,770 |
| MOTTIV | free tier without device sync; 19.99/mo or 179.99/yr | 71 |
| TriDot | 14.99 to 99/mo self serve, coached about 249/mo | 34 new, 263 legacy |
| Athletica | 19.90/mo or 189/yr | 41 |
| Humango | 79.99 and 169.99/yr IAPs | 21 |
| Garmin Coach | free, Garmin watch required, reportedly Olympic max | n/a |

All ratings US storefront, 2026-11-06 (B1, B5 to B10). The bear case is honest: about 430 combined tri app ratings may mean a small niche. The bull case: Zwift and TrainerRoad prove heavy iOS endurance spend next door, Runna proved the exact product shape sells, the niche has no free, no private and no Apple native entrant, and this build costs nothing to run while reusing most of its hard parts.

Success at 90 days uses only observable signals, since the app has no analytics: 3,000 plus downloads from App Store Connect's own reporting, reviews and support mail describing plans followed to race day, and share cards or debriefs appearing in the wild. Funnel rates (plan previews reached, week 4 completion) come only from TestFlight and Akshay's test circle, are self reported, and never gate the 1.1 decision on their own. Those signals trigger the 1.1 investment; far below them, the app stays in maintenance and the bike fit module decision is revisited standalone.

## 14. Name

Brickline is the working favorite: the name leans on the brick (defined in 3.2) and matches the Wingline and Layover house style. Risks: a Brickline Greenway civic project in St. Louis and food businesses of the same name; USPTO search and a full App Store browse are required before anything ships under it (B40). Fallbacks, both with zero exact App Store results on 2026-11-06: Taperline (also the race first concept's favorite) and Tricadence. Avoid TriPace (two existing triathlon apps), Trivelo (established UK blog), anything with Openwater or Swim Bike Run (generic or taken). The standalone bike fit app names (Saddlemark, and the earlier candidate Pedalmark) retire; the module ships as the Bike Fit tab.

## 15. Build plan

Sixteen planned solo weeks; 12 to 14 with the cut list. Cut order: adaptation depth first (rules shrink, the reason line stays), then 70.3 to 1.1 with messaging shifted to pool swims and race day on the watch. Any weeks 1 to 10 deliverable unfinished at the end of week 11 exercises the cut order. Never cut the reason line, the phone player or the acknowledgement.

- Week 1, gate: the spikes of section 11, on a named simulator and a real watch, written go or no go.
- Weeks 1 to 4: plan engine in pure Swift: templates, phases, microcycles from available days and pool days, zones from benchmarks, fully unit tested, no trapping asserts in tested paths.
- Weeks 5 to 6: onboarding to plan preview, Today card with the purpose sentence, calendar, drag to reschedule with week recompute.
- Weeks 7 to 8: WorkoutKit delivery, Sunday Sync, the phone interval player with its background model.
- Weeks 9 to 10: HealthKit completion matching, the load engine port with its tests, adaptation rules with reason lines, Monday preview and Sunday recap notifications. The live test starts no later than the start of week 10, and may start at week 9 delivery only (sessions to the watch, completion logged manually), with matching and adaptation joining as they land, so the adaptation code gets at least three weeks of field soak.
- Weeks 11 to 12: race window, race day multisport push, debrief.
- Weeks 13 to 14: template QA against golden fixtures, the live test concluding (a submission gate per section 11: any slip past a week 10 start moves the submission date, consuming the buffer first and never the test length), share cards and codes, polish, screenshots at 1320 by 2868, Vercel site with privacy and support pages.
- Weeks 15 to 16: buffer, Fable end to end review, fixes, Akshay's go, submission with release after approval. App Store Connect app created by Akshay in the web UI; listing via the API; App Privacy set by Akshay.
- During the review wait: the bike fit bench per bikefit-spec section 10; pass starts the 1.1 module build, fail ships the fallback beat.

Test plan in annex J. Commits by Akshay as sole author, no trailers. Unit tests never trap; the named simulator shuts down after each run.

## Appendix: sources

Checked 2026-11-06 by the research and verification pass; full notes with every URL in docs/tri, corrections applied per the fact check (docs/tri/tri-direction-final.md section 3).

- B1. Runna: iTunes Search API, US, 35,585 ratings, seller Strava Inc.; price 19.99 USD/mo or 119.99/yr, week 1 free. https://itunes.apple.com/search?term=runna&entity=software&country=us and https://the5krunner.com/2026/10/14/is-runna-free/ Bundle 149.99/yr annual only: https://marathonhandbook.com/strava-and-runna-launch-joint-subscription/
- B2. Runna triathlon plans cover the run leg only; no duathlon. https://support.runna.com/en/articles/15443877-how-to-create-a-training-plan-in-runna
- B3. Runna scale: reported 120 to 150 people around acquisition (some reports up to 180) and roughly 8 to 10 million GBP raised. https://startups.co.uk/news/runna-acquired-by-strava/ and https://app.welcometothejungle.com/companies/Runna
- B4. Strava acquired Runna, April 2025. https://dcrainmaker.com/2025/04/strava-acquires-runna-thoughts-forward.html
- B5. TriDot pricing page (Lifestyle 14.99, Essentials 39, Complete 99, coached typically 249 USD/mo). https://www.tridot.com/pricing TriDot terminated the Ironman partnership itself, August 2025: https://slowtwitch.com/industry/lessons-from-the-ironman-x-tridot-break-up/ Ratings: iTunes Search API (34 new app, 263 legacy).
- B6. MOTTIV pricing (free tier: one race, workout ads, no device connections; Premium 19.99/mo or 179.99/yr); 71 US ratings. https://www.mymottiv.com/pricing and https://apps.apple.com/us/app/id1561001166
- B7. Athletica 19.90/mo, 99/6mo, 189/yr, 41 US ratings. https://athletica.ai/pricing/ Humango annual IAPs 79.99 and 169.99, 21 US ratings. https://apps.apple.com/app/id1554430755
- B8. TrainingPeaks Premium 134.99/yr effective 2025-04-02; 12,770 US ratings. https://help.trainingpeaks.com/hc/en-us/articles/12916774026765
- B9. Zwift 19.99/mo, 199.99/yr, 21,480 ratings. https://www.zwift.com/uk/news/33635-how-much-does-zwift-cost-and-whats-included-everything-you-need-to-know TrainerRoad 21.99/mo, 209.99/yr, 21,439 ratings. https://join.cc/ride-smarter/trainerroad
- B10. Garmin Coach triathlon plans free with a Garmin watch; longest plan reportedly Olympic (user forum, verify in Garmin Connect). https://forums.garmin.com/outdoor-recreation/outdoor-recreation/f/descent-mk3-series/422830/triathlon-training-program
- B11. 80/20 Endurance plan prices 54.95 to 99.95 USD; Team 16.58/mo annual with TrainingPeaks Premium. https://www.8020endurance.com/training-plans/sprint-triathlon/
- B12. WorkoutKit framework: workout types, scheduling into the stock Workout app with the app's icon and name, runtime supports checks. https://developer.apple.com/documentation/workoutkit and https://developer.apple.com/documentation/workoutkit/customworkout
- B13. WWDC24 session 10084: custom pool swimming workouts, distance with time goal and step display names (iOS 18 and watchOS 11 APIs), pool length conversion; no open water custom workouts. https://developer.apple.com/videos/play/wwdc2024/10084/ and https://developer.apple.com/documentation/workoutkit/workoutgoal/poolswimdistancewithtime(_:_:)
- B14. SwimBikeRunWorkout: ordered activities and display name only; no per leg intervals, goals or alerts. https://developer.apple.com/documentation/workoutkit/swimbikerunworkout
- B15. WorkoutScheduler and maxAllowedScheduledWorkoutCount, numeric value unpublished. https://developer.apple.com/documentation/workoutkit/workoutscheduler
- B16. HealthKit multisport: swimBikeRun workout type, HKWorkoutActivity per leg statistics, transitions (iOS 16, watchOS 9). https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/swimbikerun and https://developer.apple.com/videos/play/wwdc2022/10005/
- B17. Swim detail: HKWorkoutSwimmingLocationType pool and open water; stroke style per lap metadata; HKWorkoutRoute. https://developer.apple.com/documentation/healthkit/hkmetadatakeyswimmingstrokestyle and https://developer.apple.com/documentation/healthkit/hkworkoutroute
- B18. App privacy details: collect means transmitting off device; on device processing is not collected. https://developer.apple.com/app-store/app-privacy-details/
- B19. App Store Review Guidelines: 1.2 UGC duties; 2.3 accurate metadata (no misleading or unverifiable claims, no references to other apps: 2.3.1(a), 2.3.7); 2.5.1 HealthKit purpose; 4.3 spam; 5.1.1(v) account deletion; 5.1.2 consent for sharing; 5.1.3(ii) no personal health information in iCloud, no false HealthKit writes. https://developer.apple.com/app-store/review/guidelines/ Rejection language and appeal attempts under 4.3(b): no documented successful appeal; approvals followed differentiation changes. https://developer.apple.com/forums/thread/775597
- B20. Strava API agreement: single player rule, no competing or replicating apps, token and deletion duties; rate limits, new apps at athlete capacity 1; uploads endpoint accepts FIT, TCX, GPX with activity write. https://www.strava.com/legal/api and https://developers.strava.com/docs/rate-limits/ and https://developers.strava.com/docs/uploads/
- B21. Garmin Connect Developer Program: Personal (own data), Starter (application, push, no history), Enterprise; applications paused spring 2026, reportedly relaunched around October 2026. https://developer.garmin.com/gc-developer-program/overview and https://the5krunner.com/2026/09/14/garmin-developer-api-access-paused/ and https://byteiota.com/garmin-connect-api-revamp-personal-access-free/
- B22. TSS, IF, NP, TP, TPU registered to TrainingPeaks LLC (TSS registered 2014, renewed 2024); intervals.icu names the metric Load; GoldenCheetah renamed to BikeStress, BikeIntensity, IsoPower. https://trademarks.justia.com/owners/trainingpeaks-llc-4253944 and https://forum.intervals.icu/t/show-tss-in-intervals-icu/24435 and https://groups.google.com/g/golden-cheetah-users/c/Qjn4Xe8ShQ0/m/FmOLo_PXAAAJ
- B23. FTP as 95 percent of 20 minute power (Coggan standard); retest every 4 to 6 weeks (Moninger). https://www.bikeradar.com/advice/fitness-and-training/what-is-ftp-and-why-it-matters-for-cyclists
- B24. CSS test: 400 and 200 same session with 5 to 10 min active recovery; pace per 100 = (400 minus 200)/2; error flow when the 200 is not faster. https://support.myprocoach.net/hc/en-us/articles/360040593392-How-Does-The-CSS-Swim-Test-Work
- B25. Run LTHR and threshold pace from the 30 minute time trial, last 20 minutes average HR; validated against lab assessment. https://runnersconnect.net/how-to-calculate-your-lactate-threshold/
- B26. Banister and Edwards TRIMP constructions; Fitness and Fatigue from 42 and 7 day exponential averages, Form as their difference (Coggan performance management model). https://moveit.webs.upv.es/how-to-quantify-the-training-load/ and https://fasttalklabs.com/articles/an-introduction-to-training-metrics-part-2
- B27. Polarized intensity distribution: Stoggl and Sperlich review; 2024 systematic review finds superiority only for VO2 peak. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2015.00295/full and https://link.springer.com/content/pdf/10.1007/s40279-024-02034-z.pdf
- B28. Brick and transition runs: purpose and 10 to 20 minute format. https://www.active.com/triathlon/articles/what-brick-workouts-and-why-they-matter and https://www.tri247.com/guides/brick-workout-triathlon
- B29. Race fueling: 60 to 90 g/h bike and 50 to 70 g/h run for legs over 2.5 hours; glucose absorption caps near 60 g/h, fructose raises total toward 90; stomach trouble is the main risk of overdoing it. https://www.triathlete.com/nutrition/triathletes-guide-to-race-fueling/ Duration tiers up to 30, 60, 90 g/h: https://www.pressreader.com/canada/calgary-herald/20140724/282411282446162 Flat calculator error 15 to 25 minutes at full distance: https://www.bestbikesplit.com/triathlon-bike-pace-calculator
- B30. Ten percent rule: GRONORUN randomized trial, graded program produced the same injury rate (20.8 vs 20.3 percent, n 532). https://research.rug.nl/en/publications/no-effect-of-a-graded-training-program-on-the-number-of-running-r
- B31. Run walk: Hottenrott 2016 randomized trial in 42 non elite marathoners, similar finish times, less muscle pain and fatigue after the race. https://pubmed.ncbi.nlm.nih.gov/25467199/
- B32. ACWR as heuristic only: evidence disputes prediction framing. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.669687/pdf and https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972
- B33. FDA General Wellness: Policy for Low Risk Devices, updated January 6, 2026; exercise and endurance uses qualify. https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices
- B34. AGPL reuse boundary: copyright holder may relicense own files; openGym derived core stays AGPL; linking treated as derivative by the FSF. https://lwn.net/Articles/819101 and https://medium.com/swlh/understanding-the-agpl-the-most-misunderstood-license-86fd1fe91275
- B35. Reserved.
- B36. Chorus (funded social fitness app) shut down about 8 months after launch. https://www.businessinsider.in/dick-costolo-explains-why-he-shut-down-his-fitness-startup-after-8-months-we-were-up-against-hard-wired-human-behavior/articleshow/63102989.cms
- B37. Strava free users over 95 percent of the base power its engagement engine. https://insider.fitt.co/issue-no-158-tracking-stravas-rise/
- B38. Plan shapes: 16 week Olympic example with 3 plus 1 blocks; 70.3 at 10 to 14 hours; weekly hour ranges and peak and recovery deltas (coach heuristics). https://www.triathlete.com/training/olympic-triathlon-16-week-training-plan/ and https://www.trainingpeaks.com/training-plans/triathlon/half-ironman/tp-649925/14-week-70-3-plan and https://tri-alliance.com/tools/training-hours/
- B39. Runna adaptation documentation: skip and shift, realignment after 3 plus misses or a missed week, pace insights ignoring outliers, unwell mode up to 14 days. https://support.runna.com/en/articles/15012850 and https://support.runna.com/en/articles/10026375 and https://intercom.help/runna/en/articles/12809806
- B40. Name checks, iTunes Search API US, 2026-11-06: Taperline 0 results; Tricadence no exact match; Brickline no fitness app but check the St. Louis Brickline Greenway mark; TriPace taken. Method: https://itunes.apple.com/search?term=NAME&country=US&entity=software
- B41. Apple Watch multisport workout type since watchOS 9, auto transitions. https://support.apple.com/en-mn/guide/watch/combine-multiple-workouts-apdf42f22a41/11.0/watchos/11.0
