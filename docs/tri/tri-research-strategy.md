# Triathlon app: strategy and risk research notes

Research date: 2026-11-06. All claims carry source URLs. Where I could not find a number, I say so. No legal advice; flag items for a lawyer where noted.

## 1. What "a community like Strava" actually requires from a solo dev

Building an owned social graph means, at minimum:

- A server backend with accounts, a social graph, an activity feed, media storage (photos), notifications, blocking and reporting. This is a second full product beside the training app.
- Apple App Store Review Guideline 1.2 (User-Generated Content): apps with UGC must ship content filtering, a mechanism to report offensive content, the ability to block abusive users, and published developer contact information, and the app can be removed until compliance is shown. Primary: https://developer.apple.com/app-store/review/guidelines/#user-generated-content . Secondary summary of the obligations: https://conductatlas.com/platform/apple/apple-app-store-review-guidelines/user-generated-content-moderation-obligations/
- CSAM reporting duty (US federal law, 18 USC 2258A) once the app hosts user photos: providers must report apparent CSAM to the NCMEC CyberTipline, with evidence packaging (hash, timestamp, account info) and retention workflow. Vendor explainers (not primary law, verify): https://dev.to/sentinelsafety/ncmec-mandatory-reporting-for-online-platforms-what-developers-need-to-know-4k74 and https://www.traverselegal.com/blog/does-my-ai-company-have-to-report-illegal-content/ . One source notes obligations attach to actual knowledge, so scanning creates duties, and that hosting location, not home country, can drive which regimes apply.
- EU Digital Services Act: micro enterprises (under 10 employees, under 2M EUR turnover) are exempt from the online-platform-specific duties such as internal complaint handling (Art 20), out-of-court dispute settlement (Art 21), trusted flaggers (Art 22) and transparency reports, but the baseline hosting duties (notice and action, point of contact, terms transparency) still apply. Secondary: https://presencis.com/regulations/dsa/applicability/ , https://presencis.com/regulations/dsa/article-19/ , https://actonline.org/2022/08/05/dsa-explainer/ . Verify against Regulation (EU) 2022/2065 Article 19 on EUR-Lex before relying.
- UK Online Safety Act is a separate regime flagged by the same vendor sources (risk assessments for user-to-user services, no small-size exemption from the core duties): https://dev.to/sentinelsafety/building-compliance-native-child-safety-what-dsa-and-ukosa-actually-require-11ac
- Moderation staffing: there is no staffing, it is Akshay at 11pm reviewing reported photos. Sample small-app policies say "reports are manually reviewed by the developer", which a compliance vendor calls a legal exposure when reports lag days or weeks.
- App Privacy: a social product with accounts and a feed cannot ship as "Data Not Collected". That breaks the standing target in Akshay's pipeline (step 6 in CLAUDE.md). A solo-synced CloudKit private database app can; a public feed cannot.

### Server cost at zero revenue

