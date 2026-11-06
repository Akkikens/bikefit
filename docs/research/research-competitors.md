# Bike fit competitors, prices and traction (research notes)

Researched 2026-11-03 for Akshay Kalapgar's on-device AI bike fit iPhone app concept.
Method: WebSearch to find candidate pages, then WebFetch of the page itself for every number below. Where a page could not be fetched (paywall, 403, 429) the source is marked "search snippet only" and should be treated as lower confidence. Web search budget ran out before every item could be chased; gaps are listed at the end.

No em or en dashes are used in this file.

---

## 1. Professional fit systems (hardware sold to fitters and shops)

### Retul (owned by Specialized)
- Origin: a portable 3D motion capture system that became Retul launched November 2007 in Boulder, Colorado. Specialized made "a strategic investment" in Retul on 2012-09-14 (not described as a full acquisition in that article).
  Source: https://bicycleretailer.com/north-america/2012/09/14/specialized-invests-ret%C3%BCl
- Today retul.com is run by Specialized: footer privacy/terms link to specialized.com and contact is bodygeometry@specialized.com. Products listed: Retul Fit, Retul Footbeds, Saddle Sizing. No fitter count, no prices on the site.
  Source: https://www.retul.com/
- Technology (BikeRadar review 2010-12-16): seven LED markers from foot to hand on each major joint, tracked by a tripod mounted sensor array; 3D data capture; both sides of body measured; the Zin tool digitises 13 to 15 bike reference points. Quoted fit price then: USD 249 "varies depending on location and fitter". Rated 4.5/5. No numeric accuracy claim in the review.
  Source: https://www.bikeradar.com/gear/category/tools/cycling-tools/fitting-systems/product/review-retul-fit-system-42715/
- Retul is marker based (LED harness), not markerless. Retul Fit V8 was rolled out in 2025 (Japanese BE-PAL article 2025-05-17): "3D motion capture system", visualises joint angles while pedalling and the knee trajectory. Japan price: 33,000 yen tax included, plus 5,500 yen for bikes with DH bars or rear suspension, about 3 hours.
  Source: https://www.bepal.net/?p=543840
- Retul Fit iPad app (Specialized Bicycle Components, Inc.): free, 6 ratings, 2.3 stars; fitter facing; reviews mention harness, Zin, VCB and needing a newer iPad for cameras used in physical assessments.
  Source: https://apps.apple.com/us/app/-/id1434354462
- Retul Match (2018): Specialized's entry level in-store sizing tool given to dealers. Bikerumor article was 403 and the Triathlete article is behind a login, so details are search snippet only: "Specialized brings free 3D fit tech to dealers: Retul Match".
  Sources (not fetched): https://bikerumor.com/2018/02/02/specialized-brings-free-3d-fit-tech-dealers-retul-match/ and https://www.triathlete.com/gear/bike/specializeds-entry-level-fit-system-might-give-bike-shops-edge/
- Partnerships: "As the Official Bike Fit Technology of USA Triathlon, Retul will also provide the bike fits for USA Triathlon Foundation's Fantasy Camp" (2015-03-23). British Cycling teamed up with Retul in 2013 (search snippet). No evidence found of an IRONMAN bike fit partnership for Retul, Trek or anyone else.
  Source: https://www.sportsdestinations.com/management/marketing-sponsorships/usa-triathlon-announces-renewed-partnerships-9042
  Source (snippet only): https://www.britishcycling.org.uk/about/article/20130715-British-Cycling-teams-up-with-Retul-0

### Retul fit prices charged to consumers (sample, mixed dates)
- US (search snippets from shop pages, each shop page returned 429 when fetched): Fullcycle Retul Full Bike Fit USD 339 for 1.5 h; Co-Mo Sports Retul 3D fit USD 350 for 2.5 h plus USD 100 sizing only 45 min; Lakeside Bikes USD 350 with follow ups; River City Bicycles USD 320, pre purchase and custom fits USD 250; Parvilla Cycles (MD) USD 350 to 450 on the Slowtwitch directory; Playtri Retul Dynamic Bike Fit USD 245.
  URLs: https://www.fullcycle.bike/pages/bike-fitting , https://comorsports.com/pages/retul-3d-motion-capture-fit-service , https://lakeside-bikes.com/?p=702 , https://www.rivercitybicycles.com/product-list/bikes-1000/comfort-1020/?rb_br=2942 , https://slowtwitch.com/directory/fitters/parvilla-cycles-parvilla-custom-fit/ , https://playtristore.com/products/playtri-retul-dynamic-bike-fit
