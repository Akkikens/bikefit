# Completeness critic: on device iPhone bike fit spec

Date 2026-11-03. Read: synthesis.md and all six research-*.md notes in full; angle*.md files only grepped for name lists and scorecard figures. Method for the name check: iTunes Search API on five storefronts (US, GB, DE, AU, JP), the USPTO trademark search UI (tmsearch.uspto.gov) driven in the browser with RETUL as a positive control, and TMview (tmdn.org, maintained by EUIPO and covering EUIPO, USPTO, WIPO and national offices) with ZWIFT as a positive control. EUIPO eSearch plus itself returned zero trade marks for every query including the ZWIFT control over an anonymous session (its ctmsearch backend answered total 0), so EUIPO coverage below comes through TMview. DNS A record lookups for .com and .app. The shared web search budget was already exhausted when this review started, so no general web or company name search was possible; that gap is stated per name. Nothing here is legal advice.

## 1. Coverage against the required sections

| Required section | State in synthesis.md | Verdict |
|---|---|---|
| Intent and why | Section 1 | Present, but the "why" rests on scorecard sums (145, 144, 142, 140, 123, 111) that are not in the notes folder; see 4.1 |
| Target users and jobs | Scattered in 1, 7, 12 | Weak: no persona, no jobs list, no statement of who the day one user is (road enthusiast with a trainer, not a triathlete) |
| Fit protocol | Section 3 | Present and specific |
| On device CV pipeline | Sections 3 and 4 | Partial: no stroke segmentation method, no crank phase source, no confidence and error bar math; see 2.2 |
| Recommendations and safe phrasing | Sections 4 and 5 | Present; knee card logic has a bias problem; see 2.4 and 5.1 |
| User flow | Sections 6 and 7 | Partial: no screen by screen flow, no first run, no permission moment, no failure paths |
| MVP scope and non goals | Section 6 | Present |
| Monetization with free now | Section 9 | Present; the price anchor mixes a one time unlock with an annual subscription benchmark |
| Data and privacy | Sections 5 and 6 | Partial: no privacy policy text, no purpose string, no deletion story for joint tracks, no statement on crash logs |
| Accuracy validation vs Retul | Section 10 | Present but underpowered; see 2.6 |
| Risks and open questions | Section 11 | Present as questions; no risk register with likelihood, impact and mitigation |
| Build plan | "Cap the build at 10 to 12 weeks" | Missing: no week by week plan, no milestone that gates the kill criteria, no test plan |
| Go or no go with numbers | Section 12 | Present; one arithmetic contradiction; see 5.5 |

## 2. What is still missing or weak

### 2.1 Target users and jobs
- No persona. The research gives two populations (triathletes 0.6 to 1.2 million, enthusiast drop bar riders 9 to 18 million) and the synthesis picks road first, but never says who installs the app on day one, what they own (trainer, tripod), and what job they hire it for. Write three jobs: "I changed something and want to know what moved", "I rebuilt the bike after travel", "I want a starting saddle height before I pay for a fit".
- The single most important unknown in research-market.md ("the share of enthusiasts who will film themselves on a trainer") has no plan beyond "a Slowtwitch or r/triathlon poll". Give it a number to beat and a date.