- Supabase Free: 2 projects, 500 MB Postgres, 50,000 auth MAU, 1 GB file storage, 5 GB egress, pauses after 7 days of inactivity; Pro is $25 per month with 8 GB and 100,000 MAU. Third-party 2026 summaries (verify on supabase.com/pricing): https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/ , https://www.activepieces.com/blog/supabase-pricing-free-tier-limits-pro-costs-egress.md
- Photos and video are the cost driver (storage plus egress), not rows. 1 GB free file storage is roughly a few thousand workout photos.
- CloudKit public database: free quota scales with users (Apple's 2015 numbers: base 100 MB storage growing 2.5 MB per user up to 10 TB, transfer 50 MB per user per month up to 200 TB, free): WWDC 2015 session 704 https://nonstrict.eu/wwdcindex/wwdc2015/704/ . Apple no longer publishes a current pricing page; a 2025-era developer forum reply said pricing info is not public: https://developer.apple.com/forums/thread/740916 . CloudKit public DB is the one way to run a feed-like backend at near zero cost, but it gives no server-side moderation tooling, no web presence, and still does not make the app "Data Not Collected" if profiles are public.
- Vercel Hobby is personal and non-commercial; his existing thin proxy fits, a social feed API with sustained traffic does not stay comfortably in it long term (vercel.com/pricing, not fetched; flagging as unverified).

### Documented examples of small fitness social apps

Searches did not surface a shutdown explicitly blamed on Strava; what exists:

- Chorus (Dick Costolo, ex-Twitter CEO, funded, team of engineers): group social fitness app shut down about 8 months after launch; he said they were "up against hard-wired human behavior", users who missed goals avoided their support group. https://www.businessinsider.in/dick-costolo-explains-why-he-shut-down-his-fitness-startup-after-8-months-we-were-up-against-hard-wired-human-behavior/articleshow/63102989.cms and https://globalventuring.com/chorus-quiets-down
- BodyWise closing post (founder admits failure, no single competitor blamed): https://medium.com/@mrmikehalligan/its-time-bodywise-is-closing-%EF%B8%8F-fd056e03db73
- Fitfu (iPhone workout app, closed after 2 years): https://thenextweb.com/news/iphone-workout-app-fitfu-closes-doors-ending-2-year-battle
- Maxout (solo-ish fitness app closed after about a year): https://deploy-preview-592--dreamy-brahmagupta-b6f0be.netlify.app/blog/en/closing-maxout
- Even Garmin Connect and Ride with GPS social features are described by commentators as failed Strava emulations (forum opinion): https://singletrackworld.com/forum/topic/endomondo-is-retiring-what-are-you-replacing-it-with
- Takeaway: the failure mode is not "Strava sued us", it is an empty feed. A social app with 50 users is worse than no social features, because it advertises that nobody is there.

## 2. Why Strava won network effects, and why a new social graph is the hardest wedge

- Recording a workout is a commodity; Strava's kudos, clubs and segments are the product. Case study: https://www.g-co.agency/insights/strava-case-study-why-the-community-is-the-product
- Free users (over 95 percent of the base in a 2021 analysis) generate the posts, segments and interactions that make the paid product valuable: https://insider.fitt.co/issue-no-158-tracking-stravas-rise/
- Segment leaderboards are direct network effects: every new user adds segments and competition, so value compounds with scale: https://d3.harvard.edu/platform-digit/submission/strava-social-fitness-veteran/index.html
- Strava is deliberately platform-agnostic (works with every watch and bike computer), which makes it the neutral social layer no device vendor can displace: https://sacra.com/research/the-whole-foods-of-social-networks/ (Sacra reads as AI-assisted research, treat numbers cautiously; user counts across sources conflict between 90M and 150M+ and were not verified against filings)
- For a new entrant the cold-start problem is maximal in social fitness: the product is other people, and the people are already on Strava. Every triathlete's training partners, club and race friends are there. A solo dev cannot seed density in even one metro area, let alone the geo-sharded density segments and feeds require.
- Strava is also buying the adjacent wedge: it acquired Runna (the exact "Runna for X" template) in April 2025 and keeps it standalone: press release https://persportaal.anp.nl/artikel/CSN-170425027/-strava-to-acquire-runna-a-leading-running-training-app , coverage https://www.t3.com/active/strava-just-bought-runna-and-we-got-the-inside-story-from-both-ceos . So "training plans plus community" is now literally Strava's own roadmap, with a bundle at $149.99 per year: https://stack-archive.com/blog/is-runna-free-price-trial-strava-bundle-2026/

## 3. Community without owning it (the right answer)

- Auto-post to Strava: the Strava API still supports uploads. POST https://www.strava.com/api/v3/uploads accepts FIT, TCX, GPX (optionally gzipped) and JSON with activity:write scope: https://developers.strava.com/docs/uploads/ . Pushing the user's own completed workout to their own Strava account is the allowed direction.
- What the November 2024 API agreement banned (effective Nov 11, 2024, 30 days notice to partners): displaying a user's Strava data to anyone other than that user (kills coach views and third-party leaderboards), using Strava data for AI/ML training, and broad "analytics, analyses, customer insights" processing of Strava data. Showing the user their own data remains allowed; Strava said "the overwhelming majority of existing use cases are still allowed." Sources: https://www.dcrainmaker.com/2024/11/stravas-changes-to-kill-off-apps.html , https://road.cc/content/news/strava-users-cant-publicly-share-data-third-party-apps-311329 , https://marathonhandbook.com/strava-api-changes/ , https://tryterra.co/blog/strava-discontinues-api
  - Design implication: write to Strava, do not build on reading from Strava. Plan generation should run off HealthKit and in-app data (his own TRIMP engine), never off Strava-pulled data, both for ToS safety and because analytics on Strava data is now prohibited.
- Rich share cards (the Liftspark pattern): render the workout summary as an image and share to Instagram, iMessage, Strava photo. Zero backend, zero moderation, the community sees the brand inside communities that already exist.
- Strava clubs: a free club gives group feed, leaderboards and events inside Strava with no infrastructure. Club data via API is read-limited post-2024, but running a club as a brand surface needs no API at all.
- Discord or a race-team and coach "group code" layer: share a plan code or compare-with-friends via iCloud sharing (CKShare) keeps data in Apple infrastructure, no public feed, no UGC photo hosting, far smaller moderation surface, and can stay close to Data Not Collected.

## 4. AGPL implications of reusing Liftspark (openGym derived) code

Not legal advice. Sources: https://medium.com/swlh/understanding-the-agpl-the-most-misunderstood-license-86fd1fe91275 , LWN discussion https://lwn.net/Articles/819101 , Stack Exchange answer mirror https://backiee.wasmer.app/https_opensource_stackexchange_com/a/12926 , explainer https://dodatech-tutorial.pages.dev/fundamentals/agpl-license/

- Clean reuse: code Akshay wrote from scratch and holds copyright on (his native Capacitor plugins for HealthKit, BLE heart rate, the Watch app, Live Activity, CloudKit sync, barcode scan; the Edwards TRIMP engine if written by him; the Vercel proxy) can be relicensed by him and shipped closed in the new app. The copyright holder can license their own work any way they want, provided those files do not incorporate openGym code and are not themselves derivative works of it.
- Not clean: the openGym derived core (UI, data model, screens evolved from openGym) stays AGPL. If any of it ships in the new app, the new app's source must be offered under AGPL, including to network users if any part runs server side (AGPL section 13).
- Gray zone: separate-process communication over an API is generally considered outside the derivative-work boundary, while linking is contested (FSF says linking creates a derivative work; untested in court). In a Capacitor app everything bundles into one process, so "we only import a little of it" does not create separation.
- Practical rule for the new app: start the UI and core clean (or accept shipping AGPL and publishing source, which is also viable for a free app), and lift only the plugins and engines he solely authored, after checking each file's history for openGym-origin lines.

## 5. App Store Guideline 4.3 spam risk

- 4.3(b) rejects apps that are hard to distinguish from many existing apps in a saturated category; fitness and training is template-heavy, and rejection notes cite "the same feature set as other apps submitted to the App Store; it simply varies in content". Guideline text: https://developer.apple.com/app-store/review/guidelines/#spam . Developer threads with the rejection language and appeal outcomes: https://developer.apple.com/forums/thread/775597 , https://developer.apple.com/forums/thread/774834 , https://developer.apple.com/forums/thread/850731 . Third-party guide on the two clauses: https://newly.app/guides/guideline-4-3-spam-rejection
- Mitigation consistent with his CLAUDE.md rule: lead the metadata with what is unique (the camera bike fit module is a genuine differentiator no template app has; triathlon-specific brick scheduling is another), original art and names, and be ready to appeal by phone, which worked in the threads above.

## 6. Liability and FDA framing

- FDA: training plans are squarely inside the general wellness carve-out. The FDCA device definition (21st Century Cures Act, section 520(o)) excludes software "for maintaining or encouraging a healthy lifestyle"; FDA's "General Wellness: Policy for Low Risk Devices" guidance was updated January 6, 2026 and lists exercise, measuring aerobic fitness and improving endurance as qualifying wellness uses, now explicitly including some non-invasive physiologic sensing. Guidance landing: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices (older PDF: https://www.fda.gov/media/90652/download ). Law firm summaries of the Jan 2026 update: https://www.agg.com/news-insights/publications/dont-fear-the-regulator-fda-clarifies-when-software-and-wellness-products-are-not-medical-devices/ , https://www.jonesday.com/es/insights/2026/01/a-relaxing-2026-fda-updates-general-wellness-and-clinical-decision-support-software-guidance , https://www.honigman.com/alert-3236 , CRS overview https://www.everycrsreport.com/reports/IN12657.html
- The condition is claims discipline: marketing and in-app copy must stay on fitness, endurance and training, never disease ("lowers blood pressure", "treats", "diagnoses"), and the heart rate zone features should be framed as training guidance, not health monitoring.
- The bike fit module: keep claims to comfort and performance fit, not injury diagnosis or treatment, same reasoning.
- Swim safety (open water) is the one place a training app can plausibly contribute to a death. No regulation found specific to apps; this is ordinary tort exposure. Mitigations: never schedule unsupervised open water as a requirement (always offer pool equivalents), prominent in-app safety guidance (swim with a buddy, use a tow float, know the venue), a disclaimer and terms acknowledging inherent risk, and consider making open water sessions opt-in. I could not find a documented lawsuit against a training app over an open water drowning; absence of a found case is not absence of risk.

## 7. Free competitors (so "free" is not a wedge)

- Garmin Coach triathlon plans: free adaptive triathlon plan inside Garmin Connect for watch owners, "sign up ... you'll get a free custom plan": https://www.garmin.com/en-US/blog/?p=35760 and running coach free plans https://www.garmin.com/en-US/blog/?p=27784 (some extras behind Connect+).
- MOTTIV: $0 per month free plan covering sprint through full distance, paid from $14.99 per month billed annually (their comparison pages also show $19.99 per month or $179.99 per year, prices conflict on their own site): https://www.mymottiv.com/pricing , free tier announcement https://www.endurancesportswire.com/mottiv-announces-free-version-of-their-app-with-new-a-basic-plan/ , App Store listing https://apps.apple.com/app/id1561001166
- 80/20 Endurance: free 12-week triathlon maintenance plans (code TRY8020), free 2-week full distance samples, free strength plug-in on TrainingPeaks; full race plans paid: https://www.trainingpeaks.com/training-plans/triathlon/tp-113637/free-triathlon-maintenance-training-plan-12-weeks-80-20-pace-power-free-with-cod , https://www.trainingpeaks.com/partners/80-20-endurance/
- Runna (the model being copied): $19.99 per month or $119.99 per year as of October 2026 (earlier 2026 reviews said $17.99), only week 1 free, Strava bundle $149.99 per year: https://the5krunner.com/2026/10/14/is-runna-free/ , https://www.tomsguide.com/reviews/runna-app , https://stack-archive.com/blog/is-runna-free-price-trial-strava-bundle-2026/
- Implication: a genuinely free, well-designed triathlon planner is still differentiated against Runna-style paywalls, but not against Garmin and MOTTIV free tiers. The durable differentiators are the bike fit camera module, Watch-native execution of brick workouts, and privacy (no account, Data Not Collected), none of which the free incumbents offer together.

## 8. Realistic 12 to 16 week solo scope

Grounded in his reusable assets (HealthKit, BLE HR, Watch HKWorkoutSession, Live Activity, CloudKit sync, TRIMP engine, share cards). My sizing judgment, no external source:

- Weeks 1-6: plan engine (race date back-scheduling for sprint and olympic first, 70.3 later), swim/bike/run session library, brick sessions, TRIMP-based load and zones reuse.
- Weeks 5-10: iPhone app UI (today view, week view, calendar), HealthKit read/write, workout logging, Watch app for run and bike execution, pool swim on Watch.
- Weeks 9-13: bike fit module from the existing reviewed spec (it exists, so integration not design), share cards, Strava auto-upload (activity:write only).
- Weeks 13-16: Fable review, fixes, screenshots, site, submission.
- Cut order when behind: 1) anything social (first and totally), 2) full and 70.3 distances (ship sprint and olympic), 3) open water mode, 4) adaptive replanning (ship static plans with manual shuffle), 5) Watch standalone swim metrics. The bike fit module is the differentiator and should be cut last, not first; if time is desperate it ships as "coming in 1.1" only with Akshay's sign-off since it is the 4.3 defense.

