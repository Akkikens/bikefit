# Integration research: Garmin Connect Developer Program (as of 2026-11-08)

Purpose: decision input for Brickline's Garmin integration (readiness and recovery signals, completed workouts, structured workouts pushed to Garmin devices). Written for a solo developer, free app, no revenue, App Privacy target "Data Not Collected" where feasible, no third party analytics or ads SDKs, thin Vercel backend.

Evidence labels used below:
- PRIMARY: read directly from a Garmin page, Garmin PDF or Garmin GitHub repo in this session.
- SECONDARY: press, blogs, forum posts, developer write-ups. Not verified against Garmin.
- UNVERIFIED: could not confirm; also listed in the open questions.

Garmin's Developer Portal documentation (the real Health API, Activity API and Training API specs, including the Training API workout schema) is behind a login and approval. Direct fetches of developerportal.garmin.com returned HTTP 403. So every field level statement about those APIs below is SECONDARY unless stated.

---

## 1. Program structure today (PRIMARY)

Source: https://developer.garmin.com/gc-developer-program/overview/ (fetched 2026-11-08; page footer says 2026).

Three tiers:

| | Personal | Business: Starter | Business: Enterprise |
|---|---|---|---|
| Purpose (Garmin wording) | "Secure access to your own Garmin Connect data" | "The starting point for organizations building apps with Garmin Connect API access" | "Designed for companies operating at scale requiring capabilities beyond Starter Access" |
| How you get it | Log in to Garmin Connect web, create a personal API key, no application | Apply via the access request form, then create an app with Starter Access | Request later through Garmin Developer Portal |
| APIs | Activity (JSON and .FIT), Health (JSON), Women's Health (JSON) | Activity (JSON and .FIT), Courses, Health, Training, Women's Health (all JSON) | Same as Starter plus Golf |
| Delivery | Pull only | Push only | Push or Ping/Pull |
| Historical data | not stated | Not included | "1 month +" |
| User capacity | own account | "Limited" | "Unlimited" |
| Technical support | not stated | not stated | Included |
| Price (Garmin page) | not stated | not stated | "tailored based on business and technical requirements" |

The page says the Business program "supports a broad range of organizations, from individual developers and startups to companies operating at significant scale."

Other PRIMARY pages:
- Business program FAQ: https://developer.garmin.com/gc-developer-program/enterprise/program-faq/
- Health API page: https://developer.garmin.com/gc-developer-program/enterprise/health-api
- Activity API page: https://developer.garmin.com/gc-developer-program/enterprise/activity-api
- Training API page: https://developer.garmin.com/gc-developer-program/enterprise/training-api
- Courses API page: https://developer.garmin.com/gc-developer-program/enterprise/courses-api
- Personal API FAQ: https://developer.garmin.com/gc-developer-program/personal/personal-faq/
- Personal API quick start: https://developer.garmin.com/gc-developer-program/personal/personal-api
- Access request form (JavaScript rendered, contents not readable): https://www.garmin.com/en-US/forms/StarterGarminConnectDeveloperAccess/

Note: older URLs such as /gc-developer-program/health-api/, /training-api/, /activity-api/ and /program-faq/ now return 404 (site restructured under /enterprise/). Earlier notes in tri-research-platform.md recorded those 404s; the content lives at the /enterprise/ paths above.

---

## 2. Pause in spring 2026 and relaunch on 2026-10-21: what is true now

Verdict: the pause and the relaunch both appear real. The relaunch is corroborated by Garmin's own pages (three tier overview, Personal API FAQ, a Garmin GitHub client repo last pushed 2026-10-21T16:14:35Z). I did not find a Garmin authored announcement of either the pause or the relaunch.

Pause evidence:
- Garmin reply, relayed by a forum user, no date: "The application form for new API access requests is currently unavailable" ... "new access requests are temporarily paused" ... the form "will be made available again on our developer website" once the updated program "and application process are finalized." SECONDARY (relayed text, not posted by Garmin staff): https://forums.garmin.com/developer/connect-iq/f/discussion/434798/cannot-access-developer-program-application-form---under-construction/2027757
- Terra, 2026-09-07: the application form showed "Under Construction" by spring; pause covered all five cloud APIs including Training API; existing approved partners not announced as cut off. SECONDARY: https://tryterra.co/blog/garmin-connect-developer-program-pause
- the5krunner, 2026-09-14: pause with no timeline; Garmin cited a "significant redesign and modernisation of the API program" (as reported earlier in tri-research-platform.md). SECONDARY: https://the5krunner.com/2026/09/14/garmin-developer-api-access-paused/
- DC Rainmaker: Garmin closed the program to new applicants in March because of a flood of mostly AI generated app requests. SECONDARY: https://www.dcrainmaker.com/2026/10/garmin-connect-api-revamps-connect-developer.html
- Garmin forum thread where a solo developer asks what to do while applications are paused (community replies only; no Garmin staff answer; one reply claims access had been "basically limited to Garmin partners" and another claims many solo developers got Training API access in the prior year before March; both unverified): https://forums.garmin.com/developer/connect-iq/f/discussion/441459/connect-developer-program-what-should-a-solo-developer-do-while-applications-are-paused
- Dissent: aifitnessapi.com says Garmin's own pages never said the program was paused and that Terra claims it. SECONDARY and contradicted by the forum text above: https://aifitnessapi.com/fix/garmin-api-approval

