# Synthesis: one direction for the on device bike fit app

Date 2026-11-03. Inputs: six concepts, three scorecards, six research summaries. Where a concept and the research disagree, the research wins.

## 1. The chosen direction

**Build a fit record and drift instrument, not a fitter.** The rider records where their body sits when the position is trusted (a side view reference capture plus a tape measured Setup Card per bike), measures their own re-placement noise on day one, and every later capture is a diff against that reference, judged against that noise. The one absolute output is a saddle height starting point from dynamic knee flexion, because saddle height is the only fit variable with an evidence base; everything else is a trend against the rider's own reference.

Why: the judges picked three different winners but all three said mvp-first, retention-first and contrarian are one product seen from three sides, and the sums agree (145, 144, 142, 140 against 123 and 111). The accuracy evidence demands a differential design: single camera markerless pose on cyclists carries 4 to 8 degree hip and knee error (Bini 2023) but 1 to 3 degree repeatability. Free plus on device is table stakes (BikeFit AI has both), so the listing leads with reference, drift and noise floor, never with angles.

Triathlete-first is not 1.0: the hold test and the Build, Sharpen, Lock calendar are the best ideas on the panel, but on an unproven instrument they make a 16 week plan, and the aero tuck is Apple's named degraded case. Both wait for 1.1, built only if the bench shows TT captures pass the gates.

## 2. Grafted from each runner up

- **mvp-first**: the capture stack (2D Vision only, confidence gating, cycle segmentation, refuse and name the failing joint, median plus spread), Photos import, Pack and Rebuild Check, pinned Vision revision, validation week with a kill criterion.
- **contrarian**: Lock, Check, Carry (Carry in 1.1), the tape notebook, "Tape it?" instead of a degrees to millimetre conversion, joint tracks only, fitter hand off card, alignment score before recording.
- **retention-first**: trigger picker on first launch, change window at ride 1 and ride 3, "nothing moved" as a first class result, Setup Card with photo, ghost outline, stricter TT gate.
- **science-first**: recommend only when the whole noise band is outside the window, 5 mm cap with forced re-measure, "No change supported by this measurement", explicit refusals, no traffic lights, Methods screen with n and error figures.
- **triathlete-first**: saved tripod spot overlay, pain tag that suppresses advice for that region, one change per session; hold test and race calendar in 1.1.
- **business-first**: capture quality grade, public accuracy page that publishes disagreements, tilt gate. Its millimetre prescriptions for setback, reach and drop are rejected: Vision has no pedal, bottom bracket or bar landmark, and KOPS has no biomechanical basis.

## 3. Capture protocol

- Trainer, axles level, 10 minute warm up, then 80 to 95 rpm at the rider's usual training effort, labelled and stored. Hands in the stored position (hoods, or extensions for TT and tri).
- Phone landscape on a tripod or shelf, main 1x lens, 1080p at 60 fps, stabilization off, no ultra wide. Lens about top tube height, 2.5 to 3.5 m away, perpendicular, whole bike and rider in frame, rider at least a third of frame height.
- Camera side is the rider's choice, stored per bike and kept for every later capture. Only the camera side leg is measured.
- Gates: CoreMotion pitch and roll within 2 degrees; alignment score against the ghost outline of the reference frame; joint confidence on a 5 second preview. The 3D request's cameraOriginMatrix yaw is a squareness hint, promoted to a hard gate at 20 degrees off plane only if the bench shows it tracks a protractor.
- Hands free: 10 second voice countdown, visible recording indicator (Guideline 2.5.14), record until 12 clean cycles or 20 seconds.
- Noise floor on day one: capture A, dismount, remove and re-place the phone against the ghost outline, capture B. The difference per angle is that bike's re-placement noise.
- Photos import through the picker (Guideline 5.1.1(iii)), labelled "placement not verified", never gets the knee card.
- A cycle counts when hip, knee and ankle on the camera side clear the threshold on 90 percent of its frames; upper body joints gate separately. Fewer than 8 clean cycles: no numbers, a retake screen naming the joint and the fix.

## 4. Measurements and recommendations

All angles come from VNDetectHumanBodyPoseRequest keypoints: dynamic, 2D, camera side, per stroke, median across clean cycles with spread and re-placement noise. Nothing is shown alone, coloured, or as pass or fail.

