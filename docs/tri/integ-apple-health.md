# Apple Health as the zero approval integration layer

Researched 2026-11-08 for Brickline (free iPhone triathlon app, iOS 18 minimum per spec section 8). Apple documentation was read as primary source through the `.md` form of developer.apple.com pages. Vendor help pages are marked PRIMARY (read), PRIMARY-BLOCKED (exists, my tools got HTTP 401/403 or a JavaScript shell, content known only from search excerpts or quotes) or THIRD PARTY. No dashes are used as punctuation in this file.

## 1. Bottom line

1. HealthKit is the only integration that needs no approval, no business entity, no OAuth client and no server. Everything below can be read on device and keeps the App Privacy answer at Data Not Collected, because Apple defines collection as data transmitted off the device.
2. What HealthKit gives Brickline for readiness depends almost entirely on the device. Apple Watch alone writes HRV (SDNN), resting heart rate, sleep stages, respiratory rate, sleeping wrist temperature, blood oxygen and an effort score per workout. No third party device writes the full set.
3. WHOOP and Oura, the two recovery devices, do NOT write HRV or their recovery or readiness scores to Apple Health. Oura writes sleep stages, 1 minute heart rate and nightly respiratory rate; WHOOP writes resting heart rate, SpO2, respiratory rate, workouts and coarse sleep. HRV and readiness need their vendor APIs (the Liftspark OAuth proxy pattern), which in turn have their own terms (see sibling notes integ-whoop.md and integ-oura.md).
4. Garmin writes steps, workouts (no GPS), all day heart rate, sleep (with stages since 2023) and energy, one way only. HRV, Body Battery and Training Readiness do not reach Apple Health (secondary sources agree; Garmin's own page was blocked). Garmin timed activities carry only high and low heart rate, which weakens any heart rate based Load fallback for Garmin athletes.
5. Polar, Wahoo, COROS and Suunto write completed workouts with thin heart rate (Polar: average only, confirmed on Polar's own page) and no recovery signals. They are completion sources, not readiness sources.
6. Never pool HRV across sources. Apple uses SDNN, WHOOP and Oura use RMSSD (WHOOP states this as the reason it does not export HRV). Baselines must be per source.
7. Do not build the loop on background delivery timing. Delivery is capped (hourly for most types), the store is encrypted while the phone is locked, and vendor data only arrives after the vendor's own app syncs, sometimes the next day. Compute readiness on app open and in a background refresh.
8. HealthKit hides whether read permission was granted: denied and empty look identical. New in iOS 27: people can limit your history window, which directly affects HRV baselines.

## 2. Source map (what was actually read)

| Short name | URL | Status |
|---|---|---|
| HK HRV | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn.md | read |
| HK RHR | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate.md | read |
| HK resp | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/respiratoryrate.md | read |
| HK SpO2 | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/oxygensaturation.md | read |
| HK wrist temp | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature.md | read |
| HK VO2 | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/vo2max.md | read |
| HK cycling power | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/cyclingpower.md | read |
| HK FTP | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/cyclingfunctionalthresholdpower.md | read |
| HK HRR | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartraterecoveryoneminute.md | read |
| HK breathing | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingbreathingdisturbances.md | read (no description text) |
| HK effort | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore.md and .../estimatedworkouteffortscore.md | read (availability only, no description) |
| HK sleep values | https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis.md and .../asleepcore.md | read |
| HK condensed | https://developer.apple.com/documentation/healthkit/accessing-condensed-workout-samples.md | read |
| HK updates | https://developer.apple.com/documentation/updates/healthkit.md | read |
| HK source rev | https://developer.apple.com/documentation/healthkit/hksourcerevision.md | read |
| HK source | https://developer.apple.com/documentation/healthkit/hksource.md | read |
| HK device | https://developer.apple.com/documentation/healthkit/hkdevice.md | read |
| HK external uuid | https://developer.apple.com/documentation/healthkit/hkmetadatakeyexternaluuid.md | read |
| HK user entered | https://developer.apple.com/documentation/healthkit/hkmetadatakeywasuserentered.md | read |
| HK bg delivery | https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:).md | read |
| HK observer | https://developer.apple.com/documentation/healthkit/executing-observer-queries.md and .../hkobserverquery.md | read |
| HK anchored | https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery.md | read |
| HK bg entitlement | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery.md | read |
| HK update freq | https://developer.apple.com/documentation/healthkit/hkupdatefrequency.md | read |
| HK auth article | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data.md | read |
| HK auth status | https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:).md | read |
| HK earliest date | https://developer.apple.com/documentation/healthkit/hkhealthstore/getearliestauthorizedsampledate(for:completion:).md | read |
| HK privacy | https://developer.apple.com/documentation/healthkit/protecting-user-privacy.md | read |
| HK workoutPlan | https://developer.apple.com/documentation/healthkit/hkworkout/workoutplan.md | read |
| App privacy | https://developer.apple.com/app-store/app-privacy-details/ | read |
| Review guidelines | https://developer.apple.com/app-store/review/guidelines/ | read to character 100000 of 114428 (2.5.1, 5.1.2(vi), 5.1.3 all read) |
| Apple Vitals | https://support.apple.com/120142 and https://support.apple.com/guide/watch/apd15aa7ed96 | read |
| Apple Sleep Score | https://support.apple.com/guide/watch/view-your-sleep-score-apded441a669/watchos and https://support.apple.com/en-us/108906 | read |
| Apple Training Load | https://support.apple.com/guide/watch/track-your-training-load-apde4c07a6cf/watchos | read |
| Apple HR page | https://support.apple.com/en-us/120277 | read |
| Apple Series 12 | https://www.apple.com/newsroom/2026/09/introducing-apple-watch-series-12-with-the-all-new-health-sensing-system/ | read |
| Apple source order | https://support.apple.com/en-us/108779 | search excerpt only (not fetched) |
| Oura Apple Health | https://support.ouraring.com/hc/en-us/articles/360025438734 | PRIMARY, read, shows "Last updated October 14, 2026" |
| WHOOP Apple Health | https://support.whoop.com/hc/en-us/articles/4413142119195-Apple-Health-Integration (also https://support.whoop.com/s/article/Apple-Health-Integration?language=en_US) | PRIMARY-BLOCKED (401 and a JavaScript shell). Content known from search excerpts of the page, and from SensAI which cites "last updated April 16, 2026" |
| WHOOP staff post | https://www.community.whoop.com/t/issue-with-apple-health-integration-data-not-syncing/7615 | read; staff reply dated 2025-08-25 |
| WHOOP sleep thread | https://www.community.whoop.com/t/apple-health-missing-sleep-stage-data-from-whoop/8192.md | read; users only, latest post 2026-07-02 |
| Polar | https://support.polar.com/en/support/connecting_polar_flow_with_apple_health | PRIMARY, read |
| COROS | https://support.coros.com/hc/en-us/articles/360041549551-Connecting-Apple-Health-with-COROS-App | PRIMARY-BLOCKED (403), known from search excerpt; plus App Store text https://apps.apple.com/us/app/coros/id1277625343 (read) |
| Garmin | support.garmin.com articles "Sharing Your Garmin Connect Data With Apple Health" and "What Garmin Connect Information Can Be Shared With Apple Health?" | PRIMARY-BLOCKED (Cloudflare 403; titles known only from forum and SensAI mentions). Used THIRD PARTY below |
| Garmin staff on direction | https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-ios/435526/why-not-sync-data-from-apple-health/2055581 | read; Garmin staff reply, one way only |
| Garmin sleep stages | https://www.notebookcheck.net/Garmin-Connect-begins-sharing-more-sleep-data-with-Apple-Health-after-new-iOS-app-update.753484.0.html | THIRD PARTY, read, dated 2023-09-20 |
| Garmin summary | https://the5krunner.com/2025/06/20/garmin-to-add-health-connect-support-to-apple/ ; https://sahha.ai/blog/garmin-developer-program-paused/ ; https://trainconstant.com/blog/garmin-apple-health ; https://athlyticapp.helpscoutdocs.com/article/14--third-party-wearables | THIRD PARTY, read |
| Wahoo | https://www.wahoofitness.com/fitness-apps (read, one sentence); support.wahoofitness.com Authorized Apps and release notes articles | PRIMARY-BLOCKED (403), known from search excerpts |
| Suunto | https://apps.apple.com/us/app/suunto/id1230327951 (read, one sentence) ; https://forum.suunto.com/topic/2599/suunto-app-is-not-pushing-data-to-apple-health | App Store text read; no official Suunto help page found |
| Cross brand summary | https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin | THIRD PARTY (commercial publisher), read, dated 2026-08-11 |
| Apple Watch HRV validity | https://pmc.ncbi.nlm.nih.gov/articles/PMC11478500/ | read |
| Recovery apps on HealthKit | https://help.bevel.health/en/articles/11258241 and https://athlyticapp.helpscoutdocs.com/article/14--third-party-wearables | search excerpt and read |
| Sibling notes | integ-oura.md, integ-whoop.md in this folder; tri-research-platform.md | read locally |

