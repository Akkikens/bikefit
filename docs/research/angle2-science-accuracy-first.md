# Angle 2: Science and accuracy first. Research notes for an on-device iPhone bike fit app

Date: 2026-11-03. Designer role: one of six independent panelists. Note: the task said "using the filename given below" but no filename was supplied, so this file is named angle2-science-accuracy-first.md.

## 1. Competitor landscape (what was actually read)

### MyVeloFit (web app, video uploaded to servers)
- Home page: riders do a mobility assessment, set bike type and goals, record a pedaling video on a trainer, upload it through the website. Marketing claims: "world's #1" online bike fit, 200k active users, 450k fits processed, 100+ countries. No independent validation posted; one fitter testimonial says output comparable to Retul. Bike types shown: TT, road, MTB. Web only, "not in the app store". https://www.myvelofit.com/
- Pricing page: Starter free (1 rider, 1 bike, 1 upload per week, basic analysis, no detailed report). Enthusiast 35 USD one time, two weeks. Pro 75 USD per year, unlimited uploads. Expert Review add on from 75 USD. 30 day better fit guarantee. https://myvelofit.com/pricing
- TrainerRoad forum thread: users report results close to Retul and Frame Finder fits, but also: saddle height "kept rising" session after session, reach recommendation drifted from 10 mm to 40 mm across repeat videos, missed a left/right asymmetry a human caught, sensitive to camera placement (users resorted to tripods and laser levels), cannot do cleats or rear view. https://www.trainerroad.com/forum/t/opinions-on-myvelofit/100943.md
- Cycling Weekly head to head with an in-person fitter exists but the article body could not be fetched (title only): https://www.cyclingweekly.com/fitness/bike-fit/is-ai-tech-good-enough-for-bike-fitting-i-had-both-an-ai-and-an-in-person-bike-fit-at-my-local-shop-heres-how-they-differed

### BikeFit AI - Bike Fit Analyzer (iOS, developer Jonas Friesslich)
- Free, 1.9 MB, requires iOS 26.2, App Privacy "Data Not Collected", analysis on device with Apple Vision, no upload, no account. Metrics: knee extension and flexion, hip angle, back angle, elbow angle, ankle angle (heel drop), each with a traffic light and "ideal range". Protocol: phone at hub height side on, framing guide, pedal 30 s, results in under 20 s. Endurance vs Performance target ranges. Session history and side by side compare. Says it teaches rather than prescribes and is not a substitute for a professional fit. 1 rating. https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471
- This is the closest direct competitor to the planned app: same stack, same privacy posture. It does NOT show error bars, repeatability, or camera geometry checks. That is the gap.

### Bike Fast Fit Elite (iOS, Double Dog Studios)
- Free with 29.99 USD per year subscription. 4.7 stars, 417 ratings (US). Auto records 3.5 s (4 to 5 pedal strokes) when pedaling detected. Markerless tracking since 2.0 (earlier versions used stickers). Angles on key frames, saddle advice, knee tracking, stem and cockpit calculators, Compare, PDF report. Privacy label: data not linked to identity collected (Health and Fitness, Identifiers, Usage Data, etc). https://apps.apple.com/us/app/bike-fast-fit-elite/id1145619812
- DC Rainmaker 2013 review of the original (marker based): https://dcrainmaker.com/2013/10/automated-measurement-review.html

### Retul (Specialized), the professional benchmark
- Product pages: https://www.retul.com/retul-fit and https://retul.com/bike-fit (marketing, retailers quote "within 1 mm").
- Independent validation: Scoz et al 2021, Sensors 21(13):4473, "Validation of a 3D Camera System for Cycling Analysis". 11 amateur male triathletes, own bikes on smart trainer, 120 s at 60 to 90 rpm, 100 W. Retul Vantage (18 Hz, LED markers, interpolation) vs Vicon Bonita (240 Hz). Mean differences under 1 degree for most angles; r 0.76 to 0.95; ICC 0.79 to 0.96; SEM: max knee flexion 0.36 deg, max knee extension 0.59 deg, knee range 1.27 deg, hip open 1.87 deg; Bland Altman bias flagged in Ankle Range, Knee Range, Knee Lateral Travel, Hip Lateral Travel. Limits: n 11, right side only, cadence capped, men only. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- Retul intra rater reliability thesis (UFMG, Brazil), abstract only, "good intra rater reliability": https://repositorio.ufmg.br/bitstream/1843/65097/2/Does%20the%20Ret%c3%bcl%20System%20provide%20reliable%20kinematics%20information%20for%20cycling%20analysis_.pdf