- US aggregate (thepricer.org, updated 2026-10-04, secondary source): basic adjustment fit USD 50 to 150; comprehensive manual or dynamic fit USD 150 to 250; Retul or 3D motion fit USD 250 to 400 with named examples USD 250 (ProTriFit), USD 300 (Kinetic Cycles, Pumpkinvine Cyclery), USD 400 (University Bicycles).
  Source: https://www.thepricer.org/how-much-does-a-bike-fit-cost/
- UK (Velosport, London, fetched): Basic Fit GBP 90 to 95 (30 to 45 min), Level 1 Fit GBP 195 (Retul system, 1 to 1.5 h), Level 2 GBP 260, TT/Tri Level 1 GBP 235, TT/Tri Level 2 GBP 300, Frame Sizing GBP 50 to 60 on Retul frame jig, second bike GBP 150.
  Source: https://www.velosport.co.uk/pages/fitting/
- UK (London Cyclist, 2012-07-24, old): Cyclefit Camden GBP 250 for 2 h; Freespeed GBP 195; Bike Whisperer GBP 195; Mosquito GBP 180; Pretorius GBP 175; Bike Science Putney Retul GBP 150 (comment); On Your Bike GBP 100.
  Source: https://www.londoncyclist.co.uk/bike-fitting-in-london/
- UK (Cycle magazine Feb/Mar 2014, old): bike fit "around GBP 100"; Trek Precision Fit at York Cycleworks GBP 90, Trek New Bike fit GBP 35, Trek Pro Level Fit GBP 150 or GBP 200 with physio; bikefitting.com dealers charge their hourly workshop rate.
  Source: https://cyclinguk.org/cycle/fitting-bill
- UK (Cycling Weekly 2023-06-22): in person fit GBP 175 at Ride 24/7 Cirencester.
  Source: https://www.cyclingweekly.com/fitness/bike-fit/is-ai-tech-good-enough-for-bike-fitting-i-had-both-an-ai-and-an-in-person-bike-fit-at-my-local-shop-heres-how-they-differed (fetched through r.jina.ai because the direct page returned only a consent stub)
- Germany (radsport-news.com, 2019-01-21): Specialized Body Geometry Fit with Retul EUR 150 to 300 (1 to 2 h); Radlabor SmartFit EUR 110 Basic to 345 Expert; CycleFit EUR 200 to 250 (3 to 4 h); Shimano Bikefitting EUR 99 to 299; Trek Precision Fit EUR 220 to 300 (2 to 3 h); Body Scanning CRM usually free with a bike purchase. gebioMized not covered.
  Source: https://www.radsport-news.com/markt/marktnews_113430.htm
- Germany (Tour Magazin, search snippet only): "meist zwischen 150 und 300 Euro", 2 to 3 hours.
  Source (not fetched): https://www.tour-magazin.de/fitness/training/bikefitting-trainer-fur-wen-lohnt-es-sich/
- Australia (Tri Alliance, Melbourne, fetched, undated): Retul Standard Fit AUD 295 (AUD 225 for members), Power Fit AUD 395 (AUD 295 members), extra bike +110 / +220. 1.5 to 2.5 hours.
  Source: https://tri-alliance.com/services/retul-bike-fit/
- Australia (MyVeloFit blog "Top 5 bike fitters in Sydney", 2024-06-20): Onebody Retul Bike Fit AUD 489, Frame Selection fit 595; Evoker 397 (two bikes 595); Velofix comprehensive 599; Power2Move 300; Fusion Peak 115.50 per hour.
  Source: https://www.myvelofit.com/fit-academy/top-5-bike-fitters-in-sydney/
- Australia (search snippets, not fetched): BikeNow South Melbourne fit AUD 100; Ciclo standard 1 h AUD 250, 2 h AUD 450.
  URLs: https://bikenow.com.au/pages/bike-fitting , https://ocelot-chartreuse-ns36.squarespace.com
- Japan: Specialized Retul Fit 33,000 yen incl. tax (see above).
- Singapore (search snippets; procyclebikes page returned 429): Pro Cycle Bikes Essential Bike Fit SGD 260, Deluxe Road SGD 360, Deluxe TT SGD 420, Pro Cycle Triathlon (TT) fit SGD 660, prices "subjected to prevailing GST"; Q Fitter (East Coast) S$600 exclusive of parts, certifications include Retul (Slowtwitch directory, page had a TLS error).
  URLs: https://procyclebikes.com.sg/products/bike-fitting , https://directories.slowtwitch.com/?p=9000
