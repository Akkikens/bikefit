# Angle 3 research notes: triathlete and TT user first (2026-11-03)

Note on method: the shared WebSearch budget for this turn was already used up when this agent started, so every source below was reached by fetching known URLs directly with WebFetch. No search engine results were used. Items marked OPEN could not be verified.

## Competitors

### MyVeloFit (web app, video upload, cloud analysis)
- Homepage: https://www.myvelofit.com/
  - Record and upload a video of yourself pedalling on a trainer, rollers, smart bike or spin bike. Any phone camera works. Web app, not an App Store product.
  - Claims: "world's #1 online bike sizing and fitting tools", 200k active users, 450k fits processed, 3.5bn data points, 30 day Better Fit Guarantee. No independent accuracy validation on the page.
  - TT mentioned only in an image caption ("time trial, road, and mountain bikes"). No TT specific page found.
- Pricing: https://www.myvelofit.com/pricing
  - Starter $0 (1 upload per week, basic analysis), Enthusiast $35 one time for 2 weeks, Pro $75 per year, Expert Review add on from $75.
- Setup guide: https://www.myvelofit.com/fit-academy/getting-setup-for-your-bike-fit/
  - Camera square to the side, level, centred on rider, more than 3 m away, roughly saddle height (over 1 m). Record 20 to 30 s, trim to middle 10 to 15 s. 720p or 1080p, no wide angle, no slow motion. Warm up 10 to 15 min, cadence 85 to 95 rpm, realistic resistance. One hand position per video. Avoid all black clothing, plain background, no mirrors or other people, light from camera side.
  - Does not mention aero bars or TT.

### Bike Fast Fit (Double Dog Studios, iPhone, on-device model)
- Site: https://www.bikefastfit.com/
  - Phone side on to the bike on a trainer, few seconds of pedalling. "Our own model, built and trained specifically for cyclists on bikes", 240 fps. Reports knee angle at max extension, hip angle, torso and shoulder position, shown as ranges. Claims a database of over 1.15 million rider videos. No quantitative accuracy figure.
  - Three apps: EZ $9.99 per year, Elite $29.99 per year, Pro $139.99 per year (fitters). "Works with road, gravel, mountain, TT, and indoor bikes." No triathlon specific content.
- App Store EZ: https://apps.apple.com/us/app/id1578925255
  - 4.6 stars, 176 ratings. Requires iOS 15.5. Records a 4 s video of 4 to 5 pedal strokes. App Privacy: "Data Not Linked to You" including Health & Fitness, User Content, Identifiers, Usage Data, Diagnostics. Not "Data Not Collected".
- App Store Elite: https://apps.apple.com/us/app/id1145619812
  - 4.7 stars, 417 ratings. Privacy: Data Not Linked to You, analytics includes fitness data, photos or videos, user content, device IDs. Version 3.6.0 added "two contact points for Aero fits"; a review mentions a tri bike bike type setting. Version 2.0 added iCloud storage for fit data.

### Retul (Specialized, in person 3D motion capture)
- https://www.retul.com/ and https://www.retul.com/retul-fit
  - Retul Vantage 3D motion capture, LED markers on 8 anatomical points, real time data, Zin digital bike map, report. Fitter found via scheduler.retul.com. No pricing, no TT page, one pro triathlete testimonial (Richard Murray).

### Bikefit.ai
- OPEN: https://bikefit.ai/ returned 404, https://www.bikefit.ai/ had a certificate error (firebaseapp.com), https://bikefit.ai/en 404. Could not verify this product in this session.

### Bike Fit Advisor
- https://bikefitadvisor.com/ redirects to https://www.bikefitadviser.com/ which is a physical therapist's in person fitting and education site in Grand Junction, Colorado (29 years as a PT). Not an app. If "Bike Fit Advisor" is a different app, OPEN.

## Apple Vision body pose

- VNDetectHumanBodyPoseRequest (2D): https://developer.apple.com/tutorials/data/documentation/vision/vndetecthumanbodyposerequest.json
  - iOS 14.0+. Produces VNHumanBodyPoseObservation.