## 3. HealthKit types for recovery and readiness

Availability comes from the metadata block on each Apple page. "Reads" means a third party app with per type read authorization.

| Type (identifier) | What Apple says | Availability | Notes for Brickline |
|---|---|---|---|
| `heartRateVariabilitySDNN` | Standard deviation of beat to beat (RR) intervals; "The system automatically records samples on Apple Watch." Metadata key `HKMetadataKeyAlgorithmVersion` marks algorithm version. | iOS 11, watchOS 4 | SDNN only. Not comparable to RMSSD from WHOOP, Oura or Garmin. Track algorithm version when present. |
| `restingHeartRate` | Daily estimate from sedentary samples; the system "may delete earlier samples and replace them with better estimates"; Apple Watch replaces only its own samples for the current or previous day. | iOS 11, watchOS 4 | Today's value is provisional until the day ends. Use yesterday or the overnight minimum for readiness. Use an anchored query so replacements and deletions are seen. |
| `sleepAnalysis` category with `HKCategoryValueSleepAnalysis` | Values `inBed`, `awake`, `asleepCore`, `asleepDeep`, `asleepREM`, `asleepUnspecified`. Stage samples overlap the in bed sample but not each other. "Samples recorded by Apple Watch only include awake samples that occur between two sleep samples." | enum iOS 8; stage cases iOS 16, watchOS 9 | Use `HKCategoryValueSleepAnalysis.allAsleepValues` to total sleep. Sources that write only `asleepUnspecified` or asleep and awake give duration without stages. |
| `respiratoryRate` | "The system automatically records samples on Apple Watch." | iOS 8 | Oura writes an average nighttime value; WHOOP writes respiratory rate. |
| `oxygenSaturation` | Percentage of oxygen in the blood. | iOS 8 | Apple Watch hardware and regional availability vary (Vitals page: some US models bought on or after 2024-01-18 have no Blood Oxygen). WHOOP writes a nightly value per its page excerpt. |
| `appleSleepingWristTemperature` | Series 8 and Ultra sample every five seconds overnight, aggregate to one nightly sample; absolute value recorded, Health shows relative; about five nights before Health shows it but "you can read them immediately from the HealthKit store". Read only. | iOS 16, watchOS 9 | One nightly absolute value. Needs own baseline. Not written by Oura or WHOOP to Health. |
| `appleSleepingBreathingDisturbances` | No description text on the page. | iOS 18, watchOS 11 | Optional extra overnight signal; not needed for 1.x. |
| `vo2Max` | Apple Watch Series 3 and later estimates it "based on data gathered while the user is walking or running outdoors"; also hiking; needs flat ground, GPS, heart rate at least about 130 percent of resting; range 14 to 60 ml/kg/min. | iOS 11, watchOS 4 | Not updated by cycling or swimming per Apple's description. A fitness trend input, not a daily readiness input. |
| `heartRateRecoveryOneMinute` | Drop from peak exercise rate to one minute after. | iOS 16, watchOS 9 | Per workout, optional. |
| `heartRate` | Condensed and coalesced for first party workouts; see below. | long standing | Workout HR series. |
| `cyclingPower` | "Cycling power can be automatically collected by peripherals connected to an Apple Watch during cycling workouts." May be condensed. | iOS 17, watchOS 10 | Only exists if a power meter was paired to the Watch (or an app wrote it). A Garmin or Wahoo bike computer ride in Health will not carry a power series unless that vendor writes one (not confirmed, see open questions). |
| `cyclingFunctionalThresholdPower` | Estimated 60 minute max average power; "During cycling workouts, the system automatically records estimated FTP samples on Apple Watch." | iOS 17, watchOS 10 | Do not use as the user's FTP; spec section 3.1 uses a guided test. |
| `workoutEffortScore` and `estimatedWorkoutEffortScore` | No description on the page. HealthKit updates list (June 2024): associate perceived and estimated exertion with workouts via `relateWorkoutEffortSample` and `HKWorkoutEffortRelationshipQuery`. | iOS 18, watchOS 11 | Apple's per workout 1 to 10 effort. See section 8. |
| Workouts (`HKWorkout`, `HKWorkoutActivity`, `swimBikeRun`) | See tri-research-platform.md section 2. | | `HKWorkout.workoutPlan` (iOS 17, needs `import WorkoutKit`) links a workout to the scheduled plan. |
| Workout zones | June 2026 update: read heart rate and cycling power zone configuration and time in zone via `HKWorkoutZoneGroup`; `preferredWorkoutZoneConfiguration(for:)`. | newest SDK (listed under June 2026) | Spec section 3 already says alerts use explicit ranges because zone alerts follow the watch's zones. Treat as optional and gate by availability. |

