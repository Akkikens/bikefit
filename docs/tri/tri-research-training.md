# What a credible triathlon training plan engine must contain

Research notes, 2026-11-06. All numbers carry their source URL. Where a number could not be verified against a primary source, that is stated.

## 1. Periodization basics and plan shapes

Standard structure across commercial plans and coaching guides: base, build, peak, taper, with a recovery week roughly every 4th week (3 load + 1 recovery blocks).

- Olympic 16 week plan example: 6 week base, 5 week build, 5 week peak with recovery weeks at weeks 4, 8, 12 and the final week as taper. https://www.triathlete.com/training/olympic-triathlon-16-week-training-plan/
- Full distance 24 week TrainingPeaks plan: Base Phase in 3+1 week blocks, Peak Phase 2+1 weeks, 1 week taper, for athletes training 8 to 12 hours per week. https://www.trainingpeaks.com/training-plans/triathlon/ironman/tp-631122/24-weeks-ironman-plan-hr-pace-power-rpe
- 70.3 14 week plan: 10 to 14 hours per week overall, base 9 to 11 hours, peak weeks 13 to 14 hours, then structured taper. https://www.trainingpeaks.com/training-plans/triathlon/half-ironman/tp-649925/14-week-70-3-plan
- 70.3 free 6 month plan (220 Triathlon): minimum 6 hours per week, 8 to 10 preferable. https://www.220triathlon.com/training/training-plans/free-6-month-ironman-70-3-training-plan
- Ironman plans commonly sold at 23 to 24 weeks at 10 to 15 hrs per week. https://www.trainingpeaks.com/training-plans/triathlon/ironman/tp-38056/23-week-cozumel-2026-training-plan-10-15-hrs-week

Weekly hour ranges by distance (Tri Alliance planning tool, a coaching site, so coach heuristics not peer review):
- Sprint 4 to 7 h/wk, Olympic 6 to 10, 70.3 8 to 14, full 12 to 20. Peak weeks run 20 to 30 percent above average, recovery weeks 30 to 40 percent below. https://tri-alliance.com/tools/training-hours/