- Canada (search snippets): Ziggy's Cycle Velogic Level 1 CAD 275, Level 2 CAD 350. Racer Sportif Retul Premium fit page not fetched (429).
  URLs: https://ziggyscycle.ca/about/bicycle-fitting-pg273.htm , https://racersportif.com/pages/retul-premium-bike-fit
- New Zealand (search snippet): Specialized retail NZ Velogic 3D Fit NZD 275.
  URL: https://specializedretail.co.nz/pages/book-a-fit

### Guru (Dorel / Cannondale)
- Dorel (Cannondale, Schwinn) bought the GURU name, fit bike rights and patents in 2011 and licensed the name back to the Montreal custom frame factory. GURU filed for bankruptcy 2015-12-21; a source called it "indeed the end of Guru"; about 47 legacy fit bikes were produced. Slowtwitch opinion 2016-01-08.
  Source: https://www.slowtwitch.com/Opinion/The_Death_of_Guru_5574.html
- Dealer pricing (search snippets, 2012 to 2013): Dynamic Fit Unit about USD 10,000, a 2013 report put the Guru Fit System at USD 17,999 including training, with a two year contract and USD 1,500 per year plus a share of fit revenue.
  URLs (not fetched): https://bikerumor.com/2013/11/11/ib13-gurus-revolutionary-fit-system-gets-even-better/ , https://bikerumor.com/dorel-aka-cannondale-confirms-guru-acquisition-to-improve-retail-experience
- Status in 2026: Cannondale dealers still advertise Guru fit units, but the brand has no active development that I could find. Open question.

### Shimano bikefitting.com
- Shimano acquired BikeFitting.com BV on 2012-04-04 (BikeBiz).
  Source: https://bikebiz.com/shimano-acquires-bikefitting-com-bv/
- System cost to retailers at the 2013 launch: about EUR 20,000 (about USD 26,600): position simulator with power measuring crankset EUR 6,000 to 7,000, motion analysis camera EUR 10,000, static jig EUR 1,000 (Bicycle Retailer 2013-08-28).
  Source: https://bicycleretailer.com/international/2013/08/28/shimano-unveils-new-bike-fitting-system
- Dealer services listed on the B2B gateway: Shoe Cleat Adjustment, Saddle Selection, Static Fit, Fit Bike, Motion Analysis, Bike Adjustment. Dealers set consumer prices. No dealer counts published on the open site.
  Source: https://www.bikefitting.com/b2b
- Consumer price examples: Germany EUR 99 to 299 (radsport-news 2019); a French retailer lists a Shimano Bikefitting cleat and setup service at EUR 25 and a dynamic posture study gift voucher at EUR 200 (search snippet, materiel-velo.com).
- The BFC_Company_Onepager_2026.pdf exceeded the fetch size limit; it may hold dealer counts. URL: https://www.bikefitting.com/storage/app/media/Articles/BFC_Company_Onepager_2026.pdf

### idmatch (Selle Italia)
- Products: Bike Fitting (Analysis System, Smart Bike, Accessories Pack, Set-Up System, Foot Kit), Saddle Fitting (Pressure Map, Test Saddle, Positioning Tool, Smart Caliper), Foot Fitting (Cleat Fit, Footbed, Footmeter, Tiltmeter, Cleat Wedges). Company info in the footer is Selle Italia Srl, Casella d'Asolo (TV), Italy. No prices or lab counts on the site.
  Source: https://idmatch.cc/en/
- Bike Lab review (The Sweet Cyclists, 2022-04-28, updated 2022-08-12): cost about USD 300, "almost double the cost of a traditional fit"; the system takes a "3D scan of the rider without markers" to map joint angles plus three photos and foot measurements; about one hour; at the time only two US locations (Oklahoma, Texas).
  Source: https://thesweetcyclists.com/idmatch-bikefit-review/
- Smart Caliper retail: USD 299.99 (probikesupply), EUR 189.99 vs suggested EUR 302.52 (Alltricks) (search snippets).
  URLs: https://www.probikesupply.com/products/selle-italia-idmatch-smart-calipers , https://www.alltricks.fr/F-11929-outillage/P-302059-outil_de_mesure_selle_italia_idmatch_smart_caliper
- Note: idmatch is the one shop system that markets itself as markerless 3D.

### Velogicfit (New Zealand)
- Current software pricing (velogicfit.com/pricing, fetched): Essentials USD 300 per month for the first 12 months then USD 120, or USD 3,000 first year then USD 1,200 per year; Pro USD 450 per month then USD 180, or USD 4,500 first year then USD 1,800. Subscription only; hardware sold separately at shop.velogicfit.com. Features: Kinect camera integration, webcam integration, stroke analysis, bilateral mocap, bike measurements, 3D Aero virtual wind tunnel (Pro), saddle pressure mapping "planned for 2025".
  Source: https://www.velogicfit.com/pricing