| Metric | Convention | Context shown | Role |
|---|---|---|---|
| Knee flexion at maximum extension | 180 minus the hip, knee, ankle included angle at each stroke's most extended frame | Dynamic 30 to 40 (Ferrer-Roca 2012; Swart and Holliday 2019) | Starting point card |
| Knee flexion at top | Same angle at the most flexed frame | None | Trend |
| Hip, most closed | Knee, hip, shoulder included angle at its per stroke minimum near TDC | Expert opinion only (Burt 55 to 65 road). No TT range | Trend |
| Torso | Hip to shoulder keypoint line versus horizontal | Expert opinion 30 to 45 racing up to 50 to 60 casual. No TT range | Trend |
| Elbow flexion | 180 minus the shoulder, elbow, wrist included angle | Expert opinion 20 to 30 hoods, 60 to 70 drops | Trend |
| Shoulder | Hip, shoulder, elbow included angle | None published | Trend |

- **Saddle height starting point**, the only directive. Fires only when all gates passed at the labelled effort, the median plus and minus the re-placement noise lies entirely outside 30 to 40, and no pain tag is set. Direction only (below 30 the knee is too straight, lower the saddle; above 40 raise it), capped at 5 mm, next step locked until a re-measure. Otherwise "No change supported by this measurement." Typical phone error is 4 to 8 degrees against a 10 degree window, so this is a starting point, not a verdict.
- **Everything else is a diff.** "Knee flexion at full extension is 5 degrees less than your reference, outside your re-placement noise of 2. Changes like this usually show up when the saddle sits higher. Reference saddle height 745 mm. Tape it?" No degrees to millimetre conversion until the bench measures one.
- **TT and tri**: stricter thresholds for hip, shoulder and elbow (Apple names bent over subjects as degraded); refuse rather than guess; no TT targets.

## 5. Phrasing that stays safe

- Allowed: "published fitting ranges put most riders", "within your noise", "consider", "try and re-measure", "tape it". Forbidden in app and metadata: should, fix, correct, optimal, injury, prevent, pain relief, diagnose, treat, medical grade, clinical, as accurate as a pro fit, any named condition.
- Every result card says phone video reads a few degrees differently from lab systems, which is why the app compares you with yourself; the Methods screen carries model, pinned revision, conventions, protocol, bench and Retul numbers with n, and citations including Fonda's 2.2 degree 2D bias, cited and never applied (Guideline 1.4.1).
- A pain or numbness tag shows a fixed line (see a bike fitter or clinician, do not adjust from an app), suppresses advice for that region and draws no cause. Health and Fitness category, no HealthKit, no healthcare framing (Guideline 5.1.1(ix)), no injury prevention claims, which keeps it outside EU MDR and inside FDA general wellness.

## 6. MVP scope and non goals

1.0 (iOS 17 and later, iPhone only, SwiftUI, SwiftData, no network calls): bikes with hand position; Setup Card (saddle height, setback, nose to bar, drop, crank length, pad stack and reach, photo, change log, all skippable); the capture flow above; six angles, per metric gating, quality grade, joint tracks stored, video deleted after processing; reference, check and compare views; saddle height card; "nothing moved"; change window; Pack and Rebuild Check with race date notifications; monthly drift check; fitter hand off card; shareable result image; Methods, privacy and support screens; StoreKit 2 scaffold behind an OFF flag.

Non goals: ankle, cleat, wedge, crank or saddle model advice; any millimetre from the image; setback, reach, drop or KOPS; front or rear view; asymmetry; hold test, race calendar, transfer calculator, tape diagrams, CSV, PDF (all 1.1); iCloud sync (label guidance unresolved, ask Apple first); accounts, cloud, analytics, ads, Watch, iPad, Android.

## 7. The come back loop

Session one ends with the re-placement capture, so everyone records twice on day one. Then the rider picks triggers and the app schedules only those: change window (log a change, re-check at ride 1 and ride 3, close with a before and after card); travel rebuild (Pack snapshot before boxing, Rebuild Check after, notifications the day before travel and the day after arrival when a race date is set); a gear note mentioning shoes, saddle or cleats suggests a re-check in two weeks; a quiet monthly drift check that says so when nothing moved and generates nothing; a flagged drift offers "share with your fitter". 1.1 adds season flips, the A race calendar with Build, Sharpen and Lock, and the opportunistic hold test during any aero interval. No streaks, points or badges.

## 8. Name shortlist

All unchecked beyond web search. Clear each against the App Store on five storefronts, USPTO and EUIPO in classes 9 and 42, and the domain before committing.