- 2D joint names (19): https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodyposeobservation/jointname.json
  - nose, leftEye, rightEye, leftEar, rightEar, neck, left/right shoulder, elbow, wrist, root, left/right hip, knee, ankle. Normalized image coordinates with per point confidence.
- VNDetectHumanBodyPose3DRequest: https://developer.apple.com/tutorials/data/documentation/vision/vndetecthumanbodypose3drequest.json
  - iOS 17.0+, macOS 14.0+. "Detects points on human bodies in 3D space, relative to the camera." Uses AVDepthData to improve accuracy when available.
- VNHumanBodyPose3DObservation: https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodypose3dobservation.json
  - bodyHeight (meters), heightEstimation (measured vs reference), cameraOriginMatrix (hip to camera transform), cameraRelativePosition(joint), pointInImage(joint).
- 3D joint names (17): https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodypose3dobservation/jointname.json
  - topHead, centerHead, centerShoulder, left/right shoulder, elbow, wrist, left/right hip, knee, ankle, root, spine. No feet, no toes, no eyes or ears.
- WWDC23 session 111241 "Explore 3D body pose and person segmentation in Vision": https://developer.apple.com/videos/play/wwdc2023/111241/
  - 17 joints, positions in meters with origin at root (hip center). Without depth, height is assumed at a 1.8 m reference; with depth (LiDAR) height is measured. One skeleton per frame, most prominent person. No stated accuracy figures.
- Sample "Detecting human body poses in 3D with Vision": https://developer.apple.com/tutorials/data/documentation/vision/detecting-human-body-poses-in-3d-with-vision.json
  - Needs A12 or later. "The input image should have all limbs of the subject visible."
- Implication: 3D pose has no foot or toe joint, so ankle angle and cleat position cannot be measured from it. Knee, hip, torso, shoulder and elbow angles are feasible from the side view in 2D with 3D as a sanity check for camera squareness (cameraOriginMatrix rotation).

## Markerless accuracy (for honesty copy)
- Europe PMC query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=smartphone%20AND%20%22pose%20estimation%22%20AND%20cycling%20AND%20(validity%20OR%20accuracy)%20AND%20%22joint%20angle%22&format=json&resultType=core&pageSize=6&sort=CITED%20desc
  - Cabuk S et al., Biology of Sport 2026, DOI 10.5114/biolsport.2026.154942: OpenCap meta analysis, pooled joint angle RMSE 5.877 degrees (4.9 to 5.2 after sensitivity), tasks not cycling specific.
  - Wade L et al., PeerJ 2022, DOI 10.7717/peerj.12995: markerless joint angles "not yet sufficiently accurate for clinical applications" (gait).
  - Uhlrich SD et al., PLoS Comput Biol 2023, DOI 10.1371/journal.pcbi.1011462: OpenCap from smartphone video.
- OPEN: no cycling specific validation of single phone 2D pose vs 3D motion capture was found in this session. A second query returned only a thermography review (Clarys W, Sensors 2025, DOI 10.3390/s25082356).

## Fit science used in the concept
- Saddle height / knee angle, Europe PMC query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22saddle%20height%22%20AND%20%22knee%20angle%22%20AND%20cycling&format=json&resultType=core&pageSize=5&sort=CITED%20desc
  - Peveler WW, JSCR 2008, PMID 18545167: 25 degree knee angle gave lower VO2 than 35 degrees or 109 percent inseam.
  - Peveler WW, JSCR 2011, PMID 20581695: 25 degree knee angle better economy and peak power than 109 percent inseam; 109 percent fell outside 25 to 35 degrees 73 percent of the time.
  - Ferrer-Roca V, JSCR 2012, PMID 22190163: static vs dynamic evaluation differ; proposes 108.6 to 110.4 percent of inseam.
  - Priego Quesada JI, J Sports Sci 2017, DOI 10.1080/02640414.2016.1215496: most comfortable at recommended knee angle, least comfortable at 40 degree knee with 35 degree trunk flexion.
- Bini query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=AUTH:%22Bini%20R%22%20AND%20%22saddle%20height%22%20AND%20review&format=json&resultType=core&pageSize=3
  - Systematic review, J Sports Sci 2022, PMID 34706617, DOI 10.1080/02640414.2021.1994727: strong evidence that saddle height should be set with dynamic knee angle measurement.
  - Delphi consensus on bicycle set up dimensions and kinematics, Sports Med 2024, PMID 39304615, DOI 10.1007/s40279-024-02100-6.