- Velogic Studio 4 launched 2024-01-10 at CES; hardware is Orbbec Femto Mega time of flight cameras; 18,000 bike database; CEO Paraic McGlynn (Cyclologic took an equity stake early 2023), CTO Darren Bruning.
  Source: https://endurance.biz/2024/industry-news/velogic-studio-4-offers-up-3d-motion-capture-bike-fit-and-rider-analysis/
- Marker based: fitters apply eight retro reflective markers per side, detected in the infrared channel of three Orbbec Femto Mega cameras; used in "over 30 different countries" (Vision Systems Design 2024-08-29).
  Source: https://www.vision-systems.com/non-factory/article/55136432/velogicfit-ltd-develops-machine-vision-assisted-bike-fitting-tool
- Earlier pricing: 3D Motion retailer package USD 199 per month plus USD 199 startup, hardware included, selling in 28 countries (Cycling Industry News 2019-06-25).
  Source: https://cyclingindustry.news/velogicfit-sets-new-pricing-to-bring-in-bike-fit-retailers/
- 2D system (Slowtwitch 2017-08-29): USD 1,500 software, Kinect v2 plus reflective adhesive markers, total setup "just over USD 2,000".
  Source: https://slowtwitch.com/industry/velogicfit-2d-motion-capture/

### Trek Precision Fit
- Trek's own fitting philosophy delivered through participating retailers; fitters trained at Trek HQ in Waterloo, Wisconsin, levels 1 and 2 (search snippets). The official trekbikes.com precision_fit_retail page returned 404.
- Village Cycle Center Chicago: "Motion Capture Dynamic Analysis (M.C.D.A.) Fit" using Trek Precision Fit, high speed video, 3 hours, aerobar setup add on USD 50, base price not listed.
  Source: https://www.villagecycle.com/about/bike-fit-studio-pg756.htm
- Scheller's (KY/IN): Road Bike Fit, Tri Bike Fit, Cleat Fitting, about two hours, no prices listed.
  Source: https://schellers.com/articles/precision-bike-fitting-services-pg1071.htm
- Germany EUR 220 to 300 (radsport-news 2019); UK GBP 90 to 200 (Cycle 2014).
- No Trek Precision Fit and IRONMAN partnership found. IRONMAN's bike related partners found: Quintana Roo first brand in the IRONMAN Bike Partner Program (2025-02-11, mechanical pre race checks, no fitting); Wahoo Official Technical Partner of The IRONMAN Group (2022-04-06, no fitting mentioned); Ventum earlier official bike partner (snippet).
  Sources: https://www.slowtwitch.com/industry/quintana-roo-becomes-first-brand-to-join-ironmans-bike-partner-program/ , https://www.mynewsdesk.com/se/rlvnt-distribution-ab/pressreleases/wahoo-and-the-ironman-group-announce-multi-year-partnership-to-shape-the-future-of-endurance-sports-and-connected-technology-globally-3174036
  ironman.com/partners could not be fetched.

### Fit Kit Systems (US, since 1982)
- Catalog prices (fitkitsystems.com brand page, fetched): The Fit Kit USD 950; Fit Kit Studio Bike Fitting Software USD 175; Seat Height Tool USD 250; Inseam Measuring Device USD 395; Fit Stick USD 225 to 325; Extendable Goniometer USD 125; Saddle to Handlebar Drop Tool USD 75; VeloAngle Pro Bundle USD 479.50; Ryden Pro Bike Tool Bundle USD 279.50; Velometrik SmartCover BT saddle pressure system USD 4,580; SmartCube Pro sit bone tool USD 2,720.
  Source: https://fitkitsystems.com/brands/fit-kit-systems/
- Fit Kit measures foot length, inseam, torso, arm (femur, lower leg, shoulder width optional). Fit Kit Studio web app: Quick Size free, Quick Fit paid.
  Sources: https://fitkitsystems.com/the-fit-kit-system/ , https://fitkitsystems.com/fit-kit-studio/
- Static anthropometric sizing, no camera.

### Bike Fit Advisor
- No standalone app by this name found. The closest match is BikeCAD's "Fit Advisor" feature (frame design software; free version suggests only saddle height, more needs BikeCAD Pro).
  URL (snippet): https://bikecad.ca/fit_advisor

### Posture by Kinetic
- Nothing found under this name. Kinetic Fit (Kurt Kinetic trainer app, id1023388296) is a trainer workout app; the US App Store page returned 404. "Kinetic: Pain Test & Recovery" (id6761114646) is an unrelated recovery app. Treat "Posture by Kinetic" as unverified; may be a misremembered name.