Relaunch evidence:
- 2026-10-21 reopening with Personal, Starter, Enterprise tiers: Garmin Rumors (2026-10-21) https://garminrumors.com/garmin-connect-developer-program-personal-starter-enterprise/ ; iDevice (2026-10-21) https://idevice.com/garmin-reopens-its-connect-api-with-free-personal-keys-and-a-fee-for-big-apps.md ; Momentum (updated 2026-10-28) https://www.themomentum.ai/blog/garmin-connect-developer-program-reopens ; Sahha https://sahha.ai/blog/garmin-connect-api-reopened-fees/ . SECONDARY, consistent with each other and with the PRIMARY overview page.
- Reported timeline (SECONDARY, Pain Cave): March 2026 closure and agreement revision; 2026-05-20 Garmin tells a developer it cannot say when processing resumes; 2026-07-22 Garmin acquires TrainingPeaks and TrainHeroic; 2026-10-21 reopening; 2027-04-01 companies must start paying for Enterprise. https://www.paincave.io/blog/garmin-api-changes-training-data-2026
- Garmin acquired TrainingPeaks and TrainHeroic, announced 2026-07-22 (financial terms not disclosed; announcement says nothing about open integrations): https://peaksware.com/garmin-acquires-trainingpeaks-and-trainheroic-leading-endurance-and-strength-training-platforms-for-athletes-and-coaches/ . Inference, not sourced: a Garmin owned training platform makes a triathlon training app a more direct competitor to Garmin's own stack, which could matter for discretionary Training API approvals. Treat as a risk to watch, not a fact.

Post relaunch approval experience: no first hand solo developer report found. DC Rainmaker expects Starter approval to be "virtually instant"; a commenter there reports one Starter applicant approved the same day and another with no response. Garmin's FAQ says only that after approval "a typical integration takes between 1 and 4 weeks." No stated review time on Garmin's pages.

---

## 3. Who qualifies: individual versus company

Conflicting signals, no resolution available without Garmin:
- Garmin PRIMARY (overview and FAQ): program "supports a broad range of organizations, from individual developers and startups to companies operating at significant scale."
- Per Garmin Rumors and Sahha (SECONDARY, both describe the live access form): the form "is for businesses, organizations and commercial entities," "must be submitted by the organization that owns, operates, or distributes the app," and "individuals are directed to Personal." It reportedly asks for company details, privacy policy URL, business model, expected users over 12 months (0 to 100, 100 to 1,000, over 1,000), every third party service that will process Garmin data (including analytics, ML or AI platforms), requested APIs, and any prior Garmin contact. aifitnessapi.com and the5krunner's coverage add that applicants need a public website and published privacy policy (SECONDARY).
- Garmin's Personal API FAQ PRIMARY: Personal API "is not intended for commercial applications serving multiple end users." So a Personal key cannot power Brickline for other users. https://developer.garmin.com/gc-developer-program/personal/personal-faq/
- Practical consequence: whether a sole proprietor with no registered entity is accepted for Starter is UNVERIFIED. Whether to form an entity just for this is a legal and tax question that belongs with qualified advisors, not with this note.

---

## 4. Limits, fees, approval mechanics

