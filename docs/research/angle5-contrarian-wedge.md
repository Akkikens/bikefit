# Angle 5: Contrarian wedge for a camera based bike fit app

Date: 2026-11-03. Author: panel designer 5 (Fable subagent). Filename note: the task text said "using the filename given below" but no filename was included, so this file follows the sibling naming pattern (angle1 to angle4).

Method note: the shared WebSearch budget for this turn was already exhausted when this agent started (every search call returned "budget used up"), so all checks below were done with direct WebFetch of known URLs. Pages that could not be reached are listed as such. The sibling file research-competitors.md in this folder was skimmed for Bikefit.ai and Retul facts that this agent could not fetch itself.

## 1. Competitor landscape (what was actually read)

### MyVeloFit (web service, video upload, cloud)
- Home page read: https://www.myvelofit.com/
  - Record and upload a video of yourself pedalling on a trainer, rollers, smart bike or spin bike. Any phone camera plus something to hold it.
  - Feature names on the page: Personalized Recommendations, Bike Specific Analysis, AI Video Analysis, Tracking and Progress, Custom Riding Goals, Mobility Analysis, Virtual Fit First Sizing, Compare Bikes, Expert Review (human fitter add on), Fit Academy.
  - Self reported figures: 200k active users, 450k fits processed, 100+ countries. Claims to be "the world's #1 online bike sizing and fitting tools". No numeric accuracy claim. A testimonial says data is "comparable to other fit systems such as Retul".
  - 30-Day Better Fit Guarantee.
- Rider pricing read: https://www.myvelofit.com/pricing/rider/
  - Starter: USD 0, one fit upload per week, basic analysis, no detailed report, no specific recommendations.
  - Enthusiast: USD 35 one time for 2 weeks access, 5 uploads per day, video mobility assessment, detailed report, adjustment recommendations.
  - Pro: USD 75 per year, unlimited bikes and uploads.
  - Expert Review add on from USD 75, requires a paid plan.
- Business pricing read: https://www.myvelofit.com/pricing/business/
  - "For retailers and bike fitters". Level 1 USD 49 per month (1 client session, USD 20 extra), Level 2 USD 149 per month (15 sessions, USD 15 extra), Level 3 USD 249 per month (30 sessions, USD 10 extra). Shareable reports with before and after, PDF, video mobility assessment per client.
- FAQ read: https://www.myvelofit.com/faq/
  - No quantitative accuracy claim. Says online fitting "absolutely can be" effective for many riders but some "will benefit more from an in-person fit".
  - "place your camera consistently relative to your bike on both sides to ensure consistent results". Full body must be visible, head, feet, arms and legs, through the whole stroke. Trainer or rollers required for outdoor bikes. Needs "some resistance on the pedals". Does not provide cleat positioning recommendations.
- Not reachable: https://www.myvelofit.com/setup-guide/ (404). App Store page guess https://apps.apple.com/us/app/myvelofit/id1572263093 returned 404 (the id was a guess and should not be reused).

### Bike Fast Fit (Double Dog Studios, iOS, three apps)
- Site read: https://www.bikefastfit.com/
  - Phone mounted side on, bike on indoor trainer, short video of normal pedalling. Road, gravel, mountain, TT, indoor bikes. "Markerless AI Tracking", "no dots". Own model "built and trained specifically for cyclists on bikes". Video at 240 fps where the device supports it. Recommendations as ranges, "based on published fitting references" and their session database.
  - EZ USD 9.99 per year (side view, saddle height and fore aft, riding position Upright, Relaxed or Aggressive). Elite USD 29.99 per year (adds front view and bike measurements, rear view, Knee Tracking, Explore Possible Changes, session records). Pro USD 139.99 per year for fitters and shops (LiveCheck real time angles, Rear View Analysis with pelvic angle, knee displacement in mm, spinal bend, upper body balance; Custom Data; Branded Reports; rider and bike records).
  - Metrics: knee angle at maximum extension, hip angle, torso and shoulder position, saddle height and fore aft in mm or inches.
  - Self reported: over 1.15 million rider videos as of July 2026 and a 4.7 average rating from 2,940 ratings (the App Store pages below show far fewer ratings per app on the US storefront).
  - A fitter testimonial says their motion capture system "sits in the drawer".