---

## 2. Consumer AI / camera bike fit products

### MyVeloFit (Ottawa, Canada) : the incumbent
- Founded 2020 by Jesse Jarjour (co-founder and CEO; IBFI Level 2, Retul and Trek fit certifications, USAC Level 3 coach, data science and ML certificates, fitted over 2,000 people) and Justin Goulding (co-founder and COO). CTO Jerome Cornet (seed round announcement 2021-11-30, amount undisclosed). Invest Ottawa lists 1 to 10 employees.
  Sources: https://www.myvelofit.com/about-us/ , https://www.myvelofit.com/fit-academy/myvelofit-secures-seed-funding-and-expands-executive-team/ , https://techjobfinder.investottawa.ca/companies/myvelofit
- Pricing (myvelofit.com/pricing, fetched 2026-11-03):
  - Starter: free; 1 rider, 1 bike, 1 fit upload per week, quick mobility assessment, basic analysis, Virtual Fit First sizing. No detailed report or specific recommendations.
  - Enthusiast: USD 35 one time, 2 weeks access, 5 uploads per day, video mobility assessment, detailed report, adjustment recommendations.
  - Pro: USD 75 per year, unlimited bikes and uploads.
  - Expert Review add on: "Starting from USD 75" by a professional fitter (Phil Burt, former Head Physio at British Cycling and Team Sky, is named as an expert reviewer on the home page).
  - 30 Day Better Fit Guarantee on paid plans.
  Source: https://www.myvelofit.com/pricing
- Traction: home page stats "200k ACTIVE USERS", "450k FITS PROCESSED", "100+ COUNTRIES", "3.5bn DATA POINTS". Speed Skating Canada renewal (2026-07-15, four more years) says "over 200,000 riders worldwide have used the platform".
  Sources: https://www.myvelofit.com/about , https://speedskating.ca/speed-skating-canada-extends-partnership-with-bike-fit-platform-myvelofit/
- What it measures (our_process page): a 15 second video of the rider pedalling on a trainer with resistance, captured on a phone or tablet; "Key joint angles at three positions in your pedal stroke"; joint tracking for excess movement; position relative to a target fit window based on mobility and goals; upper and lower body mobility assessment; results in about 90 seconds; recommendations for one of eight bike types; no cleat recommendations.
  Source: https://www.myvelofit.com/our_process
- Processing is server side (upload, then results), so it is not an on-device product. The site does not publish any validation study or error margin; the only accuracy wording is marketing ("accurate, detailed, AI powered online bike fit", "The World's #1 Online Bike Fit").
- Virtual Fit First Bike Sizing launched 2022-06-13, free, AI body scan on the phone matches bikes from a database to a target position.
  Source: https://prnewswire.com/news-releases/myvelofit-launches-the-worlds-first-virtual-fit-first-bike-sizing-platform-301566211.html
- Independent test (Cycling Weekly 2023-06-22): MyVeloFit USD 35 (GBP 28) two week plan vs GBP 175 human fit. AI and fitter both said lower saddle 15 mm and increase setback 10 mm; both flagged knee too open and back too closed. Fitter also removed 10 mm of spacers and repositioned hoods; AI suggested a 10 mm longer stem which the fitter did not adopt. Fitter: "The figures suggested by the system are very accurate but there's a range we can play within." Limitation: MyVeloFit "only looks at one orientation" (side view) so misses bar width, hood position, pedal choice. Verdict: "impressive", but a "faff" for a novice.
  Source: https://www.cyclingweekly.com/fitness/bike-fit/is-ai-tech-good-enough-for-bike-fitting-i-had-both-an-ai-and-an-in-person-bike-fit-at-my-local-shop-heres-how-they-differed
- Community: TrainerRoad forum thread started 2021-04-10, launch price USD 35 per fit and USD 75 Pro; early users "definitely worth USD 35", complaints about slow turnaround, no cleat advice, asymmetry detection depends on careful capture.
  Source: https://www.trainerroad.com/forum/t/myvelofit-online-ai-powered-bike-fit/57283
- Triathlete review exists but is behind the Outside login: https://www.triathlete.com/gear/bike/my-velo-fit-review/ (not read). Search snippet mentions USD 75 for human escalation.
- Review platforms: G2 shows zero reviews (snippet). https://www.g2.com/sellers/myvelofit

