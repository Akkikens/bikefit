# Saddlemark: on device bike fit for iPhone

Product spec, version 0.2, 2026-11-04. Author: Akshay Kalapgar with a Fable research and brainstorm pass (six research sweeps, six product angles, three independent review passes, 248 claims fact checked: 218 confirmed, 27 corrected, 3 unverifiable; ledger in docs/research/verification-ledger.md) and a Fable review of version 0.1 (55 confirmed findings applied). Pipeline parameters, verdict arithmetic, failure paths, notification rules, the privacy policy checklist and the test plan are in bikefit-annex.md. Working name only; see section 13. Spec only, no code yet.

## 1. Intent and the why

A professional motion capture bike fit (Retul or similar) costs 250 to 400 USD in the US, 175 to 300 GBP in the UK, 150 to 300 EUR in Germany and 300 to 760 SGD in Singapore; a manual dynamic fit runs 150 to 250 USD in the US (appendix A1 to A4). Most riders never buy one, and those who do rarely go back when something changes: a new saddle, new shoes, a bike rebuilt after a flight, a winter off the bike. Camera based tools exist. MyVeloFit (web) uploads video to its servers and sells two week or annual access (A50). Bike Fast Fit (iOS) processes on the phone but is a 9.99 to 139.99 USD a year subscription family (A49). Neither publishes a numeric accuracy figure. Internal framing only; nothing in this section is listing or site copy (5.3).

The evidence says a single phone camera measures pedaling joint angles to within roughly 4 to 8 degrees of a lab system for hip and knee (A20). That is not good enough to prescribe a fit in millimetres, but it is good enough for two honest things: a saddle height starting point from dynamic knee angle, the one fit variable with a real evidence base (A6, A7), and detecting when a rider's own position has drifted from a reference they trust, because repeat measurements on the same setup are far more consistent than absolute ones.

So Saddlemark is a fit record and drift instrument, not a robot fitter. It records where your body sits when the position is good, measures its own noise, and every later capture is a diff against that reference judged against that noise. Everything runs on the phone. Nothing is uploaded. It is free.

Why Akshay: same solo pipeline as Wingline and Duck Duck Truck (SwiftUI, no backend, Data Not Collected, StoreKit 2 behind an OFF flag, section 9), a credible on device computer vision project, and a community he is part of.

## 2. Target users and jobs

Day one user: an enthusiast road, gravel or triathlon rider who owns an indoor trainer and an iPhone, trains 50 or more days a year, and has never had a fit or had one years ago. Triathletes are the most motivated slice (TT, that is time trial, position; no fitter nearby; a race calendar) but the aero tuck is the hardest case for pose estimation (A17), so 1.0 is road first and TT bikes get trend and compare only, never the saddle height card (5.1).

Jobs, in expected order of frequency:

1. I changed something (saddle, shoes, cleats, stem, bars) and want to know what moved.
2. I rebuilt the bike after travel or a service and want to confirm it matches.
3. I want a defensible saddle height before I spend 300 USD on a fit, or because I never will.
4. I have a new bike and want my position carried over (1.1).
5. I want to show my coach or fitter what my position looks like without a visit.

Not the target: riders without a trainer (estimate layer only), children (the app states it is built for adults), riders with current pain who want treatment (routed to a doctor and a fitter), bike shops (a fitter mode is a flagged later feature).

## 3. The fit protocol

### 3.1 Three confidence levels

Every number carries one of three labels, always visible, never mixed:

