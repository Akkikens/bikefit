# Research notes: how fitters and apps capture and measure a bike fit (protocol design input)

Date: 2026-11-03. Researcher: Fable subagent. Scope: capture protocol for a phone camera, on device AI bike fit (road, TT/tri, gravel).
Rule followed: every number below has the URL that was actually read next to it. Where a page could not be opened, that is stated.
No em or en dashes are used in this document.

## 0. Sources that were actually read (primary list)

Peer reviewed
- Millour, Duc, Puel, Bertucci 2019, Acta of Bioengineering and Biomechanics 21(4): "Comparison of static and dynamic methods based on knee kinematics to determine optimal saddle height in cycling". PDF read in full via pdftotext. https://actabio.pwr.edu.pl/fcp/PGBUKOQtTKlQhbx08SlkTUARAUWRuHQwFDBoIVURNWH5XFVZpCFghUHcKVj0GQUw/302/public/publikacje/v21-4-2019/70.pdf
- Bini, Hume, Croft 2011, Sports Medicine 41(6):463-476, "Effects of Bicycle Saddle Height on Knee Injury Risk and Cycling Performance". PDF read (OCR text). https://paulogentil.com/pdf/Effects%20of%20Bicycle%20Saddle%20Height%20on%20Knee%20Injury%20Risk%20and%20Cycling%20Performance.pdf
- Bini and Hume 2016, Human Movement 17(1):36-42, "A comparison of static and dynamic measures of lower limb joint angles in cycling: application to bicycle fitting". Abstract read. https://openrepository.aut.ac.nz/items/9fba7a89-48d4-43cd-8515-9925d3aefd63/full and https://hummov.awf.wroc.pl/doi/10.1515/humo-2016-0005
- Holliday and Swart 2021, Sports Medicine and Health Science 3(2):93-100, "Anthropometrics, flexibility and training history as determinants for bicycle configuration". Full text read. https://pmc.ncbi.nlm.nih.gov/articles/PMC9219349
- Scoz et al 2021, Sensors 21(13):4473, "Validation of a 3D Camera System for Cycling Analysis" (Retul Vantage vs Vicon). Full text read. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- Branco, Resende, Carpes, Mendonca 2022, Journal of Science and Cycling 11(3), "Does the Retul System provide reliable kinematics information for cycling analysis?". PDF read. https://repositorio.ufmg.br/bitstream/1843/65097/2/Does%20the%20Ret%c3%bcl%20System%20provide%20reliable%20kinematics%20information%20for%20cycling%20analysis_.pdf
- Bini, Serrancoli, Santiago, Pinto, Moura 2023, Journal of Sports Sciences 41(1):36-44, "Criterion validity of neural networks to assess lower limb motion during cycling". Only metadata page read (full text 403). https://scholars.unf.edu/en/publications/criterion-validity-of-neural-networks-to-assess-lower-limb-motion/
- Fonda, Sarabon, Li 2014, J Sports Sci 32(10):940-946, "Validity and reliability of different kinematics methods used for bike fitting". Only search snippets, not read directly. https://lida.sport-iat.de/bdr/Record/4029658