1. Saddlemark (four of six lists; no App Store hit in web search; first to clear)
2. Kneeline (three lists; check knee brace marks)
3. Samefit (fits the thesis exactly; unchecked)
4. Holdline (check telecom products)
5. Driftmark (new; unchecked)
6. Pedalmark (new; unchecked)
7. Reseat (dictionary word, weak for search)
8. Setline (fishing term, probable collisions)
9. Fitkeep (generic fit prefix, probable collisions)
10. Plumbline (likely collision with level apps and existing companies)

Dropped: Sagitta, Setpoint and Fitmark (existing brands), Rebase Fit (a git joke).

## 9. Monetization, gated off

StoreKit 2 built and tested behind an Info.plist flag that ships OFF, the WLSalesEnabled pattern; no Paid Apps Agreement, no IAP products, nothing enabled for now. If ever on: a one time Pro unlock (unlimited bikes, year over year history, PDF fit card, CSV export, near Bike Fast Fit Elite's 29.99 a year) with the free tier keeping two bikes and twelve months, and a later Fitter mode flag. Capture, noise floor, compare, the knee card and the Setup Card stay free forever. No ads, no analytics SDK.

## 10. Validation plan against a Retul fit

- Week 1 bench on Akshay's trainer: 10 captures over 5 sessions with the phone re-placed each time (between session noise); captures at 0, 10 and 20 degrees of yaw; saddle at reference, plus 5, minus 5 and minus 10 mm (degrees per 5 mm, and whether 5 mm clears the noise); TT captures (gate pass rate). Then three to five friends, consented, nothing leaving any phone.
- Kill criteria: re-placement noise above 3 degrees on knee flexion at maximum extension, or a 5 mm change not detectable, stops the project before listing work. TT pass rate under about 70 percent means TT ships as knee only trend and the hold test is shelved.
- Retul comparison before submission: one Retul session for Akshay plus two to four volunteers (US shops 320 to 350 dollars each, or via a fitter ally), app recording the same side simultaneously. Compare knee extension and flexion, hip closed, torso, elbow and shoulder as mean difference and SD, map Retul's max knee extension to flexion from straight, and record whether Retul's saddle height direction agrees with the knee card. Targets: knee mean absolute difference under 5 degrees, direction agreement. Publish n, means, SDs and disagreements. No bias correction in 1.0; a consistent bias is stated, not subtracted, until n reaches 10.

## 11. Top ten open questions for Akshay

1. Does Vision 2D hold hip, knee and ankle confidence on the camera side leg with the frame, crank and far leg in view, and in the aero tuck? The bench decides the TT scope.
2. What is the between session noise per angle on your trainer, and does it beat the 3 degree kill line?
3. How many degrees of knee flexion per 5 mm of saddle height? Measure before any copy hints at it.
4. Does cameraOriginMatrix yaw track a protractor well enough to be a gate?
5. Drive side or non drive side: which gives the ankle keypoint a clear view past the chainring?
6. Name clearance for Saddlemark and the next two across storefronts, USPTO, EUIPO and domains.
7. Can two or three fitters be recruited before launch for the Retul comparison and the hand off card?
8. Will App Review treat joint angles as a 1.4.1 health measurement for an individual developer account?
9. Do Vision outputs shift between iOS versions with the revision pinned? Run one clip on two versions before shipping baselines people keep for a year.
10. How many riders will film themselves on a trainer at all? A Slowtwitch or r/triathlon poll is the cheapest way to size 1.1. Also confirm whether EU Directive 2024/2853 reaches a free app from a non EU solo developer after December 2026.

## 12. Verdict on "huge potential"

Go on building it; no on "huge". Market: 0.6 to 1.2 million year round triathletes plus 9 to 18 million enthusiast drop bar riders, a people TAM of 10 to 19 million; the iPhone plus training app slice is 2.3 to 4.3 million, the triathlete only slice 180 to 430 thousand. Demonstrated demand: every dedicated bike fit app in the US App Store together has under 700 ratings in a decade, MyVeloFit claiming 200 thousand active users after five years. Realistic year one for a free app with no ad spend: 10 to 50 thousand downloads, 3 to 15 thousand MAU. If a paid tier were ever on, at RevenueCat Health and Fitness medians (2.9 percent download to paid, 35.64 dollars per payer in year one): 290 to 1,450 payers and 10 to 52 thousand dollars in year one, top quartile 22 to 110 thousand. That sits below the 1,000 dollars a month bar 83 percent of new apps never reach, and a five times upside is a 250 thousand dollar a year app, not a venture outcome.

It is a real, small, durable product that fits every constraint (free, Data Not Collected, no SDKs, honest come back loops, iPhone only). Cap the build at 10 to 12 weeks, hold the two kill criteria, and let 1.1 be earned by the bench and the first 90 days.
