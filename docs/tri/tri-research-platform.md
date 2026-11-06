# Platform research: Apple capabilities and third party API constraints for a triathlon training app

Researched 2026-11-06. All claims carry source URLs. Primary sources (Apple docs, Strava legal, vendor pages) preferred; secondary sources are flagged.

## 1. WorkoutKit (iOS 17+, watchOS 10+): structured workouts in the stock Workout app

Source (primary): https://developer.apple.com/documentation/workoutkit (fetched via https://developer.apple.com/documentation/workoutkit.md)

- Framework availability: iOS 17.0+, iPadOS 17.0+, macCatalyst 17.0+, watchOS 10.0+ (per the doc page metadata).
- "The WorkoutKit framework provides models and utilities for creating and previewing workouts in your iOS and watchOS apps, and for syncing scheduled workouts to the Workout app on Apple Watch."
- Supported workout types:
  - CustomWorkout: "A structured interval workout with a series of steps containing custom goals and alerts"
  - SingleGoalWorkout: single distance, energy, or time goal
  - PacerWorkout: distance plus time
  - SwimBikeRunWorkout: "A workout that allows triathletes to seamlessly transition between swim, bike, and run activities"
- Scheduling: "You can also use WorkoutKit to create and maintain a workout schedule and, with the user's permission, sync scheduled compositions to Apple Watch. These compositions appear in a dedicated space in the Workout app and include your app's icon and name." Authorization via WorkoutScheduler.shared.requestAuthorization(), then schedule(_:at:). A plan can also be opened directly with openInWorkoutApp() or exported with dataRepresentation(as:).

### CustomWorkout details
Source: https://developer.apple.com/documentation/workoutkit/customworkout.md
- init(activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType, displayName: String?, warmup: WorkoutStep?, blocks: [IntervalBlock], cooldown: WorkoutStep?)
- Runtime capability checks: static supportsActivity(HKWorkoutActivityType), supportsGoal(WorkoutGoal, activity:location:), supportsAlert(_:activity:location:). Apple does not publish a static list of supported activities in the reference docs; apps must query these at runtime.

