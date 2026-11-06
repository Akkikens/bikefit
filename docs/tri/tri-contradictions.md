# Adversarial review of tri-synthesis.md: contradictions and overclaims

Reviewed 2026-11-06 against the synthesis itself, the five concept angles context inside it, and the verified Saddlemark spec (/Users/akshay/Documents/GitHub/bikefit/docs/specs/bikefit-spec.md, v0.2). Facts disputed below were checked today against Apple's live App Store Review Guidelines, Apple WWDC23/24 WorkoutKit material, the iTunes Search API (US storefront), and press coverage of the Strava and Runna deal, the Strava plus Runna bundle, the TriDot and Ironman split, and Chorus. Each finding: section, severity, problem, exact fix text.

## Blockers

### B1. CloudKit sync in the committed 1.0 schedule contradicts the Data Not Collected position and the verified Saddlemark precedent

Sections 2, 5, 6 (Q3). The one-liner sells "Free, private, no account" and section 3 argues the whole trust wedge rests on Data Not Collected, yet "Weeks 12 to 14" commits "CloudKit private sync" to 1.0 while open question 3 admits nobody knows whether private-database CloudKit sync keeps that label. The verified Saddlemark spec faced the identical question and resolved it the other way: "iCloud sync is excluded from 1.0 because Apple has not said whether private CloudKit sync counts as collection (A36)." The synthesis cannot claim the Saddlemark spec as a verified input and then ship the thing the spec excluded for cause. As written, 1.0 risks launching with a privacy label the product's own positioning calls a broken promise.

Fix, section 5, weeks 12 to 14 line: replace "share cards and codes, CloudKit private sync, polish" with "share cards and codes, polish. CloudKit private sync builds only if open question 3 resolves to a confirmed Data Not Collected label before week 12; otherwise it moves to 1.1 behind the same investigation, matching the Saddlemark spec's A36 decision. Local SwiftData remains the system of record either way."
Fix, section 5, cut order: replace "then CloudKit sync" with "(CloudKit sync is already conditional, not a cut)" and see M3 for the 70.3 line.

## Majors

### M1. "No free plan product exists there" for the first 70.3 is contradicted by the synthesis's own MOTTIV paragraph

Sections 2 and 7. Section 2: "the first 70.3 is the highest-intent moment in the sport and no free plan product exists there." Section 7: "MOTTIV has 71 US ratings ... the free tier has no device sync." MOTTIV's free tier generates personalized plans including 70.3 (its App Store listing names "70.3 half Ironman" plans and the free Basic tier launched May 2023), so a free 70.3 plan product exists; what does not exist is a free one that delivers sessions to a watch. The differentiator survives, but the sentence as written is falsifiable in one search.

Fix, section 2: replace "no free plan product exists there" with "the only free plan product there, MOTTIV's basic tier, keeps device sync behind the paywall, so no free product delivers a 70.3 plan to any watch, let alone natively."

### M2. The Saddlemark characterization contradicts the spec's own retention design

Section 1: "Saddlemark by itself is a few-times-a-year utility with no comeback loop." The spec's section 6 step 10 is literally titled "Come back loop": change windows with ride 1 and ride 3 re-checks, a monthly drift check, Pack and Rebuild Check around travel, all driven by a notification scheduler. The honest version of the argument is that Saddlemark's loop is deliberately low frequency (the spec caps notifications at two a month), not that it lacks one. The overclaim matters because it is the first premise of the lead recommendation.

Fix, section 1: replace the sentence with "Saddlemark by itself is a deliberately low-frequency instrument: its spec caps the comeback loop at two notifications a month and its core trigger events (a changed part, a rebuilt bike) arrive a few times a year, on top of an unbuilt computer vision core with a week 2 kill decision."

### M3. The cut order sacrifices the stated flagship first

Sections 2, 5, 7. Section 2 calls 70.3 "the flagship wedge"; the verdict rests the structural-hole argument on the first 70.3 being the highest-intent moment; yet the cut order's first cut is "70.3 moves to 1.1." If weeks slip, 1.0 launches as a Sprint and Olympic app against Garmin Coach, which is free and reportedly covers up to Olympic (the synthesis's own Q7 flags that this is a forum report). The document never admits that the slippage product has materially weaker positioning.

Fix, section 5, cut order: replace "Cut order if slipping: 70.3 moves to 1.1 first, then CloudKit sync, then adaptation depth." with "Cut order if slipping: adaptation depth first (the explanation line stays, the rules shrink), then 70.3 to 1.1. Cutting 70.3 is a positioning cut, not just a scope cut: without it 1.0 overlaps free Garmin Coach's reported Sprint to Olympic range, so if 70.3 is cut, launch messaging shifts to pool swims and race day on the watch, and 70.3 ships in the first update. Never cut the explanation line or the phone player."