- App Store pages read (US):
  - EZ https://apps.apple.com/app/apple-store/id1578925255 : 4.6 stars, 176 ratings, free with USD 9.99 annual IAP, 61.5 MB, version 2.14.1. Privacy label: data not linked to you in Health and Fitness, Purchases, User Content, Identifiers, Usage Data, Diagnostics, Other Data.
  - Elite https://apps.apple.com/app/apple-store/id1145619812 : 4.7 stars, 417 ratings, USD 29.99 annual IAP, version 3.12.1. Same style privacy label plus Contact Info.
  - Pro https://apps.apple.com/app/apple-store/id6502648219 : 5.0 stars, 20 ratings, USD 139.99 annual IAP, version 2.12.1.
- Privacy policy read: https://www.bikefastfit.com/en/privacy/
  - "Everything you create in the apps, including riders, sessions, measurements and videos, is stored on your device." Videos and tracked body positions are uploaded only with opt in Data Sharing. Usage events, device model, purchase details are collected regardless. Earlier versions sent rider names, birthdays, contact details, medical notes. No third party analytics SDK named.
- BFF Academy page read: https://www.bikefastfit.com/academy (no numeric camera setup or knee angle ranges on the page; those are in lessons at academy.bikefastfit.com, not fetched).

### Retul (Specialized)
- Home read: https://www.retul.com/ : Retul Fit, Retul Footbeds, Saddle Sizing, "Book a Fit Near You". No prices, no technology details, no consumer app. Contact bodygeometry@specialized.com. https://www.specialized.com/us/en/retul returned 403.
- From sibling notes (research-competitors.md in this folder): marker based LED harness, Retul Fit V8 in 2025, US consumer prices roughly USD 245 to 450 per fit from shop pages, Retul Fit iPad app is fitter facing with 6 ratings.

### Bikefit.ai
- https://www.bikefit.ai/ failed with a certificate mismatch (cert is for firebaseapp.com) and https://bikefit.ai/ returned 404. The sibling notes reached the same conclusion: no product exists under that name as of 2026-11-03. There is an unrelated iOS app "BikeFit AI - Bike Fit Analyzer" (id6759576471, Apple Vision, on device, Data Not Collected, 1 rating) per research-competitors.md.

### Bike Fit Advisor
- https://bikefitadvisor.com/ redirects to https://www.bikefitadviser.com/ which was read: an educational site by a physical therapist with 29 years of fitting experience, linked to The Bicycle Studio in Grand Junction, Colorado. Online consulting offered. No app, no capture method, no prices on the home page. Not a software competitor.

### Takeaway for the contrarian argument
- Only Bike Fast Fit Elite (417 ratings) has a meaningful US rating count after roughly a decade in the category (id1145619812 is a 2016 era app id). The fitter tier has 20 ratings. MyVeloFit sells access in 2 week blocks, which is the business model of a one time event, not a habit.
- Every product sells "a fit" (absolute recommendations) from 2D side video, none publishes a numeric accuracy figure, and the honest ones (MyVeloFit FAQ) say camera consistency is the user's job.

## 2. Apple Vision body pose (read from Apple's docs JSON and WWDC transcript)

- VNDetectHumanBodyPoseRequest: https://developer.apple.com/tutorials/data/documentation/vision/vndetecthumanbodyposerequest.json : iOS 14.0+, macOS 11.0+, visionOS 1.0+. Returns VNHumanBodyPoseObservation with recognized points carrying confidence.
- Joint list: https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodypose3dobservation/jointname.json was not fetched; the 2D list was read at https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodyposeobservation/jointname.json : 19 joints (nose, neck, eyes, ears, shoulders, elbows, wrists, root, hips, knees, ankles). No foot or toe joint, so ankle angle and pedal spindle position are not directly available from 2D pose.
- VNDetectHumanBodyPose3DRequest: https://developer.apple.com/tutorials/data/documentation/vision/vndetecthumanbodypose3drequest.json : iOS 17.0+, macOS 14.0+. "If the system allows it, the request uses AVDepthData information to improve accuracy." Depth optional.
- VNHumanBodyPose3DObservation: https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodypose3dobservation.json : bodyHeight (meters), heightEstimation, cameraOriginMatrix (hip to camera transform), cameraRelativePosition, pointInImage, parentJointName.
- Article "Identifying 3D human body poses in images": https://developer.apple.com/tutorials/data/documentation/vision/identifying-3d-human-body-poses-in-images.json : 17 joints, one observation for the most prominent person, all 17 joints or none, positions in meters with origin at the root between the hips, bodyHeight is a 1.8 m reference value unless the capture session uses the LiDAR camera, localPosition is relative to the parent joint and useful for joint angles.
- WWDC23 session 111241 transcript: https://developer.apple.com/videos/play/wwdc2023/111241/ : "returns a 3D skeleton with 17 joints", "the camera may not be exactly facing your subject" (cameraOriginMatrix), depth accepted via new VNImageRequestHandler initializers with AVDepthData, left and right are relative to the person.
- Design implications: 2D request is enough for a side view differential check and runs back to iOS 14. The 3D request's cameraOriginMatrix is useful for a camera alignment score (did the user put the phone in the same place as last time) rather than for absolute angles, and the 1.8 m fallback height means absolute scale needs the user's own tape measurements, which this concept collects anyway. The HTML doc pages themselves render client side and return only a title to WebFetch, so the JSON endpoints above are the ones actually read.