- Starter user limit: Garmin's page says only "Limited." DC Rainmaker reports "up to 1,000 users" and free (SECONDARY): https://www.dcrainmaker.com/2026/10/garmin-connect-api-revamps-connect-developer.html . Open Wearables also says up to 1,000 (SECONDARY): https://openwearables.io/docs/providers/garmin-api-integration
- Starter fee: free per press. The agreement itself (Rev. B, section 10.1) says "no license fees or other payments will be due" but Garmin "reserves the right to charge fees for future use of or access to the API in Garmin's sole discretion" effective on 30 days' notice, and section 10.2 reserves fees for excess request volume. PRIMARY: https://www8.garmin.com/en-US/GARMINCONNECTDEVELOPERPROGRAMAGREEMENT/GARMINCONNECTDEVELOPERPROGRAMAGREEMENT_EN.pdf
- Enterprise fee: DC Rainmaker reports a one time $1,000 entry fee credited against a per active monthly user bill, negotiated per company; billing starts 2027-04-01; existing partners move to Enterprise without the entry fee; Garmin dropped a $5,000 entry fee in 2019. SECONDARY (same DC Rainmaker URL). Garmin's own pages publish no prices.
- Starter apps carry an "unverified" label until Garmin reviews them and new user connections may be limited during review (SECONDARY, the5krunner and Garmin Rumors).
- Production path (SECONDARY, Open Wearables): create an evaluation app, enable endpoints and scopes, pass Partner Verification, apply for production access, switch to production credentials. Evaluation apps used in production may be disabled without notice. https://openwearables.io/docs/providers/garmin-api-integration
- All APIs use OAuth 2.0 (PRIMARY FAQ). Whether PKCE is supported on the business OAuth flow is UNVERIFIED.
- Request rate: one developer guide reports a limit of 100 requests per minute (SECONDARY, https://openwearables.io/blog/garmin-connect-api-developer-guide-activities-health-metrics ). Not confirmed by Garmin.
- Garmin can terminate on 30 days' written notice (agreement 9.2), can rescind or suspend a license key at any time (4.2), may require pre-publication app review (4.2), and may update the API with the licensee bearing the cost of changes (3.2).

---

## 5. Push versus ping, historical data, backfill

- Starter is push only, Enterprise push or ping/pull (PRIMARY overview).
- Push means Garmin POSTs payloads to a public HTTPS webhook on the developer's server after the user syncs their device; there is no polling endpoint on Starter. Delivery typically 1 to 5 minutes after a device sync, no real time guarantee; respond HTTP 200 fast, any other response triggers redelivery; duplicates can arrive so upsert by summary ID (SECONDARY, Open Wearables guide URL above). Ping delivers a callback URL to fetch.
- Historical data: none on Starter (PRIMARY). Enterprise backfill, per Open Wearables (SECONDARY): requires Enterprise, about the last 30 days, each type generally once, one day per request, the user must grant a historical data export permission or backfill returns 403, retries stop after three attempts.
- Consequence for a deployed design (analysis): with push only and no history, Brickline's server must be online to receive payloads and must hold them until the phone fetches them, because the app is otherwise offline. A new Garmin connection starts with no history, so baseline calibration (for example resting HR or HRV baselines) has to build up over days from first connection, or fall back to Apple Health history where present.

---

## 6. APIs and what data is actually available

### Health API (PRIMARY feature list, Garmin page)
https://developer.garmin.com/gc-developer-program/enterprise/health-api lists: Steps, Intensity Minutes, Sleep, Calories, Heart Rate, Stress, Pulse Ox, Body Battery, Body Composition, Respiration, Blood Pressure, plus "Enhanced Beat-To-Beat Interval" (asterisked as Enterprise only; the page marks Enhanced Beat-To-Beat Interval, multi project support, backfill and Ping/Pull as "Supported with Enterprise Access only"). Data is JSON that "summarizes the individual user data uploaded to Garmin Connect from supported devices," including "detailed stress, pulse-ox, and epoch summaries." After consent, "end-users sync their device with Garmin Connect to upload device data, at which point it is accessible via the API." The page targets Corporate Wellness, Population Health and Patient Monitoring markets.

Summary types and fields (SECONDARY, from integrators; field names unverified against Garmin's spec):
- Summary families: dailies, epochs (15 minute slices), sleeps, bodyComps, stressDetails, allDayRespiration, pulseox, bloodPressures, userMetrics, skinTemp, healthSnapshot, HRV, thirdPartyDailies. Sources: https://openwearables.io/blog/garmin-connect-api-developer-guide-activities-health-metrics , https://github.com/jimmykane/quantified-self/issues/613 (references Health API 1.2.4), https://support.mydatahelps.org/garmin-export-overview
- Daily stress: averageStressLevel in dailies (-1 means no data); stress detail time series in stressDetails.
- Body Battery: derived from stressDetails.timeOffsetBodyBatteryValues (min and max for the day) in one integration; dailies may carry charged and drained values "where Health API 1.2.4 defines them." https://github.com/Janibertz/zone3/pull/23
- HRV: HRV summary with lastNightAvg; Garmin's own blog snippet says HRV is a JSON summary collected during the overnight sleep window "on limited devices such as the Forerunner 995" (search snippet of a Garmin Developer Portal blog post that is login gated: https://developerportal.garmin.com/blog/hrv-summaries-are-now-available-health-api ). So HRV availability depends on device model.
- Sleep: sleeps summary with duration, stages, and overallSleepScore.value on supported devices (same Zone3 PR; Garmin blog "Sleep scores available on supported devices" is login gated).
- Resting heart rate: restingHeartRateInBeatsPerMinute in dailies (Zone3 PR).
- VO2 max and fitness age: userMetrics summary (quantified-self issue 613).
- Training readiness: NOT available. Zone3 PR states "Training Readiness" does not exist in the Health API (SECONDARY). A commenter on DC Rainmaker reports training readiness, training status, acute and chronic load, load ratio and VO2max return "not found" on the new Personal API, while HRV, sleep, Body Battery, stress, resting HR, weight and steps work (SECONDARY, comment, not the article author). Community MCP server for the Personal API reports the same 404s. Unofficial wrappers expose training readiness and status by scraping Garmin Connect's internal endpoints, which is not an approved integration path.
- Training load and effect: no official Health API field found. The Activity API may carry per activity training effect; but see FIT stripping below.

### Personal API (PRIMARY: Garmin's own client repo) endpoint wrappers
https://github.com/garmin/connect-personal-api-python (README, last pushed 2026-10-21) lists these GET endpoints under personal.connectapi.garmin.com: daily stress, steps, hydration, weight, sleep, sleep summaries, Body Battery daily reports, daily summaries, daily heart rate, HRV (single day and range), heart rate zones, fitness age, SpO2, menstrual cycle, wellness activity summaries, activities search, activity detail, activity workouts, and activity file download as ZIP. There is no wrapper for training readiness, training status, VO2 max or acute load. Full endpoint list is in the Swagger docs page https://developer.garmin.com/gc-developer-program/personal/swagger-docs/ (JavaScript rendered; not readable by my tools). This is useful as the closest public evidence of which data classes Garmin considers part of the offering, but the Personal API is not the business API and cannot serve Brickline's users.

### Activity API
PRIMARY page: "detailed fitness data captured during an activity" for Running, Cycling, Swimming, Yoga, Strength Training; "JSON summaries or FIT files"; Enterprise only: push or ping/pull choice, backfill, multi project; full activity detail files in FIT, GPX, TCX are listed (the page says "Activity data files (.FIT, GPX, .TCX formats) available" with no tier marker; the overview page lists only JSON and .FIT for Starter). Multisport activity detail: Garmin forum thread says transitions are separate sessions in the FIT file with a transition sport type (SECONDARY): https://forums.garmin.com/developer/fit-sdk/f/discussion/436246/parsing-transitions-in-multi-sport-fit-files-best-practice
FIT stripping (SECONDARY, two sources): Garmin removes VO2 max, recovery time, performance condition, training effect and sweat loss from FIT files delivered through the API while manual downloads keep them (byteiota https://byteiota.com/garmin-connect-api-revamp-personal-access-free/ ; iDevice URL above citing Runalyze losing VO2 max, recovery time and performance condition; the5krunner https://the5krunner.com/2026/10/22/garmin-personal-api/ says Garmin has not said whether a personal key returns the complete or stripped file). Treat per activity training effect and recovery time as not available.

### Training API (PRIMARY feature page, SECONDARY schema)
https://developer.garmin.com/gc-developer-program/enterprise/training-api : "publish workouts and training plans to the Garmin Connect calendar. Once published, the training data will be available for users to sync with their compatible Garmin devices," the user "can easily start a workout and follow the steps on the wearable or cycling computer." Features listed: Workouts, Training Plans, REST architecture, multi project (Enterprise only). Flow: users consent, send data to Garmin Connect, Garmin Connect handles device interaction, the user syncs their device. "New devices with course and workout features are supported automatically." Not in the Personal tier (PRIMARY overview; also Tredict https://www.tredict.com/blog/garmin_personal_api_chatgpt_and_claude/ and the5krunner).
What I could not obtain: the actual Training API specification (workout JSON model, enums, step limits). It is in the login gated portal.
Evidence on sport coverage (SECONDARY): Tredict, an established integrator, says its workouts reach the watch through the Training API for running, cycling, pool swimming and strength, with steps, target zones, repetitions and full training plans, no duplicates, and withdraws workouts from watch and calendar when rearranged. Source: https://www.tredict.com/blog/garmin_personal_api_chatgpt_and_claude/
Multisport (swim bike run in one structured workout): UNVERIFIED. Community forum threads say Garmin Connect's workout builder is single sport and users build one workout per leg and start them in sequence (https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-web/69679/multi-sport-workouts-garmin-connect , SECONDARY and possibly dated). Devices do have a Multisport activity type with transition recording (Forerunner 970 manual: https://www8.garmin.com/manuals/webhelp/GUID-025D75CF-3445-49E1-8D81-1AA74AB4E00F/EN-US/GUID-05226345-0236-472A-AA19-D6E428604A52.html ), but that is recording, not a structured workout. Plan for single sport sessions per leg until Garmin's spec is read. Brick = two scheduled workouts back to back.
Intervals and targets (SECONDARY, reverse engineered community tooling for Garmin Connect's workout JSON, not the official Training API schema): step types warmup, interval, recovery, cooldown, rest and repeat groups with a repeat count; end conditions time, distance, lap button; targets heart rate (zone or range), pace, cadence, power (zone or range), speed; swim steps carry pool length, stroke type, equipment (fins, kickboard, paddles, pull buoy) and drill type. Source: https://github.com/ThomasRondof/GarminWorkoutAItoJSON . Do not assume the official Training API schema matches.

### Courses API
PRIMARY page https://developer.garmin.com/gc-developer-program/enterprise/courses-api : publish Courses and Course Points to Garmin Connect, same sync flow. Relevant only for race route files later.

### Women's Health API
Exists in Starter (PRIMARY overview); out of scope for Brickline.

---

## 7. Brand and attribution (PRIMARY)

Source: Garmin API Brand Guidelines v 6.30.2025, https://developer.garmin.com/downloads/brand/Garmin-Developer-API-Brand-Guidelines.pdf (linked from https://developer.garmin.com/brand-guidelines/api-brand-guidelines/ ). The agreement (6.2/6.4) says developers must follow it; Garmin "reserves the right to review applications for attribution compliance. Noncompliance may result in suspension or termination of API access."

Rules that bite a training app:
- Title level or primary displays (dashboards, activity feeds, overview cards, summary views): every use of Garmin device sourced data needs a "Garmin [device model]" attribution, placed directly beneath or adjacent to the primary title of the data view, above the fold, visually associated with the data. "Never bury the Garmin attribution in tooltips, footnotes or expandable containers." If the device model is not provided, list "Garmin" as the source. Text or the Garmin tag logo allowed; do not alter or animate the logo; do not use it in avatars or badges or where Garmin data is not present.
- Secondary screens (detail views, reports, settings, historical views, including heart rate, steps, Body Battery): attribution in all expanded views, global header allowed for multi entry displays. Screenshots, printouts and reports must retain visible attribution.
- Exported or shared data (CSV, PDF, API or webhook): attribution adjacent to data and repeated on each page; downstream systems must preserve it; developer responsible for enforcing downstream attribution.
- Combined or derived data (analytics, algorithms, ML, AI, blended with other sources; "any use where the output is influenced materially by Garmin device-sourced data"): attribution required as a distinct or contributing source; must not imply Garmin endorsement of other devices' data. Acceptable examples: "This chart was created using data provided by Garmin devices." "Insights derived in part from Garmin device-sourced data." "Model incorporates Garmin [device model] data." Not acceptable: "Garmin speed model."
- Visual and social media (images, infographics, charts): "The Garmin attribution must be visible in every image."
- Authenticating: use the full app name and tile ("GARMIN CONNECT" with trademark) when showing the connection; do not abbreviate or stylize.
- Agreement 6.5/6.6 (March 2026 template): 14 days to cure a branding issue, then Garmin may reduce data and, after another 14 days, suspend; 30 days' prior written notice to connect-support@developer.garmin.com before introducing new display formats that incorporate Garmin brand features or attributed data.
- Exemption: the attribution requirement does not apply to Health API data used only in defense, research or remote patient monitoring without third party branding (agreement 6.4a). Does not apply to Brickline.

Design implications for Brickline (analysis): every Brickline surface that shows a Garmin derived number (a readiness chip, an adaptation reason line like "eased Tuesday because your overnight HRV dropped", a completed workout card, a share card image, a plan share export) carries a visible "Garmin [device model]" or "derived in part from Garmin device-sourced data" line. Share cards are the highest risk because the image leaves the app.

---

## 8. Terms on data storage, derivative use, privacy (PRIMARY: agreement)

Two agreement PDFs are published; check which one Garmin gives you at acceptance:
- Older: developerportal PDF, last modified 2025-01-07, PDF creation 2023-10-04, counterparty "Garmin International, Inc.": https://developerportal.garmin.com/sites/default/files/Garmin%20Connect%20Developer%20Program%20Agreement.pdf (14 pages, Rev. B, no AI clause, no Garmin Device Sourced Data definition).
- Newer: www8.garmin.com PDF, last modified 2026-03-06, PDF creation 2026-03-03, counterparty "Garmin China Shanghai RHQ Co., Ltd." with a China cross border data annex (19 pages, Rev. B): https://www8.garmin.com/en-US/GARMINCONNECTDEVELOPERPROGRAMAGREEMENT/GARMINCONNECTDEVELOPERPROGRAMAGREEMENT_EN.pdf . The counterparty name suggests a regional template; whether a US licensee signs this text is UNVERIFIED. Both show footer "FRM-0952 Rev. B". Section numbers below refer to the newer file unless noted.

Clauses that matter (paraphrased, not quoted at length):
- 4.1: licence is non sublicensable (except approved subcontractors); data usable "solely for internal business purposes" and "only to the extent necessary to format and display such data" in the licensee's application, and only as allowed by law and consistent with each end user's consent. Tension with deriving readiness scores and plan adjustments is real; the brand guidelines separately contemplate analytics and algorithms with attribution, so derived use appears intended but the contract wording is narrow. Get written clarification from Garmin (open question).
- 15.6: no modification of end user personal data other than formatting for display, unless legally permitted.
- 5.2(e): may not "derive income from the use or provision of the API, whether for direct commercial or monetary gain or otherwise, without Garmin's prior written permission." A free app is fine; any later monetisation (including the StoreKit scaffold) needs written permission. Keep any sales flag OFF.
- 5.2(o): may not make the API or end user data available to third party sites, apps, platforms or services not approved by Garmin in writing, including by building your own API for that purpose. Reported to be the basis for cutting off platform-to-platform passthrough (Intervals.icu, Intervals Pro shutdown 2026-10-12): https://the5krunner.com/2026/10/14/garmin-api-intervals-third-party-apps/ (SECONDARY). Implication: Brickline must not relay Garmin data into other services (for example forwarding to Strava) and the spec's "Strava upload" must send only Brickline originated workouts, not Garmin imported ones.
- 5.2(q): may not combine or integrate the API with any software, technology or services unless authorised by the agreement or by Garmin in writing. Ambiguous; relevant to mixing Garmin with WHOOP, Oura and HealthKit in one readiness model. Ask Garmin.
- 4.5: apps that send data to Garmin must give conspicuous notice with a link to the Garmin Connect privacy notice, get express consent, and tell users not to upload data they are restricted from uploading. Applies to pushing workouts.
- 4.6: Garmin may use any Licensee Data transferred to Garmin (including derivative works) for any purpose, with no obligation to delete it. Applies to workouts and plans Brickline pushes.
- 5.1(f) to (h): security program meeting Garmin's Minimum Security Requirements; notify security@garmin.com and by phone within 24 hours of identified weaknesses and of any confirmed breach.
- 5.3: monitor use, provide an abuse reporting resource, and enter into a written agreement with each end user that protects Garmin at least as well as the Garmin agreement (so Brickline needs end user terms).
- 15.2 to 15.5: Garmin is an independent controller, not the licensee's processor; licensee must give privacy notice, obtain and allow withdrawal of consent, process only per notices and consents, answer data subject requests (access, erase, export), and not sell end user personal data without lawful consent.
- 15.10 (newer file only): privacy policy must carry a conspicuous AI transparency statement if end user data is used for training with or processing by AI systems, with explicit and withdrawable consent. Brickline's spec uses deterministic rules and no AI coach, so likely inapplicable; do not introduce an LLM on Garmin data without revisiting this. A DC Rainmaker commenter quoted a stricter AI clause (no AI models or knowledge bases from device sourced data) that I could not find in the PDF; UNVERIFIED.
- 15.8: use only Garmin's authorisation system; never collect Garmin credentials.
- Data retention: no fixed retention period found in either agreement. Consent, deletion on request and (for China transfers) retention limits appear; nothing sets a number of days for developer-held data. UNVERIFIED whether the portal docs add one.
- 9.5: on termination, destroy the API and Garmin brand features; the delete obligation for stored end user data is not spelled out in the clauses I read beyond the data protection duties.
- 12: Garmin's total liability capped at $1.00. 14.2: licensee indemnifies Garmin for breach and data breaches.

Privacy label consequence (analysis, not Garmin text): push delivery means Brickline's server receives and holds Garmin health data until the phone retrieves it. Apple's definition of "collect" is transmitting data off device so the developer can access it for longer than needed to service a request in real time (https://developer.apple.com/app-store/app-privacy-details/ , quoted in tri-research-platform.md). A server buffer almost certainly breaks "Data Not Collected" for users who connect Garmin; likely disclosures: Health & Fitness, possibly Identifiers, with a linked or not linked decision. Options: (a) accept a non "Data Not Collected" label from the release that adds Garmin (the cleanest and most honest), (b) ship a separate Garmin connected build, not recommended, (c) keep Garmin out until the label question is decided. Liftspark's existing Vercel backend is a stateless OAuth proxy (providers.ts holds Strava, WHOOP and Oura only; PLAN.md says "Garmin's Health/Connect APIs require business approval" and routes Garmin through Apple Health and BLE broadcast meanwhile), so Garmin push would require new persistent storage plus a webhook receiver. That is a different class of backend than the token-proxy pattern.

---

## 9. What Garmin Connect writes to Apple Health on iOS, and how reliable it is

Garmin's own support article (https://support.garmin.com/en-GB/?faq=lK5FPB9iPF5PXFkIpFlFPA ) is behind a bot challenge (HTTP 403 to my tools). Everything here is SECONDARY.

Written by Garmin Connect to Apple Health (one way, Garmin to Health):
- Steps, walking and running distance, active and resting energy, flights climbed, heart rate (all day), sleep analysis, weight, body fat percentage, BMI, water, blood pressure, and workouts uploaded to Connect. Sources: https://the5krunner.com/2025/06/20/garmin-to-add-health-connect-support-to-apple/ (quotes Garmin's FAQ list; page metadata shows updated 2026-10-03), https://gadgetsandwearables.com/2021/10/09/garmin-not-syncing-apple-health/ , https://ultrafit360.com/blog/garmin-apple-health-health-connect (updated 2026-10-09).
Not written:
- GPS tracks and routes for workouts.
- Heart rate for timed activities is only the high and low values, not a sample series, so Apple's Activity app can show "Chart Unavailable" (all three sources agree).
- HRV, Body Battery and other Garmin scores stay in Garmin Connect (ultrafit360, ScoreVitals listing HRV status, Body Battery, stress, VO2 max, SpO2 and training load as not synced: https://scorevitals.com/howtos/sync-garmin-watch-to-apple-health ). Resting heart rate: sources conflict (gadgetsandwearables says it is included in all day HR; ultrafit360 says not listed).
- Nothing flows back: Connect does not read from Apple Health or Apple Watch.
Reliability notes:
- Garmin Connect must be open in the foreground for transfers to finish; if closed, the transfer waits for the next sync made with the app open.
- Data arrives only after the watch syncs to the phone, so timing depends on the user.
- Competing sources: Apple Health shows the highest priority source per data type, and iPhone steps can outrank Garmin; users must reorder sources.
- Past forum reports of weight sync stopping and of energy data being removed when the app was next opened (older Garmin Forums threads, for example https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-ios/138152/apple-health-sync-issues-weight-active-resting-energy-flights-climbed-distance ); a historical import window of about two weeks after enabling (ultrafit360).
- Garmin Connect app update 4.37 once broke sync for many users (gadgetsandwearables, old).
Implication for Brickline's existing HealthKit completion loop: Garmin workouts will arrive as HKWorkouts with duration, distance, energy, and only high/low heart rate; no route; no per second HR; no power or cadence series confirmed (ultrafit360 mentions cycling cadence and swim strokes "where applicable"; not confirmed for power). Load calculations from HR zones for Garmin workouts via Apple Health will therefore be coarse, which is a strong argument for the Activity API (FIT) if Starter is granted. Not confirmed whether Garmin sets the plan UUID link (it will not; that is WorkoutKit specific), so matching falls back to type, time and duration.

---

## 10. Connect IQ and live heart rate

- Connect IQ is a separate program; per Garmin's FAQ neither program requires the other (PRIMARY: https://developer.garmin.com/gc-developer-program/enterprise/program-faq/ ). SDK free, current version 9.3.0 updated 2026-10-30 (PRIMARY: https://developer.garmin.com/connect-iq/overview/ ). App types: watch faces, widgets, data fields, device apps, audio content providers. Device apps and data fields can access ANT+ sensors, record FIT, use BLE to talk to mobile phones, and do OAuth web services. Connect IQ stayed open during the 2026 pause (SECONDARY).
- iOS companion: the Connect IQ Mobile SDK for iOS lets an iOS app exchange messages with a Monkey C app over Bluetooth; "Unlike the Android version, iOS companion apps are standalone" but Garmin Connect Mobile is still needed to discover devices and install apps (PRIMARY: https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-ios , nav snippet confirmed; body text via search result, so partly SECONDARY). Cost to a solo developer: Monkey C app plus Connect IQ store review, a new codebase. A Connect IQ path would allow on-watch plan display or a data field without Garmin Connect Developer Program approval, but it does not pull Health API data or push structured workouts to the native workout list.
- Heart rate broadcast (live HR to a phone app): Garmin watches have a "Broadcast Heart Rate" setting that broadcasts "to a compatible device" and says "There is no indication that the watch is broadcasting"; it drains battery and stops when the activity stops (PRIMARY manual text for Forerunner 965: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-57A88A77-3813-4E79-9DB1-FC95B06F01BA.html , page dated April 2026). Transport: ANT+ on virtually all Garmin wearables, which iPhones cannot receive; Bluetooth LE only on newer watches, historically via a "Virtual Run" activity profile (DC Rainmaker 2020, SECONDARY: https://dcrainmaker.com/2020/04/garmin-wearable-broadcasting.html ). Reliability varies by model: a Forerunner 970 user reports broadcast works over ANT+ but not Bluetooth to phone and PC apps, with no Garmin answer (SECONDARY: https://forums.garmin.com/sports-fitness/running-multisport/f/forerunner-970/416682/bluetooth-on-broadcast-hr-not-working ). Treat live HR from Garmin to the iPhone as best effort on supported models only. The owner's Liftspark README claims BLE Heart Rate Service 0x180D works with "Garmin with heart-rate broadcast on" and PLAN.md lists real device QA for it as not yet done, so it is untested on hardware.
- Garmin Health SDKs (Companion SDK streams live heart rate, stress, accelerometer, beat to beat intervals to iOS and Android) are for "Garmin Health enterprise partners"; evaluation is free, commercial use needs "License Fee or Minimum Device Order Quantity" (PRIMARY: https://developer.garmin.com/health-sdk/overview/ and https://developer.garmin.com/health-sdk/questions-answers/ ). Not a fit for a free solo app.

---

## 11. Net assessment for Brickline (analysis, flagged as such)

1. Apple Health is the zero permission Garmin path today: completed workouts (no routes, high/low HR only), sleep, steps, all day HR. It carries no HRV, Body Battery or Garmin scores. It also never writes anything to a Garmin device.
2. The only supported way to put Brickline sessions on a Garmin watch is the Training API in Starter or Enterprise. Needs business access approval, a public webhook/OAuth server, privacy policy, and compliance with the agreement. Multisport structured workouts are unconfirmed; single sport swim (pool), bike and run workouts are evidenced by Tredict.
3. The only supported way to get Garmin recovery signals into the app is the Health API under the same approval. Training readiness and training status are not offered; Body Battery, overnight HRV (limited devices), sleep score, resting HR and stress average are. A rule engine should key off the signals that exist, and say which device they came from (attribution).
4. The Personal API can read a single user's own data but is excluded from commercial multi user apps by Garmin's own FAQ, has no Training API, and tokens expire every 24 hours with no refresh. Do not build a "paste your own key" flow without written confirmation from Garmin; it conflicts with the FAQ's intent.
5. Cost of ownership: push webhook server with persistence, consent and deletion flows, breach notification duty within 24 hours, end user terms, attribution on every surface, 30 day notice before new displays that carry Garmin data, and a privacy label other than "Data Not Collected" for connected users. The Liftspark backend does not yet have persistence.
6. Business risks: Garmin can change terms or fees with 30 days' notice, can suspend access, owns TrainingPeaks since July 2026, and cut off platform-to-platform data flows in 2026. Plan the Garmin layer as optional and removable; the core plan and WorkoutKit loop must work without it.

---

## 12. Open questions (also returned in structured output)

See the structured result's open_questions; mirrored here:
1. Does Starter accept an individual with no legal entity, and what does the form require in practice? Garmin's page says individuals are welcome; press describes the form as business only.
2. Real post relaunch approval time for a new Starter applicant (no first hand report found).
3. Does the Training API accept multisport workouts, and what are the sport enums, step and repeat limits, target types (pace, power, heart rate, cadence), swim pool length handling, and a limit on scheduled workouts per athlete? Spec is behind the login.
4. Which Health API summary fields exist on a Starter app today (HRV availability per device, Body Battery source field, sleep score, userMetrics VO2 max), and whether VO2 max, training effect and recovery time are truly stripped for Starter apps.
5. Does the contract's "format and display only" wording (4.1, 15.6) allow deriving a readiness score and plan adjustments? Needs written clarification from Garmin.
6. Which agreement text applies to a US licensee (Garmin International text of Jan 2025 or the China RHQ template of March 2026)?
7. Does Starter need persistent server storage, and is a short lived buffer deleted on device pickup acceptable under Apple's definition of "collect" for Data Not Collected?
8. Does the business OAuth 2.0 flow support PKCE and a mobile redirect, and what are Garmin's token lifetimes and rate limits (100 per minute is from one third party)?
9. Garmin's own list of data Garmin Connect writes to Apple Health (support article blocked to my tools), including whether resting heart rate and cycling power are written.
10. Whether Garmin treats Brickline's competitor profile (training plans) differently now that it owns TrainingPeaks.
11. Whether Garmin watches in current models (Forerunner 970, 965, Fenix 8) broadcast heart rate over Bluetooth LE in a way iOS apps can read, without the Virtual Run workaround.
12. Whether any Garmin authored announcement of the pause or the October relaunch exists (none found).