There is no HealthKit type for a Sleep Score or a readiness score. The Apple Sleep Score page and the Health app describe the score but no `sleepScore` identifier exists (a fetch of `.../hkquantitytypeidentifier/sleepscore.md` returned 404). Treat the score as not readable by third parties until Apple documents otherwise.

### Condensed workout samples

For first party workouts at least "a few months old" and "a few minutes" long, HealthKit condenses and coalesces `heartRate`, `activeEnergyBurned`, `distanceCycling`, `distanceWalkingRunning` and `basalEnergyBurned` into quantity series, and may do it again later. Rule from Apple: use `HKStatisticsQuery` or `HKStatisticsCollectionQuery` when you only need aggregates; if you need raw samples query by `predicateForObjects(from: workout)`, and when a discrete sample has `count > 1` read it with `HKQuantitySeriesSampleQuery`. Brickline's TRIMP style fallback (spec 3.4) should therefore be built on statistics over zone buckets, not on counting raw samples. Source: https://developer.apple.com/documentation/healthkit/accessing-condensed-workout-samples.md

## 4. Which third party devices write to Health, vendor by vendor

Direction first: all of these are companion app writes. Apple's own source page says "Currently, HealthKit supports only the direct import of data from Bluetooth LE heart rate monitors. All other devices need a companion app to collect and save the data to HealthKit." (https://developer.apple.com/documentation/healthkit/hksource.md) So every row below depends on the vendor app being installed, signed in, allowed to write each type, and syncing in the background.