## 3. Fit science used (bibliographic facts confirmed, abstracts where retrievable)

- Fonda B, Sarabon N, Li FX. Validity and reliability of different kinematics methods used for bike fitting. Journal of Sports Sciences 2014;32(10):940-946. PMID 24499342. Abstract read via Europe PMC: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:10.1080/02640414.2013.868919&resultType=core&format=json . Eleven cyclists, knee angle at bottom dead centre measured with 13 camera 3D system (reference), 2D high speed camera and electrogoniometer. All other methods significantly underestimated knee angle versus 3D. Dynamic methods differed from static by effect sizes 0.4 to 0.6. 2D kinematics judged a valid tool; authors recommend adding a correction factor of 2.2 degrees. Crossref metadata also read: https://api.crossref.org/works/10.1080/02640414.2013.868919
- Ferrer-Roca V, Roig A, Galilea P, Garcia-Lopez J. Influence of saddle height on lower limb kinematics in well-trained cyclists: static vs. dynamic evaluation in bike fitting. J Strength Cond Res 2012;26(11):3025-3029. PMID 22190163. Abstract read via Europe PMC: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:22190163%20AND%20SRC:MED&resultType=core&format=json . Saddle height outside 106 to 109 percent of inseam in 56.5 percent of subjects; inappropriate knee flexion by the dynamic method in 26 percent; target knee flexion 30 to 40 degrees; proposed range 108.6 to 110.4 percent of inseam. Semantic Scholar metadata also read: https://api.semanticscholar.org/graph/v1/paper/DOI:10.1519/JSC.0b013e318245c09d?fields=title,authors,year,venue,abstract,externalIds
- Bini R, Hume PA, Croft JL. Effects of bicycle saddle height on knee injury risk and cycling performance. Sports Medicine 2011;41(6):463-476. Only Crossref metadata read (no abstract): https://api.crossref.org/works/10.2165/11588740-000000000-00000
- Not retrieved: Holliday et al. 2017 (static vs dynamic goniometer, inclinometer and 3D) at the guessed DOI 10.1080/17461391.2017.1328708 returned 404 on Crossref, so the DOI guess is wrong and no claim is made from it. Semantic Scholar rate limited (429) three of four calls.
- Why this matters for the wedge: the 2D method's error against 3D is a systematic bias (a correction factor is proposed), and dynamic versus static differs systematically. A differential design (compare the rider to their own earlier capture with the same camera placement) cancels systematic bias and keeps only placement and jitter noise, which the app can measure from the reference clip itself.

## 4. The contrarian argument (why nothing has broken out)

1. They sell an event, not a job. A fit is wanted a few times in a cycling life. MyVeloFit's best selling unit is 2 weeks of access for USD 35. There is no reason to open the app in week three, so there is no word of mouth engine and no compounding data per user.
2. Absolute prescriptions from a 2D side view invite the one comparison they cannot win: against the rider's human fitter. The science says 2D reads low by about 2 degrees and that static and dynamic methods disagree, and no app publishes an error figure. The first time the app says "raise your saddle 8 mm" and the fitter says no, the app is deleted.
3. Capture friction is front loaded for a one time payoff: trainer, tripod, full body in frame, both sides, resistance on the pedals (MyVeloFit FAQ). People do it once.
4. Fitters are treated as the competitor (MyVeloFit Business at USD 49 to 249 per month, Bike Fast Fit Pro at USD 139.99 per year with 20 ratings) rather than as the distribution channel. A fitter has no reason to put a rival's app on a client's phone.
5. The category is undifferentiated: a dozen iOS apps in the sibling notes all do side view knee angle, which is why none can build a brand or escape Guideline 4.3 territory.