Vendor and app pages
- MyVeloFit setup instructions (Dec 2023, Justin Goulding): https://www.myvelofit.com/fit-academy/myvelofit-setup-instructions/ (same article also at https://www.myvelofit.com/?p=3519)
- MyVeloFit "Getting setup for your bike fit" (Oct 2022): https://www.myvelofit.com/fit-academy/getting-setup-for-your-bike-fit/
- MyVeloFit "Our process": https://www.myvelofit.com/our_process
- MyVeloFit home / marketing: https://www.myvelofit.com/?p=5338
- MyVeloFit "How to get the most out of your bike fit": https://www.myvelofit.com/fit-academy/how-to-get-the-most-out-of-your-bike-fit/
- MyVeloFit "New bike fit ranges" (Jan 2022, no numbers): https://www.myvelofit.com/fit-academy/new-bike-fit-ranges/
- MyVeloFit "The 4 bike measurements every rider needs": https://www.myvelofit.com/fit-academy/the-four-bike-measurements-every-rider-needs/ (also https://www.myvelofit.com/?p=4132)
- MyVeloFit "Bicycle Geometry 101: Fit Geometry": https://www.myvelofit.com/fit-academy/bicycle-geometry-101-fit-geometry/
- MyVeloFit "Cycling Cleat Positioning 101": https://www.myvelofit.com/fit-academy/cycling-cleat-positioning-101/
- MyVeloFit "Bike Fitting: What to adjust first?": https://www.myvelofit.com/fit-academy/bike-fitting-order-of-adjustments/
- MyVeloFit "Saddle Height 101": https://www.myvelofit.com/fit-academy/saddle-height-101-a-comprehensive-guide-to-setting-your-saddle-height/
- MyVeloFit "Saddle Fore-Aft Positioning 101": https://www.myvelofit.com/fit-academy/saddle-fore-aft-positioning-101/
- MyVeloFit "Saddle Tilt 101": https://www.myvelofit.com/fit-academy/saddle-tilt-101/
- MyVeloFit "Best ways to adjust reach": https://www.myvelofit.com/fit-academy/best-ways-to-adjust-reach-on-your-bike/
- MyVeloFit "Ankling in cycling": https://www.myvelofit.com/fit-academy/the-truth-about-ankling-in-cycling/
- MyVeloFit TT bike UCI measurement without tools: https://www.myvelofit.com/fit-academy/how-to-measure-and-set-up-your-time-trial-bike-for-uci-regulations-without-any-fancy-tools-0/
- MyVeloFit Fit Academy index: https://www.myvelofit.com/fit-academy/
- BikeFit AI - Bike Fit Analyzer (Jonas Friesslich), App Store: https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471 (bikefit.ai domain returned 404; this App Store app is the closest match to "Bikefit.ai")
- Bike Fast Fit EZ, App Store: https://apps.apple.com/us/app/bike-fast-fit-ez/id1578925255
- Bike Fast Fit Pro, App Store: https://apps.apple.com/app/id6502648219
- Bike Fast Fit website: https://bikefastfit.com
- Bike Fast Fit FAQ: https://bikefastfit.com/faq
- DC Rainmaker 2013 review of Bike Fast Fit: https://dcrainmaker.com/2013/10/automated-measurement-review.html
- Retul fit at Landry's (8 LED markers): https://www.landrys.com/pages/retul-bike-fit-at-landrys
- BikeRadar Retul Fit System review (2010): https://www.bikeradar.com/reviews/maintenance/tools-kits-and-boxes/fitting-systems/retul-fit-system-review
- Cyclocross Magazine Retul fitting article: https://www.cxmagazine.com/retul-cyclocross-bike-fitting
- road.cc "Get fit: experiencing Retul": https://road.cc/content/blog/88098-get-fit-get-bike-fit-experiencing-retul
- Slowtwitch "Retul or go(niometer) it alone?": https://slowtwitch.com/industry/retul-or-goniometer-it-alone/
- Slowtwitch forum thread "Retul knee angle" (anonymous posters, low confidence): https://forum.slowtwitch.com/t/retul-knee-angle/720566
- APOPT AI cycling analysis setup guide: https://apopt.com/cycling/cycling.php
- Steve Hogg "Power to the pedal: cleat position": https://www.stevehoggbikefitting.com/bikefit/2011/04/power-to-the-pedal-cleat-position/
- Cycling Inform "How to measure your bicycle position accurately and repeatedly": https://www.cycling-inform.com/how-to-measure-your-bicycle-position-accurately-and-repeatedly
- Canyon "Road bike geometry explained": https://www.canyon.com/en-us/blog-content/road-cycling-news/road-bike-geometry-explained/b19102022.html
- ctyeh.com cleat guide: https://ctyeh.com/articles/664?lang=en
- ctyeh.com Q factor and knee alignment: https://ctyeh.com/articles/1330?lang=en
- ctyeh.com stem/bar/saddle fine tuning: https://ctyeh.com/articles/3403?lang=en
- ctyeh.com TT/tri fit: https://ctyeh.com/articles/13194?lang=en
- Velosmart blog (Adam Baskin, "Knee tracking"): https://velosmart.blogspot.com/2008/12/knee-tracking-by-steve-hogg-june-20.html
- BikeRadar "Why hip angle is crucial when using tri bars" (Garth Fox 2011): https://www.bikeradar.com/features/technique-why-hip-angle-is-crucial-when-using-tri-bars
- Apple Vision 2D body pose joint names: https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname (read via https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodyposeobservation/jointname.json)
- Apple Vision 3D body pose joint names: https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/jointname (read via https://developer.apple.com/tutorials/data/documentation/vision/vnhumanbodypose3dobservation/jointname.json)

Pages that could not be opened (403/404/429/paywall): Ferrer-Roca 2012 full text, Bini 2023 J Sports Sci full text (tandfonline 403), Bini Nascimento Nibali MediaPipe/TransPose paper (Springer login wall), Fintelman 2014 J Biomech, 220triathlon aero article, Cane Creek fit adjustments blog (429 three times), Competitive Cyclist fit hub (empty body), Cycling Weekly MyVeloFit review (truncated), Triathlete.com MyVeloFit review (login redirect), retul.com/bike-fit (404), mdpi.com (403).

## 1. Camera placement for sagittal (side) video

What the apps say
- MyVeloFit (Dec 2023 setup page): side view, left or right, camera centred on the bike, square to the rider, level; camera "approximately at saddle height off the ground"; distance such that full body head to toe stays in frame, "typically 2-3 m from the bike"; tripod best, steady hand held or propped on books acceptable; mark floor positions of rider and camera for repeatability; landscape, rotation lock off; standard lens, avoid 0.5x ultra wide; do not record 4K; 15 to 20 s of riding; trim mounting/dismounting. https://www.myvelofit.com/fit-academy/myvelofit-setup-instructions/
- MyVeloFit (Oct 2022 page): camera more than 3 m (10 ft) from rider, at about saddle height, generally above 1 m (3 ft) off the ground; level, square to the side, centred on the rider; record 20 to 30 s and trim to middle 10 to 15 s; 720p or 1080p; avoid wide angle and slow motion modes; light from the camera side; avoid windows behind rider; blank wall background; avoid black on black clothing. https://www.myvelofit.com/fit-academy/getting-setup-for-your-bike-fit/
- BikeFit AI (App Store listing): phone "side-on to your trainer" at hub height; pedal steadily at least 30 s. https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471
- Bike Fast Fit EZ (FAQ): frame whole bike and rider from the side, camera level with the top tube; use the rear camera (needs 240 fps slow motion, 1080p/240 fps ideal, iPhone XS or newer); 4 s fixed recording; stationary trainer required, outdoor free pedalling does not work. Elite/Pro: alignment aid shows a green rectangle when the phone is level and square to the bike (checks tilt and rotation, not framing). https://bikefastfit.com/faq
- Bike Fast Fit (2013, DC Rainmaker): developer said about 10 ft recommended "but it isn't necessary"; red alignment outline for framing; commenters warned to use a flat (non wide angle) lens. https://dcrainmaker.com/2013/10/automated-measurement-review.html
- APOPT guide: side camera perpendicular to the bike on the rider's left side; 60 fps and 1080p when possible; tripod; full rider in frame shoulder to foot; 10 to 20 s per view. No distance or height given. https://apopt.com/cycling/cycling.php

What the research labs do
- Millour 2019: GoPro Hero 3 at 1280 x 1080, 60 Hz, "positioned at 4 m and perpendicular to the cyclist"; Kinovea with parallax and distortion correction. https://actabio.pwr.edu.pl/... (full URL in section 0)
- Bini and Hume 2016: right sagittal plane, digital camera, cyclists on own bike on a stationary trainer, self selected gear and cadence. Abstract read. A search snippet of the full text (core.ac.uk/download/478536294.pdf, which returned 403 when fetched) said the camera was at saddle height 4 m away; treat as medium confidence. https://openrepository.aut.ac.nz/items/9fba7a89-48d4-43cd-8515-9925d3aefd63/full
- Scoz 2021 (Retul vs Vicon): rider's right side filmed by both systems; distance and height not reported. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997

Design takeaway: a phone at hip/saddle height (roughly 0.9 to 1.1 m), 2.5 to 4 m away, perpendicular to the bike's long axis, main 1x lens, landscape, 1080p at 60 fps (or 120/240 fps slow motion if the pipeline can take it), 15 to 20 s clip after trimming. A level/square guide using the phone's gyroscope plus the detected wheel axles matches what Bike Fast Fit Elite/Pro and the 2013 app already do.

## 2. Indoor trainer, cadence, resistance, warm up

- MyVeloFit requires a trainer, rollers, stationary bike or smart bike; mount so that front and rear axles are approximately level (measure floor to each axle); warm up 10 to 15 min; cadence 75 to 95 rpm at comfortable resistance, "do not pedal slowly" (Dec 2023 page); the Oct 2022 page says 85 to 95 rpm with enough resistance "to require some effort while staying comfortable"; hands on hoods for drop bars, aero bars for TT/tri, grips for flat bars; keep one hand position for the whole clip. https://www.myvelofit.com/fit-academy/myvelofit-setup-instructions/ and https://www.myvelofit.com/fit-academy/getting-setup-for-your-bike-fit/
- Bike Fast Fit EZ: stationary trainer or stationary bike required. https://bikefastfit.com/faq
- Millour 2019 lab protocol: 100 W at 80 rpm for 3 min on a Cyclus 2 ergometer; authors chose 80 rpm (lower than the 90 to 100 rpm of earlier studies) "to improve the accuracy of video analysis" and cite work showing no HA/KA/AA difference between 73 and 90 rpm. https://actabio.pwr.edu.pl/...
- Branco 2022 (Retul reliability): ~90 rpm with 200 W resistance for 3 min on a CycleOps PowerBeam, giving about 180 pedal cycles; first and last 30 s excluded for acceleration/deceleration. https://repositorio.ufmg.br/...
- Scoz 2021 (Retul validation): 60 to 90 rpm (70 to 90 in discussion), 100 W automatic load on a smart trainer, 120 s session. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- road.cc Retul experience: turbo trainer at a "manageable wattage", about 15 s of natural pedalling per capture, hands on hoods, both sides captured. https://road.cc/content/blog/88098-get-fit-get-bike-fit-experiencing-retul
- BikeRadar Retul review: multiple wattage scenarios up to stated lactate threshold selected by RPE; data points averaged by the software. https://www.bikeradar.com/reviews/maintenance/tools-kits-and-boxes/fitting-systems/retul-fit-system-review

## 3. How many pedal strokes are sampled and which frames matter

- Bike Fast Fit EZ: 4 s recording covering 4 to 5 full pedal strokes at 240 fps; Elite waits for 10 pedal strokes of steady pedalling before recording; Pro max duration 3.5, 5, 10 or 15 s. https://apps.apple.com/us/app/bike-fast-fit-ez/id1578925255 and https://bikefastfit.com/faq
- MyVeloFit: about 15 s of riding video; results "about 90 seconds" later; joint angles reported "at three points in the pedal stroke". https://www.myvelofit.com/our_process
- Millour 2019: 15 consecutive crank cycles during the last minute of a 3 min bout. https://actabio.pwr.edu.pl/...
- Scoz 2021: data split into five consecutive crank cycles from a 10 s window at 60 to 70 s. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- Branco 2022: mean of ~180 cycles over 3 min minus first/last 30 s. https://repositorio.ufmg.br/...
- Retul (CX Magazine): knee lateral travel is reported as an average per pedal stroke. https://www.cxmagazine.com/retul-cyclocross-bike-fitting

Which frames
- Knee: maximum knee extension (MKE) and knee at BDC are different frames. Millour 2019: "the Ferrer-Roca method suggests using a saddle height that induces a KA in the range of 30-40 degrees while pedalling at maximum knee extension (Dynamic MKE) which occurs when the crank arm is parallel to the seat tube". With seat tube angles of 72 to 75 degrees this puts MKE roughly 15 to 18 crank degrees before BDC (derived: the crank points down and forward, parallel to the seat tube line). Dynamic knee angle at BDC was 3 degrees greater (more flexed) than at MKE in the same riders (38 ± 5 vs 35 ± 5, n = 26), and static BDC was 30 ± 9 (8 degrees lower than dynamic BDC). Hip angle (thigh to vertical) 22 static, 29 dynamic MKE, 27 dynamic BDC. Ankle 57 static, 50 dynamic. https://actabio.pwr.edu.pl/...
- Bini and Hume 2016 (n = 30): static vs dynamic at 6 o'clock differ by a lot (static hip greater by 4.9 ± 3, static knee smaller by 8.2 ± 5, static ankle smaller by 8.2 ± 5.3) while at 3 o'clock the difference is under 1.4 degrees; so measure dynamically, or statically only at 3 o'clock. https://openrepository.aut.ac.nz/items/9fba7a89-48d4-43cd-8515-9925d3aefd63/full
- Hip: most closed hip angle near TDC (Retul "Hip Angle Closed", knee-hip-shoulder). Scoz 2021 table. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- Knee over foot / spindle: Retul "Knee Forward of Foot" and "Knee Forward of Spindle" are measured at the 3 o'clock crank position (horizontal forward crank). Slowtwitch notes the foot pick up on the metatarsal records the most forward point of the foot when the drive side crank is at 3 o'clock. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997 and https://slowtwitch.com/industry/retul-or-goniometer-it-alone/
- Bike Fast Fit Elite computes saddle height from knee angle and foot angle together at the bottom of the stroke; Pro at maximum knee extension. Elite gives heel down riders a higher knee angle target than toe down riders. https://bikefastfit.com/faq
- Ankle: Retul Ankle Min (max dorsiflexion), Ankle Max (max plantarflexion), Ankle Angle at Bottom. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997

## 4. Marker placement and markerless approximations

Marker based (reference)
- Retul 8 LED markers (Landry's page says 8 anatomical points; Branco 2022 names 7 sagittal landmarks, the 8th is not named in that paper): fifth metatarsophalangeal joint, lateral malleolus, lateral femoral condyle, greater trochanter, acromion, lateral humeral epicondyle, styloid process of ulna (wrist). LED sensors taped directly to skin, 18 Hz sampling. https://repositorio.ufmg.br/... and https://www.landrys.com/pages/retul-bike-fit-at-landrys
- 2D video labs: Millour 2019 reflective markers on greater trochanter, lateral femoral epicondyle, lateral malleolus, fifth metatarsal head of the left limb, placed by one experimenter to reduce variability. https://actabio.pwr.edu.pl/...
- MyVeloFit Saddle Height 101 goniometer landmarks: lateral femoral condyle (knee), lateral malleolus (ankle), greater trochanter (hip). https://www.myvelofit.com/fit-academy/saddle-height-101-a-comprehensive-guide-to-setting-your-saddle-height/
- Slowtwitch: Retul knee landmark is the lateral condyle; back line is greater trochanter to acromion; F.I.S.T. uses the femur/tibia joint line centre and the clavicle protrusion instead; the same knee measured 144 degrees included under F.I.S.T. landmarks is about 142 under Retul landmarks. https://slowtwitch.com/industry/retul-or-goniometer-it-alone/
- Bike Fast Fit 2013: app auto recognised body parts but the user dragged points; stick on dots at hip, knee, ankle recommended; commenters said 1 mm on screen can be a larger error on the body. https://dcrainmaker.com/2013/10/automated-measurement-review.html

Markerless
- MyVeloFit: markerless motion capture, no markers or special hardware. https://www.myvelofit.com/our_process
- Bike Fast Fit EZ and Elite: markerless; Pro allows marker override for one landmark when lighting, clothing or anatomy defeat tracking. https://bikefastfit.com/faq
- BikeFit AI: "100% on-device", Apple Vision framework, no internet, no account, App Privacy label Data Not Collected, 1.9 MB, requires iOS 26.2. https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471
- Apple Vision VNHumanBodyPoseObservation (iOS 14+): 19 joints: nose, neck, eyes, ears, shoulders, elbows, wrists, root, hips, knees, ankles. No foot, toe or heel landmark. https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname
- Apple Vision VNHumanBodyPose3DObservation (iOS 17+): 17 joints: topHead, centerHead, centerShoulder, shoulders, elbows, wrists, spine, root, hips, knees, ankles. No foot landmark. https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/jointname
- Consequence: with Apple Vision alone, ankle angle (which needs the 5th metatarsal head or a foot vector) and Retul style "knee forward of foot" cannot be computed from body keypoints; the app needs a foot/pedal/shoe heuristic (for example the cleat/pedal axle detected from the bike, or MediaPipe style foot index keypoints from a different model). Markerless validation papers (Bini 2023 J Sports Sci with OpenPose, and the Springer MediaPipe/TransPose paper) report the ankle as the worst joint; search summaries gave OpenPose hip/knee errors of 4 to 8 degrees and ankle errors of 15 to 22 degrees, and MediaPipe typical errors 3 to 9 degrees, but the full texts could not be opened, so these numbers are medium to low confidence. https://scholars.unf.edu/en/publications/criterion-validity-of-neural-networks-to-assess-lower-limb-motion/
- Retul itself, against Vicon (n = 11): SEM under 1 degree for Max Knee Flexion (0.36) and Max Knee Extension (0.59), Back Angle 1.02, Hip Angle Closed 1.18, Shoulder to Wrist 2.77, Knee Lateral Travel 2.15 (mm). https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997
- Retul intra rater reliability (n = 10): SEM under 3 degrees for all angular variables, under 5 mm for the linear variable; minimal detectable difference 2.15 to 6.55 degrees, 15.51 mm for knee forward of foot. https://repositorio.ufmg.br/...

## 5. Frontal and rear view

- Bike Fast Fit Elite front view: phone on a tripod, centred in front of the bike, level; outputs Knee Angle as tilt from vertical ("a few degrees is normal"), Knee Tilt (top vs bottom of stroke), Knee Tracking (whole stroke), Toe Tracking (quality check). Pro rear view: PSIS landmarks must be visible (form fitting kit or bare lower back), outputs left/right knee displacement in mm, pelvic angle, spinal bend (high 170s typical, 180 is straight) at each leg's BDC frame. https://bikefastfit.com/faq and https://bikefastfit.com
- APOPT rear view: camera directly behind the bike, hips knees shoulders visible; metrics: knee lateral tracking (peak to peak side to side knee travel), pelvic obliquity (vertical hip travel side to side, the "hip rocking" measure), shoulder sway. https://apopt.com/cycling/cycling.php
- ctyeh front view protocol: camera about 2 m in front of the rider with the lens at knee height, 30 s at moderate intensity, review in slow motion, mark foot and knee centres and compare paths; ideal knee stays over the foot, nearly straight up and down path, no cave in at TDC or splay out in the power phase. Q factor defined as outer surface to outer surface of crank arms; road Q factors Shimano 146, SRAM 148, Campagnolo 145.5 mm; MTB 168 to 176 mm; pedal axle spacers add 2 to 10 mm per side; most cleats allow about 5 mm total lateral adjustment. https://ctyeh.com/articles/1330?lang=en
- Baskin (Velosmart): second toe, patella and femoral head should stay in one plane perpendicular to the bike; knees out at top suggests insufficient Q factor (add 2 to 3 mm pedal washers per side or move cleats inward); knees in at top suggests cleat wedges in 1 degree steps, typically 1 to 3 per side. https://velosmart.blogspot.com/2008/12/knee-tracking-by-steve-hogg-june-20.html
- Retul reports Knee Lateral Travel, Knee Travel Tilt (frontal plane tilt of the knee path relative to vertical), Hip Lateral Travel; CX Magazine says 40 mm lateral knee travel is Retul's "red flag" threshold. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997 and https://www.cxmagazine.com/retul-cyclocross-bike-fitting
- Hip rocking: MyVeloFit heel method says heel contact should hold "without needing to tilt your pelvis through the bottom of the pedal stroke"; no numeric rocking threshold found anywhere. https://www.myvelofit.com/fit-academy/saddle-height-101-a-comprehensive-guide-to-setting-your-saddle-height/

## 6. What MyVeloFit, BikeFit AI and Bike Fast Fit ask and return

MyVeloFit (web/app, cloud processing, upload required)
1. Account, choose one of eight bike types (road, smart bike, hybrid, gravel/CX, MTB, triathlon, time trial, spin), choose goal (comfort, performance, mix).
2. Mobility assessment: two guided videos (or questionnaire) of upper and lower body movements; results tune the target ranges.
3. Set up trainer, lighting, camera (see sections 1 and 2); set cleats first.
4. Record about 15 s, upload; results in about 90 s.
5. Returns: key joint angles at three points in the pedal stroke, joint tracking (excess movement), a "target fit window" showing where the rider falls, and recommendations that say what to change and by how many millimetres (saddle height, saddle position, handlebar tilt). Cleat position is detected but not recommended. Saddle fore aft is not in the report; the rider sets it with the KOPS plumb line guide. Repeat record/adjust rounds; re record a new 10 to 15 s video after each round. https://www.myvelofit.com/our_process, https://www.myvelofit.com/?p=5338, https://www.myvelofit.com/fit-academy/how-to-get-the-most-out-of-your-bike-fit/, https://www.myvelofit.com/fit-academy/saddle-fore-aft-positioning-101/
- Numeric target ranges are not published; the Jan 2022 page only says lower bound of knee extension was lowered, upper bound of back angle raised, upper bound of shoulder angle raised. https://www.myvelofit.com/fit-academy/new-bike-fit-ranges/
- Claimed scale: 100K to 200K users, 250K to 450K fits (page shows inconsistent numbers), 30 day refund guarantee. https://www.myvelofit.com/?p=5338

BikeFit AI - Bike Fit Analyzer (iOS, free, Data Not Collected)
- Record a side view with the phone at hub height, pedal steadily at least 30 s on an indoor trainer; on device analysis with Apple Vision; returns knee extension and flexion, hip angle, back angle, elbow angle, ankle angle (heel drop) rated against an "ideal range for your riding style" with Endurance (relaxed) and Performance (tighter) modes; session history and side by side comparison. No numeric ranges on the listing. https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471

Bike Fast Fit (Double Dog Studios, iOS)
- EZ ($9.99/yr, 7 day trial): detects pedalling, records 4 s (4 to 5 strokes) at 240 fps from the rear camera, finds key frames, returns saddle height and fore/aft adjustments in mm plus upper body position (Upright, Relaxed, Aggressive); crank length fixed at 172.5 mm; up to 5 mm variation between captures is normal, 10 mm swings indicate a tracking problem. https://apps.apple.com/us/app/bike-fast-fit-ez/id1578925255 and https://bikefastfit.com/faq
- Elite ($29.99/yr): side + front views, knee angle at maximum extension, hip angle, torso and shoulder position, front view knee movement, photo based bike measurements (can be off by up to 10 percent; saddle angle must be entered manually), 2 to 4 mm variation between good recordings normal. https://bikefastfit.com and https://bikefastfit.com/faq
- Pro ($139.99/yr): over 70 measurements, LiveCheck real time angles, rear view, editable target ranges per bike type (for example Effective Saddle Angle, Knee/Pedal, Ankle-Toe at each crank position), PDF/CSV reports, remote second iPhone camera; App Privacy lists analytics data not linked to the user. https://apps.apple.com/app/id6502648219
- 2013 original: user calibrated distances by entering one known length on the bike; custom three point angles; 5 to 7 paragraphs of guidance per measurement. https://dcrainmaker.com/2013/10/automated-measurement-review.html

## 7. Bike measurements: saddle height, setback, reach, drop, stack and reach

- Saddle height, scientific definition: "the measure between the centre of the bottom bracket to the top of the saddle measured in alignment with the seat tube" (Millour 2019). https://actabio.pwr.edu.pl/...
- MyVeloFit Saddle Height 101: most common method is BB centre to top of saddle; LeMond method measures from BB spindle centre to saddle top following the seatpost (inseam x 0.883); Hamley measures from the lower pedal axle with cranks in line with the seat tube to saddle top (inseam x 1.09). Heel method: cranks in line with seat post, heel on lower pedal, knee locked out, then lower 10 to 15 mm as a starting point. https://www.myvelofit.com/fit-academy/saddle-height-101-a-comprehensive-guide-to-setting-your-saddle-height/
- Cycling Inform repeatable method: bike level on trainer (check between axle centres with a long level); saddle height from BB centre to the underside of a steel rule laid on the saddle, tape passing through a dot at the midpoint of the flat rail section; setback with a vertical level through the BB centre and a rule to the saddle nose; reach from saddle nose to the centre of the top of the bar next to the stem clamp (within 1 mm of the true bar centre); drop with a level held horizontally from the saddle, rule down to bar top next to the stem clamp, add 13 mm for 26.0 mm bars or 16 mm for 31.8 mm bars to reach bar centre; saddle angle with a digital level, + nose up. https://www.cycling-inform.com/how-to-measure-your-bicycle-position-accurately-and-repeatedly
- MyVeloFit four measurements: Saddle Reference Point = saddle midpoint (UCI and some fit software use the tip instead); Grip Reference Point = crook of hand on the hood; saddle height = straight line BB centre to SRP; setback = (wall to BB) minus (wall to SRP) with rear wheel against a wall; grip drop = (floor to SRP) minus (floor to GRP), negative when saddle is higher; grip reach = straight line SRP to GRP; bars square to the top tube, level ground. https://www.myvelofit.com/fit-academy/the-four-bike-measurements-every-rider-needs/
- Stack = vertical distance from BB centre to the centre of the top of the head tube; Reach = horizontal distance between the same two points; grip stack and grip reach add spacers, stem, bars and hoods and are what you replicate between bikes. https://www.myvelofit.com/fit-academy/bicycle-geometry-101-fit-geometry/ ; Canyon says the same for stack and also defines effective stack/reach to the hood position. https://www.canyon.com/en-us/blog-content/road-cycling-news/road-bike-geometry-explained/b19102022.html
- TT bike with tape against two walls (MyVeloFit): wall to extension tip, wall to saddle tip, wall to BB centre, floor to arm pad underside, floor to extension high point; setback = BB minus saddle tip; UCI: saddle tip not in front of BB, saddle tilt within ±9 degrees, arm pad angle within ±30 degrees, forward position (0 to 50 mm setback) allows extension reach up to 750 mm and extension height up to 100 mm; page notes its numbers were accurate to end of 2023. https://www.myvelofit.com/fit-academy/how-to-measure-and-set-up-your-time-trial-bike-for-uci-regulations-without-any-fancy-tools-0/
- Setback via KOPS (MyVeloFit): pedals at 3 and 9 o'clock, plumb line from tibial tuberosity of the forward leg should intersect or be very close to the pedal spindle; "a widely-accepted starting guide" but "not a measure for success". Millour used the Silberman method: inferior pole of the patella over the pedal axle. https://www.myvelofit.com/fit-academy/saddle-fore-aft-positioning-101/ and https://actabio.pwr.edu.pl/...
- Saddle tilt: measure with a phone level app on the middle third of the saddle on level ground; 1 degree nose down is often enough; more than 1 degree nose up is very uncommon; if the saddle previously had more than about ±2 degrees of tilt, revisit height. https://www.myvelofit.com/fit-academy/saddle-tilt-101/

## 8. Adjustment increments, rate of change, adaptation

- Stems come in 10 mm increments (some 5 mm); many riders only move one size; changes under 20 mm are unlikely to be noticeable in handling; measure stem centre of steerer to centre of bar; common angles 6, 17, 45 degrees; bar reach typically 70 to 100 mm. https://www.myvelofit.com/fit-academy/best-ways-to-adjust-reach-on-your-bike/
- MyVeloFit order: cleats first; saddle tilt (start level), then height, then fore aft; then bar height, then reach; moving the saddle back raises effective height and forward lowers it; "it can take many riders two weeks of riding for their bodies to adapt"; lowering the saddle is harder to adapt to; follow up at least once a year. https://www.myvelofit.com/fit-academy/bike-fitting-order-of-adjustments/
- MyVeloFit "most out of your fit": effects are non linear (a first 10 mm may do little and "the next 5mm could be incredibly impactful"); prefer several smaller changes; re record 10 to 15 s after each round; adaptation can take several rides to a few weeks. https://www.myvelofit.com/fit-academy/how-to-get-the-most-out-of-your-bike-fit/
- MyVeloFit ankling article: gradual saddle lowering over 7 to 10 rides for riders used to an over extended knee. https://www.myvelofit.com/fit-academy/the-truth-about-ankling-in-cycling/
- Bike Fast Fit: 2 to 4 mm capture to capture noise on Elite/Pro, up to 5 mm on EZ, so changes under about 3 mm are below the measurement noise of a phone video fit. https://bikefastfit.com/faq
- Retul examples: saddle lowered almost 2 cm to meet 37 ± 3 extension (BikeRadar); saddle raised about 6 mm and 6 mm cleat shim for a 12.5 mm leg length difference (CX Magazine); stem 120 to 110 mm, bars rotated about 1 degree (road.cc). https://www.bikeradar.com/reviews/maintenance/tools-kits-and-boxes/fitting-systems/retul-fit-system-review , https://www.cxmagazine.com/retul-cyclocross-bike-fitting , https://road.cc/content/blog/88098-get-fit-get-bike-fit-experiencing-retul
- Lower authority (shop blog, Taiwan): saddle height in 2 to 3 mm steps when the total change exceeds 5 mm, 2 to 3 weeks adaptation, stem 70 to 130 mm in 10 mm steps, ride 30 min on a trainer after each change; cleats no more than 1 to 2 mm at a time, ride at least 50 km before judging, torque 5 to 6 Nm. https://ctyeh.com/articles/3403?lang=en and https://ctyeh.com/articles/664?lang=en
- Bini 2011 review: changes of less than 4 percent of trochanteric length do not seem to affect injury risk or performance; a 5 percent change in saddle height affected knee kinematics by 35 percent and moments by 16 percent. https://paulogentil.com/pdf/...
- Not found with a readable primary source: the often quoted "saddle 5 mm, stem 10 mm, spacers 5 mm, cleat 2 degrees" list (Competitive Cyclist page body would not load). The 5 mm spacer figure is simply the common spacer size.

## 9. Angle targets and conventions

Conventions
- Knee angle in the saddle height literature (Holmes, Ferrer-Roca, Millour, Bini) is the flexion angle: 0 degrees = full extension, measured between thigh (trochanter to lateral condyle/epicondyle) and shank (condyle to lateral malleolus). Included angle = 180 minus flexion. Millour: "KA: angle between the thigh and the leg; 0 degrees corresponds to full knee extension". https://actabio.pwr.edu.pl/...
- Retul reports Max Knee Extension and Max Knee Flexion from the hip-knee and knee-ankle lines; BikeRadar quotes "extension 37 ± 3" and "flexion 110 ± 3", a Slowtwitch poster subtracts 37 from 180 to get 143 included, so Retul extension numbers are flexion from straight and Retul flexion numbers at TDC are reported as around 110 (the forum could not agree whether that is included or flexion; CX Magazine gives flexion "slightly under 110 to 115" and extension "30 to 40"). https://www.bikeradar.com/reviews/maintenance/tools-kits-and-boxes/fitting-systems/retul-fit-system-review , https://forum.slowtwitch.com/t/retul-knee-angle/720566 , https://www.cxmagazine.com/retul-cyclocross-bike-fitting
- Hip angle: Retul Hip Angle Closed/Open = knee-hip-shoulder included angle; Millour uses thigh to vertical (a different quantity, 27 to 29 degrees at BDC); Holliday uses a true hip joint angle to the lumbar spine. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997 , https://actabio.pwr.edu.pl/... , https://pmc.ncbi.nlm.nih.gov/articles/PMC9219349
- Back angle: hip (trochanter) to shoulder (acromion) line relative to horizontal (Retul, Slowtwitch, APOPT). Shoulder angle: hip-shoulder-wrist (Retul SAW) or hip-shoulder-elbow (SAE). Ankle: knee-ankle line vs heel-foot line. https://pmc.ncbi.nlm.nih.gov/articles/PMC8271997 , https://repositorio.ufmg.br/...

Numbers
- Holmes static BDC knee: 25 to 35 flexion (Millour quoting Holmes). Later Holmes group and Peveler: 25 degrees static for economy and anaerobic power. https://actabio.pwr.edu.pl/...
- Bini 2011 review recommendation: knee flexion 25 to 30 at BDC (knee flexion angle method) to reduce injury risk and minimise VO2. https://paulogentil.com/pdf/...
- Ferrer-Roca dynamic MKE: 30 to 40. Millour proposed dynamic BDC: 33 to 43 (road and MTB), and warned that tri seat tube angles of 78 to 82 change the BDC geometry so BDC knee angle needs care in that discipline. https://actabio.pwr.edu.pl/...
- Retul road norms as reported by journalists: extension 37 ± 3 (BikeRadar) or 30 to 40 (CX Magazine); flexion about 110 (BikeRadar 110 ± 3) or under 110 to 115 (CX); ankling max 95 to 105; knee lateral travel red flag 40 mm. Retul's own table is not public.
- Holliday and Swart 2021 (50 trained male road cyclists, static inclinometer, hands on hoods): knee at BDC 36 ± 7 (range 20 to 51), hip at TDC 77 ± 5, ankle 116 ± 7, shoulder 112 ± 7, elbow 19 ± 8. Ranges they cite from Burt 2014 and others: knee 25 to 35; hip 55 to 65 at TDC on a road bike; elbow 20 to 30 on hoods; torso 45 to 55 recreational and 30 to 45 fast road (Burt), 30 to 45 racing, 40 to 50 fitness, 50 to 60 casual (Pruitt and Matheny); ankle 5 to 15 plantarflexion. https://pmc.ncbi.nlm.nih.gov/articles/PMC9219349
- TT/tri (shop blog, cites a University of Birmingham study and other secondary sources; low to medium confidence): torso angle 0 to 8 aggressive, 8 to 15 balanced, 15 to 24 comfort; open hip near TDC about 48 to 52 for Ironman/70.3 and 40 to 48 for Olympic and shorter; below 40 flagged; effective seat angle 76 to 78 vs 73 to 74 road; forearms tilted up 5 to 25 degrees. https://ctyeh.com/articles/13194?lang=en
- The 2014 Birmingham torso angle study (Fintelman et al, J Biomech) tested 19 TT cyclists at 0, 8, 16 and 24 degrees torso angle; the primary paper could not be opened; secondary pages only. https://www.active.com/triathlon/articles/has-science-found-your-optimal-aero-position
- Shoulder 80 to 100 and TT back 10 to 25 and the Retul "hip closed angle" table could not be sourced from a readable primary page in this session.

## 10. Cleat position relative to the first metatarsal (and a phone photo)

- MyVeloFit Cleat 101: feel the 1st and 5th metatarsal heads, put masking tape on the shoe sides and mark both, draw a line across the sole connecting the marks, a centre line lengthwise, and put the cleat's axle marker at the intersection; the distance from the 1st metatarsal mark to the axle marker should be more than 10 mm (larger shoes more); moving cleats back shortens effective leg length so recheck saddle height; set rotation to match the natural foot angle seen with legs dangling off a bench. https://www.myvelofit.com/fit-academy/cycling-cleat-positioning-101/
- Steve Hogg: mark the 1st MTP joint line (check with a pen tip: dorsiflex the toe, if the pen tip does not move it is on the joint axis), mark the 5th; Method 1 offsets, centre of 1st MTP in front of the pedal axle by 7 to 9 mm (EU 36 to 38), 8 to 10 (39 to 41), 9 to 11 (42 to 43), 10 to 12 (44 to 45), 11 to 14 (46 to 47), 12 to 16 (48 to 50); Method 2 wall method: heels against a wall, measure wall to 1st MTP and wall to 5th MTP with a steel rule, halve the difference (example 182 minus 154 = 28, so 14 mm) and set the 1st MTP that far in front of the axle; measure with the crank forward and horizontal, shoe level, viewed from the opposite side with a T square or rule held vertically from the axle centre to the pen mark. https://www.stevehoggbikefitting.com/bikefit/2011/04/power-to-the-pedal-cleat-position/
- ctyeh: same 1st/5th marking, midpoint over the axle, cleat changes no more than 1 to 2 mm at a time, torque 5 to 6 Nm, float options 0, 2 to 3, 6, 9+ degrees. https://ctyeh.com/articles/664?lang=en
- Phone photo: no source in this session describes a photo method for cleats. Bike Fast Fit Elite estimates bike dimensions from a photo with up to 10 percent error. A workable app protocol (derived, not sourced): side photo of the shoe clipped in with the crank at 3 o'clock, the shoe sole level, a tape mark on the 1st MTP, and the pedal axle end cap visible; the app detects the axle circle and the mark and reports the horizontal offset in mm after scaling by a known crank length or a reference card. https://bikefastfit.com/faq

## 11. Open questions (for the spec author)

1. Retul's actual normative table (knee extension, hip closed, back, shoulder by discipline) is not public; only journalist quotes (37 ± 3 and 110 ± 3; or 30 to 40 and 110 to 115) exist.
2. TT/tri targets (back 10 to 25, shoulder 80 to 100, hip closed minimum) were not found in a readable primary source; only a shop blog and secondary coverage of Fintelman 2014.
3. Exact crank angle of maximum knee extension: Millour says "crank parallel to the seat tube"; this implies about 15 to 18 degrees before BDC for 72 to 75 degree seat tubes, but no paper read states a crank angle in degrees.
4. Markerless error magnitudes (OpenPose 4 to 8 hip/knee, 15 to 22 ankle; MediaPipe 3 to 9) come from search summaries of papers behind paywalls.
5. Apple Vision has no foot keypoint, so ankle angle and knee over foot need a different detector or a pedal/shoe heuristic; no app vendor documents how they get the foot.
6. No source gives a numeric hip rocking threshold; Retul uses 40 mm knee lateral travel as a red flag (secondary source).
7. The "5 mm saddle, 10 mm stem, 2 degree cleat" increment list is widespread but its page would not load; the strongest sourced increments are MyVeloFit (stems in 10 mm, two weeks adaptation) and Bike Fast Fit noise floor (2 to 5 mm).
8. Web search budget ran out before confirming the Bini and Hume 2016 camera height (saddle height, 4 m) from the full text.