### M4. The 1.1 merge of Saddlemark collides with the Saddlemark spec's hard promises and is unbudgeted

Section 2 (bike fit paragraph) and section 6 Q8. The synthesis folds the reviewed spec in as "the 1.1 marquee update" without touching the collisions:

- Privacy: the spec promises "no network calls", "Nothing is uploaded", a camera purpose string ending "Video never leaves your device", and a pain tag that "stays on the phone". The tri app (even with B1 fixed) contemplates CloudKit sync and a 1.1 write-only Strava upload. A merged app must exclude every fit artifact (joint tracks, pain tags, Setup Cards) from sync and upload, or the spec's promises and purpose strings are false.
- Data model: the spec defines SwiftData entities Rider, Bike, SetupCard, Capture, JointTrack, NoiseEstimate, Change. The tri app necessarily has its own Bike (bike leg zones, "bike service due" notifications) and athlete profile. Two Bike entities in one app is a migration and UX bug factory; one shared Bike must own both the fit Setup Card and the training config.
- Notifications: the spec's scheduler enforces "at most two a month, quiet hours respected". The tri app schedules Monday preview, Sunday recap, and a T minus 21 race window burst. An app-wide two-a-month cap is impossible in the merged app; a per-module budget inside one shared scheduler must replace it, and the spec's cap language must be rescoped to the fit module.
- Identity: the spec carries its own first-launch acknowledgement, bundle id com.akkikens.saddlemark, own privacy policy and site. As a module these become first-use-of-module screens and the standalone collateral is dropped.
- Effort: the spec is a 12-week standalone build. "Becomes the 1.1 marquee update" silently assumes the merge costs less than that; nothing in the synthesis budgets it.

Fix, section 2, end of the bike fit paragraph, add: "Merging is real work, not a drop-in: one shared Bike entity owns both the Setup Card and training config; fit artifacts (joint tracks, pain tags, Setup Cards) are excluded from any sync or Strava upload so the spec's on-device promises stay true; the spec's two-notifications-a-month cap becomes a per-module budget inside the app's one scheduler; and the spec's first-launch acknowledgement moves to first use of the fit module. Budget the 1.1 module at most of the spec's original 12 weeks, minus the shared capture-free parts."

### M5. The Runna cofounder quote is load-bearing and unverified

Section 7 (verdict): "Runna's own cofounder said they skipped tri because it is complicated." This carries the whole answer to the biggest competitive risk (Strava shipping Runna tri plans). A search today found no such quote from Ben Parker or Dom Maskell; coverage describes Runna's focus as the everyday runner and nothing more specific about triathlon.

Fix: either attach the primary source (interview or podcast URL with the quote) to the sourced notes, or replace the clause with "and Runna has to date chosen not to build swim and bike coaching, which is a materially harder product than running plans." If the quote cannot be sourced, it must not survive to any document Akshay acts on.

## Minors

### m1. "24-hour action windows cited in rejections" overstates the written guideline

Section 3. The live guideline 1.2 text (checked today) requires "a mechanism to report offensive content and timely responses to concerns"; no 24-hour window appears anywhere in the current guidelines. The 24-hour figure comes from Apple developer communications and reviewer correspondence, not the written rule.

Fix: replace "with 24-hour action windows cited in rejections" with "the written rule says only 'timely responses', and Apple communications and reviewer correspondence have cited 24-hour expectations".

### m2. "The scheduler's 7-day window" misnames a display window as a scheduler limit

Section 2. Per WWDC23, the Watch Workout app shows the user workouts scheduled in the next seven days and the previous seven; Apple documents no 7-day cap on how far ahead schedule(_:at:) may be called, and the maximum scheduled count is undocumented (a developer forum thread asks about a 50 limit, unanswered). The weekly-cadence conclusion still holds, but the week 1 spike should test the real unknowns.

Fix: replace "the scheduler's 7-day window makes weekly the honest cadence" with "the Watch surfaces only the coming 7 days of scheduled workouts, which makes weekly the honest cadence; the true scheduling horizon and the maximum scheduled count are undocumented and belong to the week 1 spike".

### m3. Rebuild check is claimed twice

Section 2. "Bundled with race-first's rebuild check for traveled bikes" presents as new something the Saddlemark spec already ships in its own 1.0 ("Pack and Rebuild Check", spec sections 6 and 7). The merged 1.1 must have one rebuild check, not a race-first one plus a Saddlemark one.

Fix: replace with "bundled with the spec's own Pack and Rebuild Check, which race-first's race window then triggers automatically around typed travel dates".

### m4. "Sequencing it second loses nothing" is too strong

Section 2. Sequencing Saddlemark second loses at least: the freshness of its name clearance (checked 2026-11-03; a year stale by a post-tri-launch start), its competitor pricing snapshot, and a year of the category staying uncrowded (its own risk register calls thin entrants "certain").

