# Brickline engineering annex

Companion to tri-spec.md (version 0.2). Implementation detail the spec references. Where the spec and this annex state the same parameter, this annex is canonical; the spec quotes it for readability and is corrected to match on any change. Same rules: no em or en dashes, no forbidden words outside Safety.strings, no TrainingPeaks marks anywhere. B numbers refer to the spec appendix. Glosses: RPE is rate of perceived exertion (1 to 10 feel scale); FTP is functional threshold power; LTHR is lactate threshold heart rate; CSS is critical swim speed; TRIMP is training impulse, a heart rate based load score.

## A. Benchmarks and zone math

Swim, CSS (B24):
- Test: warm up, all out 400 m, 5 to 10 minutes active recovery, all out 200 m, cool down. CSS pace per 100 m = (T400 minus T200) / 2. Reject with a friendly retest flow when T200 pace is not faster than T400 pace.
- Zones (app defined offsets, stated as such on the Methods screen): Easy = CSS + 8 to 15 s per 100; Steady = CSS + 4 to 7 s; Threshold = CSS plus or minus 3 s; VO2 = CSS minus 4 to 8 s. Exact offsets fixed during template QA with the coach reviewer.

Bike, FTP or LTHR (B23):
- Power: FTP = 0.95 times best 20 minute average power; guided test with a 5 minute clearing effort in the warm up.
- Power zones as percent of FTP, from the Coggan model, cross checked against the book before hardcoding: Z1 under 55, Z2 56 to 75, Z3 76 to 90, Z4 91 to 105, Z5 106 to 120, Z6 121 to 150, Z7 above 150, so no power sample falls outside every zone.
- No power: LTHR from a 30 minute solo time trial, average heart rate of the final 20 minutes. Heart rate zones from LTHR, one fixed 5 band table used for both prescriptions and the load model: Z1 under 81 percent of LTHR, Z2 81 to 89, Z3 89 to 94, Z4 94 to 102, Z5 above 102 (Friel style bands; exact boundaries confirmed with the coach reviewer). RPE descriptions on every step regardless, so a session is executable with nothing but feel.

Run, threshold pace and LTHR (B25):
- Test: 10 minute warm up, 30 minutes hard and even; threshold pace per km = 1800 s divided by distance covered in km (equivalently threshold speed = distance / 1800 s, the form WorkoutKit speed range alerts use); LTHR = average HR of the final 20 minutes.
- Zones, app defined pending coach review: Easy = threshold pace + 45 to 90 s per km (or 81 to 89 percent LTHR); Steady = threshold pace + 20 to 45 s per km (or 89 to 94 percent LTHR); Threshold = threshold pace plus or minus 3 percent, floored at plus or minus 10 s per km, for prescriptions and watch alerts alike (tighter tolerances may be used internally for adaptation analysis but never surface as alerts); VO2 = threshold pace minus 15 to 25 s per km. Exact offsets fixed during template QA with the coach reviewer.

Retest rotation:
- Test weeks sit on every 4 week block boundary, but at most two sports test per test week, rotating which sport sits out, so each sport retests about every 6 weeks, inside the supported ranges (B23), with never more than two maximal efforts in a recovery week and at least 48 hours between them. Sprint plans of 12 weeks or less keep the full three test opening week and rotate only the retests. The rotation is stated on the Methods screen.

Seeding without tests, per metric:
- Bike: seed FTP as 0.95 times the best 20 minute power only when the chosen HealthKit workout contains cycling power samples; otherwise estimate LTHR from the best sustained 20 to 30 minute heart rate segment of a hard ride and use the heart rate zone table. When no power samples are found, the benchmarks screen says bike zones were estimated from heart rate and suggests a test.
- Run: seed threshold pace from the best sustained 20 to 30 minute segment of the speed or distance series, plus LTHR from heart rate.
- Swim: no seeding in 1.0; CSS requires the test (pool pace data is too noisy to promise).
- Seeded values are labelled Estimated everywhere and never drive pace nudges (annex C rule 3).

## B. Template parameters

