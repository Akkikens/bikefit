# Angle 1: MVP first pragmatist. Research notes and concept

Date: 2026-11-03. Designer role: one of six independent panel brainstorms. Note: the task said "using the filename given below" but no filename was supplied, so this file is named angle-1-mvp-pragmatist.md.

## 1. Competitor landscape (what I actually read)

### MyVeloFit (web service, not an iOS app)
- Source: https://myvelofit.com/pricing (fetched 2026-11-03)
- Starter: free, 1 rider, 1 bike, 1 fit upload per week, basic analysis, no detailed report.
- Enthusiast: $35 one time for 2 weeks, 5 uploads per day, video mobility assessment, detailed report, 30 day better fit guarantee.
- Pro: $75 per year, unlimited bikes and uploads.
- Expert review add-on from $75, requires a paid plan.
- Capture protocol (https://www.myvelofit.com/fit-academy/myvelofit-setup-instructions/): camera at about saddle height, 2 to 3 m away, side view, level and square, landscape, not ultra wide, not 4K, tripod recommended, mark floor positions, well lit room, no other people or mirrors in frame, snug contrasting clothing (not all black), usual shoes and cleats, 10 to 15 min warm up, hands on primary position (aero bars for TT/tri), 75 to 95 rpm, 15 to 20 s of riding, trim mount/dismount.
- Forum signal (https://trainerroad.com/forum/t/opinions-on-myvelofit/100943 and https://www.trainerroad.com/forum/t/myvelofit-online-ai-powered-bike-fit/57283?page=10): generally positive; questions about trainer/bike motion needing stable references and how recommendations are derived. MyVeloFit's own guidance says camera height, distance and angle affect results.
- Triathlete.com review exists (https://www.triathlete.com/gear/bike/my-velo-fit-review/) but redirected to a login wall; summary from search: reviewer paid $35 Enthusiast, found the result more comfortable than the original setup. Not read directly.

### BikeFit AI - Bike Fit Analyzer (iOS, closest direct competitor)
- Source: https://apps.apple.com/us/app/id6759576471 (fetched 2026-11-03)
- Developer Jonas Friesslich. Free, no IAP shown. 5.0 from 1 rating. Requires iOS 26.2 or later.
- Protocol: side view video, at least 30 s, phone at hub height, framing guide, results in under 20 s.
- Measures: knee extension and flexion, hip angle, back angle, elbow angle, ankle angle (heel drop). Traffic light per angle plus measured degrees plus ideal range. Endurance vs Performance range sets. Standard vs Detailed analysis.
- Claims 100 percent on device using Apple Vision, no upload, no internet, no account. Privacy label: Data Not Collected.
- Session history, side by side comparison, shareable report images, skeleton overlay replay, Photos import. Disclaimer: educational, not a substitute for a professional fit.
- Third party intel page (https://marlvel.ai/apps/bikefit-ai-bike-fit-analyzer) says it lacks retention loops and PDF export; low reliability source, partly AI generated.
- Takeaway: "record 30 s, show six angles with traffic lights, on device, free" is already on the store. An MVP that only does that is a clone.

### Bike Fast Fit Elite (iOS, incumbent since 2013)
- Source: https://apps.apple.com/us/app/bike-fast-fit-elite/id1145619812 (fetched 2026-11-03)
- Double Dog Studios. Free with IAP, annual subscription $29.99. 4.7 from 417 ratings. iOS 15.5+. Version 3.12.1 dated Oct 24.
- Auto detects pedaling and captures a 3.5 s clip. Markerless tracking, zoomable key frames with angles and distances, knee tracking, bike measurements over a bike image, PDF reports, unlimited riders and bikes, iCloud sync.
- DC Rainmaker 2013 review (https://dcrainmaker.com/2013/10/automated-measurement-review.html): tripod about 10 feet away was hard in a normal room; auto detected hip point needed manual correction; handlebar measurements more road focused than tri; results emailed one angle at a time; recommendations framed as ballpark ranges with exceptions; not a replacement for a pro fit.
- Forum signal: a blogger saw max knee angle differ by about 8 degrees between trainer and road bike captures before fine tuning (search summary, https://www.alananna.co.uk/blog/?p=14896); a CycleChat user saw knee angle vary 8 degrees after a saddle change (https://www.cyclechat.net/threads/bike-fast-fit-app.172769/). Capture sensitivity is the recurring complaint across apps.

### Retul (pro fit benchmark)
- No official 2026 price found. Shop pages: Full Cycle $339 (https://www.fullcycle.bike/pages/bike-fitting), The Bike Lab OKC sizing $100 and 3D fitting $300 (https://the-bike-lab-okc.shoplightspeed.com/service/retul-fit-services), Racer Sportif CAD 375 plus tax (https://www.racersportif.com/pages/retul-premium-bike-fit), Playtri $245 (https://playtristore.com/products/playtri-retul-dynamic-bike-fit), Tri-Alliance AUD 165 to 440 (https://tri-alliance.com/services/retul-bike-fit/). Sessions reported 90 min to 3 h.

### Bike Fit Advisor
- No app with this exact name found. Closest: BikeCAD's "Fit Advisor" feature (https://bikecad.ca/fit_advisor), free version limited to saddle height. Also Bike Fit Performance (https://apps.apple.com/app/id6476923182), aimed at shops, free with IAP. Also Apiir Bike Fit (https://apps.apple.com/us/app/apiir-bike-fit/id1643512367), paid IAP, covers triathlon bikes. Also PedalPro - Fast Bike Fit (https://apps.apple.com/us/app/-/id6478609734).

## 2. Apple Vision body pose (primary sources)

- VNDetectHumanBodyPoseRequest: iOS 14.0+, returns VNHumanBodyPoseObservation. https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest.md
- 2D article (https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images.md): up to 19 points (wrists, elbows, shoulders, ears, eyes, hips, knees, ankles, nose, neck, root). Points are normalized 0 to 1 with bottom left origin, each with a confidence; ignore confidence 0. regionOfInterest generally gives more accurate pose estimation. Accuracy guidance: subject height at least a third of image height, key regions visible, flowing clothing reduces accuracy, crowds bad.
- VNDetectHumanBodyPose3DRequest: iOS 17.0+. Uses AVDepthData to improve accuracy if available. https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest.md
- 3D article (https://developer.apple.com/documentation/vision/identifying-3d-human-body-poses-in-images.md): 17 joints in meters relative to the root joint between the hips; only the most prominent person; all 17 joints or none; depth not required but improves accuracy; bodyHeight is a 1.8 m reference unless a LiDAR AVCaptureSession is used; pointInImage projects back to 2D.
- Decision for MVP: use the 2D request. It is older, available on more devices, per joint confidence lets me reject bad frames, and the literature validation of bike fit angles is for 2D side view video. 3D adds surface area without a validated benefit for a side on, single plane measurement.

## 3. Measurement validity

- Fonda B, Sarabon N, Li FX. Validity and reliability of different kinematics methods used for bike fitting. Journal of Sports Sciences 2014;32(10):940-946. Record: https://lida.sport-iat.de/bdr/Record/4032256?lng=en (PubMed https://pubmed.ncbi.nlm.nih.gov/24499342/ blocked by cookie wall). 11 cyclists, 3D (13 infrared cameras) as reference vs 2D high speed camera vs electrogoniometer vs static. All dynamic methods reliable within session. Non 3D methods significantly underestimated knee angle (P = 0.00, partial eta squared 0.73). 2D is valid for knee angle; suggested correction add 2.2 degrees. Dynamic methods differed from the static measure (effect sizes 0.4 to 0.6).
- Search summaries (not read in full): a low cost 2D Kinovea setup underestimated knee extension by 2.4 degrees (https://comum.rcaap.pt/bitstreams/c052c4c7-921b-485b-8a96-ec24bd0ba495/download); knee flexion 5.4 degrees greater in dynamic than static, suggesting 30 to 40 instead of 25 to 35 for dynamic (https://lida.sport-iat.de/ta/Record/4032945).
- Tri hip angle: Slowtwitch (https://www.slowtwitch.com/industry/hip-angle/) reports self selected aero positions cluster at 95 to 105 degrees, measured greater trochanter to clavicle vs greater trochanter to bottom bracket. Note the bottom bracket is not a Vision landmark, so the app must use a body only definition (trochanter to knee at a fixed crank position) and state its ranges accordingly.
- Open: no head to head study of a smartphone app vs Retul was found.

## 4. Market and policy

- USA Triathlon 2025 impact report (https://www.usatriathlon.org/news/2026/february/04/usa-triathlon-releases-2025-impact-report-highlighting-strategic-growth-membership-event-momentum-and-progress-toward-la28): 303,000 unique active members in 2025, 829 sanctioned events, 20 to 39 the largest group, 20 to 29 grew nearly 20 percent, 73 percent raced shorter formats.
- IRONMAN 2025 (https://www.slowtwitch.com/news/we-noticed-ironmans-global-participation-trends-your-watch-is-watching-and-more/, 2025-12-15): 148 races, more than 250,000 registrations, first timers up 10 percent, 32 European races sold out, women 22.5 percent of athletes. Travel to races is normal for this group, which matters for the come back loop below.
- App Store Review Guidelines (https://developer.apple.com/app-store/review/guidelines/): 1.4.1 says apps must clearly disclose data and methodology to support accuracy claims relating to health measurements, and should remind users to check with a doctor before medical decisions. 5.1.3 restricts use of health and fitness data. Implication: no injury or pain claims, no "accurate to X degrees" marketing without a methodology page, show the method in app.

## 5. Name collision check (quick, App Store web search only)
- Search for "Saddlemark", "Hubline", "Pedalstance": no apps with those names surfaced (search result page listed Pedal, PedalPro, Wattbike Hub, SuperCycle, EXAKT Power instead). Not a trademark search; Akshay must check App Store search in app and USPTO/EUIPO before committing.
- "Fitmark" and "Sidecheck" were not checked.

## 6. Concept (angle 1)

See the structured output. Core idea: not a sixth "measure your angles" app but a repeatable before/after instrument for triathletes: baseline, change one thing or rebuild the bike after travel, re-measure, see the delta against your own noise floor. Zero backend, 2D Vision, five angles, three bike types, SwiftData, local notifications, share image. Eight to ten weeks.