### 2.2 CV pipeline
- Stroke segmentation is unspecified. Vision has no pedal, crank or foot keypoint (research-apple-cv.md section 1, research-protocol.md section 4). The synthesis says "per stroke" and "most extended frame" without saying how a stroke is found. State it: ankle keypoint vertical track, peak detection, cycle = ankle minimum to minimum, with a cadence sanity check (60 to 110 rpm) and a rejection rule when the ankle track is lost behind the chainring.
- "Most extended frame" is maximum knee extension (MKE), which occurs when the crank is parallel to the seat tube, about 15 to 18 crank degrees before BDC (research-protocol.md section 3, Millour 2019). Knee flexion at BDC is about 3 degrees more flexed than at MKE (38 vs 35, n = 26). The synthesis compares an MKE measurement against ranges that are partly BDC ranges (Swart and Holliday 2019 is "at the bottom dead center crank position"). Pick one frame and one range and say so on the Methods screen.
- Confidence and error bars: the spec needs the formula. Proposal: per metric, report median across clean cycles, interquartile range, and the rider's re-placement noise; show a change only when |delta| exceeds the minimal detectable change, MDC = 1.96 x sqrt(2) x SEM, not the raw A minus B difference. With a raw A minus B difference the day one "noise" is a single draw and will be too small about half the time.
- Day one re-placement noise is within session noise. Between session noise (clothing, warm up state, trainer reposition, lighting, a different day) is larger; the only markerless test retest figures in the notes are Horsak 2024 OpenCap, SEM 2.2 degrees and MDC 6.0 degrees across sessions (research-apple-cv.md section 6). The spec should grow the noise estimate from the first three checks and say so, otherwise "drift" will over flag.
- Landmark bias: Vision keypoints are joint centres learned from photo annotations, not the greater trochanter, lateral condyle and lateral malleolus that fitters mark. Slowtwitch notes a 2 degree knee difference just between F.I.S.T. and Retul landmark conventions (research-protocol.md section 4). The spec never states that the absolute numbers carry an unknown landmark offset on top of the 4 to 8 degree model error.
- Pinned revision: VNDetectHumanBodyPoseRequest has only Revision1 since iOS 14 and the 3D request has only one revision (research-apple-cv.md sections 1 and 2). Pinning the revision therefore guarantees nothing about model drift across iOS releases; open question 9 is the real control and should become a release gate (same clip, two iOS versions, delta under 1 degree).
- No processing time budget. Apple publishes no ms figures (research-apple-cv.md section 8). Set a target (a 20 second 1080p60 clip processed in under 60 seconds on an A15) and a fallback (drop to every second frame).
- Thermal and storage: 1080p60 for 20 seconds plus per frame Vision on an iPhone 11 class device is not discussed. iOS 17 runs on iPhone XS and XR (A12). Say which devices are tested.
- The Photos import path: a PHPicker video has no CoreMotion data, unknown lens and unknown stabilization. The synthesis labels it "placement not verified" but does not say that ultra wide or stabilized clips should be refused or flagged (stabilization warps intrinsics, research-apple-cv.md section 5).

### 2.3 Fit protocol gaps
- Camera height: synthesis says top tube height; MyVeloFit says saddle height (0.9 to 1.1 m), BikeFit AI says hub height, Bike Fast Fit says top tube (research-protocol.md section 1). Any is defensible; the spec should pick one, store it per bike, and make the ghost outline enforce it, because changing camera height between captures is itself a perspective change.
- Effort labelling: "usual training effort" is unmeasured. Holliday 2023 reports knee extension rises 6 to 9 percent and elbow flexion 39 percent from 60 to 90 percent HRmax (research-fit-science.md section 3.3). Without a power or heart rate number the compare view cannot tell drift from a harder day. At minimum store a self reported RPE 1 to 10 and refuse comparison when RPE differs by more than 2; optionally read trainer power from a BLE power meter in 1.1 (that is not a network call).
- Hand position and clothing are stored, good, but shoe and pedal system are not. A shoe change moves the ankle keypoint and the effective leg length.
- Crank length is in the Setup Card but not used by the capture; a crank change invalidates the reference and should force a new one.
- The "12 clean cycles or 20 seconds" rule and the "fewer than 8 clean cycles: no numbers" rule are not reconciled with the 90 percent per cycle confidence threshold; give the thresholds numeric values (point confidence above 0.3 on hip, knee, ankle) and say what happens between 8 and 12.