| Parameter | Sprint | Olympic | 70.3 |
|---|---|---|---|
| Plan length | 8 to 12 wks | 10 to 16 wks | 14 to 24 wks |
| Weekly hours | 4 to 7 | 6 to 10 | 8 to 14 |
| Sessions per week | 4 to 6 | 5 to 7 | 6 to 9 |
| Swims per week | 1 to 2 | 2 | 2 to 3 |
| Bricks | 1 short from build | 1 weekly in build and peak | 1 weekly, race specific in peak |
| Taper | about 1 wk | 1 to 2 wks | 2 wks, up to 3 |

- Taper lengths are the app's own parameters inside the published span (1 week sprint up to 2 to 3 weeks long course, B38).
- Phase ratios about 40 to 50 percent base, 30 build, 15 peak, 5 to 10 taper; 3 load weeks then 1 recovery week; recovery weeks 30 to 40 percent below average volume, peak weeks 20 to 30 percent above (B38).
- Intensity distribution: roughly 80 percent of weekly session time in Easy and Steady. Quality sessions are capped per week in total by level: first timer 2, intermediate 3, experienced 4, with at most 2 in any one sport (the second only in build and peak for intermediate and experienced); all other sessions are easy; every week contains at least one fully easy session per scheduled sport; never back to back hard days in the same sport.
- Levels: first timer (run walk options, shorter quality), intermediate, experienced; level changes session density and quality volume, never the safety rules.
- Microcycle assembly: sessions are placed on the athlete's declared days, pool sessions only on pool days, the long ride and long run separated by at least one day, the weekly brick attached to a key ride.
- No race yet mode: a rolling 4 week base block with test weeks, convertible to a race plan when a date arrives.

## C. Adaptation rules

Deterministic, ordered, every fired rule writes a reason line shown on the Today card and kept in the log. Thresholds tunable in one constants file. A structural change is one rule action applied to the plan, however many sessions it touches; a rule 2 realignment, once the athlete confirms it, counts as that day's single structural change and suppresses any other structural rule for the rest of the day. Zone nudges (rule 3) and copy only flags are not structural. Rules never apply more than one structural change per day.

| # | Trigger | Action | Reason line pattern |
|---|---|---|---|
| 1 | Session skipped | Move to a later free day in the same week, except a day already holding a quality session, never creating a second quality day; with no slot it drops | Moved to Friday so your hard days stay separated |
| 2 | 3 or more misses in 14 days, or an entire week missed | Realignment prompt: resume at today with the arc compressed, or shift the whole plan if the race date allows | You missed a week; here are two honest ways forward |
| 3 | Completed pace or power consistently above or below target across the last 3 comparable quality sessions (median, outliers dropped); never fires on Estimated zones | Nudge that sport's zones one step (about 2 percent), max once per 2 weeks | Your last three threshold runs came in faster than target, so paces moved up slightly |
| 4 | Feeling unwell toggle | Easy sessions only for up to 14 days, quality returns gradually over 1 week | Easy week while you recover; quality returns Thursday |
| 5 | A recomputed or athlete edited load week's planned load exceeds 110 percent of the most recent load week (recovery weeks excluded from the comparison on both sides; template designed peak and taper weeks exempt by construction) | Clamp the week to the cap | This week grew too fast, so one session got shorter |
| 6 | Acute load (7 day) over chronic (28 day) above 1.5 | Insert one easy day, flag the week | Your recent load spiked; today went easy. This is a caution rule, not a prediction that anything is wrong |
| 7 | Race window active | Taper lock: no added intensity, no zone nudges, rules 3 and 5 suspended | Race week: the plan holds steady on purpose |
| 8 | Any sport's last completed test older than 8 weeks | Insert that sport's test at the next block boundary | Time to retest so your zones stay honest |

Rule 6's reason line carries the B32 heuristic disclaimer and must stay phrased without the words doctor, injury or illness so a copy pass cannot clash with the Safety.strings fence.

## D. Load model