Fix: replace "so sequencing it second loses nothing" with "so sequencing it second costs only time-sensitive collateral: rerun the name clearance and pricing snapshot before the 1.1 build, and accept the category gets a year more crowded".

### m5. Runna build-cost figures drift from the reporting

Section 7. Press coverage puts Runna at roughly 150 employees at acquisition (Sifted; LBC says a little under 150; Engadget says 180) and about 8 million GBP raised (UKTech News says around 10 million; aggregators 9.5 to 10.3 million USD). "More than 120 people and over 8 million GBP" is defensible but reads as precision it does not have, and the acquisition price was undisclosed.

Fix: replace with "was built by a team reported around 150 people on roughly 8 to 10 million GBP raised".

### m6. "Just lost its Ironman partnership" is stale and misassigns the actor

Section 7. TriDot itself terminated the Ironman partnership, citing unresolved business matters, in early August 2025, fifteen months before this document. "Just lost" is wrong on both counts.

Fix: replace "and just lost its Ironman partnership" with "and walked away from its Ironman partnership in August 2025".

### m7. The under-450 ratings claim needs its roster and date to stay auditable

Sections 1 and 7. Checked today it holds, barely: MOTTIV 71, TriDot 34 plus Legacy TriDot 263, Athletica 41, Humango 21 totals 430. TriDot's two listings are not enumerated in the verdict, and 430 of 450 leaves no drift room.

Fix, section 7: after "the tri-specific field is tiny and paywalled" insert "(as of 2026-11-06: MOTTIV 71, TriDot 34 plus its legacy app 263, Athletica 41, Humango 21, totalling about 430 US ratings)" and change section 1's "under 450" to "about 430 as of 2026-11-06".

### m8. Point-in-time App Store numbers lack as-of dates

Sections 1 and 7. Runna 35,585, TrainingPeaks 12,770 and Strava 380,000 US ratings reverified today (35,585, 12,770, 380,480); Zwift 21,480 and TrainerRoad 21,439 were not reverified. The Saddlemark spec dates every such number; the synthesis dates none.

Fix: append "(US storefront, 2026-11-06)" to the first ratings figure in section 7 and state once that all ratings counts are that date's iTunes Search API values.

### m9. The AGPL paragraph states the FSF position as settled law and misses a stronger argument

Section 4. "The FSF treats linking as derivative" is the FSF's interpretation, untested in court, and should be labeled as such even while being the right planning assumption. The paragraph also omits the decisive point: the FSF holds that App Store distribution terms are incompatible with GPL and AGPL (the VLC takedown precedent), so shipping openGym-derived code in any App Store app is a problem even if the app itself were open sourced.

Fix: replace "since the FSF treats linking as derivative" with "since the FSF's position, the right planning assumption even though courts have not settled it, treats the linked whole as one work; and App Store distribution terms are themselves held incompatible with the AGPL (the VLC precedent), so no amount of open sourcing the new app makes openGym reuse safe there".

### m10. "USPTO TESS" names a retired system

Section 6, Q4. TESS was retired in late 2023 and replaced by the USPTO's Trademark Search (tmsearch.uspto.gov). The Saddlemark spec says "USPTO" generically; the synthesis should match.

Fix: replace "clear USPTO TESS" with "clear USPTO Trademark Search (tmsearch.uspto.gov; TESS is retired)".

### m11. "12 to 16 solo weeks" does not match the enumerated schedule

Section 5. The listed plan runs through week 16 (and skips a week: "Weeks 12 to 14" is followed by "Weeks 15 to 16"). No 12-week path is defined; 12 is only reachable through the cut list, which the heading hides.

Fix: retitle section 5 "Build shape, 16 solo weeks planned, 12 to 14 with the cut list exercised", and change "Weeks 15 to 16" to "Weeks 14 to 16: buffer, Fable end-to-end review, fixes, Akshay's go, submit."

## Verified and standing

To keep the re-edit honest, these disputed-looking claims checked out today and need no change: Strava announced the Runna acquisition 2025-04-17; the Strava plus Runna bundle is 149.99 USD per year (annual only, launched July 2025); Runna's US ratings count is exactly 35,585 today; TrainingPeaks 12,770 and Strava 380,480 match; pool swim custom workouts with the new distance-and-time goal type are real watchOS 11 WorkoutKit features and SwimBikeRunWorkout is real WWDC23 API; Chorus shut down roughly eight months after launch in early 2018; TSS, IF and NP carry registered trademark notices on TrainingPeaks' own glossary ("developed and are owned by TrainingPeaks"), so the original-names rule is correct; guideline 1.2's filtering, reporting, blocking and published-contact requirements are quoted accurately; Supabase Pro at 25 USD per month is correct; and Apple's collected definition does turn on transmission off device, so the public-database point in section 3 stands.