### Bike Fit Advisor
- No standalone app found by that name. Closest: BikeCAD "Fit Advisor" (frame geometry recommendation, free version saddle height only): https://bikecad.ca/fit_advisor and https://www.bikecad.ca/node/847. Also "Bike Fit Performance" for shops: https://apps.apple.com/app/id6476923182. Treat as unresolved.

### Other
- Aggregator of fit apps (secondary): https://join.cc/cycling-tips/best-bike-fit-app

## 2. Apple Vision body pose capability (primary docs)
- VNDetectHumanBodyPoseRequest: 2D, iOS 14+. Returns VNHumanBodyPoseObservation; points normalized with lower left origin, each with confidence. https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest.md
- VNDetectHumanBodyPose3DRequest: iOS 17+. "detects points on human bodies in 3D space, relative to the camera"; uses AVDepthData if available. https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest.md
- "Identifying 3D human body poses in images": 17 joints (wrists, elbows, shoulders, hips, knees, ankles, top and center of head, spine, root, center shoulder). Only the most prominent person, one observation, all 17 joints or none. Positions in meters relative to root joint between the hips. bodyHeight is measured only when an AVCaptureSession uses the LiDAR camera, otherwise it returns a reference 1.8 m. Depth not required but improves accuracy. cameraRelativePosition and cameraOriginMatrix available; pointInImage projects back to 2D. localPosition relative to parentJoint simplifies joint angles. https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images.md
- Implication: the 2D request has no foot/toe landmark (ankle is the most distal point), so ankle plantarflexion and heel drop are weakly defined from Vision alone. The 3D request has no foot or ear landmarks either. Scale (meters) without LiDAR is referenced to an assumed 1.8 m, so absolute distances (saddle height in mm) must come from a user supplied scale object (crank length, wheel diameter) or LiDAR, not from the pose alone.
- No Apple published accuracy figures (degrees or mm) for either request were found. This is an open question; the app must measure its own.