### 2.4 Recommendations
- The knee card fires when median plus or minus re-placement noise lies outside 30 to 40. That ignores the 4 to 8 degree systematic error (Bini 2023) and the landmark offset. A rider truly at 36 can read 29 and be told to lower the saddle. Either widen the firing band by the published bias (fire only outside about 24 to 46, which almost never fires, and say so honestly), or reframe the card as "your reading is low for the published range; if the saddle feels high, try 5 mm lower and re-measure", and never use the word "lower" as an instruction.
- The 5 mm step cap and the "5 mm must be detectable" kill criterion are in tension. The notes contain no measured degrees per 5 mm figure (open question 3). Bike Fast Fit reports 2 to 5 mm capture to capture noise (research-protocol.md section 8), which suggests 5 mm is at the noise floor of phone video. Consider 10 mm as the detectability test and keep 5 mm as the step.
- Intensity dependent ranges are cited (Swart and Holliday 2019: 33 to 43 low intensity, 30 to 40 high) but the card uses 30 to 40 regardless of effort.
- The "Tape it?" flow needs the safety copy from research-risk.md section 10: mark the old position, one change per session, torque, ride before the next change, stop if pain. None of it is in section 6's scope list.
- Missing from scope entirely: the onboarding acknowledgement (research-risk.md section 8, item 1) and the "check with a doctor" reminder that Guideline 1.4.1 asks for. The pain tag covers riders who declare pain; it does not cover first run.
- Race legality toggles (UCI road, UCI TT 50 mm, World Triathlon non drafting, extension tips vs front wheel) are recommended in research-risk.md section 9 and appear in neither scope nor non goals. Decide and write it down.
- Sex specific guidance: Wilber 1995, Gaither 2018, Olewinski 2026 (research-fit-science.md section 7) are in the notes; the synthesis never says the ranges are from male cohorts (Holliday 2021 is 50 men). Say so on the Methods screen.

### 2.5 User flow
- No first run flow: trigger picker, bike creation, Setup Card, camera permission moment (the HIG says ask at first capture, research-risk.md section 1), tripod placement guide, noise floor capture A and B, result, re-placement explanation.
- No failure paths: retake screens are mentioned, but not what happens after three failed retakes, or when the phone falls over mid capture, or when two people are in frame.
- No notification copy or scheduling rules (how many per month, quiet hours, what cancels them).
- No shareable image spec (what numbers it shows, that it carries the error band, that it has no traffic light).

### 2.6 Validation plan
- n = 3 to 5 riders cannot establish "knee mean absolute difference under 5 degrees" with any confidence; with an SD of about 4 degrees the 95 percent interval on the mean difference is about plus or minus 4 degrees at n = 5. Either state the plan as a smoke test, not validation, or budget for n = 10 (open question count says bias is only stated until n reaches 10, which is the right instinct; apply it to the headline too).
- Retul samples at 18 Hz (Branco 2022) and the fitter captures at several wattages; the plan must match effort and time window, and Retul's LED harness and straps change the rider's silhouette, so the Vision side should be captured both with and without the harness.
- "Map Retul's max knee extension to flexion from straight" is unnecessary: Retul already reports extension as flexion from straight (37 plus or minus 3, BikeRadar; 30 to 40, CX Magazine; research-protocol.md section 9). Compare directly.
- There is no plan to validate the yaw gate against a protractor, the tilt gate against a level, or the ghost outline against tape measured camera position. Those are cheaper than Retul and gate the kill criteria.
- Week 1 bench says "10 captures over 5 sessions". With one rider on one bike this measures Akshay's noise, not the product's. Add at least one rider on a different bike type and one with loose clothing before the kill decision.

### 2.7 Data and privacy
- No privacy policy text, purpose string, or support page copy. research-risk.md section 1 has a draft purpose string; adopt it.
- Joint tracks are stored and video is deleted after processing: say where (SwiftData in the app container, not the Photos library), whether iTunes or Finder backup includes them, and how the user deletes everything.
- Crash logs: the plan relies on Apple's opt in (research-risk.md section 2). Write that down as the reason the label stays Data Not Collected.
- Pain tag text is health adjacent data. Keep it local, never in a shareable image, never in a fitter hand off card without an explicit tap.
- Local notifications are fine but the spec should say the app never registers for remote notifications (no APNs token, no server).