### Custom swimming workouts: yes, pool swims, from watchOS 11
Source (primary): WWDC24 session 10084 "Build custom swimming workouts with WorkoutKit" https://developer.apple.com/videos/play/wwdc2024/10084/
- Custom POOL swimming workouts arrive in watchOS 11: "All the API that exists today for custom workouts like creating steps, goals, and alerts, are now coming to pool swimming." The session does not extend custom workouts to open water swimming.
- New goal type combining distance with time (poolSwimDistanceWithTime): "The workout only advances to the next step once both goals have been achieved." Built for swim sets like 2x25m in 1:00.
- Pool length: the Workout app asks for pool length at workout start; if the pool differs from the planned intervals "the Workout app will convert the distances and scale the time just for this swim."
- Also per that session: power alerts for running and cycling (watchOS 10.4), pace alerts for indoor running (watchOS 11), custom step names via displayName on WorkoutStep (watchOS 11), user-selectable indoor/outdoor location (watchOS 10.1).
- The associated sample code ("Customizing workouts with WorkoutKit", https://developer.apple.com/documentation/workoutkit/customizing-workouts-with-workoutkit.md) is marked iOS 18+ / watchOS 11+ and shows the full loop: schedule from iPhone, workout appears "at the top of the Workout list on the watch", user runs it in the stock Workout app, app later reads completion.

### SwimBikeRunWorkout (multisport) details and its limits
Source: https://developer.apple.com/documentation/workoutkit/swimbikerunworkout.md
- Availability: iOS 17.0+, watchOS 10.0+ (also macOS 15, macCatalyst 18).
- init(activities: [SwimBikeRunWorkout.Activity], displayName: String?) plus static supportsActivityOrdering([Activity]) -> Bool.
- Limit: the initializer takes only an ordered activity list and a display name. There is no API surface for per-leg interval blocks, goals, or alerts inside a SwimBikeRunWorkout. Structured brick or race-specific interval work per leg is NOT expressible in the multisport plan; only ordered swim/bike/run legs with automatic transitions. (Direct reading of the reference page; no per-leg goal API exists on the page.)

### WorkoutScheduler and scheduling limits
Source: https://developer.apple.com/documentation/workoutkit/workoutscheduler.md and https://developer.apple.com/documentation/workoutkit/workoutscheduler/maxallowedscheduledworkoutcount.md
- isSupported, requestAuthorization() -> AuthorizationState, schedule(WorkoutPlan, at: DateComponents), scheduledWorkouts, markComplete(_:at:), remove(_:at:), removeAllWorkouts().
- static let maxAllowedScheduledWorkoutCount: Int, "The maximum number of workouts your app can schedule." The numeric value is NOT published in the reference docs; read it at runtime. (Could not find an official number; do not assume one.)

### Does a third party need its own Watch app?
- For delivering structured training sessions: no. WorkoutKit syncs plans into the stock Workout app on the watch (framework overview above), the stock app executes them with alerts, and it writes the resulting workout to HealthKit, which the iPhone app can read back (framework overview: "To access health data for the workout, see the HealthKit framework"). The sample flow confirms completion can be observed from the iPhone app.
- A custom Watch app (HKWorkoutSession, like Liftspark already has) is only needed for: custom in-workout UI/metrics, custom data capture, coaching audio, or any live behavior the stock Workout app does not do. Tradeoff note (analysis, not sourced): stock Workout app execution gets Apple-quality swim/auto-set detection and multisport auto-transition for free, which a solo dev cannot realistically match.

## 2. HealthKit: workout types and what third parties can read

### Multisport / triathlon
Sources:
- https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/swimbikerun.md ("use it for workouts that contain swimming, cycling, and running activities", for multisport events like triathlons)
- https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/transition.md (activity type for the time between activities in a multisport workout)
- https://developer.apple.com/documentation/healthkit/hkworkoutactivity.md (HKWorkoutActivity, available iOS 16.0+ / watchOS 9.0+)
- https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities.md
- WWDC22 session 10005 https://developer.apple.com/videos/play/wwdc2022/10005/ (workout API updated in iOS 16 / watchOS 9 to capture multisport workouts and per-activity statistics; activities cannot overlap and need not be contiguous because transitions sit between them)
- Net: a triathlon recorded on Apple Watch (watchOS 9+) is one HKWorkout of type swimBikeRun containing HKWorkoutActivity children (swimming, cycling, running, transition), each with its own statistics. Third party apps with HealthKit read authorization get the whole structure.

### Swimming detail
- Pool vs open water: HKWorkoutSwimmingLocationType enum with cases pool, openWater, unknown; available since iOS 10 / watchOS 3. https://developer.apple.com/documentation/healthkit/hkworkoutswimminglocationtype.md
- Stroke style per lap: HKMetadataKeySwimmingStrokeStyle is set on workout lap events, value from HKSwimmingStrokeStyle. https://developer.apple.com/documentation/healthkit/hkmetadatakeyswimmingstrokestyle.md
- HKSwimmingStrokeStyle cases include freestyle, backstroke, breaststroke, butterfly, mixed, kickboard, unknown. https://developer.apple.com/documentation/healthkit/hkswimmingstrokestyle.md
- Lap structure: HKWorkoutEvent of type .lap on the workout; stroke count via the swimming stroke count quantity type (community sample reading laps and stroke counts: https://gist.github.com/ochim/981fa55dd42cc0bc2a3a35a85d23311c, secondary).
- Routes: open water swims can carry an HKWorkoutRoute; pool swims do not expose location. A developer forum report (secondary) says routes were readable for open water workouts but not for historical pool workouts, and quotes an Apple DTS answer that there is no public API for third party access to indoor workout locations: https://developer.apple.com/forums/thread/849272

### Routes
- HKWorkoutRoute (iOS 11+ / watchOS 4+): location data stored as CLLocation array, read asynchronously in batches with HKWorkoutRouteQuery. https://developer.apple.com/documentation/healthkit/hkworkoutroute.md

### Cycling and running metrics
- HKQuantityTypeIdentifier list includes cyclingPower ("estimated power being used while riding a bike") and cyclingCadence ("rate at which the user is pedaling"): https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier.md (the .md fetch of the list page was not read in full; identifiers confirmed via search snippet of that page). Version tags (cycling types = iOS 17) were not verified against Apple docs in this pass; verify before writing specs.
- Running: runningPower and runningGroundContactTime were present in iOS 16 docs; there is no dedicated running cadence identifier (derive from speed and stride length). Source (secondary, Apple dev forum): https://developer.apple.com/forums/thread/708208
- What a third party can read overall: with per-type HealthKit read authorization, apps can read HKWorkout objects (all activity types incl. swimming, cycling, running, swimBikeRun), per-activity statistics, raw sample series (heart rate, power, cadence, speed, distance, stroke count), workout events (laps, segments, pauses), and routes. Heart rate sample density from Apple Watch workouts is high but not officially specified; no URL found stating a guaranteed sampling rate (not found, so not claimed).

## 3. Garmin Connect Developer Program

Primary source: https://developer.garmin.com/gc-developer-program/overview
- Two paths: Personal (your own data) and Business.
- Personal: "Secure access to your own Garmin Connect data." Setup: "Log in to the Garmin Connect website to retrieve your personal API key." Includes Activity Data (JSON and .FIT), Health Data (JSON), Women's Health Data (JSON). Pull only. No application or approval.
- Business Starter: "The starting point for organizations building apps with Garmin Connect API access." Apply for the program and create an app with Starter Access. Includes Activity API (JSON and .FIT), Courses API, Health API, Training API, Women's Health API. Push delivery only, no historical data, limited user capacity.
- Business Enterprise: "Designed for companies operating at scale." Adds Golf API, push or ping/pull, historical data 1 month or more, unlimited user capacity, tech support; "Available options and commercial terms are tailored based on business and technical requirements."
- Solo devs: the page says the program supports "individual developers and startups to companies operating at significant scale," so a solo dev can apply for Starter. Pricing and approval criteria are not stated on the page.
- The FAQ URL https://developer.garmin.com/gc-developer-program/program-faq returned 404 on fetch (with and without trailing slash), as did /gc-developer-program/activity-api/ and /gc-developer-program/training-api; the program pages appear restructured. Search snippets of the FAQ said access "is free to approved business developers."

History and current state (secondary sources, verify before relying):
- the5krunner, 2026-09-14: https://the5krunner.com/2026/09/14/garmin-developer-api-access-paused/ Garmin stopped processing new Connect Developer Program applications around spring 2026; application form removed; applicants (CycleLytic, applied 2026-03-02; Blocks, applied 2026-07-16) left pending with no timeline; Garmin cited a "significant redesign and modernisation of the API program." Context: Strava sued Garmin in 2025 (dropped about three weeks later); Garmin acquired TrainingPeaks and TrainHeroic in July 2026; Garmin's API Brand Guidelines (July 2025) required Garmin branding on data displays. Existing integrations kept working; Connect IQ unaffected. Wahoo and Hammerhead approved comparable requests within weeks.
- byteiota (undated, retrieved 2026-11-06): https://byteiota.com/garmin-connect-api-revamp-personal-access-free/ Program relaunched (article dated as of 2026-10-23): Personal tier is free, self-serve, instant (personal API key from Garmin Connect web; key lifetime 30/90/180/365 days; tokens 24h; pull only; no write back). Starter: free up to 1,000 users, application and approval required, adds webhook push plus Courses and Training APIs, no historical data. Enterprise: negotiated pricing, Golf API, unlimited users, historical data. Claim: Personal tier FIT files omit VO2 max, recovery time, performance condition, training effect, sweat loss (business tiers only).
- Program agreement PDF (primary, not fetched): https://developerportal.garmin.com/sites/default/files/Garmin%20Connect%20Developer%20Program%20Agreement.pdf
- Net for Akshay: Health API vs Activity API: Activity API = workout/activity files (JSON summaries and FIT); Health API = daily wellness (steps, sleep, HR, stress). Training API (Starter+) is the one that pushes structured workouts TO Garmin devices. Realistic path: ship with Apple Watch + HealthKit first; apply for Garmin Starter as a business (Starter is free, approval required and recently unreliable); Personal tier cannot serve app users.

## 4. Strava API

Primary source, API Agreement: https://www.strava.com/legal/api
- Single player rule: "Strava Data provided by a specific user can only be displayed or disclosed in your Developer Application to that user." Data about other users may not be displayed even if publicly viewable on Strava.
- "You may not create applications that compete with or replicate Strava functionality." Apps must be "designed to interact with and enhance the Strava Platform" (section 1.1). So: no building a rival social network, feed, segments, or leaderboards from Strava data; segment and leaderboard data is defined as Strava Data (section 2.3(i)) and falls under the same display restrictions.
- One API token per application (section 1.1). No sharing a user's data with other users or third parties without explicit consent (section 5). On termination you must "permanently delete all the Strava API Materials" and Strava Data (section 4.4). Strava may charge for API access in the future (section 3.2) and may modify or discontinue access "at any time for any reason."
- A training app READING a user's own Strava activities and showing analysis back to that same user is the intended, allowed pattern. Anything social built on Strava data is not allowed.

Primary source, rate limits: https://developers.strava.com/docs/rate-limits/
- Default per app: overall 200 requests per 15 minutes, 2,000 per day; read (non-upload) 100 per 15 minutes, 1,000 per day.
- Upgraded (via API Settings Dashboard): read 200/15min and 2,000/day; overall 400/15min and 4,000/day; athlete capacity 10. "New apps start in Single Player Mode with capacity of 1" (one connected athlete) until approved for more.
- Higher limits: only for apps approaching capacity, via the Developer Program form with screenshots showing Strava branding and the "Connect with Strava" button; "increased access is not a guarantee."

Secondary (verify against current agreement text):
- tryterra 2026 overview: https://tryterra.co/blog/strava-api-changes-2026 (segment explore endpoint limited to approved Extended Access apps; 7 day caching cap; ban on using API data in AI applications incl. prompts, embeddings, RAG; conflicting policy sections on small-capacity display exceptions).
- road.cc on the Nov 2024 tightening: https://road.cc/content/news/strava-users-cant-publicly-share-data-third-party-apps-311329

## 5. Suunto, Wahoo, COROS (brief)

- Wahoo Cloud API (primary): https://developers.wahooligan.com/cloud OAuth 2.0; scopes cover workouts (read/write), plans (plans_read/plans_write), routes (read/write), power/HR zones, offline_data. "Wahoo Fitness is currently limiting use of the API to those who request it": apply via the developer portal, reviewed; Sandbox and Production are separate applications and a Sandbox app cannot be upgraded. Rate limits not stated on page. Secondary note (the5krunner above): Wahoo approvals reportedly took weeks, no pause.
- Suunto (secondary): https://openwearables.io/docs/providers/suunto-api-integration Cloud API access via the Suunto Developer Program; reportedly granted only to companies/organizations, not personal use; approval about two weeks; Developer API tier limited to 10 calls/minute, max 200 calls/week. Verify at Suunto's own apizone portal.
- COROS (primary-ish, COROS support site): https://support.coros.com/hc/en-us/articles/17085887816340-Submit-an-API-Application Partner API requires an established user base and a registered company; apply to api@coros.com; identity and security verification before credentials. A self-service OAuth MCP path exists for developers who do not qualify (per search snippet of COROS support articles). Partnership context: COROS-Wahoo two-way sync announced April 2026: https://coros.com/au/stories/press-release/c/coros-wahoo-partnership
- Net: for a solo dev with no company, Garmin Personal is self-serve but own-data only; Garmin Starter, Suunto, and COROS all want an application and mostly a business entity; Wahoo is application-based but reportedly friendly. Apple Watch via HealthKit needs no approval at all and is the only zero-permission integration.

## 6. CloudKit for lightweight social

- CloudKit marketing page (primary): https://developer.apple.com/icloud/cloudkit/ "store private data securely in your users' iCloud accounts for limitless scale" and "get up to 1PB of storage for your app's public data." No pricing/quota numbers published there.
- CKShare (primary): https://developer.apple.com/documentation/cloudkit/ckshare.md Available since iOS 10. Shares live in the user's PRIVATE database (custom zone); share a record hierarchy or a whole zone. "CloudKit limits the number of participants in a share to 100, and each participant must have an active iCloud account." publicPermission lets anyone with the URL join. Notable for App Review 1.2: CKShare now has access-request and blocking APIs: allowsAccessRequests, requesters, blockRequesters(_:), blockedIdentities, denyRequesters(_:), unblockIdentities(_:). Requires CKSharingSupported in Info.plist.
- Public database practical limits (secondary, forum reports): old free-tier formula around 10 requests/sec per 100k users and overage pricing circulated in 2020 (https://forums.swift.org/t/questions-regarding-the-fee-for-the-public-container-of-cloudkit/40213); anecdotal throttling around 40 req/s with retryAfter errors (https://developer.apple.com/forums/thread/114154, https://developer.apple.com/forums/thread/740916, https://developer.apple.com/forums/thread/808698). Apple has not published current hard numbers; design for CKError rate-limit handling.
- Moderation reality (analysis): CloudKit has NO server-side logic, no content scanning, no admin console for user reports. Any public-feed feature means building report/block/filter flows client side (CKShare blocking helps for share-based groups) plus some way for Akshay to review and delete offending records (CloudKit Console). Queries on the public DB need indexed fields; no full-text search. Identity: users are anonymous CKUserRecordIDs unless they opt into discoverability; no usernames/avatars for free.
- Big constraint interaction: App Review 5.1.3(ii) says apps "may not store personal health information in iCloud" (see below). A CloudKit-backed fitness social feature must therefore share only derived, user-chosen content (a post, a planned workout, a club roster), NOT HealthKit exports. This materially limits a Strava-style feed of raw workouts synced via iCloud.

## 7. App Review requirements

Source (primary): https://developer.apple.com/app-store/review/guidelines/
- Guideline 1.2 User-Generated Content. Apps with UGC must include ALL of:
  1. "A method for filtering objectionable material from being posted to the app"
  2. "A mechanism to report offensive content and timely responses to concerns"
  3. "The ability to block abusive users from the service"
  4. "Published contact information so users can easily reach you"
  Plus: it is the developer's responsibility to remove violating content; failures can escalate to Developer Code of Conduct violations and removal.
  Minimum viable community feature (analysis): invite-only groups via CKShare (private, 100 people) still count as sharing content between users; safest 1.0 pattern is share-by-code of workout plans (like Breakthru's Workshop codec) plus local-only display, deferring open feeds; if any feed ships, it needs report buttons, a block list, a filter (even keyword based), and a support page contact.
- Guideline 5.1.1(v) Account Sign-In: "If your app doesn't include significant account-based features, let people use it without a login. If your app supports account creation, you must also offer account deletion within the app." Apps may not require personal info unless core-functionality relevant.
- Guideline 4.3 Spam: don't submit apps "indistinguishable from what's already widely available" (relevant to pitching the listing as meaningfully different from Runna/TriDot etc.).
- Guideline 2.5.1: HealthKit must be used for health/fitness purposes and the integration indicated in the app description.
- Guideline 5.1.2(vi): HealthKit data "may not be used for marketing, advertising or use-based data mining, including by third parties."
- Guideline 5.1.3 Health and Health Research: (i) no use/disclosure of health data to third parties for advertising/marketing/data mining; must disclose the specific health data collected; (ii) "Apps must not write false or inaccurate data into HealthKit ... and may not store personal health information in iCloud."

## 8. Privacy label

Source (primary): https://developer.apple.com/app-store/app-privacy-details/
- Definition: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time."
- "Data that is processed only on device is not 'collected' and does not need to be disclosed."
- CloudKit is not addressed by name. Applying the definition: data in the user's PRIVATE CloudKit database that the developer cannot access arguably fails the "allows you to access it" test, which is how apps like Liftspark can target Data Not Collected while still syncing via private-DB CloudKit (inference, consistent with the quoted definition; Apple does not confirm it explicitly on this page).
- A CloudKit PUBLIC database social feature is accessible to the developer, so posted content is collected: expect a label of at least User Content, probably linked to identity if accounts/usernames exist. So: training plans + HealthKit analysis + private CloudKit sync can keep Data Not Collected; an open community feed cannot. A free app with accounts and UGC can still have a relatively clean label (no tracking, no third-party ads), but not Data Not Collected.
- Note 5.1.3(ii) above independently bars putting personal health information in iCloud at all.

## 9. Bottom-line implications for the triathlon app (analysis)

1. Apple-first works with no approvals: HealthKit (read triathlon/multisport, swim laps/strokes, cycling power, running dynamics, routes) + WorkoutKit (push structured swim/bike/run sessions into the stock Workout app, custom pool swim intervals on watchOS 11) means a complete plan-and-execute loop with zero third party gatekeepers and no required Watch app for 1.0.
2. Multisport gap: scheduled SwimBikeRunWorkout plans cannot carry per-leg intervals; race-day plan = ordered legs only. Brick sessions with structure = schedule two consecutive CustomWorkouts.
3. Garmin/Suunto/COROS all gate behind business applications and Garmin access was paused for much of 2026; treat device integrations beyond Apple Watch as post-1.0 and apply early for Garmin Starter (free). Wahoo is the easiest non-Apple approval per reports.
4. Strava can be an import source for the user's own history (capacity 1 in Single Player Mode until approved, then request capacity), but it legally cannot power any community feature, and nothing resembling segments/leaderboards/feeds may be built from Strava data. Build community, if at all, on original user-generated content.
5. Community features cost the Data Not Collected label and trigger guideline 1.2 obligations (filter, report, block, contact) and 5.1.1(v) account deletion, and 5.1.3(ii) forbids personal health information in iCloud. CKShare small groups (max 100 participants, built-in blocking APIs) are the lightest-weight compliant shape; a public Strava-like feed is a heavy lift for a solo dev under these rules.

## Unresolved / could not verify
- Numeric value of WorkoutScheduler.maxAllowedScheduledWorkoutCount (not published; read at runtime).
- Official iOS version tags for cyclingPower/cyclingCadence (believed iOS 17) and runningPower etc. (believed iOS 16); confirm in Xcode headers.
- Garmin program FAQ and per-API pages 404 on direct fetch; current approval criteria, SLA, and whether Starter truly accepts sole proprietors are unverified. Program agreement PDF not yet read.
- Strava 2026 policy details (7 day cache cap, AI ban, Extended Access tiers) come from a secondary blog; re-read https://www.strava.com/legal/api plus the API policy page before building.
- Current CloudKit public database request quotas (Apple publishes no firm numbers; forum reports only).
- Wahoo rate limits and Suunto first-party terms (only third party summaries found).