## 9. Monetization posture

- Free app, no ads SDK, no analytics, StoreKit 2 built behind an OFF Info.plist flag; no paid products for now. A server backed social product adds recurring cost, moderation duties and legal process with no income to offset them, which argues for no shared features in 1.0, or CloudKit at near zero cost if any ship.

## 10. Name collision check (iTunes Search API, US storefront, entity=software, 2026-11-06)

Method: curl https://itunes.apple.com/search?term=NAME&country=US&entity=software&limit=5

- Taperline: 0 results. FREE.
- Tricadence: 0 exact results (only Trix/Trichify noise). FREE.
- Brickline: no fitness app; collisions are Brickline Pizza Co., Brickline Mercantile, a game "Brick Line". Mostly free, fits his -line naming (Wingline), but check trademark for Brickline Greenway (St. Louis project) before committing.
- Tribeat: no exact match (TRIBE Influencer is unrelated). Mostly free.
- Trivelo: no exact app match, but trivelo.co.uk is an established UK triathlon blog, common-law trademark risk. CAUTION.
- Openwater Tri: "Open Water Swim" app exists and term is generic plus Openwater is an existing brand. AVOID.
- Tripace: taken, two triathlon apps named TriPace (BMAC Infotech, Marc-Andre Stickel). AVOID.
- Swimbikerun: "Swim Bike Run" app exists (Ludovic Mathieu), generic. AVOID.

Best candidates: Taperline, Tricadence, then Brickline and Tribeat. Per CLAUDE.md, still run a USPTO TESS search and full App Store browse before committing.

## Gaps and open questions

- Could not find Apple's current CloudKit public database quota numbers (Apple pulled the pricing page); 2015 WWDC figures are the last official ones.
- No documented case of a fitness app shutdown attributed specifically to losing against Strava; evidence is indirect (Chorus behavioral failure, forum consensus that Garmin and RideWithGPS social flopped).
- Strava developer program status in 2026 (whether new API apps get approved easily, and any paid API rumor) unverified; the $11.99 developer fee claim came from a low-reliability aggregator and should not be relied on.
- DSA Article 19 text verified only through secondary sources, not EUR-Lex directly.
- No lawsuit precedent found for open water swim training app liability (searched indirectly; absence unconfirmed).