Taper guidance varies: 2 weeks (Triathlon Magazine Canada https://triathlonmagazine.ca/training/periodize-your-triathlon-training-for-peak-race-day-performance/), 2 to 3 weeks or volume cut 40 to 60 percent over 1 to 3 weeks in other guides from the same search set. There is no single standard; an engine should parameterize taper length by race distance (1 week sprint up to 2 to 3 weeks full) and cut volume while keeping some intensity.

Implication for plan engine: plan lengths cluster at 8 to 16 weeks for sprint/Olympic and 14 to 24 weeks for 70.3/full. Phase ratios roughly 40 to 50 percent base, 30 percent build, 15 percent peak, 5 to 10 percent taper.

## 2. Intensity distribution: polarized and 80/20 (Seiler)

- Origin: retrospective analyses of elite endurance athletes (Norwegian rowers, XC skiers) show about 75 to 80 percent of sessions at low intensity, 15 to 20 percent high, little in the middle. Review: Stoggl and Sperlich, Frontiers in Physiology 2015. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2015.00295/full
- Controlled comparison: Stoggl and Sperlich 2014 RCT found polarized superior to threshold training for VO2max and peak power (an 11.7 percent VO2max gain is widely quoted in secondary sources but I did not verify it against the primary paper). Secondary summary: https://getfitcraft.com/science/polarized-training-research
- 2024 systematic review (Sports Medicine): polarized training superior to other intensity distributions only for VO2peak; no evidence of superiority for other endurance performance outcomes. https://link.springer.com/content/pdf/10.1007/s40279-024-02034-z.pdf
- Caveat: Seiler describes 80/20 as a population pattern among high volume athletes (about 10+ h/wk), not a prescription for everyone; popular coverage at https://pezcyclingnews.com/toolbox/cycling-polarized-training-stephen-seiler/

Engine implication: default plans should keep roughly 80 percent of session time easy (zone 1 to 2) and concentrate quality in 1 to 3 sessions per sport per week. This is defensible and citable, but do not market it as proven superior for race performance beyond VO2max effects.

## 3. Brick workouts

- Purpose: teach the body to run off the bike (neuromuscular adaptation), not to build run endurance. https://www.active.com/triathlon/articles/what-brick-workouts-and-why-they-matter
- Frequency, sources disagree: Rouvy says one short brick every 10 to 14 days (https://rouvy.com/en/blog/brick-workouts-triathlon); TriDot prescribes 1 transition run per week year round (https://tps.tridot.com/resources/post/what-is-a-brick-workout-and-how-can-it-boost-your-triathlon-performance); Tri247 says sprint plans typically add one weekly brick as race day approaches (https://www.tri247.com/guides/brick-workout-triathlon).
- Short transition run format: 10 to 20 min run immediately after a full bike, most valuable for beginners and short course. https://www.active.com/triathlon/articles/transition-workouts-when-to-run-after-a-ride
- Matt Dixon (via Active): short runs off the bike add run frequency without musculoskeletal overload. https://www.active.com/triathlon/articles/using-brick-workouts-in-triathlon-training

Engine implication: schedule a 10 to 20 min transition run after one key ride per week in build/peak, scaling up to race specific bricks for 70.3/full.

## 4. Swim training by CSS

- CSS test: all out 400m and 200m swims same day with 10 to 15 min rest. CSS pace per 100m = (400m time minus 200m time) / 2. Example: 6:05 400 and 2:59 200 gives 1:33 per 100m. https://support.myprocoach.net/hc/en-us/articles/360040593392-How-Does-The-CSS-Swim-Test-Work
- General form CSS = (D1 minus D2) / (T1 minus T2). https://tritrainingharder.squarespace.com/blog/2013/10/swim-testing-critical-swim-speed.html
- CSS approximates the pace sustainable for a 1500m time trial, treated as aerobic swimming threshold. Same MyProCoach source.
- Validity: CSS overestimates threshold by about 3 percent versus a 30 minute swim test (cited in the Tri Training Harder blog above; primary study not fetched).
- Error handling the engine must do: if the 200m pace is not faster than the 400m pace, the test is invalid and should be rejected. https://support.myprocoach.net/hc/en-us/articles/4415959137549-Error-Your-200-pace-is-slower-than-your-400-pace
- Zones are not standardized. One coach uses a 90 to 105 percent CSS band for aerobic work; a calculator uses offsets (recovery CSS + 10 s/100m, threshold CSS plus or minus 3 s, VO2max CSS minus 8 s). Treat zone schemes as app defined. https://hacecuentas.com/calculadora-velocidad-critica-natacion

## 5. Bike training by FTP and power/HR zones

- FTP from 20 minute test: FTP = 95 percent of max 20 min average power (Coggan protocol); 20 min power runs 95 to 100 percent of true 1 hour power; include a 5 min hard clearing effort in warmup; pacing even matters more than starting fast. https://biketips.com/ftp-testing-training-zones-explained-2/ and https://biketips.com/ftp-test-what-is-functional-threshold-power/
- Coggan 7 zones as percent FTP: Z1 under 55, Z2 56 to 75, Z3 76 to 90, Z4 91 to 105, Z5 106 to 120, Z6 121 to 150, Z7 above 150. From a calculator reproducing the Coggan model; cross check against Allen and Coggan, Training and Racing with a Power Meter, before hardcoding. https://biketips.com/coggan-power-zones/
- Retest cadence: every 4 to 8 weeks, commonly 6 to 8. https://biketips.com/ftp-testing-cyclists-training-zones/
- HR threshold (LTHR) field test for bike or run: 30 min all out, average HR of the final 20 minutes = LTHR (see run section source, same protocol used for bike by Friel style methods).

## 6. Run training by threshold pace

- 30 minute time trial: 10 min warmup, 30 min hard; average HR over the last 20 min = LTHR; pace = distance meters / 1800 s. Validation: a study found the 30 min TT and VDOT methods as accurate as lab LT assessment. https://runnersconnect.net/how-to-calculate-your-lactate-threshold/ and https://run.outsideonline.com/training/track-workouts-lactate-threshold-heart-rate-test/
- Threshold pace approximates what a fit runner holds for about 60 minutes, close to 15k to half marathon race pace for non elites; half marathon pace is within seconds of LT pace; 10K pace is roughly LT2 plus 3 to 5 s/mile. https://marathonhandbook.com/lactate-threshold/
- Tempo prescription: 20 to 40 continuous minutes at LT2 pace or within 3 bpm of LTHR. Same Marathon Handbook source.

## 7. Load metrics and the TSS trademark question

### Formulas
- Banister TRIMP = duration (min) x HR reserve fraction x A x exp(B x HRr); for men A = 0.64, B = 1.92 is the standard pairing (search result confirmed the women constants: A = 0.86, B = 1.67; mens constants are standard literature values and should be verified against Banister 1991 before shipping). Source for structure and women constants: https://moveit.webs.upv.es/how-to-quantify-the-training-load/
- Edwards TRIMP = sum of time in 5 HRmax zones x zone weight (1 to 5). Same source. (Akshay already has an Edwards TRIMP engine in Liftspark.)
- Lucia TRIMP: 3 zones anchored at ventilatory thresholds, weights 1, 2, 3. Same source. Edwards and Lucia TRIMP correlate r = 0.93. Same source.
- Caveat from the literature: HR derived load is considered inferior to power based load in cycling. https://arxiv.org/pdf/2503.14841
- CTL/ATL/TSB (Coggan Performance Management Chart, built on Banister fitness fatigue model): today's CTL = yesterday's CTL + (today's load minus yesterday's CTL) / 42; ATL same with time constant 7; TSB = CTL minus ATL (most tools use yesterday's values; intervals.icu uses same day, a convention choice to document). https://fasttalklabs.com/articles/an-introduction-to-training-metrics-part-2 and the Coggan PMC paper PDF mirrored at https://oldtrasparenzamonasterolo.yamme.it/velodynamics2.webs.com/PerfMgr.pdf (k = 7 ATL, k = 42 CTL)
- IF = NP / FTP; TSS = IF^2 x hours x 100 (1 hour at threshold = 100). https://www.bestbikesplit.com/blog/intensity-factor-if-cycling-pacing-guide
- ACWR: acute (about 7 day) over chronic (about 28 day) load ratio. Evidence status: Gabbett's 2016 BJSM review called it a best practice predictor (https://bjsm.bmj.com/content/53/3/144 is the later clarification; original review via https://pmc.ncbi.nlm.nih.gov/articles/PMC4789704), but Hulin and Gabbett later conceded the predict framing was overstated; Impellizzeri's group argued the framework should be dismissed; a Frontiers editorial notes the time spans are arbitrary and no biological marker validates it. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.669687/pdf and https://simplifaster.com/articles/acwr-high-performance-tool/ and systematic review https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972
  Engine implication: use ACWR style spike flags as a warning heuristic (for example flag ratio above about 1.5), never as injury prediction, and say so in copy.

### Trademark situation (important for a free app)
- TSS, IF, NP, TP, TPU are registered US trademarks of TrainingPeaks, LLC; TSS registered January 21, 2014. Aggregator records: https://trademarkdir.com/trademark/tss-85913857 , https://trademarks.justia.com/owners/trainingpeaks-llc-4253944 , https://trademarks.justia.com/859/13/tss-85913859.html (verify against USPTO TSDR before shipping).
- TrainingPeaks has publicly said it wants attribution rather than royalties (forum statement, not a license: https://forum.slowtwitch.com/t/np-if-tss-registered-trademarks/678476). Third parties that use the names carry notices like "Training Stress Score (R), TSS (R)... trademarks of TrainingPeaks, LLC, used with permission" (Sauce for Strava https://www.sauce.llc/release_notes , Polar manual https://support.polar.com/e_manuals/M460/Polar_M460_user_manual_English/Content/TrainingPeaks.htm).
- Free alternatives in practice: intervals.icu calls the identical metric "Load" explicitly because of the trademark (https://forum.intervals.icu/t/show-tss-in-intervals-icu/24435); GoldenCheetah (GPLv3, https://github.com/GoldenCheetah/GoldenCheetah) renamed TSS to BikeStress, IF to BikeIntensity, NP to IsoPower in v3.5 (https://groups.google.com/g/golden-cheetah-users/c/Qjn4Xe8ShQ0/m/FmOLo_PXAAAJ) and has a TriScore per a user forum claim (https://forum.intervals.icu/t/correlation-between-load-and-tss/1154).
- rTSS (run TSS from threshold pace) is TrainingPeaks terminology too; no search result covered its exact formula, so treat it as another name to avoid. The underlying math (intensity squared times hours times 100 against a threshold anchor) is a published formula and the safe path is to compute it under an original name (for example "Strain" or "Load"), exactly as intervals.icu and GoldenCheetah do, with no TrainingPeaks marks anywhere in UI or metadata.
- Note: GoldenCheetah is GPLv3; reading its docs is fine but copying code into a non GPL app is not. Liftspark is already AGPL derived so Akshay knows this terrain.

## 8. Adaptive plan adjustment (Runna and TriDot patterns)

Runna (primary support docs):
- Pace Insights reviews completed runs and adapts pace targets when the runner is consistently off pace across workouts, ignoring outliers. https://support.runna.com/en/articles/10026375 and third party analysis https://the5krunner.com/2026/09/28/is-runna-ai/
- Single missed session: Skip Workout, subsequent workouts shift automatically; move missed workouts within the week. https://support.runna.com/en/articles/15012850-how-and-when-to-skip-a-run-managing-missed-sessions-in-your-training-plan and https://intercom.help/runna/en/articles/10137793-how-to-use-and-manage-your-training-calendar
- More than 3 missed workouts or a missed week triggers a Plan Realignment prompt (skip missed week or continue unchanged; irreversible once confirmed). Same support article set.
- Illness: "Not Feeling 100%" reduces difficulty or keeps only easy and long runs for up to 14 days. https://intercom.help/runna/en/articles/12809806-feeling-unwell-how-to-adapt-your-training-plan
- Heat: Adapt for Heat adjusts paces for temperature and humidity. https://support.runna.com/en/articles/15647483-how-does-runna-adapt-my-workouts-for-heat-and-humidity and https://9to5mac.com/2026/07/29/runna-now-automatically-adapts-training-paces-based-on-heat-and-humidity/
- Race time edits recommended in 15 to 30 second steps. https://support.runna.com/en/articles/6205998-adjusting-your-estimated-race-time-and-pace-targets
- Positioning: Runna says coaches design plans and an algorithm tailors and adapts them; the algorithm itself is unpublished. https://www.techradar.com/health-fitness/are-ai-training-apps-like-runna-putting-you-at-risk-of-injury-i-asked-a-real-life-running-coach and https://the5krunner.com/2026/02/21/runna-ai-marathon-training-injury/ (the latter notes no peer reviewed study shows higher injury rates on Runna; ignore the unverified "2025 JAMA 23 percent" claim circulating from news.lavx.hu)

TriDot (vendor claims, no independent validation found):
- Four phase loop: Assess, Prescribe, Evaluate (TrainX execution score 1 to 100), Predict (RaceX race day planning). https://www.tridot.com/ and https://tridot.com/faq
- FitLogic engine re evaluates after every logged workout using pace, power, HR response, recovery signals, completion rate, consistency. https://finder.tridot.com/what-tridot-delivers
- EnviroNorm normalizes prescribed intensities for temperature, humidity, elevation, wind, terrain, indoor vs outdoor. https://tridot.com/faq
- Marketing claims to treat skeptically: "train up to 30 percent less," "20+ years of athlete data." https://apps.apple.com/us/app/tridot-triathlon-training/id6754208848

Pattern for a solo dev MVP: coach authored template plans + deterministic rules (shift missed workouts, realign after a missed week, pace nudges from repeated over/under performance, illness mode, taper lock) covers what Runna documents. That is honest to ship as "coach designed plans with rule based adaptation," and avoids unverifiable AI claims.

## 9. Race day pacing and nutrition calculators

Pacing (bike leg dominates the math):
- IF targets by distance: roughly 0.70 to 0.90 of FTP depending on distance and fitness (vendor guidance). https://www.bestbikesplit.com/blog/ironman-bike-pacing-intensity-factor-tss and https://www.bestbikesplit.com/blog/pacing-70-3-bike-leg-intensity-factor-tss
- Flat windless calculators can be off by 15 to 25 minutes on an Ironman on hilly or windy courses; full plans model terrain, wind, aero segment by segment (Best Bike Split sells this as second by second power plans). https://www.bestbikesplit.com/triathlon-bike-pace-calculator and https://www.bestbikesplit.com/blog/what-is-best-bike-split
- Sanity rule: if training rides never reached the planned race TSS, ride the bottom of the IF range. https://www.trainerroad.com/forum/t/70-3-triathlon-training-plan-and-race-day-pacing/54340

Nutrition:
- Jeukendrup, Jentjens, Moseley "Nutritional Considerations in Triathlon": 5 to 8 percent carb concentration, aim for 60 to 70 g carbs/hour, up to 90 g/h if tolerable; dehydration and glycogen depletion are the main fatigue causes; GI problems, hyperthermia, hyponatremia are the health threats. https://typeset.io/pdf/nutritional-considerations-in-triathlon-33u57spi4y.pdf
- Mechanism for 90 g/h: SGLT1 glucose transport caps near 60 g/h; adding fructose (2:1 glucose:fructose) raises absorption to about 90 g/h; practical targets 60 to 90 g/h on the bike, 50 to 70 g/h on the run. https://www.triathlete.com/nutrition/triathletes-guide-to-race-fueling/
- Scaling by duration (Jeukendrup review via press): up to 30 g/h for 1 to 2 h, up to 60 g/h for 2 to 3 h, 90 g/h beyond 3 h. https://www.pressreader.com/canada/calgary-herald/20140724/282411282446162
- By distance (commercial table, verify before shipping): Olympic 30 to 60 g/h, 70.3 60 to 90, full 70 to 90. https://dischemlivingfit.co.za/endurance/the-ideal-race-day-fuelling-strategy-for-a-triathlon/
- Sodium and fluid: no primary figure found in this pass; sources conflict (drink to thirst vs about 1.5 L/h). A calculator should stay conservative: carbs per hour by duration and distance, fluid by thirst plus sweat rate test option, and avoid prescribing sodium without a primary source (ACSM or IOC consensus statement would be the next lookup).

## 10. Injury safe progression

- 10 percent rule: the one direct RCT (Buist et al., Am J Sports Med 2008; 36(1):33-39, GRONORUN, N = 532 novice runners) found a 13 week graded program built on the 10 percent rule produced the same injury rate as a standard 8 week program (20.8 vs 20.3 percent). https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1821023/ (protocol) and https://research.rug.nl/en/publications/no-effect-of-a-graded-training-program-on-the-number-of-running-r (result)
  Implication: use graded progression as a sane default (cap weekly volume growth around 10 percent, insert recovery weeks) but never claim it prevents injury.
- Run walk: Hottenrott et al. 2016, J Sci Med Sport, randomized trial, 42 non elite marathoners: run/walk finished in similar time to continuous running (about 4:14 vs 4:08, p = 0.377), no reduction in cardiac stress markers, but less muscle pain and fatigue after the race (p = 0.006). https://pubmed.ncbi.nlm.nih.gov/25467199/
  Galloway's own 500,000 runner figures are self reported program data, not peer reviewed. https://runnersconnect.net/galloway-run-walk-run/ ; NZ Herald notes little scientific research exists on the method overall. https://nzherald.co.nz/lifestyle/the-secret-to-better-running-walking/4E5KOPY7K5HJHGHCMZ2X6HD7BI
  Implication: offer run/walk intervals (for example start 2:1 or 90s:30s) in beginner plans, framed as comfort and adherence, citable to Hottenrott for "similar finish times, less soreness."
- ACWR spike flags: see section 7; heuristic only.

## 11. Certifications and disclaimers

- No statute or App Review rule mandating specific disclaimers surfaced; what exists is near universal industry practice plus Apple guideline 5.1.1 style data rules (not fetched this pass). Standard disclaimer elements across fitness apps: not medical advice or diagnosis; consult a physician before starting (especially 35+, pregnant, heart conditions, diabetes); stop if dizzy, pain, shortness of breath; call emergency services for emergencies; assumption of risk; limitation of liability. Examples: https://www.ifit.com/legal/ifit-medical-disclaimer , https://notfit.io/medical-disclaimer , https://smartgymapp.com/terms/ ; checklist at https://terms.law/Terms-Scanner/app/fitness/
- Apps citing human coaching credibility: Runna leads with "plans designed by experienced coaches" and employs named head coaches (https://www.tomsguide.com/wellness/running/exclusive-runna-just-announced-a-new-partnership-so-i-sat-down-with-the-head-coach-to-find-out-more). No source found requiring a certification (like USAT or ACSM) to publish training plans; credibility is marketing, not regulation. Gap: FDA software as medical device boundaries were not researched; a plain training planner that does not diagnose or treat stays clearly outside, but a physician should not be replaced by this note.

## 12. Minimum viable plan engine vs AI claims

Synthesis from the above:
1. Inputs: race distance + date, current fitness tests (CSS from 400/200, FTP or LTHR from 20 or 30 min tests, run threshold pace), weekly hours available, days available, experience level.
2. Template library: per distance and level, 8 to 24 week skeletons with base/build/peak/taper ratios and 3+1 loading, about 80/20 intensity distribution, one weekly transition run in build/peak, recovery weeks, taper rules.
3. Zone engines: CSS offsets for swim, percent FTP or LTHR for bike, threshold pace bands for run. All formulas above are public domain math; only the TrainingPeaks names are off limits.
4. Load model: session load from power (IF^2 x h x 100 under an original name) with HR TRIMP fallback (Edwards engine already exists in Liftspark); CTL/ATL/TSB with 42/7 constants under original names like Fitness/Fatigue/Form (the names Fitness, Fatigue, Form are generic and used by intervals.icu and others).
5. Rule based adaptation (matches everything Runna documents): shift a skipped workout, realign after 3+ misses or a missed week, nudge paces on consistent over or under performance, illness mode capping intensity for up to 14 days, ramp caps (about 10 percent weekly growth, ACWR style spike warning), taper protection.
6. Race tools: pacing from IF by distance with the honest flat course caveat, carb per hour calculator by duration (30/60/90 g/h tiers), fluid by thirst and optional sweat rate.
7. Copy: "coach built plans that adapt by transparent rules," never "AI coach"; disclaimers per section 11.

This whole set is implementable solo with no licensed IP: the science (Seiler, Coggan math, Banister, CSS, Jeukendrup) is published; the only legal care points are TrainingPeaks trademarks (rename metrics, no attribution needed if names are not used), GPL boundaries around GoldenCheetah code, and standard medical disclaimers.

## Open questions for follow up
- Verify TSS/NP/IF registrations directly on USPTO TSDR and whether "rTSS" and "hrTSS" are separately registered.
- Primary sodium and fluid guideline (ACSM position stand or IOC consensus) for the nutrition calculator.
- Exact Coggan zone boundaries from Training and Racing with a Power Meter (book) rather than a calculator site.
- Stoggl and Sperlich 2014 primary paper for the exact VO2max effect size.
- Skiba GOVSS / BikeScore open formulas (nothing surfaced; GoldenCheetah source would document them, but it is GPLv3).
- Whether any triathlon app publishes its adaptation algorithm (none found; Runna and TriDot both keep theirs closed, which is a transparency opportunity).