### MyBikeFitting (web, free)
- Built by a French software engineer who goes by Elouan (dev.to handle elouan_, Product Hunt @elouan_mbf). Next.js, MediaPipe pose detection, runs client side in the browser, no account. Measures knee angle at bottom of stroke, hip angle, reach; author claims "within 2-3 degrees most of the time" from his own tests on about 15 people. Compares itself to MyVeloFit USD 75 per year and pro fits EUR 150 to 300.
  Source: https://dev.to/elouan_/i-had-knee-pain-for-months-cycling-so-i-built-a-free-ai-bike-fitting-tool-586h
- Product Hunt: launched 2026 ("9mo ago" as of fetch), 97 upvotes, day rank 14, 0 reviews, tagline "Free AI bike fitting via webcam or video", free / pay what you want.
  Source: https://www.producthunt.com/products/mybikefitting
- This is the closest thing to a free, on-device, markerless competitor, but it is a browser tool, not a native iPhone app.

### Bikefit.ai
- https://bikefit.ai/ returned 404. No product found under that domain. The name "BikeFit AI" belongs to an iOS app (below). Treat "Bikefit.ai" as not existing as of 2026-11-03.

---

## 3. iOS App Store apps claiming camera based bike fit (US storefront, fetched 2026-11-03)

| App | Developer | Price / IAP | Ratings | Tech claim | Privacy label |
|---|---|---|---|---|---|
| Bike Fast Fit Elite (id1145619812) | Double Dog Studios | Free, Annual Subscription USD 29.99 | 4.7 stars, 417 ratings | "AI-powered markerless tracking", knee tracking, angles and distances, PDF reports; iOS 15.5+ | Collects Health, Purchases, Contact Info, User Content, Identifiers, Usage, Diagnostics (not linked) |
| Bike Fast Fit EZ (id1578925255) | Double Dog Studios | Free, Annual Subscription USD 9.99, 7 day trial | 4.6 stars, 176 ratings | 4 second 240 fps video, saddle height and fore/aft only | Collects Health, Photos/Videos, IDs, Usage (not linked) |
| Bike Fast Fit Pro (id6502648219) | Double Dog Studios | Free, Annual Subscription USD 139.99 | 5.0 stars, 20 ratings | For fitters and shops; "markerless tracking" trained on "over 250 million video frames"; 70+ measurements; branded PDF/video reports | Collects fitness, name, photos, IDs (not linked) |
| BikeFit AI - Bike Fit Analyzer (id6759576471) | Jonas Friesslich | Free, no IAP listed | 5.0 stars, 1 rating | Apple Vision framework pose estimation, "100% on-device", works offline, 6 angles (knee ext/flex, hip, back, elbow, ankle heel drop), Endurance and Performance modes; iOS 26.2+ | Data Not Collected |
| Bike Fit: Saddle Handlebar fix, also listed as "Bike Fit Pro: Cycling Position" (id6764557246) | Maksym Kiryanov | Free, Lifetime Access USD 14.99 | not enough ratings | Two side view photos, keypoints and angles, mm adjustments, "100% on your iPhone, nothing uploaded"; iOS 17.6+ | Usage Data and Diagnostics (not linked) |
| FramIQ: bike fit analysis (id6760600952) | Gaspard Blanc (osteopath and bike fitter) | Free, One-Time Full Analysis USD 25, Annual USD 79, Annual Loyalty USD 50 | 4.0 stars, 1 rating | "AI video analysis", automatic joint detection, knee/hip/shoulder/elbow angles, frame finder with 10,000+ geometries, saddle finder, free cleat setup, camera based CdA; "Video analysis runs 100% on your device"; iOS 18.2+ | Linked: Fitness, Purchases, Email, User ID |
| Bike Biomechanics Measuring AI (id6743622149) | Sliced Backhand Ltd | Free; Premium Weekly 3.99, Monthly 4.99, Yearly 19.99; Business Monthly 24.99, Yearly 199.99 | not enough ratings | AI and computer vision, shoulder/elbow/hip/knee/ankle, real time posture feedback, side by side video compare, processed locally; first version 2025-04-24 | Data Not Collected |
| PedalPro - Fast Bike Fit (id6478609734) | Georg Steinbacher | Free; Advice 12.99, Professional 34.99, Unlimited 49.99 | 3.7 stars, 3 ratings | Single photo, AI joint points and angles, road/city/TT/tri; first version 2024-04-14 | Tracks Usage Data; collects photos, device ID |
| Fitter - Bike (id1528225944) | Jongheon Lee | Free, Pro USD 4.99 (removes ads) | 4.7 stars, 68 ratings | Record posture, saddle height assessment, joint angles at crank positions; since 2020-10-23 | Tracks Usage Data; ads |
| Bike Fit Performance (id6476923182) | Technologies Kalida Inc. | Free; Standard 14.99, Premium 39.99 | not enough ratings | For bike shops, AI posture analysis, bike database, PDF client reports; first version 2024-12-05 | Linked: email, name, usage |
| Dynamic Cycling Fit (id6737546303, iPad) | Giant Manufacturing Co., LTD. | Free | not enough ratings | "AI and ML Kit Pose Detection" video analysis tied to Giant's DCF Bike / DCF Bike Pro fit bike; first version 2025-09-08 | Linked: User ID, environment scanning, hands, head; precise location |
| Retul Fit (id1434354462, iPad) | Specialized Bicycle Components | Free | 2.3 stars, 6 ratings | Fitter tool for the Retul hardware | not captured |