- TT torso angle, Europe PMC query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22time%20trial%22%20AND%20%22torso%20angle%22%20AND%20cycling%20AND%20(aerodynamic%20OR%20drag)&format=json&resultType=core&pageSize=5&sort=CITED%20desc
  - Fintelman DM, J Biomech 2014, PMID 24726654: optimal torso angle falls as speed rises; aero gains outweigh power losses above about 46 km/h; fully horizontal torso not optimal; more upright better below 30 km/h.
  - Fintelman DM, J Sports Sci 2015, PMID 25658151: lower torso angles reduce peak power and physiological function, worst at 0 degrees.
  - Fintelman DM, Scand J Med Sci Sports 2016, PMID 25996563: smaller torso angles lower gross efficiency; at 70 percent MAP aero gains still outweigh in trained cyclists.
  - Relevance: age group Ironman bike speeds are mostly well below 46 km/h, so the aero vs power tradeoff is real for this user and "lowest possible" is wrong advice.
- Seat tube angle and running, Europe PMC query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22seat%20tube%20angle%22%20AND%20triathlon%20AND%20running&format=json&resultType=core&pageSize=5&sort=CITED%20desc
  - Garside I and Doran D, J Sports Sci 2000, DOI 10.1080/026404100419883: 81 degree seat tube angle produced faster 10 km runs than 73 degrees, biggest gains in first 5 km.
  - Silder A, J Appl Biomech 2011, DOI 10.1123/jab.27.4.297: hand position affected kinematics more than seat tube angle alone; running not measured.
  - Bisi MC, J Electromyogr Kinesiol 2012, DOI 10.1016/j.jelekin.2012.04.013: no significant kinematic or VO2 effect of seat tube angle; trend toward less gastrocnemius and biceps femoris activation.
- Cycle to run transition, Europe PMC query: https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=triathlon%20AND%20cycling%20position%20AND%20%22subsequent%20running%22&format=json&resultType=core&pageSize=5&sort=CITED%20desc
  - Millet GP, Br J Sports Med 2000, DOI 10.1136/bjsm.34.5.384: running after cycling raises running energy cost 1.6 to 11.6 percent; forward trunk lean most notable change.
  - Vleck VE, Int J Sports Med 2006, DOI 10.1055/s-2005-837502: faster early bike inversely correlated with run performance.
  - Evans SA, Sensors 2021, PMID 34502790: posterior cleat position reduced trunk acceleration and RPE in the following run when using aero bars.

## App Store rules relevant to copy and privacy
- Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
  - 1.4.1: apps must disclose data and methodology supporting health measurement accuracy claims; remind users to check with a doctor before medical decisions.
  - 5.1.3: health and fitness data may not be used for advertising or data mining; do not store personal health information in iCloud.
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
  - "Data that is processed only on device is not 'collected' and does not need to be disclosed." Collect means transmitting off device and retaining. So on device pose analysis with local storage supports a Data Not Collected label. Avoid CloudKit sync of fit data to keep it simple (Bike Fast Fit Elite syncs to iCloud and declares collection).

## Race season timing
- Ironman World Championship: https://en.wikipedia.org/wiki/Ironman_World_Championship
  - 2023 to 2025 split between Nice and Kona; from 2026 both men's and women's races return to Kailua-Kona. 2025 women's race in Kona referenced by an article dated 12 October 2025. Exact 2026 dates not on the page as fetched.
- Ironman 70.3 World Championship: https://en.wikipedia.org/wiki/Ironman_70.3_World_Championship
  - 2025 Marbella, Spain; 2026 Nice, France. Exact dates not on the page as fetched.
- OPEN: ironman.com could not be fetched from this environment, so the full 2026 race calendar and participation numbers are unverified. Working assumption for design: northern hemisphere A races cluster May to October, world championships in September and October, with Asia Pacific and southern hemisphere races filling November to March. Verify before writing season copy.

## Name collision checks
- OPEN: no App Store or trademark search was possible this session. Candidates below need checking in the App Store, USPTO TESS and EUIPO before use.