### Oura (PRIMARY, Oura Member Care, "Last updated October 14, 2026")
URL: https://support.ouraring.com/hc/en-us/articles/360025438734
- Oura to Health (exact list): Active Energy, Heart Rate, Height, Mindful Minutes, Respiratory Rate, Sleep (duration, start time, end time, stages), Steps, Weight, Workout Routes, Workouts.
- Heart rate: one minute intervals (older Oura blog page https://ouraring.com/blog/data-sharing-partner-integrations/, and the fetch summary of the support page). Respiratory rate is the average nighttime value.
- Workouts: manual, Activity Heart Rate or Automatic Activity Detection; carry active calories, distance, type, duration; contribute to Move and Exercise rings. Whether the workout has a heart rate series is not stated; only the separate 1 minute heart rate stream is.
- Not written: HRV, resting heart rate, body temperature, SpO2, Readiness, Sleep score. The page lists none of them.
- Health to Oura (import): Active Energy, Blood Pressure, Body Fat Percentage, Cardio Fitness, Date of Birth, Heart Rate, Height, Lean Body Mass, Respiratory Rate, Resting Energy, Sex, Sleep, Steps, Weight, Workout Routes, Workouts.
- Timing: no frequency stated. Imports "can fail if both apps weren't opened before midnight, if Background App Refresh is off, or if Lower Power Mode is on"; recommends opening both apps at least once a day (paraphrase of the page).
- Caveat on the page: Oura's sleep stage and heart rate graphs "may appear differently" in Health compared to the Oura app.

### WHOOP (PRIMARY-BLOCKED, content from excerpts of WHOOP's own article plus staff post)
URL: https://support.whoop.com/hc/en-us/articles/4413142119195-Apple-Health-Integration
- Excerpts of the page (via search) say WHOOP sends Recovery Metrics (resting heart rate, blood oxygen, respiratory rate), Strain and Workouts, and sleep sessions; setup is under App Settings, Integrations, Apple Health; categories can be toggled in Health.
- Imports into WHOOP: workouts, routes, active energy, distance, mindful minutes, weight and height, heart rate (excerpt).
- HRV: "WHOOP does not export HRV data to Apple Health at this time" and the stated reason is RMSSD versus SDNN (quoted by SensAI as WHOOP Support, last updated April 16, 2026; also repeated in the search excerpt of the page). WHOOP MG: no ECG or Blood Pressure Insights export; recovery activities such as meditation and stretching are not exported (excerpt).
- Sleep detail: community thread, original post 2025-09-14, says only Time in Bed and Time Asleep appear, no REM, Deep or Light; users keep asking through 2026-07-02 and there is no staff reply or confirmation of change. Treat WHOOP sleep as duration only.
- Heart rate scope: WHOOP staff (user liv0, 2025-08-25) wrote that WHOOP "will only write heart rate data into Apple Health if it's part of a workout or sleep session." Continuous heart rate is not exported.
- Recovery score, Strain score, Sleep Performance: not documented as exported anywhere I read.
- Latency: users report data reaching Health the next day; WHOOP staff mentioned data may take time after enabling (same thread).
- 2022 history: WHOOP originally only read from Health and discarded non WHOOP heart rate (https://dcrainmaker.com/2022/02/whoops-health-integration.html). Outdated for writes, kept as context.

### Garmin Connect (PRIMARY-BLOCKED; THIRD PARTY plus Garmin staff statement on direction)
- Direction: Garmin staff said Connect can share data with Apple Health but does not pull from it (https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-ios/435526/why-not-sync-data-from-apple-health/2055581, relative date "6 months ago" at fetch time).
- Written (consistent across the5krunner 2025-06-20 and SensAI 2026-08-11): steps and distance, active and resting energy, sleep analysis, workouts, weight and body composition, blood pressure (separate Notebookcheck item), water, all day heart rate. Timed activities send only high and low heart rate. GPS tracks are not written. (THIRD PARTY.)
- Sleep stages: Garmin Connect v4.71 and newer share stages, not just duration (Notebookcheck, 2023-09-20, THIRD PARTY).
- Not written: HRV (HRV Status), Body Battery, Training Readiness, Garmin sleep score, workout GPS (Sahha, Constant, Athlytic: THIRD PARTY, mutually consistent; one outlier blog claims an overnight HRV average is written, treated as unreliable).
- Known problems: forum reports of steps and sleep stopping after iOS 26 until a Connect update; Garmin workouts sometimes carrying sync time; cycling activities historically missing (older forum thread). Treat as risk, not fact.
- Garmin's own two articles exist (titles above) but I could not read them. Confirm on a real device before shipping any Garmin specific copy.

### Polar Flow (PRIMARY, read)
URL: https://support.polar.com/en/support/connecting_polar_flow_with_apple_health
- One way: "You can only sync data from Polar Flow app to Apple Health."
- Written: Active Energy, Heart Rate (during workouts; continuous heart rate is not included), Resting Energy, Sleep Analysis (duration, falling asleep and waking times), Steps, Weight, Workouts (type, duration, distance, start and end, and workout samples: total active energy and average heart rate).
- So a Polar workout in Health has an average heart rate and a workout HR stream per the "Heart Rate" row, but the workout summary sample is average only. Which one third party queries see is a device test.
- Priority caveat: Health may ignore Polar data unless Polar Flow is first in Data Sources and Access. "Sync now" re-syncs two weeks.

### Wahoo (PRIMARY-BLOCKED)
- Wahoo's apps page says the app can "send completed activities to Strava, TrainingPeaks, Apple Health, Komoot, and more." (https://www.wahoofitness.com/fitness-apps, read.) No list of data types.
- Search excerpts of Wahoo support: iOS release notes mention a fix for "workouts would fail to be written to Apple Health" in 6.84.1 (May 2026), and 7.4.0 (2026-11-03) imports Apple Health workouts with GPS routes into Wahoo. A separate article describes Apple Health to Wahoo auto upload (last 30 days). These are excerpt level only.
- No evidence Wahoo writes a heart rate series or power series to Health. Test with a real Wahoo ride.

### COROS (PRIMARY-BLOCKED, App Store text read)
- Search excerpt of the official guide: Apple Health data types you can choose to send are Heart Rate, Sleep Analysis, Steps, Cycling Distance, Swimming Distance, Walking plus Running Distance. COROS iOS release notes (excerpt): activities synced to Apple Health "differentiate between indoor/outdoor running and cycling", so workouts are written. App Store description: "Sync steps, heart rate and other data to Apple devices using HealthKit."
- No evidence of HRV or recovery signals.

### Suunto (no official help page found)
- App Store description: "The Suunto app connects with Apple Health. Go to app settings to start sharing your data." Forum reports (users, not staff): workouts, steps and heart rate sync when Suunto is the Health source; sleep missing or unreliable; GPS routes not synced. Treat everything beyond the sentence as unverified.

### Implication
For triathletes on Polar, Wahoo, COROS or Suunto, HealthKit gives completion matching (type, time, duration) and perhaps average heart rate, never recovery. WHOOP and Oura athletes get duration and some overnight vitals but not HRV. Only Apple Watch (and, via vendor API, WHOOP and Oura) can feed a real recovery model.

## 5. Identifying the source: `sourceRevision`, `HKSource`, `HKDevice`

- Every `HKObject` read from the store carries `sourceRevision` (`HKSourceRevision`): `source` (`HKSource`: `name`, `bundleIdentifier`), `version` (app version), `productType` (device model string), `operatingSystemVersion`. Source: https://developer.apple.com/documentation/healthkit/hksourcerevision.md
- Samples may also carry `device` (`HKDevice`): `name`, `manufacturer`, `model`, `hardwareVersion`, `firmwareVersion`, `softwareVersion`, `localIdentifier`, `udiDeviceIdentifier`. The vendor chooses what to fill, so it can be nil. Source: https://developer.apple.com/documentation/healthkit/hkdevice.md
- Useful metadata keys: `HKMetadataKeyWasUserEntered` (manual entry), `HKMetadataKeyExternalUUID` (a vendor assigned id independent of the store UUID, useful for dedupe if the vendor sets it), `HKMetadataKeyAlgorithmVersion` on HRV.
- Apple Watch samples: first party data is tagged with a device UUID style app id `com.apple.health.{UUID}` rather than a store bundle id (https://docs.junction.com/wearables/providers/data-attributions, THIRD PARTY, no vendor bundle ids listed). I could not confirm bundle identifiers for Oura, WHOOP, Garmin, Polar, Wahoo, COROS or Suunto from any source. Do not hardcode them. Detect at runtime: enumerate `HKSourceQuery` results per type, show the user their sources by `source.name`, and let them pick which source is "my recovery source".
- Per source queries: `HKQuery.predicateForObjects(from: source)`; statistics `separateBySource` computes per source (https://developer.apple.com/documentation/healthkit/hkstatisticsoptions/separatebysource.md). I did not find an Apple page that states how default statistics merge overlapping sources; verify in the week 1 spike.
- Duplicates: a user with Apple Watch and Oura both writing sleep and heart rate will have overlapping samples. Health's own priority order is user controlled ("Data Sources & Access", manual entry first, then iPhone, iPad and Apple Watch, then apps and Bluetooth devices; search excerpt of https://support.apple.com/en-us/108779, page not fetched). Brickline should read per source and choose one explicitly rather than summing.

## 6. Background delivery: `HKObserverQuery` and `enableBackgroundDelivery`

Facts, all from Apple (HK bg delivery, HK observer, HK bg entitlement, HK update freq):
- `HKObserverQuery` tells you only that something changed, not what. You run an `HKAnchoredObjectQuery` (or sample query) afterward. The anchored query also reports deleted samples, which matters because resting heart rate samples are replaced during the day.
- `enableBackgroundDelivery(for:frequency:)` wakes the app when a process saves or deletes samples of that type, "at most once per time period" for the chosen `HKUpdateFrequency` (`immediate`, `hourly`, `daily`, `weekly`). Allowed types: characteristic, quantity, category and workout types; correlation types are not supported.
- The system enforces a type specific cap transparently: "Some sample types have a maximum frequency of hourly"; example on iOS: step count is hourly. For watchOS, most types are hourly, with an immediate list that includes `vo2Max`, `lowCardioFitnessEvent`, heart rhythm events and a few others; HRV, sleep and resting heart rate are not on that list. I found no Apple statement of the iOS cap for HRV or sleep; assume hourly at best.
- Entitlement: since iOS 15 you need `com.apple.developer.healthkit.background-delivery`; without it enabling fails with `errorAuthorizationDenied`. It defaults to false.
- Create observer queries in `application(_:didFinishLaunchingWithOptions:)` so they exist when HealthKit relaunches the app. You must call the completion handler. If you do not, HealthKit retries with backoff and, "If your app fails to respond three times, HealthKit assumes your app can't receive data and stops sending background updates."
- Not supported in the Simulator; test on device.
- Device lock: Apple says the device "encrypts the HealthKit store when the user locks the device. As a result, your app may not be able to read data from the store when it runs in the background." (https://developer.apple.com/documentation/healthkit/protecting-user-privacy.md) A phone that is locked overnight can wake the app but reads may fail until the first unlock.
- Not documented by Apple on the pages I read: behavior after a force quit, and background delivery in low power mode. Open question.
- Vendor side latency dominates: Oura and WHOOP only write after their own apps sync; Oura says to open both apps daily, and its readiness is computed after sleep is processed. Observer wake ups cannot beat that.
- Design consequence: use background delivery only as a hint to refresh a cached "readiness card" and to schedule a local notification, never as the thing that decides adaptation. Primary path: on app foreground, run anchored queries since the last anchor; secondary: `BGAppRefreshTask`. Adaptation rules (spec 3.3) should read "latest data available" and say so in the reason line.

## 7. Authorization behavior

- Read and write are requested per type with `requestAuthorization(toShare:read:)`; the sheet groups types in categories and lets people toggle each (https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data.md). People can change it any time in Settings or Health; after one prompt the app appears under Health sources even if everything was denied.
- Read status is hidden by design: "your app cannot determine whether or not a user has granted permission to read data. If you are not given permission, it simply appears as if there is no data of the requested type" (https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:).md). `authorizationStatus(for:)` reports only share (write) status. `getRequestStatusForAuthorization` (iOS 12) tells you whether the sheet would be shown, i.e. whether you still need to ask.
- Limited history window: after the type screen, "a second screen prompts them to choose how much historical data to grant your app" (recent window or full history). `getEarliestAuthorizedSampleDate(for:)` reports the limit, but it is availability iOS 27 and later. It returns no entry for both full access and denied, so only limited access is identifiable. Apple says to treat older data as unknown, not absent, and to ensure "baselines, or anomaly detections" work from partial data. Gate with `#available(iOS 27, *)`; on iOS 18 to 26 there is no limited window (the article text covers it generally, the API is the part with the 27 tag, so confirm on the iOS 26 SDK that no equivalent prompt exists).
- Prompt strategy for Brickline: ask only for what the first screen needs. Workouts and workout HR/power at plan start; overnight vitals (HRV, resting HR, sleep, respiratory rate, wrist temperature) only when the athlete turns on "adjust my plan to recovery"; write share only for the workout type when the phone player first records a session (already in spec section 9). Only two Info.plist purpose strings in 1.0 (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`), as the spec states; apps crash on request without them.
- Empty state copy must not accuse: "No sleep data found in the last 7 days. Check Health, Sources, and that your watch or ring is syncing." Never say "permission denied".
- Guest User sessions on Vision Pro are irrelevant for an iPhone only app.

## 8. What Apple Watch alone provides

| Signal | Apple Watch alone? | Source |
|---|---|---|
| HRV (SDNN) | Yes, written automatically. Cadence for models before the Series 12 is not given by Apple on the pages I read; a 2024 validation paper's introduction states "every two to four hours" citing an Apple document (secondary). Series 12 and Ultra 4 measure HRV "up to 24 times more often" (Apple newsroom 2026-09), with the support page saying HRV is sampled while the person is still. | HK HRV; https://www.apple.com/newsroom/2026/09/introducing-apple-watch-series-12-with-the-all-new-health-sensing-system/ ; https://support.apple.com/en-us/120277 ; https://pmc.ncbi.nlm.nih.gov/articles/PMC11478500/ |
| Accuracy of HRV | Study of Series 9 and Ultra 2 vs a chest strap: Apple Watch read lower, mean difference -8.31 ms, mean absolute percentage error 28.88 percent, limits of agreement -53.8 to 37.2 ms. Authors caution against absolute values; trend use may be fine. The paper has an internal sign inconsistency in its table. | https://pmc.ncbi.nlm.nih.gov/articles/PMC11478500/ |
| Resting heart rate | Yes. Close to reference in the same study (mean absolute error 3.73 bpm). | HK RHR; PMC study |
| Sleep stages | Yes: Core, Deep, REM, Awake plus in bed (watchOS 9 / iOS 16 and later). Sleep Focus and "Track Sleep with Apple Watch" required for Vitals. | HK sleep values; https://support.apple.com/120142 |
| Respiratory rate | Yes, during sleep per Apple's sleep comparisons; not available under age 13. | HK resp; https://support.apple.com/en-us/108906 |
| Blood oxygen | Model and region dependent. | https://support.apple.com/120142 |
| Sleeping wrist temperature | Series 8 and later and any Ultra. | HK wrist temp; https://support.apple.com/en-us/108906 |
| VO2 max | Yes from outdoor walk, run, hike only. | HK VO2 |
| Workouts with HR | Yes; stock Workout app writes multisport as `swimBikeRun` (see tri-research-platform.md). | |
| Cycling power | Only with a paired power meter on the Watch. | HK cycling power |
| Training Load style | Apple's Training Load "compares the intensity and duration of your workouts over the last 7 days to what you've done over the previous 28 days" and classes it "well below to well above". Derived from a 1 to 10 effort rating per workout; effort is estimated automatically for popular cardio types and can be edited. A reviewer (DC Rainmaker, 2024-07, THIRD PARTY) reports it is purely heart rate based and ignores power, and starts showing after about 10 days. The load number itself is not exposed in HealthKit; effort scores are (`workoutEffortScore`, `estimatedWorkoutEffortScore`). Developer forum reports say estimated scores exist for running, walking, hiking and cycling and that reading needs the relationship query or a time range predicate. | https://support.apple.com/guide/watch/track-your-training-load-apde4c07a6cf/watchos ; https://www.apple.com/newsroom/2024/06/watchos-11-brings-powerful-health-and-fitness-insights/ (via excerpt) ; https://developer.apple.com/documentation/updates/healthkit.md ; https://dcrainmaker.com/2024/07/apples-training-load-vitals-watchos11.html |
| Vitals app | Overnight: heart rate, respiratory rate, wrist temperature, blood oxygen, sleep duration; on Series 12 and Ultra 4 HRV replaces sleep duration and a daytime view with resting heart rate and HRV is added. Typical range after 7 nights of tracked sleep (support page 120142); notification when at least two overnight metrics are outside the range. The Vitals page does not say it writes anything extra to Health; the underlying samples are the same HealthKit types. Review (2024) said baseline takes 3 days; Apple's current page says 7 days, use Apple's. | https://support.apple.com/120142 ; https://support.apple.com/guide/watch/apd15aa7ed96 |
| Sleep Score | 0 to 100: duration 50 points, bedtime consistency 30 (looks at the last 13 nights), interruptions 20; bands Very Low 0 to 40, Low 41 to 60, OK 61 to 80, High 81 to 95, Very High 96 and up. MacRumors (THIRD PARTY) says a score can also come from a third party device that logs sleep in Health. No HealthKit type found for the score. | https://support.apple.com/guide/watch/view-your-sleep-score-apded441a669/watchos ; https://support.apple.com/en-us/108906 ; https://www.macrumors.com/2025/09/10/watchos-26-sleep-score/ |

Takeaway: an Apple Watch only athlete already has everything needed for a transparent rules based readiness check (overnight HRV and resting HR vs the athlete's own rolling baseline, sleep duration, respiratory rate and wrist temperature flags). Precedent: Athlytic and Bevel build recovery scores from Apple Health alone (Athlytic reads HRV and resting heart rate; Bevel uses resting heart rate, HRV, respiratory rate, SpO2 and wrist temperature and notes Apple Health HRV is SDNN while its default is RMSSD). Sources: https://athlyticapp.helpscoutdocs.com/article/14--third-party-wearables , https://help.bevel.health/en/articles/11258241 (search excerpt).

## 9. App Privacy: HealthKit read and processed on device

- Apple's definition (App Privacy Details page, Data collection section): "Collect" means "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time." Additional guidance on the same page: "Data that is processed only on device is not 'collected' and does not need to be disclosed in your answers. If you derive anything from that data and send it off device, the resulting data should be considered separately." Source: https://developer.apple.com/app-store/app-privacy-details/
- The Health data type on the page includes "data from the Clinical Health Records API, HealthKit API, Movement Disorder API" and Fitness covers "Fitness and exercise data". So HealthKit data is Health data if you collect it; if you only process it on device it is not collected and the label can stay Data Not Collected. This matches spec section 9 (B18).
- Rules that still apply even with Data Not Collected (Review Guidelines): 2.5.1 says HealthKit "should be used for health and fitness purposes and integrate with the Health app" and the integration should be indicated in the app description; 5.1.2(vi) bars HealthKit data for "marketing, advertising or use-based data mining, including by third parties"; 5.1.3(i) requires you to "disclose the specific health data that you are collecting from the device"; 5.1.3(ii) says no false data into HealthKit and "may not store personal health information in iCloud". Apple's HealthKit privacy page also requires a privacy policy for any HealthKit app. Sources: https://developer.apple.com/app-store/review/guidelines/ , https://developer.apple.com/documentation/healthkit/protecting-user-privacy.md
- Guideline 5.1.1(ix) says apps in "highly regulated fields (such as ... healthcare)" or that require sensitive information "should be submitted by a legal entity ... and not by an individual developer". Brickline is a fitness training app, not a healthcare service, and uses HealthKit as an input, but readiness copy must stay wellness and never diagnostic (spec section 6). Flagged in open questions as a review risk, not a finding.
- The vendor API path changes the label question. Reading WHOOP or Oura data over their APIs means calling a vendor server from the device with a token the device holds. The thin Vercel proxy only exchanges and refreshes tokens (Liftspark pattern). Apple's guidance says data sent to service a request and not retained after servicing is not "collected", but whether OAuth tokens and authorization codes transiting a developer controlled server count is not addressed on the page. This is the single item that could move the label off Data Not Collected. Decision belongs to the product owner; see open questions.
- HealthKit data must not go into a CloudKit or iCloud container (5.1.3(ii)); keep readiness inputs and derived scores on device only. Spec section 9 already enforces this with a schema test.

## 10. Matrix: signal by device by path

Legend: HK = readable through HealthKit with no approval. API = vendor cloud API. "no" means the vendor does not write it to Health. "?" means unverified, test on a real device. Cells cite which section holds the evidence. Vendor API cells for WHOOP and Oura come from the sibling notes (Spec fields); Garmin API is limited to what I could confirm.

| Signal | Apple Watch (HK) | WHOOP HK | WHOOP API | Oura HK | Oura API | Garmin HK | Garmin API (Health API, approval needed) | Polar / Wahoo / COROS / Suunto HK |
|---|---|---|---|---|---|---|---|---|
| HRV | Yes, SDNN, intermittent, more often on Series 12 and Ultra 4 | no (RMSSD vs SDNN) | Yes, `hrv_rmssd_milli` in recovery | no | Yes, `average_hrv` and an HRV series on sleep (RMSSD style; unit not stated in Spec) | no (HRV Status stays in Connect) | ? not confirmed | no |
| Resting heart rate | Yes, daily, provisional for current day | Yes (per WHOOP page excerpt) | Yes, `resting_heart_rate` | no | Indirect: `lowest_heart_rate` on sleep, readiness contributor only | ? not listed in third party lists | ? | no |
| Recovery or readiness score | no (Apple has none exposed; Sleep Score exists in the Health app but no HealthKit type found) | no | Yes, `recovery_score` 0 to 100 | no | Yes, `daily_readiness` score and contributors | no (Training Readiness not written) | ? | no |
| Sleep duration | Yes | Yes (asleep and awake blocks) | Yes | Yes | Yes | Yes | Yes (sleep listed) | Polar yes (duration, fall asleep, wake); COROS yes (Sleep Analysis); Suunto unreliable; Wahoo no evidence |
| Sleep stages | Yes (Core, Deep, REM, Awake) | no (duration only, per user thread to July 2026) | Yes (stage durations) | Yes | Yes | Yes since Connect v4.71 (THIRD PARTY) | Yes (sleep) | no |
| Respiratory rate | Yes (sleep) | Yes (per page excerpt) | Yes (`respiratory_rate` on sleep) | Yes (avg nighttime) | Yes (`average_breath`) | no evidence | Yes (respiration listed) | no |
| Blood oxygen | Yes on supported models/regions | Yes, nightly average (older third party note says once per day) | Yes, `spo2_percentage` (4.0 or newer) | no | Yes with `spo2` scope | no evidence | Yes (pulse ox listed) | no |
| Wrist or skin temperature | Yes, sleeping wrist temperature, Series 8 and Ultra | no | Yes, `skin_temp_celsius` (4.0 or newer) | no | Yes, `temperature_deviation` on readiness | no | ? | no |
| Heart rate during workouts | Yes, dense series (condensed later) | Yes, only when part of a workout or sleep (staff) | Yes, avg and max per workout | Yes, 1 minute stream | Yes, with `heartrate` scope | Timed activities: high and low only (THIRD PARTY); all day HR otherwise | Yes via Activity API (FIT) | Polar: average plus workout HR; others: HR stream claimed, unverified |
| All day heart rate | Yes | no | no | Yes, 1 minute | Yes | Yes (THIRD PARTY) | Yes | Polar no; COROS HR type listed; Suunto reported |
| Completed workouts | Yes (all types, `swimBikeRun`) | Yes (type, time, energy) | Yes (strain, avg and max HR, zones) | Yes (with routes) | Yes (`workout` scope) | Yes, no GPS | Yes | Yes (Polar, COROS, Wahoo write; Suunto reported) |
| Cycling power series | Only with paired meter | no evidence | no | no | no | ? | ? (Activity API delivers FIT files; power content not verified here) | ? (test) |
| VO2 max | Yes (outdoor walk, run, hike) | no | no | Import only ("Cardio Fitness") | Yes, `vO2_max` endpoint (`heart_health` scope inferred) | no | ? | no |
| Effort or training load | Per workout effort score (HR based); load itself not exposed | no | Strain (0 to 21, WHOOP's own) | no | Readiness contributors only | no (Acute Load not written) | ? | no |
| Pushing structured workouts to the device | WorkoutKit (spec 4.1), no approval | n/a | n/a | n/a | n/a | n/a | Training API, Starter approval (tri-research-platform.md) | n/a via Health |
| Latency | Near real time after watch to phone sync | Often next day | Cloud after sync | After Oura app sync, background refresh dependent | After app sync; readiness not until sleep processed | After Connect sync | Push after Connect sync | After vendor app sync |

Reading the matrix: the HealthKit column set gives (a) Apple Watch users a full readiness model, (b) every other user a training completion loop, plus partial overnight context for Oura (sleep, respiratory rate) and WHOOP (sleep duration, RHR, SpO2, respiratory rate). For HRV and for a vendor's recovery or readiness number, the API is the only path for WHOOP and Oura, and Garmin is closed to HealthKit and gated to a program with an approval.

## 11. Recommended integration shape (decision oriented)

1. Layer 1 (free, no approval, ships first): HealthKit reader with a `ReadinessInput` model that stores per source series (source name, bundle id as observed, unit, algorithm version). Compute baselines per source over a rolling 28 day window (needs 14 nights minimum before any recovery based nudge; mark the baseline "learning" before that, like WHOOP's `user_calibrating` flag).
2. Readiness rules (deterministic, with reason lines per spec 3.3): overnight HRV below baseline band, resting heart rate above, sleep short, respiratory rate or wrist temperature flagged (two or more flags before acting, copying Apple's own two metric rule) leads to an easy swap suggestion that the athlete can accept or decline. Wording: wellness, never medical, never "AI coach".
3. Layer 2 (per vendor, later, behind flags): WHOOP and Oura API connectors through the existing token proxy pattern, only after the product owner settles the Data Not Collected question and the vendor terms (integ-whoop.md, integ-oura.md). If a user connects WHOOP or Oura, prefer their HRV and recovery over HealthKit for that user, do not mix with Apple HRV.
4. Garmin: HealthKit read for completion, sleep and all day HR; no recovery signal. Do not promise Garmin recovery adjustment until the Garmin program decision (tri-research-platform.md). Honest UI: "Garmin shares workouts and sleep with Apple Health. It does not share HRV or Training Readiness, so Brickline can't use them."
5. Show a Sources screen listing what Brickline found per type, which source it uses, and what is missing. This doubles as the answer to "why didn't my plan adapt" and fixes the denied versus empty ambiguity.
6. Test matrix for the week 1 spike on real devices: Apple Watch (Series 9 or later), plus one each of Oura, WHOOP, Garmin and a Polar or Wahoo or COROS if available. Record per type: source name, bundle id, device metadata, sample cadence, latency from workout end to Health, presence of heart rate series on workouts, presence of power on a power meter ride.

## 12. Open questions (unconfirmed)

1. WHOOP's own Apple Health article could not be read (401 and a JavaScript shell). The category list is from search excerpts of that page plus SensAI; read it in a browser before copy refers to WHOOP.
2. Garmin's two Apple Health articles could not be read (Cloudflare 403). The Garmin write list, the timed activity high and low heart rate behavior and the absence of HRV all come from third party sources; verify on a device.
3. Garmin Health API data types: no primary page confirmed the list; HRV, skin temperature and Training Readiness in the Health API are unconfirmed.
4. Wahoo, COROS and Suunto: no readable official data type list for Wahoo, COROS list is from an excerpt, Suunto has none. Do they write heart rate series, cycling power, running power or swim data on workouts?
5. Bundle identifiers for each vendor source were not confirmed anywhere. Capture on device.
6. Does `HKStatisticsQuery` merge overlapping samples from several sources by Health's priority order? Apple pages I read do not say.
7. Apple Watch HRV cadence on models before Series 12: Apple's pages give no number; the "every two to four hours" figure is quoted second hand in a research paper.
8. Is there any HealthKit exposure (type or API) for Apple's Sleep Score, Vitals typical ranges or the Training Load classification? None found; check iOS 27 SDK headers.
9. iOS 27 limited history window: the APIs are tagged iOS 27. Does the limited window prompt also appear for apps on older iOS versions, and what is the default window? Not stated.
10. Background delivery: behavior after force quit and iOS caps for HRV, sleep and workouts types (Apple lists only watchOS immediate types and the step count example).
11. Does a vendor Health write retain its original sample times and not the sync time (a Garmin forum report says some workouts showed sync time)? Affects workout matching by time.
12. Data Not Collected with a token proxy: does a stateless Vercel function that handles OAuth codes and refresh tokens (never storing or logging them) leave the App Privacy answer unchanged? Product owner decision, may need a conservative label for the version that ships a vendor connector.
13. Guideline 5.1.1(ix) legal entity wording for health apps: assumed not triggered for a fitness training app using readiness as a soft input; keep copy wellness only.
14. Cycling power series from non Apple sources: does any of Garmin, Wahoo, COROS write `cyclingPower` to Health, or is power only in the vendor FIT file?