- With power: session Load = (average adjusted intensity relative to FTP) squared times hours times 100, implemented from the published math under the name Load; the TrainingPeaks names never appear (B22, B26).
- Without power: time in the five LTHR anchored heart rate zones of annex A, each hour in a zone scoring a per zone load factor: provisionally 20, 40, 65, 100, 135 for Z1 to Z5, tuned in template QA so a steady hour at each zone's midpoint intensity matches the power formula. This keeps the time in zone structure of Liftspark's TRIMP engine (so the port and its test suite carry over) while self anchoring a threshold hour at 100 for every athlete, with no HRmax input and no divergence between the heart rate and power paths feeding one Fitness and Form series. The Methods screen states that heart rate based Load is zone time based and less precise than power based Load.
- Swim load: the same zone time model on heart rate when present; otherwise duration times the planned zone's factor, labelled Estimated.
- Fitness = 42 day exponentially weighted average of daily Load; Fatigue (internal) = 7 day; Form = Fitness minus Fatigue using yesterday's values; convention documented on the Methods screen (B26).
- Display: Load per session, weekly Load bar, Fitness and Form as a simple two line chart with plain explanations. No projections, no race readiness scores.

## E. WorkoutKit mapping

- Each planned session compiles to a CustomWorkout: warm up step, interval blocks (work and recovery steps with goals and alerts), cool down. Step display names (iOS 18, watchOS 11) carry the session's own step names.
- Goals: distance or time per step; energy goals are not supported in custom workouts (measured). Pool swim steps use the distance with time goal (iOS 18, watchOS 11), which carries the CSS pace target; pool length conversion is the stock app's job (B13).
- Alerts, per the week 1 capability matrix: run pace as speed range alerts (pace inverted to speed); run power range outdoor only, never power zone alerts; bike power range or heart rate range alerts; swim heart rate alerts only, no pace or speed. Always explicit ranges, never zone alerts, since zone alerts follow the watch's own zones. All gated by runtime supports checks per activity and location (B12); when unsupported, the step ships with goal only and the session card says what the watch will and will not show.
- Scheduling: WorkoutScheduler, authorization requested at first Sunday Sync, the coming week scheduled with daily DateComponents; completed or stale entries removed on each sync; maxAllowedScheduledWorkoutCount read at runtime (50 on iOS 26.5, measured) and respected with oldest first eviction (B15).
- Completion matching: first by HKWorkout.workoutPlan (async throws) against the scheduled plan's UUID; it throws WorkoutKit.ImportError code 3 for any workout not started from a plan (measured on device), which means "no plan", never a failure; then the type, time and duration heuristic; then manual match.
- Race day: SwimBikeRunWorkout with ordered legs, open goals, scheduled for race morning (B14). The pacing plan lives on the race morning screen, not in the watch workout.
- Capability tiers. iOS exposes no API to read the paired watch's OS version, so tiers are keyed by the WorkoutKit supports APIs plus an explicit older watch setting, never by version sniffing: (1) default path assumes the watchOS 11 feature set (pool swim sets, step display names), each goal and alert gated by supportsActivity, supportsGoal and supportsAlert at compile time of the plan; (2) an older watch setting ("My watch runs watchOS 10"), offered at first sync and in Settings, delivers pool swims as a gated attempt: a goal only swim (SingleGoalWorkout, swimming, pool location, distance goal) only when the supports checks pass, else the printed set card on the phone plus phone player logging; steps on this tier appear with the stock Work and Recovery labels and the session card says so, the phone showing the named steps; (3) no watch, unpaired, or authorization denied: Sunday Sync hides, the phone player leads.
- The phone player: runs the same compiled session (steps, targets, voice cues, haptics) and saves the finished workout via HKWorkoutBuilder, since the HKWorkout initializers are deprecated as of iOS 17: HKWorkoutConfiguration with the session's activity type and location, beginCollection at the real start, endCollection at the real end, finishWorkout with duration only, never fabricated energy, distance or heart rate (B19). The completion matcher recognizes the app's own writes by sourceRevision and UUID so a session never double counts; when a watch or Garmin recording of the same session also arrives, the richer external workout wins and the player write is the fallback.
- Phone player background behavior: (1) UIBackgroundModes audio with AVAudioSession category playback; between cues the process may still suspend, so (2) every step boundary is also pre scheduled as a local notification with sound when the player starts, cancelled on foreground or finish, the guaranteed cue path with no silent audio tricks; (3) step timing derives from wall clock dates captured at start and at each pause or resume, never accumulated timers, so UI and the written workout are correct after any suspension; (4) the idle timer is disabled while the player is foregrounded and reset on leave; (5) a Live Activity shows current step and a system rendered countdown (Text timerInterval) on the lock screen, ended on finish or abandon; (6) haptics fire only in foreground on iPhone, so the session card never promises background haptics; voice cues carry the targets.