### 2.8 Build plan
- Missing entirely. The synthesis says 10 to 12 weeks and lists kill criteria but never sequences them. Minimum: week 1 to 2 capture and Vision pipeline spike plus the bench; kill decision end of week 2; weeks 3 to 6 data model, Setup Card, noise floor, compare; weeks 7 to 8 cards, notifications, Methods; week 9 Retul comparison and copy; weeks 10 to 12 polish, screenshots, Fable review, submission. Include the unit test rule from CLAUDE.md (no fatalError in tested paths) and the named simulator.

### 2.9 Go or no go
- The verdict is clear and the numbers are present, but it should state the decision rule that turns the bench into a go: for example "re-placement noise under 3 degrees on knee flexion and a 10 mm saddle change detected in 8 of 10 trials, by end of week 2, or stop".

## 3. Claims that lack a source

1. "1 to 3 degree repeatability" for single camera markerless pose on cyclists (synthesis section 1). The 1 to 3 degree figures in the notes are Retul and 3D system SEM values (Scoz 2021, Branco 2022) and Vicon intra session error (Corbett 2014, 1.7 degrees). No note contains a test retest figure for OpenPose, MediaPipe or Apple Vision on a bicycle. The closest is Horsak 2024 OpenCap walking, SEM 2.2 and MDC 6.0.
2. "Four of six lists" for Saddlemark and "three lists" for Kneeline (synthesis section 8). Grep of the six angle files finds Saddlemark in two (angle-1, angle-4) and Kneeline in two (angle-2, angle-4). If the other mentions were in the scorecards, those files are not in the folder.
3. The three scorecards and their sums (145, 144, 142, 140, 123, 111) are referenced but not present; the choice of direction cannot be audited from the notes.
4. "Typical phone error is 4 to 8 degrees" is sourced to Bini 2023 (OpenPose), but the only Apple Vision data point in all the notes is zero; no peer reviewed validation of Vision body pose against mocap was found (research-apple-cv.md section 7). The spec should say the figure is borrowed from OpenPose.
5. "Vision has no pedal, bottom bracket or bar landmark" is correct, but the synthesis also says the yaw hint from cameraOriginMatrix "tracks a protractor" only if the bench shows it; fine. What lacks a source is the implied claim that the 3D request works on a seated, bent over cyclist at all; Apple names bent over subjects as degraded for the 2D request and says nothing about the 3D request on cyclists.
6. "TT pass rate under about 70 percent" and "re-placement noise above 3 degrees" as kill lines have no derivation. Tie them to something: 3 degrees is about the Retul between day SEM (Branco 2022, under 3 degrees), which is a defensible bar; say so.
7. "Lens about top tube height, 2.5 to 3.5 m away" is a synthesis of vendor guidance; fine, but the "rider at least a third of frame height" rule has no source (Apple's segmentation guidance is half the image height for person segmentation, WWDC21, which is a different request).
8. "MyVeloFit claiming 200 thousand active users" is sourced, but research-protocol.md section 6 notes the same site also shows 100K users and 250K fits on another page; quote the range.
9. Section 12's "RevenueCat Health and Fitness medians (2.9 percent download to paid, 35.64 dollars per payer in year one)" are sourced, but they are subscription app benchmarks; the synthesis prices a one time unlock, for which RevenueCat publishes no comparable RLTV. Label the estimate as borrowed.
10. "US shops 320 to 350 dollars each" for Retul is from search snippets of shop pages that returned 429 (research-competitors.md section 1); medium confidence.

## 4. Numbers that conflict between notes

1. Retul marker count: seven LED markers (research-competitors.md, BikeRadar 2010) vs eight (research-protocol.md and research-fit-science.md, Landry's and retul.com). Branco 2022 names seven sagittal landmarks. Use "eight markers" with the official page as source.
2. Dynamic knee range: Ferrer-Roca 2012 30 to 40 at MKE; Swart and Holliday 2019 30 to 40 high intensity and 33 to 43 low intensity at BDC; Millour 2019 proposes 33 to 43 at BDC; Corbett 2014 recommends 30 to 40 dynamic; Retul journalists quote 37 plus or minus 3 or 30 to 40. The synthesis table cites Ferrer-Roca and Swart together for "30 to 40" at the most extended frame, which neither paper measured in exactly that way.
3. Static vs dynamic knee offset: 8 degrees (Holliday 2021, Millour 2019, Bini and Hume 2016: 8.2) vs 5.4 degrees (Corbett 2014). Both are in the notes; the Methods screen should quote the range 5 to 8.
4. Markerless cycling error: 4 to 8 degrees hip and knee (Bini 2023, OpenPose) vs 3 to 12 degrees (Bini 2021 ISBS, research-competitors.md section 5) vs 9.3 to 10.2 degrees knee RMSE (Kakavand 2025, OpenCap). The synthesis quotes only 4 to 8.
5. Hip angle reference: Burt 55 to 65 at TDC (cited in Holliday 2021) vs Holliday 2021's own measurement of 77 plus or minus 5 in 50 trained road cyclists. Different conventions (femur to trochanter to shoulder vs hip joint to lumbar spine). The synthesis shows 55 to 65 against a knee hip shoulder included angle; if the conventions do not match, every rider will read "outside".
6. MyVeloFit camera distance: 2 to 3 m (Dec 2023 page) vs more than 3 m (Oct 2022 page); cadence 75 to 95 vs 85 to 95. research-protocol.md records both; the synthesis picks 2.5 to 3.5 m and 80 to 95 rpm without saying why.
7. UCI saddle setback: research-fit-science.md section 6 states the 5 cm minimum as the general rule (via a track site quoting the regulation); research-risk.md section 9 reads the February 2025 Clarification Guide as "behind the BB plane" for road with 50 mm retained only for TT and pursuit positions. The synthesis does not mention UCI; if a toggle is added, use the 2025 reading and confirm against UCI Part 1.
8. App Store rating total: "under 700 in a decade" (synthesis) vs the itemised list in research-market.md, which sums to 696 only when SizeMyBike (2010) is included, making the span 16 years, not a decade.
9. Pro fit reference price: 200 dollars (Iriberri 2017 global average, used for the dollar TAM) vs 320 to 350 dollars (US Retul cluster, used for the validation budget). Both are correct in context; the spec should not let a reader think they are the same number.
10. Apple default skeleton height: 1.8 m (ARBodyAnchor, Vision 3D reference) vs 1.66 m (ARSkeletonDefinition.defaultBody3D). Noted in research-apple-cv.md; irrelevant unless ARKit is used, which it is not.

## 5. Statements I believe are wrong, with the source

1. Synthesis section 1: "single camera markerless pose on cyclists carries 4 to 8 degree hip and knee error (Bini 2023) but 1 to 3 degree repeatability". The second half is not supported for single camera markerless systems; the 1 to 3 degree figures belong to Retul vs Vicon (Scoz 2021: SEM under 1 degree for knee) and Retul test retest (Branco 2022: SEM under 3 degrees). Source: research-apple-cv.md section 6, research-protocol.md section 4.
2. Synthesis section 4 table: "Knee flexion at maximum extension ... Dynamic 30 to 40 (Ferrer-Roca 2012; Swart and Holliday 2019)". Swart and Holliday 2019 give 30 to 40 at high intensity and 33 to 43 at low intensity, at BDC, not at maximum extension. Source: research-fit-science.md section 3.1 (PubMed 31834181).
3. Synthesis section 10: "map Retul's max knee extension to flexion from straight". Retul's extension figure is already flexion from straight (37 plus or minus 3, BikeRadar review; 30 to 40, CX Magazine). No mapping is needed; applying one would double count. Source: research-protocol.md section 9.
4. Synthesis section 12: "MyVeloFit claiming 200 thousand active users after five years". MyVeloFit was founded in 2020, so by late 2026 it is six years; and the claim is "200k active users" on the home page but "over 200,000 riders have used the platform" in the Speed Skating Canada release, which is cumulative, not active. Source: research-competitors.md section 2.
5. Synthesis section 12: "10 to 52 thousand dollars in year one ... That sits below the 1,000 dollars a month bar 83 percent of new apps never reach". 52 thousand a year is 4,300 a month; only the low end (10 thousand a year, 830 a month) sits below the bar. The sentence should say the low case misses the bar and the median case clears it. Source: the synthesis's own numbers and research-market.md section 6 (17.3 percent reach 1K per month within two years).
6. Synthesis section 3: "pinned Vision revision" presented as a repeatability control. Both body pose requests have a single revision, so pinning cannot prevent output changes between iOS versions. Source: research-apple-cv.md sections 1 and 2 (developer.apple.com, VNDetectHumanBodyPoseRequestRevision1 only; WWDC21 "body pose still revision 1 only").
7. Synthesis section 6 lists "Health and Fitness category" together with "no HealthKit"; that is fine, but section 5 says the pain tag "keeps it outside EU MDR and inside FDA general wellness". The FDA 2026 wellness guidance excludes products whose UI includes "alerts, alarms, or prompts that recommend or require specific clinical action". A fixed line saying "see a bike fitter or clinician" is a prompt toward a clinician; it is almost certainly fine, but it is not what keeps the app in the wellness category. What keeps it there is the absence of disease and injury claims. Reword so the causal claim is right. Source: research-risk.md section 3 (FDA General Wellness policy, January 6, 2026).
8. Synthesis section 8: "Saddlemark ... no App Store hit in web search". There is also a dead USPTO application (serial 87565078, SADDLEMARK, class 27 cowhide rugs, filed 2017-08-11, expressly abandoned 2017-12-28, owner Saddlemark LLC, West Palm Beach). Dead and in an unrelated class, so not a blocker, but "unchecked" was the accurate word. Source: tmsearch.uspto.gov, checked 2026-11-03.
9. Synthesis section 8: "Holdline (check telecom products)". The live collision is not telecom; it is HoldLINE Calisthenics, a Health and Fitness app on the US, GB, DE, AU and JP storefronts (bundle fit.holdline.app), plus a registered Brazilian mark in class 38. Source: iTunes Search API and TMview, 2026-11-03.

## 6. Name collision check (2026-11-03)

Searches: iTunes Search API (US, GB, DE, AU, JP), USPTO wordmark search (contains), TMview (contains; EUIPO, USPTO, WIPO and national offices), DNS A record for .com and .app. "Free" below means no exact or confusingly close hit in classes 9 or 42 and no same category app; it is not a clearance opinion.

| Name | App Store (5 storefronts) | USPTO | TMview incl. EUIPO | Domains | Verdict |
|---|---|---|---|---|---|
| Saddlemark | No app with this name; results are equestrian tack shops and one "Saddle Adjust" cycling app | One dead application, class 27 rugs, abandoned 2017 | Same dead US record; a pending EUTM "Saddle.Market" (EQUIRODI SAS, classes 18, 35, 42, filed 2026-07-01, equestrian marketplace) | saddlemark.com and .app: no A record | Looks free for an app in class 9 and 42. Note the Saddle.Market EUTM shares class 42 and the equestrian flavour of search results; a reader may expect a horse app. First choice still. |
| Kneeline | No app with this name; results are knee rehab and Medical category apps | Only NELINE, 1950 hosiery, dead | Same | kneeline.com has an A record (taken); .app free | Free as a mark, but App Store search neighbourhood is medical (ACL, physio, braces), which pulls against the Guideline 1.4.1 framing. Second choice at best. |
| Samefit | No app with this name; results are generic gym apps | None | None for "samefit"; "same fit" returns only unrelated slogans and Transamerica Fit | samefit.com has an A record (taken); .app free | Free as a mark. Weak for search (drowned by "fit" apps) and the .com is taken. |
| Pedalmark | No app with this name; results are bike GPS and guitar pedal apps | None | Only PedalMarket.cl (Chile, classes 35 and 38) | pedalmark.com and .app: no A record | Free; the cleanest result of the ten. Reads as cycling, no medical adjacency, both domains unregistered at DNS level. Promote to second. |
| Driftmark | "Tic Tac Toe: Driftmark" (Games) on US, GB, DE, AU, JP | None | None | driftmark.com and .app have A records (taken) | Mark free; name already used by a game on every storefront and domains gone. Drop or keep as third. |
| Holdline | HoldLINE Calisthenics (Health and Fitness) on all five storefronts; two Hold Line games | None | Registered Brazilian mark class 38 (Holdline Tecnologia), expired German mark | Both taken | Drop: same category app collision. |
| Reseat | ReSeat and RESEAT ENTERPRISE (Business) on all storefronts | RESEAT, INC. registered in classes 35 and 37 (serials 90896332, 97490678, 97490459) | 41 marks incl. EUTM 019120455 (NEXTCHEM, class 20) and WIPO 1708032 | Not checked | Drop. |
| Setline | Setline (Music), Setline Pro (Lifestyle) | Not run | SETLINE registered in classes 9 and 42 (KEP Technologies International SA: UK, Switzerland, WIPO 1422582) | Not checked | Drop: direct class 9 and 42 collision. |
| Fitkeep | FitKeeper (Health and Fitness, FITKEEPER APPS SL) on US, GB, DE | Not run | FITKEEP US class 9 application (Fitkeep LLC, 2023, ended); FitKeeper EUTM 016168809 and UK mark in class 9 (registered); 21 marks total | Not checked | Drop: same category app plus registered class 9 marks. |
| Plumbline | Plumbline: Posture Reminder (Health and Fitness), Plumbline Studio level tool, Plumbline Golf, others on every storefront | Not run | 38 marks incl. a 2026 Benelux filing in classes 35, 41, 42 | Not checked | Drop. |

Not done because the web search budget was exhausted: general web and company registry search for Saddlemark, Pedalmark, Samefit and Kneeline (for example a Saddlemark LLC exists in Florida from the abandoned filing, a rug company), social handles, and Apple Search Ads popularity. Also not done: USPTO design search and phonetic variants (Sadlemark, Pedalmarq), and national offices outside TMview coverage. Before committing: re-run Saddlemark and Pedalmark through a lawyer's knockout search or at least the USPTO advanced search with class filters 009 and 042, register the .app and .com, and check the handle on the two forums that matter (Slowtwitch, TrainerRoad).

## 7. Priority fixes before the spec is final

1. Fix the three factual slips that would embarrass the Methods screen: the "1 to 3 degree repeatability" attribution, the Swart and Holliday frame (BDC, intensity dependent), and the Retul extension mapping.
2. Specify the pipeline math: stroke segmentation from the ankle track, MKE frame definition, MDC based change detection, between session noise growth.
3. Reframe the knee card so it cannot issue a directive from a measurement whose systematic error is nearly as wide as the window; or widen the firing band and accept that it rarely fires.
4. Add the missing sections: personas and jobs, screen flow with permission moment and failure paths, privacy policy and purpose string, onboarding acknowledgement and "stop if pain" copy, a week by week build plan with the kill decision at the end of week 2, and a decision on race legality toggles.
5. Resize the validation plan: call n = 3 to 5 a smoke test, plan for n = 10 before any public accuracy page, and add the cheap gate validations (yaw vs protractor, tilt vs level, ghost outline vs tape).
6. Correct the verdict arithmetic (52K a year clears the 1K a month bar) and label the RevenueCat figures as subscription benchmarks applied to a one time unlock.
7. Names: keep Saddlemark first, move Pedalmark to second, drop Holdline, Reseat, Setline, Fitkeep and Plumbline on the evidence above; finish the web and registry search when the budget resets.