Sources (one per row): https://apps.apple.com/us/app/bike-fast-fit-elite/id1145619812 , https://apps.apple.com/us/app/bike-fast-fit-ez/id1578925255 , https://apps.apple.com/us/app/bike-fast-fit-pro/id6502648219 , https://apps.apple.com/us/app/bikefit-ai-bike-fit-analyzer/id6759576471 , https://apps.apple.com/us/app/bike-fit-pro-cycling-position/id6764557246 , https://apps.apple.com/us/app/framiq/id6760600952 , https://apps.apple.com/us/app/bike-biomechanics-measuring-ai/id6743622149 , https://apps.apple.com/us/app/pedalpro-fast-bike-fit/id6478609734 , https://apps.apple.com/us/app/fitter-bike/id1528225944 , https://apps.apple.com/us/app/bike-fit-performance/id6476923182 , https://apps.apple.com/us/app/dynamic-cycling-fit/id6737546303 , https://apps.apple.com/us/app/-/id1434354462

Observations:
- Only Bike Fast Fit Elite (417 ratings) and the older Fitter - Bike (68) and Bike Fast Fit EZ (176) have meaningful rating counts. Every 2024 to 2026 entrant has fewer than 25 ratings. The category is wide open on the App Store.
- Three apps already claim on-device processing: BikeFit AI (Vision framework, Data Not Collected, iOS 26.2 minimum which excludes most devices), Bike Biomechanics Measuring AI (Data Not Collected), FramIQ (on-device video but collects email and user ID). "Bike Fit: Saddle Handlebar fix" also says nothing is uploaded.
- None publishes a numeric accuracy claim. The only numeric claims in the whole space are MyBikeFitting's informal "2-3 degrees" and the academic numbers below.
- Bike Fast Fit Elite's annual price has moved USD 9.99 (2023 changelog) to 19.99 to 29.99 (today).

Names found (for the later name collision check): MyVeloFit, MyBikeFitting, Bike Fast Fit, Bike Fast Fit Elite, Bike Fast Fit EZ, Bike Fast Fit Pro, BikeFit AI, Bike Fit AI, Bike Fit Pro, Bike Fit: Saddle Handlebar fix, FramIQ, Bike Biomechanics Measuring AI, PedalPro, Fitter - Bike, Bike Fit Performance, Dynamic Cycling Fit, Retul Fit, Kinetic Fit, Posturise (Product Hunt, unverified), Fit Kit Studio, VeloAngleApp, Ryden Pro companion app, BikeCAD Fit Advisor, Velogic Studio, idmatch, Retul Match, Retul Move, Retul Vantage, Precision Fit, Body Geometry Fit.

---

## 4. Adjacent platforms (Zwift, TrainerRoad, Wahoo, Strava)

- Zwift: "Bike Fit" exists only as a how to video for assembling and adjusting the Zwift Ride frame. No camera based fit analysis.
  Source: https://www.zwift.com/uk/video/how-to-collection/bike-fit
- Wahoo KICKR Bike Shift: USD 1,999.99, 5 point adjustment (stack, reach, setback, saddle height, frame height) guided by a setup app to match an outdoor bike's geometry; no camera fit analysis on the page. The 2019 KICKR Bike launch coverage described the app visually measuring your current bike from a photo (search snippet; the CyclingTips repost returned 429).
  Sources: https://www.wahoofitness.com/devices/indoor-cycling/smart-bikes/kickr-bike-shift-buy , https://zenocycleparts.com/blogs/cyclingtips/wahoo-fitness-debuts-kickr-bike-for-indoor-training-aficionados (not fetched)