- Estimate. From inseam, no bike needed. The bracket is 106 to 110 percent of inseam measured to the pedal spindle, the span between the traditional 106 to 109 percent rule and the Ferrer-Roca 2012 regression of 108.6 to 110.4 percent (A9), minus crank length to give bottom bracket (BB) centre to saddle top: about 72.9 to 76.3 cm for an 85 cm inseam and 172.5 mm cranks. The classic single number formulas (LeMond 0.883 times inseam, Hamley 109 percent) land inside this span within a few millimetres of each other (A9), but 109 percent of inseam put riders outside the 25 to 35 degree static knee range (A5) 63 to 73 percent of the time (A8), and 56 percent of well trained cyclists ride outside the 106 to 109 percent band altogether (A9), so the app shows the bracket, never a single number. Inseam is measured standing against a wall with a book pulled up firmly into the crotch, floor to book top; AR measurement is 1.1.
- Static check. One photo on the trainer at bottom dead centre. Static knee angle differs from dynamic by 5 to 8 degrees (A10, A11), so this level is for camera placement practice and frame size sanity, not for the saddle height card (the app's one recommendation, 5.1).
- Dynamic fit. Side video while pedaling. The only level that produces the saddle height card and the drift comparison.

### 3.2 Capture setup

- Indoor trainer only (rollers and outdoor riding are not supported and the placement guide says so). Axles level, bike clamped or through axle tight. 10 minute warm up, then 80 to 95 rpm at the rider's usual training effort.
- Effort and pain are logged per capture on the processing screen, before any result is shown: a 1 to 10 effort rating and one tap "Any pain or numbness while riding today?" with a region picker on Yes. Comparisons are refused when effort differs by more than 2, because knee extension rises 6 to 9 percent and elbow flexion 39 percent from 60 to 90 percent of max heart rate (A12).
- Hands in the stored position for that bike: hoods, drops, or extensions. One hand position per clip; references are scoped per bike and per hand position.
- Phone in landscape on a tripod or shelf outside the swing of the bike and clear of the flywheel, main 1x lens, 1080p at 60 fps, stabilization off, never the ultra wide. Lens at saddle height (about 1 m), 2.5 to 3.5 m away, perpendicular to the bike, whole bike and rider in frame.
- Camera side: the app recommends the side the week 1 bench shows keeps the ankle clear of the chainring; the rider can pick the other. Only the camera side leg is measured, because the far leg carries 69 to 108 percent more variability (A21).
- Clothing: tight shorts and a fitted top. Shoe and pedal system are stored on the Setup Card like saddle height, setback (how far the saddle sits behind the BB), crank length, stem and bars. Editing any Setup Card field, or logging a change, opens a change window (6, step 10): the reference is kept and the next capture is compared against it. A reference is never invalidated, only replaced by the rider.

### 3.3 Gates, checked live until recording ends

1. Level: from the CoreMotion gravity vector, camera axis within 2 degrees of horizontal and horizon within 2 degrees of level, shown as a bubble level.
2. Squareness: a ghost outline of the reference capture (first time: a generic bike outline) the live frame must align to, plus an alignment score. The 3D body pose request's camera origin transform gives a yaw hint; it becomes a hard gate at 20 degrees off plane only if the bench shows it tracks a protractor. Angles under 20 degrees out of plane change little; beyond that they read as more extended than they are (A22, A23).
3. Joint confidence: over any rolling 5 second window the live pass must show hip, knee and ankle on the camera side above the point confidence threshold (0.3 to start, tuned on the bench) in 90 percent of frames.
4. Framing: one body, no gated joint on a frame edge.

### 3.4 Recording

Hands free. The rider taps Start, which arms the capture, walks to the bike, mounts and pedals. A live pose pass on the preview (about 15 fps) checks the gates continuously and never produces a number. While armed, the live ankle track estimates cadence; outside 60 to 110 rpm the countdown holds and the voice says "pedal a little faster" or "slower". When gates and cadence hold for 5 consecutive seconds the app speaks "ready, recording in ten", counts down by voice, speaks "recording" with a visible indicator (App Review guideline 2.5.14, A32), records video only for a fixed 20 seconds (26 to 31 strokes at 80 to 95 rpm), then speaks "done, you can stop". No audio input; the app never asks for microphone access. If a gate fails during countdown or recording the app stops, names the gate by voice and re-arms once; a second failure, or 90 seconds armed without the gates holding, opens the retake screen for that gate.

Clean cycles are counted in the offline pass (4.2). Under 8: capture refused, retake screen names the joint or the cadence gate that failed most often and what to change in the setup. 8 to 11: numbers with a wider spread and a "short capture" tag, no saddle height card. 12 or more: a full capture.

### 3.5 Noise floor

The first three sessions on a bike each record twice: capture A, dismount, remove the phone, replace it against the ghost outline, capture B. From the fourth session the app records once, and asks for a pair again only when the reference is reset or camera side, tripod spot, shoe or pedal system changes. Only A and B pairs feed the noise estimate; compare results never do, because a difference the app judged to be noise cannot also define the noise. The standard error of measurement (SEM) is the square root of the sum of squared pair differences divided by 2n; the reference for each metric is the mean of the A and B medians (annex B).

### 3.6 Photos import

Existing videos come in through the system picker (no Photos permission). The app reads the QuickTime camera metadata and refuses clips from the ultra wide camera or under 20 mm equivalent focal length; clips with no camera metadata are accepted. Stabilization cannot be read from a file and the stock Camera app always stabilizes, so imports are labelled "placement and stabilization not verified", never produce the saddle height card, never feed the noise estimate, and appear in the compare view only with that label.

## 4. The on device CV pipeline

### 4.1 Pose

Apple Vision 2D body pose (`VNDetectHumanBodyPoseRequest`, iOS 14 and later, 19 joints including hips, knees and ankles, per point confidence, A13), run twice: the live pass that feeds the gates, and a per frame pass on the recorded file that produces every angle. Vision has no foot, heel or toe landmark, so ankle angle, knee over spindle and cleat position cannot be measured from it (A13); those are explicit non goals. The iOS 17 3D request is used only for its camera origin transform (yaw hint, A14); its body height is not used, because a recorded file has no depth track so the height is the 1.8 m reference on every phone, and nothing downstream needs a scale. ARKit body tracking is not used: live session only, rear camera only, no per joint confidence (A15).

### 4.2 Stroke segmentation

Vision sees no pedal or crank, so cycles come from the camera side ankle keypoint's vertical track: short confidence gaps interpolated, longer gaps split the track, a zero phase low pass filter, then local maxima (ankle at top dead centre) under a prominence and separation rule. One cycle is maximum to maximum. A cycle outside 60 to 110 rpm is dropped on its own and does not fail the capture. A cycle is clean when hip, knee and ankle each clear the confidence threshold on 90 percent of its frames and on every frame around the maximum extension frame; upper body joints gate separately so a failed shoulder does not throw away the knee. Parameters are in annex A and are fixed on the week 1 bench.

### 4.3 Angles and conventions

Each angle is computed per frame from the raw joints, then low passed with the same filter as the ankle track. The maximum extension frame is the frame of minimum filtered knee flexion within the cycle and the reported value is the filtered value there, so frame selection does not pick the noisiest frame; the same rule applies to the per cycle maximum and the hip minimum. Per capture values are the median across clean cycles with interquartile range. All angles are 2D and camera side. User copy may say "full extension", "top of the stroke" and "hip angle"; spec text uses the table names.

| Metric | Definition | Frame | Published context shown |
|---|---|---|---|
| Knee flexion at maximum extension | 180 minus the hip, knee, ankle included angle | Frame of greatest extension per cycle; Millour places it with the crank parallel to the seat tube (A16), roughly 15 to 18 crank degrees before bottom dead centre for a 72 to 75 degree seat tube (derived). The app finds it from the knee track and never needs the crank angle | 30 to 40 dynamic at maximum extension (Ferrer-Roca 2012, A7). Swart and Holliday give 30 to 40 at high intensity and 33 to 43 at low, at bottom dead centre (A6), about 3 degrees more flexed than this frame (A16) |
| Knee flexion at top | Same angle at the most flexed frame | Per cycle maximum | None, trend only |
| Hip, most closed | Knee, hip, shoulder included angle at its per cycle minimum | Near top dead centre | Expert opinion only: 55 to 65 at top dead centre on a road bike, femur to greater trochanter to shoulder (A18), the same angle as this metric apart from the trochanter versus Vision hip centre bias below. Holliday and Swart's measured 77 plus or minus 5 used an inclinometer at the hip joint alone and is not comparable (A18). Context, not a target |
| Torso | Hip to shoulder line versus horizontal | Cycle mean | Expert opinion: 30 to 45 racing, 40 to 50 fitness, 50 to 60 casual (A18) |
| Elbow flexion | 180 minus shoulder, elbow, wrist included angle | Cycle mean | Expert opinion: 20 to 30 hoods, 60 to 70 drops (A18) |
| Shoulder | Hip, shoulder, elbow included angle | Cycle mean | None published (A18) |

Known biases, printed on the Methods screen: Vision joints are learned joint centres, not the greater trochanter, lateral condyle and malleolus a fitter marks, and landmark convention alone shifts knee angle by about 2 degrees (A25). 2D video underestimates 3D knee angle by about 2.2 degrees (A10), cited and not applied. The 4 to 8 degree figure is from OpenPose on cyclists (A20); no peer reviewed validation of Apple Vision against motion capture exists. Vision does not see the foot, so ankling style moves the knee reading at the same saddle height: heel down reads straighter, toes down more bent, and a toes down rider can keep a high saddle inside the window; a fitter looks at the foot first, the app cannot. The hip, torso and elbow ranges are expert opinion with no stated cohort, the only measured reference values behind them come from 50 male road cyclists, and no range shown was derived from a female cohort (A18).

### 4.4 Error bars and change detection

Two numbers reach the rider and copy never confuses them. On a single reading, "plus or minus N" is 1.96 times the SEM. On a comparison between two captures, the app quotes the detectable change. Under three pairs the SEM floor is 2.2 degrees, the measured test retest standard error of smartphone pose across sessions (A24); from three pairs on it is the larger of the pooled SEM and 2.0 degrees, so three lucky draws cannot shrink the noise below what markerless pose has been shown to repeat. The week 2 bench SEM replaces the floor once measured.

The reference is the mean of captures A and B; a check is one capture; a change window check is the mean of the ride 1 and ride 3 captures. The noise of a difference is SEM times the square root of (1 over the reference count plus 1 over the check count). Verdicts: Matches reference under 1.96 times that noise; Possible change, measure again, between that and 2.77 times SEM (the detectable change); Changed above 2.77 times SEM, or when two consecutive checks sit beyond 1.96 times the noise on the same side. At the 2.2 degree floor the detectable change is 6 degrees. The number and its interval are always shown; the verdict is a label. With a logged change direction the test is one sided (1.64) and the copy compares the measured delta with the bench sensitivity table (annex B).

### 4.5 Performance and storage

Target: a 20 second 1080p60 clip processed in under 60 seconds on an iPhone 13 (Apple A15 chip), with an every second frame fallback on older chips. iOS 17 minimum, tested on iPhone 12 and later plus the iPhone SE (2020 and 2022). The video is deleted when processing finishes, with no exception; only joint tracks (a few hundred kilobytes), the SEM inputs and one thumbnail frame are kept in SwiftData inside the app container. The replay on the result screen and in Share is a stick figure animation rendered on demand from the stored joint tracks on a plain background; no export can contain camera frames. Vision's body pose request has only one revision, so there is nothing to pin; the release gate is one reference clip processed on two iOS versions with every angle within 1 degree.

## 5. Recommendations and how they are phrased

### 5.1 The one directive: the saddle height card

The saddle height card is the only recommendation the app makes; it is a starting point, not a prescription. It fires only when every one of these holds: a dynamic fit capture made in the app; bike type road or gravel (TT and tri bikes never get the card in 1.0: the aero tuck is the degraded pose case, A17, and the ranges are road cohorts); 12 or more clean cycles; all four gates passed; effort and pain answered before the result; no pain tag; and the knee flexion at maximum extension median plus or minus 1.96 times the SEM lies entirely below 30 or entirely above 40. This is the same 95 percent standard the compare view uses.

"Your knee reads 23 degrees at full extension, plus or minus 4, at effort 6 of 10. Published dynamic ranges put most riders between 30 and 40. Phone video can read a few degrees off a lab system, and how you point your foot moves this number too, so treat it as a starting point. If the saddle feels high, try 5 mm lower, ride it for a few sessions, and measure again. Note your current saddle height before you move it. Get off the bike and let the flywheel stop before you adjust anything."

Rules. Direction only: below 30 the knee reads straighter than the published range (saddle may be high), above 40 more bent (saddle may be low); card copy uses those phrases, never "too straight" or "too bent". 5 mm per step, one change per session. The next step is offered only after a later full capture that itself passes every condition with an effort rating within 2 of the capture that produced the previous card; a capture refused for effort mismatch, or one back inside 30 to 40, does not unlock a step. A 5 mm step moves the knee about 2 degrees, below the detectable change on any bike, so the re-measure shows the new reading and never claims to confirm the step; confirmation is offered only at 10 mm cumulative or more. The 2 cm cap is the sum of suggested steps per bike from the first card, reset only by a logged shoe, pedal, saddle or crank change or a logged professional fit; at the cap the card says "that is a lot of change for an app to suggest. A fitter is the right next step."

The window is held at 30 to 40 at every effort: the published intensity effect is about 3 degrees (A6, A12), inside the error, and in this frame Swart and Holliday's low intensity window lands near 30 to 40 anyway. When effort is 3 or less and the reading is above 40 the card adds "Easy spinning reads a few degrees more bent than training effort. Capture once at your usual effort before changing anything"; the mirror line applies at effort 8 or more below 30.

Why small steps: saddle height changes under about 4 percent of leg length (roughly 3 cm) have trivial to small effects on joint loads and none on efficiency, while a 5 percent change shifts knee kinematics by about 35 percent (A7), a fitter's territory. The 2 cm cap keeps everything the app can suggest inside the band where a wrong card costs comfort and time, not a season. The 5 mm step exists so each move can be felt and measured against the noise before the next.

### 5.2 Everything else is a diff

Setback, reach, drop, stem, cleats and crank length never get a number from the image. The app observes and the rider decides:

- Setback: "Changed: hip angle at the top is 7 degrees more closed than your reference. Re-placement on this bike hides anything under 6, so this looks like a real move. Changes like this show up when the saddle has moved back or down, or the bars lower or further away. Reference setback was 62 mm and saddle height 745 mm. Tape them?" Knee over pedal spindle (KOPS) is not used; it has no biomechanical basis (A27).
- Reach and drop, stem: torso, elbow and shoulder trends against the reference and the expert opinion ranges, with "fitters change these in 10 mm steps and some riders need two weeks to adapt" (A28). Stem changes get "a shop job if it means cutting a steerer".
- Cleats: stored on the Setup Card, never recommended. Small shifts change knee kinematics and tendon loads in ways a side camera cannot see (A30).
- Crank length: stored, never recommended. Across 120 to 220 mm cranks maximum power varied about 4 percent, and a 5 mm shorter crank reduces maximum hip and knee flexion by about 2 to 3 degrees (A31). The app may say "some riders in this situation try shorter cranks; that is a shop decision" and no more.

Every card that suggests an adjustment ends with the same fixed footer, kept on the fit card image: "One change at a time. Ride a few sessions before the next. Stop if anything hurts." Observation only cards do not carry it.

### 5.3 Language rules

Allowed: "published ranges put most riders", "within your detectable change", "consider", "try and re-measure", "tape it", "a fitter would look at". Forbidden in any claim, recommendation, result card, notification, listing or site copy: should, fix, correct, optimal, injury, prevent, pain relief, diagnose, treat, medical grade, clinical, accuracy or validated as a page title or heading, as accurate as a pro fit, any named condition. The only exemptions are three fixed strings in one file (Safety.strings), which may use injury, diagnose and treat only in the negative or to send the rider to a professional: the first launch acknowledgement, the pain tag line, and the adjustment footer. A unit test fails on any forbidden word outside that file.

A reference system (Retul) may be named only as a cited source or as the comparator in a reported comparison with n, mean difference and standard deviation, and only on the Methods screen, the methods page on the site and the references list; never in the App Store name, subtitle, keywords, description, screenshots, share images, fit cards or review notes.

The pain tag line: "Pain is a reason to see a doctor or a bike fitter, not to adjust from an app." It suppresses advice for that region, draws no cause, stays on the phone, and never appears in a shared image. The first launch acknowledgement: "This app measures your riding position and suggests small changes for comfort and efficiency. It is not medical advice and does not diagnose or treat injuries. If you have pain, numbness or a past injury, check with a doctor, and a bike fitter, before changing anything. Built for adult riders; the published ranges it shows come from adult cyclists." This is the "check with a doctor" reminder guideline 1.4.1 asks for (A32), and the framing that keeps the app a general wellness product under FDA policy (A33) and a lifestyle product outside EU MDR (A34).

## 6. User flow

1. First launch. What it does, what it does not do (the acknowledgement), what happens to video (processed here, deleted), the pain question (Yes shows the pain line and prefills the first capture). Pick a trigger: "I changed something", "new bike", "travel rebuild", "just curious". No account.
2. Add a bike. Type: road, gravel, TT or tri. Hand position. Camera side (recommended default from the bench). Optional Setup Card: saddle height along the seat tube, setback, saddle nose to bar centre, drop, crank length, pad stack and reach (vertical and horizontal distance from the BB to the arm pads) for TT, shoe and pedal system, a photo. Every field skippable.
3. Body estimate (optional). Inseam and crank length (prefilled from the Setup Card, default 172.5 mm). Returns the Estimate bracket. No stack, reach or drop estimate: no sourced formula exists.
4. Camera permission, asked here and not at launch, with the purpose string in section 8.
5. Placement guide. Tripod spot (saved per bike), bubble level, ghost outline, live confidence. Safety line: stable surface, clear of the flywheel, trainer only.
6. Capture A, re-place, capture B. Effort and pain asked on the processing screen. Result: six angles with spread, the stick figure replay, a capture quality grade (clean cycle count, share of frames clearing the confidence threshold, gate margins; informational, never changes card logic), and either the saddle height card or "No saddle change supported by this measurement".
7. Set as reference. Sessions two and three repeat the pair; from session four captures record once and open the compare view: reference versus now per metric, with "nothing moved" as a first class result. Set as reference is offered again after any capture inside a change window; a new reference keeps the noise estimate, because re-placement noise belongs to the camera setup, not the saddle.
8. Failure paths, each with its own copy and exit (annex C): camera denied; capture B failing after A; interruption during countdown or recording; low storage; thermal throttling; the rider never mounting; processing errors; three failed retakes; skipped effort or pain answers; a compare refused for effort mismatch; a second person in frame; a gate that will not pass on a given shelf.
9. Share. One tap export through the system share sheet of the stick figure replay clip (rendered from joint tracks, no camera footage, deleted when the sheet closes) and a fit card image (angles with error bands, no traffic lights, no pain tag, the adjustment footer when a card fired), plus a fitter hand off card listing the Setup Card and the last capture's angles. The app never writes to Photos itself. This is the only growth surface the product has; it gets design attention.
10. Come back loop. The rider picks triggers and the app schedules only those through one local notification scheduler: at most two a month, quiet hours respected, cancelled when the check is completed (annex E). Change window: log the change (the app prompts for the old value on the Setup Card first), re-check prompts at ride 1 and ride 3, a before and after card that names the logged change as the likely reason for whatever moved; it closes when the rider reverts or sets a new reference. Pack and Rebuild Check: a Pack snapshot before boxing and a Rebuild Check compare after reassembly, with notifications the day before and after one typed travel date (no calendar, no race list). Quiet monthly drift check: one notification a month asking for a single compare capture, which says so when nothing moved. No streaks, points or badges.

## 7. MVP scope and non goals

1.0 ships: bikes with hand position and camera side; Setup Card; estimate layer; capture flow with live gates, noise floor and hands free recording; six angles with per metric gating and quality grade; saddle height card (road and gravel only); compare view and "nothing moved"; change window; Pack and Rebuild Check; monthly drift check; share clip rendered from joint tracks, fit card and fitter hand off card; Methods, privacy and support screens; StoreKit 2 scaffold behind an OFF flag (section 9). iOS 17 and later, iPhone only, SwiftUI, SwiftData, no network calls.

Non goals for 1.0: ankle angle, cleat, wedge, crank or saddle model advice; any millimetre derived from the image; setback, reach, drop or KOPS prescriptions; body based stack and reach; front or rear view; asymmetry; cleat tape measurement flow; TT hold test and race calendar; bike to bike transfer; AR body measurement; race legality toggles (UCI, World Triathlon); CSV or PDF export; iCloud sync; accounts, cloud, analytics, ads, Watch, iPad, Android.

1.1 candidates, earned by the bench and the first 90 days: Carry (copy a fit between bikes using stack, reach and seat tube angle typed from the manufacturer's chart; no scraped geometry database); AR inseam and height with manual override; a body based stack and reach range only if a primary source for the formula is read and cited; the cleat tape measurement flow (first and fifth metatarsal marks, record only, A29); TT hold test (an opportunistic capture during any aero interval reporting whether the aero angles stay within the noise band) and a Build, Sharpen, Lock race countdown scheduling three checks at fixed weeks before an A race, both only if the TT gate pass rate clears 70 percent; race legality toggles that warn and never block; PDF fit card; optional trainer power over Bluetooth for effort matching.

## 8. Data and privacy

- All inference on device. No network calls; the only traffic is the App Store. No third party SDKs, analytics, ads, remote notifications or accounts.
- App Privacy label: Data Not Collected. Apple's definition turns on transmitting data off device; data processed only on device is not collected (A35). Crash logs reach Akshay only through Apple's own opt in and are Apple's collection (A35). iCloud sync is excluded from 1.0 because Apple has not said whether private CloudKit sync counts as collection (A36).
- Camera purpose string: "The camera records a short side view of you pedaling so the app can measure your riding position on this phone. Video never leaves your device." No microphone or Photos purpose strings in Info.plist; a build that touches either fails at first use, which is the intended tripwire.
- Stored data: joint tracks, thumbnails, Setup Cards, pain tags, change log and notification dates, in the app container, included in the user's own device backup. Delete everything is one button in settings. Video is deleted when processing finishes, with no exception; the replay and share clip contain no camera frames.
- Pose estimation measures joint angles and does not identify anyone, so it is not biometric data under GDPR Article 9 or the Illinois and Texas statutes, which name retina, iris, fingerprint, voice and hand or face geometry (A37). Never adding a feature that recognises who is riding keeps it that way.
- Privacy policy, on the Vercel site and in the app, written from the checklist in annex D: what is stored, that nothing is transmitted, retention, deletion, how to revoke camera and notification access, and how support email is handled.

## 9. Monetization

Recommendation: free, with no revenue, for now. Section 12 shows the constraint costs little in expectation.

Built but gated off: a StoreKit 2 scaffold behind an Info.plist boolean that ships false, read once at launch, the same pattern as Wingline's `WLSalesEnabled`. No Paid Apps Agreement, no products in App Store Connect. While the flag is off, which is every 1.0 build, there is no bike limit, no history limit, no Pro label, no locked or greyed control and no purchases row in settings; the scaffold is unreachable code, and a unit test asserts the key is false.

If the flag is ever turned on: a one time Pro unlock (unlimited bikes, year over year history, PDF fit card, CSV export) priced near 30 USD, about one year of Bike Fast Fit Elite at 29.99 USD (A49) and under MyVeloFit's 35 USD two week plan (A50), with the free tier keeping two bikes and twelve months of history for bikes and captures created after that build; nothing a user already has is hidden. Capture, noise floor, compare, the saddle height card and the Setup Card stay free forever. A Fitter mode is a second flag. Never ads, never analytics.

## 10. Accuracy validation plan

Weeks 1 and 2, Akshay's trainer, then two friends on different bikes and one in loose clothing: between session noise (10 captures over 5 sessions, phone re-placed each time, pooled SEM per angle); yaw at 0, 10 and 20 degrees off perpendicular by protractor, checking whether the yaw hint and the apparent thigh to shank ratio track it; tilt gate against a spirit level; ghost outline against tape measured camera position; saddle sensitivity at reference, plus 5, minus 5 and minus 10 mm, recording degrees per 5 and per 10 mm, written into this spec before any copy hints at it; TT gate pass rate in the aero position; heel down versus toes down at one saddle height for the Methods screen.

Kill criteria, decided at the end of week 2, in the app's own terms. Noise means the pooled SEM of knee flexion at maximum extension from the five bench pairs, the statistic 4.4 stores. Detected means the shipped verdict rule returns Changed, run with a reference mean of two and a check mean of two. Stop if the SEM is above 2.2 degrees. Stop if a 10 mm saddle move is reported as Changed in fewer than 8 of 10 trials. The second test is a joint test of sensitivity and noise; if the SEM passes but 10 mm still falls under the threshold, the week 2 decision picks one of two named changes before continuing, averaging two captures per check or a one sided 90 percent detectable change, and 4.4 is updated to match; no other loosening is allowed. TT pass rate decides only whether TT capture ships as a normal mode (70 percent or more) or behind a one time "TT capture is experimental, expect retakes" notice, and whether the 1.1 hold test survives.

Retul comparison (Retul is the LED marker motion capture system most professional fitters use, A26): one session for Akshay plus two to four volunteers, booked in week 3, app recording the same side at the same time, with and without the marker harness on. Compare knee flexion at maximum extension, knee flexion at top, hip most closed, torso, elbow and shoulder as mean difference and standard deviation. Retul reports knee extension as flexion from straight, so no mapping is needed (A19). Target: knee mean absolute difference under 5 degrees and agreement on saddle height direction. At n of 3 to 5 this is a smoke test, not validation: with a standard deviation of about 4 degrees the 95 percent interval on the mean difference is about plus or minus 4 degrees at n of 5 and plus or minus 10 at n of 3. A Comparison subsection of the methods page, not a separate accuracy page, waits for n of 10, opens with "This is a small sample comparison against one motion capture system. It is not a validation and does not show the app is as accurate as a professional fit", publishes n, means, standard deviations and every disagreement, and applies no bias correction. Review notes link the methods page but not the comparison until it exists, so the 1.0 submission makes no comparison claim.

## 11. Risks and open questions

Risk register (likelihood, impact, mitigation):

- Vision loses the camera side ankle behind the chainring or in the aero tuck (high, high). Bench picks the recommended camera side and decides whether TT capture ships normal or experimental; refuse rather than guess.
- Users will not set up a trainer and camera (high, high). The estimate layer gives a no trainer first run; a Slowtwitch or r/triathlon poll by end of week 3 with a number to beat: 30 percent of respondents willing to film on a trainer.
- App Review treats joint angles as a 1.4.1 health measurement (medium, medium). Methods screen, published protocol, no accuracy equivalence claims, Health and Fitness category, review notes linking the methods page.
- Angles drift between iOS versions (medium, high for year old references). Release gate in 4.5.
- A confident wrong saddle height card (medium, high). 95 percent interval gate, 5 mm steps, reading not order, cumulative cap, footer.
- Crowded category of thin entrants (certain, medium). Lead the listing with reference, drift and on device, not with angles; guideline 4.3 is handled by being meaningfully different (A38).
- EU product liability directive 2024/2853 may reach stand alone software from December 2026 (low, medium). One hour with counsel before any EU marketing (A39).

Open questions for Akshay:

1. Drive side or non drive side: which keeps the ankle keypoint clear of the chainring? The answer becomes the default in the add bike flow, not a lock. Bench, week 1.
2. Pooled SEM per angle on your trainer. Does it beat 2.2 degrees?
3. Degrees of knee flexion per 5 and per 10 mm of saddle height.
4. Does the 3D request's yaw hint track a protractor well enough to gate?
5. Camera height: saddle height is chosen here; confirm it against the ghost outline tolerance.
6. Name clearance for Saddlemark and Pedalmark (section 13).
7. Retul bay and two or three fitters for week 9, booked by end of week 4; otherwise the comparison moves after submission and the Methods screen says so.
8. Will the pre launch poll show enough riders willing to film on a trainer?
9. Publish as an individual or an LLC? Guideline 5.1.1(ix) and liability favour an entity; the personal implications of owning one need counsel (A32).
10. Will App Review accept the Methods page as the 1.4.1 disclosure? Ask in review notes.

## 12. Go or no go on "huge potential"

Verdict: go on building it as a free, honest, small product. No on "huge".

| Segment | Size | Basis |
|---|---|---|
| Year round triathletes, US, Europe, Asia | 0.6 to 1.2 million (assumption) | USA Triathlon 303,000 unique members 2025 (A40); France 75,346 licences, Germany 61,031 members, Great Britain about 120,000 active racers (A41, A42, A43); Ironman over 250,000 registrations in 2025 (A44) |
| Enthusiast drop bar riders | 9 to 18 million (assumption) | 41.2 million US paved road riders (A45), of which 5 to 8 percent ride 50 or more days a year (assumption); about 6 million German road bike riders including occasional (A46); 9.3 million Japanese hobby cyclists (A47) |
| iPhone owners who already use a training app | 2.3 to 4.3 million | iOS share 52 percent US, 50 percent UK, 28 percent Germany, 54 percent Japan (A48); app use about half (assumption) |
| Triathlete only slice | 180,000 to 360,000 | iOS taken as 50 percent (triathletes skew to the US, UK and Japan, A48), app use 60 percent (assumption, higher because year round triathletes almost all log training) |

Demonstrated demand is small. Every dedicated bike fit app in the US App Store together has under 700 ratings across 16 years; the leader, Bike Fast Fit Elite, has 417 ratings since 2016 and at least ten entrants from 2024 to 2026 have fewer than 25 each (A49). MyVeloFit, the incumbent since 2020, claims 200,000 users on one page and 100,000 on another (A50), is a web app with no native iOS presence, and has forum level traction. Strava by contrast has 380,000 US ratings and about 195 million registered athletes (A51).

Realistic year one for a free app with no ad spend: 10,000 to 50,000 downloads and 3,000 to 15,000 monthly actives, from one or two Reddit or YouTube spikes and club seeding. If a paid tier were ever on, at RevenueCat's Health and Fitness medians (2.9 percent download to paid, 35.64 USD per payer in year one; subscription benchmarks applied to a one time unlock, A52): 290 to 1,450 payers and 10,000 to 52,000 USD in year one; top quartile 22,000 to 110,000 USD. At 10,000 downloads the app misses the 1,000 USD a month bar that 83 percent of new apps do not reach within two years; at 50,000 it clears it four times over (A52). A five times upside is a 250,000 USD a year app. Durable and worth having, not venture scale.

Decision rules: the bench in weeks 1 and 2 passes or fails the kill criteria in section 10. The 90 day post launch review turns 1.1 on or off: 5,000 downloads, 25 percent of installs completing a reference capture, 20 percent returning for a second check within 60 days.

## 13. Name

Saddlemark is first choice. Checked 2026-11-03 on five App Store storefronts (US, GB, DE, AU, JP), USPTO, TMview including EUIPO, and DNS: no app of that name; one dead US application from 2017 in class 27 (rugs); a pending EU mark "Saddle.Market" for an equestrian marketplace sharing class 42; saddlemark.com and .app resolve to nothing (DNS A record check only, not a registrar lookup). Search results skew equestrian, a mild discoverability cost. Pedalmark is second: no app on any storefront, no USPTO hit, one unrelated Chilean mark (PedalMarket.cl, classes 35 and 38), both domains resolve to nothing on the same check; reads as cycling with no medical adjacency. Dropped on evidence: Holdline (HoldLINE Calisthenics, same category), Reseat (registered marks), Setline (registered in classes 9 and 42), Fitkeep (FitKeeper, same category), Plumbline (crowded), Kneeline (free as a mark but its App Store neighbourhood is knee rehab). Before committing: USPTO advanced search with class filters 9 and 42, phonetic variants, a general web and company registry search, confirm both domains at a registrar, register the Slowtwitch and TrainerRoad handles.

## 14. Build plan

Twelve weeks, solo, kill decision at the end of week 2. Test plan in annex F.

- Week 1 to 2: capture and Vision spike. AVFoundation 1080p60 via AVCaptureVideoDataOutput and AVAssetWriter, storing the intrinsic matrix once per capture from the first sample buffer; gravity vector level; per frame body pose on a file; ankle track segmentation; angle extraction; CSV out. Run the bench in section 10. Kill decision.
- Week 3 to 4: data model (SwiftData: Rider, Bike, SetupCard, Capture, JointTrack, NoiseEstimate with pair count, per metric sum of squared differences, pooled SEM and last pair date, Change), placement guide with ghost outline, live gate pass, hands free recording with voice, retake screens. Book the Retul session and recruit volunteers and fitters for week 9.
- Week 5 to 6: results, compare view with the verdict rule, noise floor flow, saddle height card logic, "nothing moved", estimate layer.
- Week 7: one local notification scheduler driving the change window, the monthly drift check and Pack and Rebuild Check.
- Week 8: share. Fit card and fitter hand off card as still images, stick figure replay export, design pass.
- Week 9: Retul comparison sessions, Methods screen with real bench numbers, copy pass against the language rules, privacy policy from annex D, support page on Vercel.
- Week 10: slack week. StoreKit 2 scaffold behind the OFF flag, settings, delete everything, accessibility, iPhone 12 and SE performance pass; anything that slipped from weeks 7 to 9 lands here. If week 10 fills, the replay export moves to 1.0.1 and the still cards ship.
- Week 11: Xcode project hygiene (bundle id com.akkikens.saddlemark pending the name, team JFNPZ2JF6V, iPhone only), unit tests with no trapping paths on a named simulator shut down after each run, screenshots at 1320 by 2868, App Store Connect listing via the API, App Privacy set by Akshay in the web UI.
- Week 12: Fable end to end review, fixes, Akshay's go, submission with release after approval.

## Appendix: sources

Numbered as cited above. All fetched and checked 2026-11-03 by the research and verification pass; full notes with every URL read, and the claim ledger, are in docs/research.

- A1. US fit prices: thepricer.org, "How much does a bike fit cost", updated 2026-10-04, basic 50 to 150 USD, manual or dynamic 150 to 250 USD, Retul or 3D 250 to 400 USD. https://www.thepricer.org/how-much-does-a-bike-fit-cost/
- A2. UK: Velosport London fitting page, Level 1 Retul 195 GBP, Level 2 260 GBP, TT 235 to 300 GBP. https://www.velosport.co.uk/pages/fitting/ and Cycling Weekly, in person fit 175 GBP. https://www.cyclingweekly.com/fitness/bike-fit/is-ai-tech-good-enough-for-bike-fitting-i-had-both-an-ai-and-an-in-person-bike-fit-at-my-local-shop-heres-how-they-differed
- A3. Germany: radsport-news.com 2019 market survey, 150 to 300 EUR typical. https://www.radsport-news.com/markt/marktnews_113430.htm
- A4. Singapore: Pro Cycle Bikes, 300 to 760 SGD GST inclusive. https://procyclebikes.com.sg/products/bike-fitting
- A5. Peveler 2012, static goniometer method 25 to 35 degrees at 6 o'clock. https://pubmed.ncbi.nlm.nih.gov/22158094/
- A6. Swart and Holliday 2019, dynamic 33 to 43 low intensity and 30 to 40 high intensity at bottom dead centre. https://pubmed.ncbi.nlm.nih.gov/31834181/
- A7. Bini and Priego-Quesada 2022 systematic review, strong evidence for dynamic knee angle; changes under 4 percent of leg length trivial. https://pubmed.ncbi.nlm.nih.gov/34706617/ Bini, Hume and Croft 2011, a 5 percent saddle height change altered knee kinematics 35 percent. https://pubmed.ncbi.nlm.nih.gov/21615188/ Ferrer-Roca 2012, 30 to 40 dynamic at maximum knee extension. https://pubmed.ncbi.nlm.nih.gov/22190163/
- A8. Peveler 2007 and 2011, 109 percent of inseam outside 25 to 35 degrees 63 and 73 percent of the time. https://pubmed.ncbi.nlm.nih.gov/18076230/ and https://pubmed.ncbi.nlm.nih.gov/20581695/
- A9. LeMond formula, inseam times 0.883, ignores crank length. https://www.roadbikerider.com/lemond-formula-saddle-height/ Peveler 2005, LeMond and Hamley did not differ (p 0.917), abstract via a secondary host. https://lida.sport-iat.de/twm/Record/4010655?lng=en Ferrer-Roca 2012, 56.5 percent outside 106 to 109 percent, regression 108.6 to 110.4 percent (A7).
- A10. Fonda 2014, 2D underestimates 3D knee angle by 2.2 degrees; dynamic differs from static. https://pubmed.ncbi.nlm.nih.gov/24499342/
- A11. Corbett and Bevins 2014, dynamic 5.4 degrees greater than static; Millour 2019 and Holliday 2021, about 8 degrees. https://lida.sport-iat.de/ta/Record/4032945 and https://pmc.ncbi.nlm.nih.gov/articles/PMC9219349
- A12. Holliday 2023, knee extension up 6 to 9 percent and elbow flexion up 39 percent from 60 to 90 percent HRmax. https://pubmed.ncbi.nlm.nih.gov/31475880/
- A13. Apple, VNDetectHumanBodyPoseRequest and joint names (19 joints, no foot). https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest and https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname
- A14. Apple, VNHumanBodyPose3DObservation, cameraOriginMatrix; bodyHeight is a 1.8 m reference without depth data. https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation and WWDC23 session 111241. https://developer.apple.com/videos/play/wwdc2023/111241/
- A15. WWDC20 session 10653, bent over subjects degrade body pose; ARKit has no per joint confidence. https://developer.apple.com/videos/play/wwdc2020/10653/
- A16. Millour 2019, maximum knee extension with the crank parallel to the seat tube; BDC 3 degrees more flexed (38 vs 35, n 26); static 8 degrees lower. https://actabio.pwr.edu.pl/fcp/PGBUKOQtTKlQhbx08SlkTUARAUWRuHQwFDBoIVURNWH5XFVZpCFghUHcKVj0GQUw/302/public/publikacje/v21-4-2019/70.pdf
- A17. WWDC20 (A15) names bent over poses as degraded; the aero tuck is that case.
- A18. Holliday and Swart 2021, literature table of expert opinion ranges (Burt 2014, Silberman 2005, Pruitt and Matheny 2006), measured means in 50 male road cyclists, no shoulder range. https://pmc.ncbi.nlm.nih.gov/articles/PMC9219349
- A19. Retul knee extension reported as flexion from straight, 37 plus or minus 3 (BikeRadar) and 30 to 40 (Cyclocross Magazine). https://www.bikeradar.com/reviews/maintenance/tools-kits-and-boxes/fitting-systems/retul-fit-system-review and https://www.cxmagazine.com/retul-cyclocross-bike-fitting
- A20. Bini 2023, OpenPose vs marker tracking in 26 cyclists, single sagittal camera, 4 to 8 degrees hip and knee, 15 to 22 ankle. https://pubmed.ncbi.nlm.nih.gov/36975046/ Follow up with MediaPipe 3 to 9 degrees: doi 10.1007/s11332-023-01075-7.
- A21. Wade 2023, occluded side knee and hip variability 69 and 108 percent higher. https://pmc.ncbi.nlm.nih.gov/articles/PMC10635560/
- A22. Stevens 2006, under 20 degrees out of plane little difference; beyond, angles appear more extended. https://people.ohio.edu/stevensn/documents/Stevens%20et%20al%202006%20Technical%20note.pdf
- A23. Baldinger 2025, 45 degrees off axis raises knee RMSE to 15 to 29 degrees. https://www.mdpi.com/1424-8220/25/3/799
- A24. Horsak 2024, OpenCap test retest SEM 2.2 and MDC 6.0 degrees across sessions. https://pubmed.ncbi.nlm.nih.gov/39163799/
- A25. Slowtwitch, landmark convention shifts knee angle about 2 degrees between F.I.S.T. and Retul. https://slowtwitch.com/industry/retul-or-goniometer-it-alone/
- A26. Branco 2022, Retul Vantage between session standard error under 3 degrees, minimal detectable difference 2.15 to 6.55 degrees, 18 Hz. https://repositorio.ufmg.br/bitstream/1843/65097/2/Does%20the%20Ret%c3%bcl%20System%20provide%20reliable%20kinematics%20information%20for%20cycling%20analysis_.pdf and Scoz 2021 Retul vs Vicon. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- A27. Bontrager, The Myth of KOPS. https://www.sheldonbrown.com/kops.html
- A28. MyVeloFit, stems in 10 mm steps, two weeks adaptation, order of adjustments. https://www.myvelofit.com/fit-academy/best-ways-to-adjust-reach-on-your-bike/ and https://www.myvelofit.com/fit-academy/bike-fitting-order-of-adjustments/
- A29. Steve Hogg, cleat position by first and fifth metatarsal marks. https://www.stevehoggbikefitting.com/bikefit/2011/04/power-to-the-pedal-cleat-position/
- A30. Chartogne 2023, 15 mm cleat shifts change knee kinematics, PMID 35129429; Firminger and Asmussen 2026, 20 mm posterior cleat reduces Achilles strain, PMID 41975639.
- A31. Martin and Spirduso 2001, 120 to 220 mm cranks, power 1149 to 1194 W. https://pubmed.ncbi.nlm.nih.gov/11417428/ Ferrer-Roca 2017, a 5 mm longer crank adds 1.8 to 3.4 degrees of maximum hip and knee flexion. https://pubmed.ncbi.nlm.nih.gov/27484153/
- A32. Apple App Store Review Guidelines 1.4.1, 2.3.7, 2.5.14, 4.3, 5.1.1. https://developer.apple.com/app-store/review/guidelines/
- A33. FDA, General Wellness: Policy for Low Risk Devices, January 6, 2026. https://www.fda.gov/media/90652/download and Policy for Device Software Functions, September 28, 2022 (posture suggestions are not devices). https://www.fda.gov/media/80958/download
- A34. EU MDR 2017/745 Recital 19 and Article 2(1). https://www.legislation.gov.uk/eur/2017/745/introduction/adopted
- A35. Apple, App privacy details, definition of collect, on device processing, Apple frameworks. https://developer.apple.com/app-store/app-privacy-details/ and Apple app analytics opt in. https://www.apple.com/legal/privacy/data/en/app-analytics/
- A36. Apple Developer Forums thread 710456 on CloudKit and the privacy label, unanswered. https://developer.apple.com/forums/thread/710456
- A37. GDPR Article 4(14) and Recital 51; EDPB Guidelines 3/2019 para 74; Illinois BIPA 740 ILCS 14/10; Texas Bus. and Com. Code 503.001. https://gdpr-info.eu/recitals/no-51/ and https://codes.findlaw.com/il/chapter-740-civil-liabilities/il-st-sect-740-14-10/
- A38. Apple guideline 4.3(b) (A32); bike fit is not a listed saturated category.
- A39. Directive (EU) 2024/2853, Gibson Dunn summary. https://www.gibsondunn.com/wp-content/uploads/2026/03/eu-product-liability-directive-responding-to-software-ai-and-complex-supply-chains.pdf
- A40. USA Triathlon 2025 Impact Report, 303,000 unique active members. https://www.usatriathlon.org/news/2026/february/04/usa-triathlon-releases-2025-impact-report-highlighting-strategic-growth-membership-event-momentum-and-progress-toward-la28
- A41. FFTri, 75,346 licences as of July 2026 (CNOSF federation sheet). https://ressources-associations-sportives.franceolympique.com/api/media/sites/ressources_associations_sportives/files/2026-07/F%C3%A9d%C3%A9ration%20Fran%C3%A7aise%20de%20Triathlon.pdf
- A42. DOSB Bestandserhebung 2025, Deutsche Triathlon Union 61,031 members. https://www.basketball-bund.de/wp-content/uploads/sites/2/2025/11/DOSB-Bestandserhebung-2025-neu.pdf
- A43. Triathlon Industry Alliance via SGI Europe, over 120,000 active racing triathletes in Great Britain. https://www.sgieurope.com/consumer/gb-triathlon-participation-returns-to-growth/119622.article
- A44. Ironman 2025 season, over 250,000 registrations. https://www.endurancesportswire.com/?p=225088
- A45. Outdoor Industry Association 2025 via SGB Online, 41.2 million US road bicycling participants. https://sgbonline.com/oia-finds-outdoor-rec-participation-slowing-outings-frequency-eroding/
- A46. Statista via Allensbach, about 6 million Rennrad riders in Germany including occasional. https://de.statista.com/infografik/amp/29917/befragung-zu-rennraedern-in-deutschland
- A47. Statista, 9.3 million hobby cyclists in Japan, October 2021. https://www.statista.com/statistics/1331631/japan-number-cyclists
- A48. StatCounter mobile OS share, October 2026, US, UK, Germany, Japan. https://gs.statcounter.com/os-market-share/mobile/united-states-of-america
- A49. iTunes Search API, US storefront, "bike fit", 2026-11-03; Bike Fast Fit Elite listing, 417 ratings, free with 29.99 USD annual subscription (EZ 9.99, Pro 139.99); its privacy policy says sessions, measurements and videos stay on device unless the user opts in to data sharing. https://apps.apple.com/us/app/bike-fast-fit-elite/id1145619812 and https://www.bikefastfit.com/en/privacy/
- A50. MyVeloFit about and home pages (200k active users; another page 100K users, 250K fits); Speed Skating Canada renewal, more than 200,000 cyclists have used it; server side processing per the process page. https://www.myvelofit.com/about and https://www.myvelofit.com/our_process and https://speedskating.ca/speed-skating-canada-extends-partnership-with-bike-fit-platform-myvelofit/ Pricing: free, 35 USD two week single fit, 75 USD a year. https://www.myvelofit.com/pricing
- A51. Strava, about 195 million athletes (Sacra; Strava press, June 2026). https://sacra.com/c/strava/
- A52. RevenueCat State of Subscription Apps 2026, Health and Fitness download to paid median 2.9 percent, top quartile 6.2 percent, 35.64 USD per payer after one year, 17.3 percent of new apps reach 1,000 USD a month within two years. https://www.revenuecat.com/state-of-subscription-apps-2026/

Unverified figures deliberately left out of the body: US Retul shop prices quoted as 320 to 350 USD (shop pages returned 429, snippets only; two of the quoted shops are in Canada per the verification ledger); Peveler 2005 heel method percentages (abstract only, secondary host); Taiwan and Korea cycling participation; competing app counts for the keyword "fit".