## 5. Wedge options considered

- Fit check for existing fits: good, but a one time check is still an event. Folded into the chosen wedge as the camera half.
- Tool for coaches and shops: strong distribution, weak solo dev economics with no revenue allowed, and Bike Fast Fit Pro and MyVeloFit Business already sit there. Folded in as a free "fitter hands the reference to the client" flow instead of a paid pro product.
- Pain driven diagnostic: highest intent, highest medical claim risk, and the one thing 2D pose cannot honestly do. Rejected as the lead; pain stays a user journal tag.
- Bike transfer tool: a real, repeated job for the triathlon target (road plus TT, travel, race rentals, new bike) and pure geometry the user can verify with a tape. Chosen as half the core loop.
- Measurement notebook: boring, useful on day one with no camera at all, and the thing that makes the camera meaningful (it supplies scale and the "known good" reference). Chosen as the spine.

Chosen wedge: a fit record and drift checker. The app never says where the rider should be. It records where the rider was when the fit was known good (tape numbers plus a pose signature), tells the rider when today's position differs from that reference and by how much relative to their own noise band, and carries the fit to a second bike.

## 6. Design details (see structured output for the condensed version)

Capture protocol for a reference or a check:
- Bike on trainer or rollers, drive side toward the camera, phone in landscape on a tripod, bottle or chair at hip height, 2 to 3 m away so the whole body plus wheels fit. Device level shown live using CoreMotion. For checks, a ghost outline of the reference frame is overlaid and an alignment score (silhouette overlap plus pointInImage root position and shoulder to hip pixel length versus the reference) must pass before recording starts.
- 20 to 30 seconds of easy pedalling at the rider's usual cadence. Vision 2D pose per frame on device at 60 fps, joints kept only when confidence passes a threshold. Video is discarded by default; joint tracks are stored. Optional keep clip.
- Derived per stroke: knee angle at the most extended point, knee angle at the most flexed point, hip angle at top of stroke, torso angle to horizontal, elbow angle, head to bar offset. Each reported as median and spread over strokes. The reference clip's spread is the noise band for later checks.
- Manual notebook per bike: saddle height from bottom bracket centre to saddle top, saddle setback from bottom bracket, saddle nose to bar centre, bar drop, saddle model and width, crank length, stem length and angle, for TT and tri also pad stack, pad reach, extension tip to saddle nose, and pad centre to centre. Each field has a line drawing of where to put the tape. Frame stack and reach entered from the maker's chart.

Recommendations (phrased as differences and checklists, never prescriptions):
- "Knee extension today 147 degrees, reference 143, your usual spread 2. Changes like this usually show up when the saddle sits higher or further back than before. Reference saddle height 745 mm, setback 62 mm. Tape it?"
- "Torso angle matches your reference within noise. Nothing to check."
- Transfer: "To match your road reference on the TT bike enter its stack and reach; here are the saddle height, setback and pad positions to set, then run a check to confirm your body lands in the same place."
- Copy rules: no "optimal", no "injury", no "pain", no "fix". Pain tags are user journal entries shown on the timeline next to checks; the app draws no causal arrow and says so in onboarding. Accuracy caveats shown inline: side view video reads a few degrees differently from lab 3D systems, which is why this app compares you with yourself.

First session: pick bike type, name the bike, lock in the fit with the tape checklist (skippable), optional reference capture, result card "Reference saved" with numbers and noise band, export a one page fit card PDF. Under 10 minutes without the camera, about 15 with it.

Come back loop (event driven, local notifications only, all opt in): bike packed or travelled, new saddle or shoes or stem logged, race date within 2 weeks, seasonal check every 8 weeks off by default, pain tag logged, and a fitter hand off where a shop sets the reference on the client's phone at the end of a paid fit so the client comes back to the shop when drift is flagged.

## 7. Open questions
- Real world noise band of Vision 2D knee angle on cyclists in dark kit against a garage background; needs a bench test with 5 to 10 riders before committing to tolerance thresholds.
- Whether cameraOriginMatrix from the 3D request is stable enough across sessions to drive the alignment score, or whether a silhouette plus scale heuristic from the 2D request is better.
- Degrees of knee angle change per mm of saddle height change was not sourced in this session; needed to translate drift into a tape measure hint. The Ferrer-Roca and Bini papers above are the places to look first.
- Name collision checks not done (no search budget). Candidate names are below in the structured output.
- Whether CloudKit private database sync is compatible with a Data Not Collected label; kept out of 1.0.