- TrainerRoad: no fit product found; its 2025 Zwift integration pushes workouts into Zwift (search snippet, cyclingnews). The TR forum is where MyVeloFit got early traction.
- Strava: official press release 2026-06-30 says "more than 195 million athletes" in "more than 185 countries". No official subscriber count. Strava filed confidentially for an IPO (draft S-1) in early 2026 (SiliconAngle 2026-01-08 per search snippet; revenue reportedly grew 50% and is believed under USD 500 million; last valued about USD 2.2 billion). Third party subscriber estimates range from 1.2 million to 6.8 million and contradict each other, so no subscriber number should be quoted as fact.
  Sources: https://press.strava.com/articles/strava-announces-collaboration-with-stanford-university-researchers , https://press.strava.com/ , https://siliconangle.com/?p=727214 (snippet only), https://sacra.com/c/strava/ (snippet only)

---

## 5. Markerless pose estimation accuracy (academic)

- Bini, Serrancoli, Santiago, Moura, ISBS 2021, "Assessment of a markerless motion tracking method to determine body position on the bicycle": 14 cyclists, 120 fps, torso/hip/knee/ankle at 3 and 6 o'clock; automated vs manual differences of 3 to 12 degrees (d = 0.38 to 1.92) for all joints except ankle at 6 o'clock; automated method overestimated torso and knee flexion and underestimated hip flexion and ankle dorsiflexion.
  Source: https://upcommons.upc.edu/entities/publication/af60cdae-fe15-4ddc-a01c-86efe17d2eb9/full
- Russo et al., Sensors 26(7), April 2026, single smartphone camera plus MediaPipe vs OPAL IMUs in gait (not cycling), 27 volunteers: knee flexion MAE 4.10 (right) and 3.15 (left) degrees, extension 2.30 and 3.12, ROM 4.55 and 4.15.
  Source: https://publikationen.bibliothek.kit.edu/1000192532
- OpenCap cycling paper (four smartphones, HRNet) exists on arXiv (2024) but the review page returned 429 and I did not retrieve the error table. URL: https://www.themoonlight.io/review/opencap-markerless-motion-capture-estimation-of-lower-extremity-kinematics-and-dynamics-in-cycling
- Slowtwitch notes that landmark definitions alone shift knee angle by about 2 degrees between F.I.S.T. and Retul conventions (snippet): https://slowtwitch.com/industry/retul-or-goniometer-it-alone/
- Takeaway for the spec: single view 2D pose on a phone is plausibly within 3 to 5 degrees for knee angle under good conditions, which is inside the ranges fitters use (Cycling Weekly's fitter: "there's a range we can play within"), but no competitor publishes a validation. Publishing one would be a differentiator.

---

## 6. Summary table of price anchors

| Segment | Typical price | Source quality |
|---|---|---|
| US pro Retul / 3D fit | USD 245 to 450, cluster 320 to 350 | shop pages (snippets) + thepricer |
| US basic shop sizing | USD 50 to 150 | thepricer (secondary) |
| UK pro fit | GBP 175 to 260; basic GBP 90 to 100; TT GBP 235 to 300 | Velosport (fetched), Cycling Weekly (fetched) |
| Germany | EUR 150 to 300 typical; EUR 99 to 345 full range | radsport-news 2019 (fetched) |
| Australia | AUD 295 to 489 Retul; AUD 100 to 599 overall | Tri Alliance, MyVeloFit Sydney roundup (fetched) |
| Japan | 33,000 yen Specialized Retul Fit | BE-PAL 2025 (fetched) |
| Singapore | SGD 260 to 660 | Pro Cycle Bikes (snippet) |
| Fitter software | Velogicfit USD 1,200 to 4,500 per year; Bike Fast Fit Pro USD 139.99 per year | fetched |
| Consumer AI | MyVeloFit USD 35 one time or 75 per year; iOS apps USD 9.99 to 79 per year or 14.99 to 25 one time; MyBikeFitting free | fetched |

---

## 7. Gaps and things not confirmed
- Retul Match dealer cost and Retul Move / Vantage hardware price: sources paywalled or 403.
- Guru's current status under Dorel / Pon (Cannondale was sold to Pon in 2021; not researched).
- gebioMized consumer price in Germany (not found; radsport-news omitted it).
- Shimano bikefitting.com dealer count (one pager PDF too large to fetch).
- Trek Precision Fit current US list price (dealer pages do not publish one).
- Singapore and Canada shop pages returned 429 and are snippet only.
- Strava paying subscriber count: no official figure anywhere.
- Triathlete MyVeloFit review: behind login.
- OpenCap cycling error table.
- "Posture by Kinetic" and "Bikefit.ai": no such products found.
- Web search quota ran out, so Fit Werx / ERO / Cyclologic US price pages, Cyclefit UK current prices, and gebioMized were not reached.