## F. Race window content

- Window opens at T minus 21 days (T minus 10 for Sprint).
- Timeline entries: bike service reminder (T minus 14, from the Bike record), travel and Pack keyed to the race record's travel flag (feeds the 1.1 Pack and Rebuild Check), carb load start (T minus 2 for 70.3, race eve for shorter), pack tonight (T minus 1), wake up math from start time minus transit minus setup minus breakfast lead.
- Pacing card: per leg target ranges from the athlete's own zones. Bike: percent of FTP band by distance (conservative defaults, exact bands fixed with the coach reviewer); run: threshold offset by distance; swim: CSS offset. Always ranges. The caveat scales by distance: at full distance context, flat calculators can run 15 to 25 minutes off on hilly or windy courses (B29); for Sprint, Olympic and 70.3 the card says targets can be off by several percent on hilly or windy courses, treat them as ranges.
- Fueling card, keyed to each leg's expected duration from the pacing targets: under about 75 minutes, fluids to thirst only, no carbohydrate target (a sipped sports drink is fine); about 1.25 to 2.5 hours, roughly 30 g per hour scaling toward 60 as duration approaches 2.5 hours; over 2.5 hours, 60 to 90 g per hour on the bike and 50 to 70 g per hour on the run with the glucose fructose mechanism. Every tier carries the practice in training line and one sentence that exceeding what the duration needs mainly raises stomach trouble (B29). Fluids to thirst, optional sweat rate test flow, no sodium numbers.
- Race morning screen: timeline, checklist state, start of day list. Calm typography, no Load, no Form. Weather only if a later version clears the no network rule and the Data Not Collected label (WeatherKit is a network service to Apple); until then, nothing.
- Debrief: per leg planned versus actual from the HealthKit multisport workout (B16), transitions included; two prompts (what went well, what to change); next race picker.

## G. Failure paths

- No watch, watch unpaired, authorization denied: phone player leads, Sunday Sync hidden, copy never shames.
- Scheduling fails or the scheduler is full: retry once, then the Today card carries a send again button; the week still exists on the phone.
- HealthKit read authorization denied per type: features degrade per type (no heart rate: RPE logging; no workouts: manual done button); the plan itself never blocks.
- HealthKit share authorization denied: the phone player still runs the full session; the workout is not saved to HealthKit and completion is recorded by the manual done button, with one calm line explaining why.
- Player suspended or killed mid session: on relaunch, rebuild player state from the wall clock start date and offer resume or finish now; the workout written covers only elapsed time.
- No pool access this week: swap flow replaces swims with dryland and extends the next swim block, stated reason.
- Race date moved or cancelled: re plan from today, keeping completed history.
- Benchmarks never done: plan runs on estimates with the Estimated label everywhere; the pace nudge rule stays off.
- Device capability missing (older watch, no power meter): capability gated per annex E; features hide with one line in Settings about why.
- Plan share code malformed or from a newer version: friendly error, never a crash; codec versioned from day one (Breakthru Workshop codec pattern).
- App deleted and reinstalled: everything local is gone; onboarding says data lives on this phone and in your own backup.

## H. Notification rules