## 3. Biomechanics evidence used for the recommendations
- Bini, Hume, Croft 2011, Sports Medicine 41(6):463 to 476, review of saddle height: methods varied and not well established; patellofemoral compressive force inversely related to saddle height; changes under 4 percent of trochanteric length do not seem to affect injury risk or performance; overuse knee pain in about 50 percent of cyclists. Abstract via https://read.qxmd.com/read/21615188/effects-of-bicycle-saddle-height-on-knee-injury-risk-and-cycling-performance (PDF at paulogentil.com could not be text extracted). A Leeds Beckett paper cites it for a dynamic knee flexion 25 to 30 deg target: https://eprints.leedsbeckett.ac.uk/id/eprint/4823
- Bini and Priego Quesada 2022 systematic review (J Sports Sci): limited evidence on effects of saddle height on supramaximal performance or injury risk (abstract via search result; not fetched directly).
- Holmes, Pruitt, Whalen 1994, Clin Sports Med 13(1):187 to 205: origin of the static 25 to 35 deg knee angle at BDC, framed as injury prevention. Cited via https://core.ac.uk/download/491725486.pdf
- Ferrer Roca et al 2012, JSCR 26(11):3025 to 3029: static inseam method (106 to 109 percent) left 56.5 percent outside range; dynamic 2D knee flexion 30 to 40 deg at max extension off target in 26 percent; proposes regression (R2 0.963). https://www.bisp-surf.de/Record/PU201302001220
- Fonda, Sarabon, Li 2014, J Sports Sci 32(10):940 to 946: 2D video valid for knee angle in bike fitting, underestimates vs 3D; add 2.2 deg correction; good intra session reliability for all dynamic methods. https://lida.sport-iat.de/bdr/Record/4032256?lng=en
- J Sci Cycling 2014 3D repeatability (15 subjects, 3 sessions): typical intra session error 1.7 deg dynamic knee flexion vs 4.2 deg static; 4.2 to 4.9 deg ankle; dynamic knee about 5.4 deg greater than static; suggests 30 to 40 deg for dynamic. Abstract only via https://lida.sport-iat.de/ta/Record/4032945
- Acta Bioeng Biomech 2019 (26 cyclists, 2D): dynamic knee angle at BDC 8 deg greater than static; proposes 33 to 43 deg dynamic. PDF could not be text extracted; search snippet source https://actabio.pwr.edu.pl/fcp/PGBUKOQtTKlQhbx08SlkTUARAUWRuHQwFDBoIVURNWH5XFVZpCFghUHcKVj0GQUw/302/public/publikacje/v21-4-2019/70.pdf and https://yadda.icm.edu.pl/baztech/element/bwmeta1.element.baztech-4dcd84f3-5e16-4d3d-8dc5-8f3cc6e64196
- Bini et al 2024, Sport Sciences for Health, "Validity of neural networks in determining lower limb kinematics in stationary cycling": 26 cyclists, TransPose and MediaPipe vs markers, standard video to mimic phones. Typical errors 1 to 10 deg (TransPose) and 3 to 9 deg (MediaPipe); correlations 0.47 to 0.98 vs 0.25 to 0.96; both poor at foot and ankle. https://link.springer.com/article/10.1007/s11332-023-01075-7 (paywalled; figures from abstract via https://www.springermedizin.de/validity-of-neural-networks-in-determining-lower-limb-kinematics/25476968)
- Earlier CNN study (OpenPose, MSRA) 4 to 8 deg hip and knee differences, poor to moderate agreement: https://informahealthcare.com/doi/full/10.1080/02640414.2023.2194725
- Fintelman et al 2015, Scand J Med Sci Sports 26:528 to 534: 21 trained cyclists, torso 0, 8, 16 deg at 70 percent MAP, 85 rpm. Lower torso raised VO2 and ventilation and lowered gross efficiency; authors still judge aero gains outweigh. https://research.birmingham.ac.uk/en/publications/effect-of-different-aerodynamic-time-trial-cycling-positions-on-m/
- Garcia Lopez and Ferrer Roca: small saddle changes shift coordination; another study: lower vs higher saddle changed hip, knee, ankle extension by about 4, 7, 8 deg (search snippets, abstracts only).

Takeaway for recommendations: the only joint with a reasonable evidence base and a measurable, repeatable signal from a phone is the knee at or near maximum extension (dynamic 30 to 40 deg, or 33 to 43 deg at BDC depending on method). Everything else (hip, back, elbow, ankle) has weaker evidence, larger pose error, or both. The app's advice must be structured around that asymmetry.

## 4. App Store policy
- Guideline 1.4.1: "Apps must clearly disclose data and methodology to support accuracy claims relating to health measurements, and if the level of accuracy or methodology cannot be validated, we will reject your app." Also "Apps should remind users to check with a doctor". https://developer.apple.com/app-store/review/guidelines/
- Guideline 5.1.3 health data restrictions, 2.5.14 camera recording consent indication (same page).
- Developer forum reports of wellness apps flagged under 1.4.1 for health measurements without sources: https://developer.apple.com/forums/thread/807508 and https://developer.apple.com/forums/thread/703502

## 5. Market size anchor (secondary)
- IRONMAN says more than 200,000 registrations for IRONMAN and 70.3 in 2024 (registrations, not unique athletes). https://www.endurancesportswire.com/future-of-triathlon-showing-positive-signs-ironman-releases-data-highlighting-areas-of-growth-globally-survey-results-revealing-areas-of-opportunity-and-a-vision-for-growing-the-sport-of-triathlon/ and Slowtwitch analysis https://slowtwitch.com/industry/digging-into-ironmans-data-on-participation-and-barriers-to-entry/

## 6. Open questions (no source found)
- Apple publishes no accuracy numbers for VNDetectHumanBodyPoseRequest or the 3D request. Must be measured in house against a goniometer or marker rig.
- No peer reviewed day to day (between session) reliability for phone pose estimated knee angle on a bike. The 3D mocap figure (1.7 deg intra session) is the closest proxy.
- No evidence base found for elbow angle, back angle or hip angle targets beyond coaching convention and one TT torso study.
- Cycling Weekly article body not retrievable.
- "Bike Fit Advisor" as a product could not be identified.
- Name candidates (Plumbline, Sagitta, Kneeline, Fitbench, Angleright) not yet checked in the App Store or trademark databases.