Local only, one scheduler, authorization by the runtime prompt (no Info.plist string exists for notifications). Standard budget: at most 5 per week (Monday preview, Sunday recap, up to 2 session reminders the athlete opts into, 1 adaptation notice). Race window weeks may add the annex F timeline entries on top, at most 1 per day and at most 4 extra in any week; if the timeline would exceed that, the entries closest to race day win. Quiet hours 21:00 to 07:00, except race day timeline entries whose computed time falls inside them: the wake up entry always fires at its computed time, and the race morning screen shows that time in advance. Everything cancels when the related screen is opened. No streaks, no guilt copy; the comeback loop is the plan itself, the test weeks, the race window and the debrief.

## I. Privacy policy checklist

The policy states: what is processed (plans on device, workouts read from HealthKit with permission, and workouts recorded by the phone player written back to HealthKit with share permission); that nothing is transmitted and there are no accounts, analytics or third party SDKs; retention (data lives in the app container, in the user's own device backup, until Delete everything or app removal); deletion (the button, and that HealthKit data belongs to the Health app); revocation (HealthKit and notifications in iOS Settings, the app keeps working); support email handling (used only to answer, deleted after, unlinkable). HealthKit derived data never syncs to iCloud (guideline 5.1.3(ii)); a schema test enforces the exclusion if sync ever ships.

## J. Test plan

- Golden plan fixtures: one per distance, level and hours combination in a reduced matrix (at least 12 plans), checked in with expected week count, session counts per sport, weekly hours, ramp profile and taper shape; regenerating must match exactly (deterministic engine, seeded).
- Property tests over randomized athlete inputs: the load week over load week ramp cap never exceeded by recomputed weeks, intensity distribution within tolerance, quality session caps (total by level and at most 2 per sport) never exceeded, at least one fully easy session per scheduled sport per week, no back to back quality in one sport, pool sessions only on pool days, taper lock honored, every adaptation writes a reason line.
- Adaptation unit tests: one per rule in annex C, firing and not firing cases, plus the invariant test asserting at most one structural action per day, including the day a confirmed realignment recompute runs.
- WorkoutKit compile tests: every session type compiles to a valid WorkoutPlan (the WorkoutKit scheduling type); unsupported alert fallback paths covered; race day workout validates ordering; the older watch tier produces goal only swims or the set card.
- Load math: per zone factor outputs against hand computed values on recorded fixtures, including parity between the heart rate and power paths at zone midpoints; Fitness and Form series against hand computed values.
- Forbidden word scan over strings, metadata and site: the full section 6 list (diagnose, treat, doctor, injury, illness, prevention claims, named conditions, medical grade, clinical, AI coach, and the TrainingPeaks marks TSS, IF, NP, TP, TPU), with exactly the three Safety.strings exemptions. When a tuning number changes in annex B or F, the spec is grepped for the old value so convenience copies cannot drift.
- Info.plist: sales flag false; NSHealthShareUsageDescription and NSHealthUpdateUsageDescription present and accurate; no camera, microphone or Photos purpose strings in 1.0.
- UI tests: onboarding acknowledgement, HealthKit permission moments (read, and share at first player use), plan preview reachable in under 3 minutes of taps, delete everything.
- No trapping asserts in tested paths; a named simulator, shut down after each run.
- Live test: Akshay on a generated Olympic plan for 4 or more weeks before submission, starting no later than build week 10 (spec section 15); divergences filed as template QA bugs.

## K. Safety.strings

1. Onboarding acknowledgement: "Brickline builds training plans for sport. It is not medical advice. Check with a doctor before starting a new training program, especially if you have a heart condition, are pregnant, or are returning from injury. Stop training and seek help if you feel chest pain, dizziness or shortness of breath."
2. Unwell mode line: "Training through illness is how small problems become big ones. Easy days only until you feel right, and see a doctor if it lingers."
3. Open water safety card: "Open water is the riskiest part of this sport. Never swim alone, use a bright tow float, know the venue and conditions, treat cold water with extra caution, and get out early if anything feels wrong. Every open water session here has a pool alternative."

These three strings are the only places the words doctor, injury or illness may appear, and they must never be rephrased by a copy pass without updating the scan test.
