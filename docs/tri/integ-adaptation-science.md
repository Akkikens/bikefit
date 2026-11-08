# Adapting a plan to recovery and readiness data: evidence and a safe design

Research notes, 2026-11-08, for the Brickline wearable integration decision (Garmin, Apple Watch, WHOOP, Oura). Scope: what the science supports, how wearables and commercial products behave, the regulatory and App Store limits, and 5 candidate rules with thresholds. No em or en dashes anywhere. Every fact carries the URL it came from. Where a page was blocked or only a search snippet was available, that is stated next to the fact.

Retrieval notes: PubMed and PMC pages return bot checks to the fetch tool, so abstracts were read through the Europe PMC REST API (https://www.ebi.ac.uk/europepmc/webservices/rest/search with query EXT_ID:<pmid> AND SRC:MED). The PubMed URL given is the canonical record of the same abstract. Whoop.com marketing pages and the TrainingPeaks help center returned HTTP 403; WHOOP facts come from developer.whoop.com or are marked secondary.

---

## 0. Bottom line

1. The evidence that HRV guided training beats a good predefined plan on fitness or performance is small and mostly not statistically significant. The consistent finding is that HRV guided groups do fewer moderate and hard sessions and end up at least as fit, with fewer non-responders. That is a safety and efficiency story, not a "faster" story. Copy must not promise faster.
2. Every protocol that worked used personal baselines, nightly or morning HRV, and acted only in the direction of backing off hard work. No protocol raised load because readiness looked high.
3. Single night values are noisy. Weekly means and rolling averages track training status better than isolated days (Le Meur 2013, Plews 2014). A minimum of 3 valid nights per week is the published floor.
4. Wearable data quality is uneven. Resting heart rate is measured well by most devices. Nightly HRV ranges from good (Oura, WHOOP at group level) to poor (Apple Watch on serial HRV, Garmin in one study). Sleep duration is valid on all major devices; sleep stages are not (agreement 50 to 65 percent).
5. Proprietary readiness scores (Garmin Training Readiness, WHOOP Recovery, Oura Readiness) have no independent published validation that they predict training outcomes. I found none in Europe PMC; one vendor affiliated style preprint exists. Use the underlying components (HRV, resting heart rate, sleep time) and show vendor scores only as attributed context.
6. A 2026 expert paper names the real gap: not data availability but "transparent, physiologically grounded decision frameworks". Transparent rules with a stated reason is exactly the credible position for a free app.
7. FDA January 2026 general wellness guidance explicitly allows non-invasive sensing outputs including HRV for wellness uses, and says such products may display values, ranges, trends and baselines in the context of sleep, activity, stress and recovery, as long as there are no disease references, no diagnostic thresholds, no clinical action prompts and no clinical accuracy claims. A readiness feature fits inside this if the copy discipline already in the spec holds.
8. Apple guideline 1.4.1 and 5.1.3 do not block this, but require honest methodology disclosure, no false HealthKit writes, no health data for marketing or data mining, and no health data in iCloud.
9. Do not mix sources. HealthKit gives SDNN; WHOOP and Oura give rMSSD. Baselines are per device and per metric. A device change resets calibration.
10. Overrides are not optional UX: the athlete can always keep the planned session, and the app never prescribes rest.

---

## 1. HRV guided versus predefined training

### 1.1 Systematic reviews and meta-analyses

| Review | Evidence base | Result | Notes |
|---|---|---|---|
| Duking et al. 2021, J Sci Med Sport. https://pubmed.ncbi.nlm.nih.gov/34489178/ (DOI 10.1016/j.jsams.2021.04.012) | 8 studies, 198 participants, 9 interventions | Submaximal physiological parameters g = 0.296 (95% CI 0.031 to 0.562, p = 0.028). Performance g = 0.079 (CI printed as minus 0.050 to 0.393, p = 0.597). VO2peak g = 0.171 (CI minus 0.213 to 0.371, p = 0.130). Most HRV guided groups did fewer moderate and hard sessions. Fewer non-responders and more positive responders for performance. | Fixed effects model. The printed performance CI does not centre on g; quote as printed or avoid. |
| Manresa-Rocamora et al. 2021, IJERPH. https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/ (abstract also https://pubmed.ncbi.nlm.nih.gov/34639599/) | 8 studies, 10 analysis units, 199 participants (106 HRV guided, 93 predefined), searches to Oct 2020 | Vagal HRV indices SMD 0.50 (CI 0.09 to 0.91). Resting HR SMD 0.04 (CI minus 0.34 to 0.43). Maximal aerobic capacity SMD 0.20 (CI minus 0.07 to 0.47). Second ventilatory threshold 0.26 (CI minus 0.05 to 0.57). Endurance performance 0.20 (CI minus 0.09 to 0.48). No heterogeneity for fitness outcomes. | Authors: HRV guided training "may be more effective" for vagal HRV with less chance of negative responses; group level fitness advantage is only by a small margin; best methods for index, position, and fixed versus rolling baselines "require further study". Interventions 2 to 8 weeks, healthy adults about 22 to 39. A full text pass returned VO2max 0.13 for a variant analysis; the abstract's 0.20 is the headline. |
| Granero-Gallegos et al. 2020, IJERPH. https://pubmed.ncbi.nlm.nih.gov/33143175/ (PMC7663087, page blocked by bot check, abstract via Europe PMC) | Randomized trials in trained endurance athletes, VO2max only | Small positive effect ES = 0.402. Amateur level and female subgroups showed better significant results. | Random effects. Moderator analyses on level and sex. |
| Duking et al. 2020, Scand J Med Sci Sports (runners only). https://pubmed.ncbi.nlm.nih.gov/32785959/ | 5 studies, 6 interventions, 166 participants | Four HRV based interventions cut moderate and hard training significantly. In five interventions performance improved more with HRV based training; VO2peak improved in both with no clear difference; submaximal parameters tended to improve more with HRV. | Authors: findings "limited and inconsistent". |
| Schaffarczyk and Sperlich 2026, Front Sports Act Living (SWOT analysis, not a meta-analysis). https://pubmed.ncbi.nlm.nih.gov/42724227/ (DOI 10.3389/fspor.2026.1858271) | Narrative critical appraisal | Main limitation "is no longer the availability of physiological data, but the lack of transparent and physiologically grounded decision frameworks". Threats: rule frameworks that oversimplify context, limited real world replication, "growing dependence on proprietary metrics whose underlying algorithms lack transparency". Opportunities: transparent multivariate decision architectures, baseline and progression logic. | Directly supports transparent rules plus reason lines. |

Reading across the reviews: pooled fitness gains are small (SMD about 0.1 to 0.4), mostly non-significant, and based on 5 to 8 small studies. The robust differences are (a) fewer hard sessions in the HRV groups and (b) fewer non-responders. Neither review population is triathletes managing three sports.

### 1.2 Individual trials that define the protocols

| Trial | Design | Protocol | Result |
|---|---|---|---|
| Kiviniemi et al. 2007. https://pubmed.ncbi.nlm.nih.gov/17849143/ | 26 healthy moderately fit men, 4 weeks, predefined vs HRV guided vs control | Morning HF HRV. Increase or no change: hard session. "Significant decrease" (below the 10 day mean minus 1 SD, or decreasing trend for 2 days): low intensity or rest. | Max running speed rose 0.9 km/h in HRV group vs 0.5 in predefined (P = 0.048). VO2peak change not significantly different between groups. |
| Vesterinen et al. 2016, MSSE. https://pubmed.ncbi.nlm.nih.gov/26909534/ | 40 recreational runners, 4 week prep then 8 weeks | Morning HRV daily. Moderate or hard session only if HRV within the individually determined smallest worthwhile change (SWC); otherwise low intensity. | EXP did 13.2 moderate or hard sessions vs 17.7 in TRAD (P = 0.021, ES 0.98). 3000 m speed improved 2.1% in EXP (P = 0.004) vs 1.1% in TRAD (not significant); between group ES 0.42. VO2max improved in both. |
| Javaloyes et al. 2019, IJSPP. https://pubmed.ncbi.nlm.nih.gov/29809080/ | 17 well trained cyclists, 4 baseline weeks to establish resting HRV, then 8 weeks | HRV guided vs traditional periodization. | HRV group improved peak power 5.1%, second threshold power 13.9%, 40 minute time trial 7.3%; traditional group did not improve significantly. No significant between group differences; "likely beneficial" by magnitude based inference. |
| Nuuttila et al. 2022, MSSE. https://pubmed.ncbi.nlm.nih.gov/35975912/ | 30 recreational runners, 15 weeks (3 prep, 6 volume, 6 interval) | Individualized group's load decreased, maintained or increased twice a week using nocturnal HRV, perceived recovery, and a heart rate to running speed index. | 10 km time improved 6.2% vs 2.9% (P = 0.002). High responders 50% vs 29%; low responders 0% vs 21%. The only trial here that combined an objective signal with a subjective one. |
| Plews et al. 2012, case study of two elite triathletes. https://pubmed.ncbi.nlm.nih.gov/22367011/ | 77 days, 23 hours per week | 7 day rolling average of ln rMSSD and its coefficient of variation | The athlete who became non-functionally over-reached showed a falling rolling average (slope minus 0.17 ms per week) and a falling coefficient of variation; the control stayed stable. n = 2, hypothesis generating only. |

Protocol details pulled from the Manresa-Rocamora full text (https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/): 7 of 8 studies measured HRV each morning after waking; RMSSD in 5 studies, HF in 2, SD1 in 1; 4 studies compared a single day value against a moving reference and 4 used rolling averages (7 day in 3, 3 day in 1) against a fixed reference; moving references used a 10 day average with mean minus 1 SD (3 studies) or 70% of the previous day (1); fixed references used mean plus or minus 0.5 SD (3 studies) or the baseline mean (1). No included study reported an SWC as such.

### 1.3 Measurement protocol evidence (daily, rolling, coefficient of variation)

- Averaging beats single days. Plews 2014: standardized change in ln rMSSD from baseline to functional overreaching grew from 0.20 (1 day) to about 0.49 (3 days) and plateaued; conclusion "a minimum of 3 (randomly selected) valid data points per week". https://pubmed.ncbi.nlm.nih.gov/24334285/
- Le Meur 2013 (21 triathletes, 3 week overload): once per week HRV values showed no clear effect because of wide day to day variability; weekly means detected a progressive rise in parasympathetic indices during functional overreaching, reversing in taper. https://pubmed.ncbi.nlm.nih.gov/24136138/ This also means "low HRV = bad" is not a safe rule. In functional overreaching HRV can go up.
- Plews 2013 review: HRV "saturation" in elite athletes (HRV falls while resting HR also falls) and recommends averaging techniques and specific indices; elite responses are equivocal in both directions. https://pubmed.ncbi.nlm.nih.gov/23852425/
- Buchheit 2014: most contradictions in the literature trace to methods and misreading; use 5 minute near daily resting measures and submaximal HR; interpret changes against measurement error and the smallest important change; combine with training logs, psychometric questionnaires and simple performance tests. https://pubmed.ncbi.nlm.nih.gov/24578692/
- Bellenger 2016 meta-analysis (27 studies in the review, 24 in the meta-analysis): resting vagal HRV rose in positive adaptation (resting RMSSD SMD 0.58), but also rose slightly in performance-decreasing training (SMD 0.26); "resting HRV is largely unaffected by overreaching" and post exercise HRV and heart rate recovery rose in overreaching too. https://pubmed.ncbi.nlm.nih.gov/26888648/
- Coefficient of variation: used as a trend signal in Plews 2012 (above). It is still research-grade (case level), not a validated consumer rule. I found no controlled trial that used CV of HRV as the decision variable. Treat as display-only or omit.
- Nocturnal vs morning: nocturnal HR and HRV indices are highly reliable between nights and respond to a maximal effort most systematically in the full night and first 4 hour segments (Nuuttila et al. 2022, IJSPP, 15 to 23 recreational runners). https://pubmed.ncbi.nlm.nih.gov/35894977/ A 2024 follow-up compared nocturnal and morning segments in 24 runners during a 2 week overload. https://pubmed.ncbi.nlm.nih.gov/39503915/ This supports using overnight values from wearables as the measurement.

### 1.4 What overtraining science says about markers

ECSS and ACSM joint consensus (Meeusen et al. 2013): no marker, hormonal, performance, psychological, biochemical or immune, "meets all the criteria" for general acceptance in detecting overreaching or the overtraining syndrome; diagnosis is by exclusion. https://pubmed.ncbi.nlm.nih.gov/23247672/ Consequence for Brickline: the app must never say it detects overtraining.

Subjective measures: a systematic review of 56 studies (Saw et al. 2016, BJSM) found subjective well being "reflected acute and chronic training loads with superior sensitivity and consistency than objective measures", and the two generally did not correlate. https://pubmed.ncbi.nlm.nih.gov/26423706/ Consequence: a one tap check-in belongs in the signal set, and a rule that ignores it is weaker than one that includes it.

---

## 2. Signals and what moves them

### 2.1 Resting heart rate and HRV in free living data

Altini and Plews 2021 (28,175 people, 9 million measurements, morning smartphone readings). https://pubmed.ncbi.nlm.nih.gov/34883936/

| Stressor | Heart rate change | HRV change |
|---|---|---|
| Training | 1.3% | 4.6% |
| High alcohol intake | plus 6% | minus 12% |
| Menstrual cycle, follicular to luteal | 1.6% | 3.2% |
| Sickness | plus 6% | minus 10% |

Their conclusion: HRV is "a more sensitive but not specific marker of stress". Menstrual cycle HRV effects are mechanistically linked to progesterone (Schmalenberger et al. 2020, 90 naturally cycling participants across two studies; lower HRV in the mid luteal phase). https://pubmed.ncbi.nlm.nih.gov/32106458/

Design consequences: (a) typical off-day effects of 5 to 12% are the same size as wearable HRV error (section 3), so a single reading cannot carry a decision; (b) alcohol, sickness, cycle phase and ordinary hard training all produce the same signature, so the app cannot name a cause; (c) the app should let the athlete tag a night (for example "alcohol", "travel", "unwell") so those nights are excluded from the baseline, and should not guess.

### 2.2 Resting heart rate trends

- Resting heart rate is measured accurately by most wearables (section 3) but is less sensitive than HRV (Altini above: 1.3% change with training, 6% with sickness or alcohol).
- Manresa-Rocamora found no difference in resting HR between HRV guided and predefined training (SMD 0.04). Resting HR as a primary trigger has no controlled trial support that I found.
- I did not find a primary source that validates a fixed "plus 5 to 7 bpm morning heart rate" overtraining rule. Do not ship an absolute bpm rule. Use deviation from the athlete's own baseline in SD units, and only as a corroborating signal.

### 2.3 Sleep and training load

- Sleep and the athlete: 2021 expert consensus (Walsh et al., BJSM). Athletes often sleep under 7 hours; habitual short sleep raises respiratory infection susceptibility in the general population; recommends an individualised approach rather than a one size 7 to 9 hour target. https://pubmed.ncbi.nlm.nih.gov/33144349/
- Acute sleep loss meta-analysis (Craven et al. 2022, 69 publications, 227 outcomes): sleep of 6 hours or less lowered exercise performance by a mean of 7.56% (95% CI 3.13 to 11.9), with deprivation and late restriction protocols consistently negative; about 0.4% performance loss per hour awake before the task; tasks in the afternoon and evening were affected, morning tasks largely not. Heterogeneity was very high (I squared 98.1%). https://pubmed.ncbi.nlm.nih.gov/35708888/
- I did not find a trial showing that cancelling or swapping a planned session after a short night improves training adaptation. The performance cost is documented; the benefit of acting on it is not. So sleep alone should inform, not restructure.
- Orthosomnia caution: clinicians report patients developing a "perfectionistic quest for the ideal sleep" from tracker data (Baron et al. 2017, JCSM). https://pubmed.ncbi.nlm.nih.gov/27855740/ In a qualitative study of 17 WHOOP and Oura users, people modified non-exercise behaviour to manage their scores while recognising "you can't really capture the complexities of a human on a device" (Ibrahim et al. 2024). https://pubmed.ncbi.nlm.nih.gov/38668986/ Design consequence: show trends and plain words, not a daily grade; do not gamify sleep.

---

## 3. Validity of wearable signals

### 3.1 Device studies

| Device and metric | Study | Finding |
|---|---|---|
| WHOOP, HR and ln rMSSD vs ECG | Bellenger et al. 2021, Sensors. https://pubmed.ncbi.nlm.nih.gov/34065516/ | HR bias 0.39% or less, within error. ln rMSSD bias 1.66 (plus or minus 1.80)% with limits of agreement of plus or minus 5.93%, which "approached or exceeded" the SWC (1.5 to 6.5%) and CV (3 to 13%). Interpret against its own bias. |
| Oura Gen 2/3, nocturnal HR and HRV vs ECG | Cao et al. 2022, JMIR (35 adults). https://pubmed.ncbi.nlm.nih.gov/35040799/ | Accurate nocturnal HR and RMSSD in 5 minute and per night tests; LF and LF:HF unreliable. |
| Five wearables vs ECG, 536 nights, 13 adults | Dial et al. 2025, Physiol Rep. https://pubmed.ncbi.nlm.nih.gov/40834291/ | RHR: Oura Gen 4 CCC 0.98 and Gen 3 0.97 (MAPE 1.7 to 1.9%); WHOOP 4.0 0.91 (MAPE 3.00%); Polar poor; Garmin excluded from RHR for methodological inconsistencies. HRV: Oura Gen 4 CCC 0.99 (MAPE 5.96%), Gen 3 0.97 (7.15%), WHOOP 0.94 (8.17%), Garmin Fenix 6 0.87 (10.52%), Polar 0.82 (16.32%). Small sample. |
| Six wearables vs polysomnography and ECG | Miller et al. 2022, Sensors (53 adults, 1 night). https://pubmed.ncbi.nlm.nih.gov/36016077/ | Sleep/wake agreement 86 to 89% for Apple Watch S6, Garmin FR245, Polar, Oura Gen 2, WHOOP 3.0; all "valid for the field-based assessment of the timing and duration of sleep". Sleep stages: agreement 53% (Apple), 50% (Garmin), 51% (Polar), 61% (Oura), 60% (WHOOP); "all six devices require improvement" for stages. Oura Gen 2 underestimated HRV by about 10 ms in the full text. |
| Apple Watch S9 / Ultra 2, serial HRV and RHR vs Polar H10 | O'Grady et al. 2024, Sensors (39 adults, 316 HRV measurements). https://pubmed.ncbi.nlm.nih.gov/39409260/ | HRV underestimated by 8.31 ms on average, MAPE 28.88%, MAE 20.46 ms, not equivalent within plus or minus 10 ms. RHR accurate (MAPE 5.91%, MAE 3.73 bpm). Authors call for "caution in interpreting HRV data" for performance monitoring. |
| Apple Watch S6 HRV vs ECG | Bonneval et al. 2025, Sensors (78 adults). https://pubmed.ncbi.nlm.nih.gov/40285070/ | R-R intervals and BPM near perfect; N-N interval (the basis of HRV) only moderate, MAPE 31.31% at rest. |
| WHOOP overall | Khodr et al. 2024, medRxiv preprint systematic review. https://doi.org/10.1101/2024.01.04.24300784 | Acceptable accuracy for two stage sleep and HR; "room for improvement" for four stage sleep and HRV; effect on athletic performance "limited based on existing studies". Preprint, not peer reviewed. |

Garmin: only Dial 2025 (Fenix 6, HRV CCC 0.87, poor) and Miller 2022 (Forerunner 245 sleep) were found. Newer Garmin hardware is not covered by independent HRV validation in what I found.

### 3.2 Validity of the composite scores

- I searched Europe PMC for independent validation of Garmin Training Readiness, WHOOP Recovery and Oura Readiness predicting training outcomes or performance. Nothing peer reviewed turned up that tests whether acting on the score improves training results. Candidates seen: a 2023 preprint (Nilsson et al., Garmin plus a 9 item questionnaire, adaptive versus static training in runners, 39 days) which reports better outcomes in the adaptive group, https://doi.org/10.1101/2023.10.06.561160 (preprint, authors' commercial affiliation not checked); an observational study of 389 pro golfers using a wearable composite recovery score (Grosicki et al. 2026, IJSPP). https://pubmed.ncbi.nlm.nih.gov/41265431/ Neither tests a plan changing rule against a control in multisport athletes.
- A surgeon study found no association between an HRV based wearable recovery score and perceived workload (Perrone et al. 2025). https://pubmed.ncbi.nlm.nih.gov/39788069/ Different population, but a reminder that a score is not a measured state.
- Conclusion for design: treat vendor scores as inputs the athlete already looks at, not as evidence. Triggers should be made from named components whose method Brickline can state.

### 3.3 What reaches an iPhone app

- HealthKit HRV is SDNN, recorded automatically on Apple Watch (https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn). WHOOP's API field is hrv_rmssd_milli (https://developer.whoop.com/api/). Oura's dashboard HRV is RMSSD (Cao 2022 above). SDNN and RMSSD are different quantities, never mix them or compare absolute values across sources.
- Apple's resting heart rate is an estimate built from sedentary samples across the day (https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate). Sleep analysis category with stages is available (https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/sleepanalysis).
- Do WHOOP, Oura and Garmin write HRV to Apple Health? Per a third-party compilation (secondary, https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin): WHOOP states it does not export HRV to Apple Health (SDNN versus rMSSD), exports resting HR and sleep; Oura exports sleep and 1 minute heart rate but not HRV or readiness; Garmin exports sleep and workouts but not HRV, Body Battery or Training Readiness. Oura's own page confirms its Apple Health export list (sleep with stages and respiratory rate, 1 minute heart rate, steps, weight, height, energy, workouts, mindful minutes) and omits HRV and resting heart rate: https://ouraring.com/blog/data-sharing-partner-integrations/ WHOOP's statement and the Garmin list are not confirmed from primary pages. Implication: HRV from WHOOP and Oura needs their cloud APIs (the Liftspark OAuth proxies); Garmin HRV needs the Garmin program or stays out; Apple Watch HRV is available directly but is the weakest measurement.
- WHOOP API scopes and fields (https://developer.whoop.com/api/): read:recovery gives recovery score, HRV and resting heart rate; read:sleep gives performance percentage and duration per stage; read:cycles gives day strain; read:workout gives activity strain; read:profile gives name and email. Recovery response includes recovery_score, resting_heart_rate, hrv_rmssd_milli, spo2_percentage, skin_temp_celsius, user_calibrating. Oura v2 offers a daily_readiness endpoint and scopes including daily and heartrate (https://cloud.ouraring.com/v2/docs, from search summary). The Liftspark proxy currently requests WHOOP 'offline read:recovery read:cycles read:workout read:sleep read:profile' and Oura 'daily heartrate workout personal' (/Users/akshay/Documents/GitHub/liftspark/backend/lib/providers.ts). Least privilege for this feature would drop read:profile and personal. Do not store or display spo2 or skin temperature fields (see section 5).

---

## 4. How products adapt and what they claim

| Product | Signals used | Adaptation behaviour | Claims and transparency | Source quality |
|---|---|---|---|---|
| Garmin Training Readiness | Sleep score (last night), recovery time, HRV status, acute load, sleep history (last 3 nights), stress history (last 3 days). Score 1 to 100: Prime 95 to 100 "Best possible", High 75 to 94 "Ready for challenges", Moderate 50 to 74 "Good to go", Low 25 to 49 "Time to slow down", Poor 1 to 24 "Let your body recover". | A score and a message; no plan change by itself. | No numeric weights published; manual page has no accuracy disclaimer. https://www8.garmin.com/manuals/webhelp/GUID-31D23DBB-57C2-4DF7-A0C9-8D1A00AB4BE7/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html | Primary, fetched |
| Garmin HRV Status | 7 day average of overnight HRV against a personal baseline range. Balanced (within), Unbalanced (above or below), Low (well below), Poor (well below the normal for age), No status (insufficient data). Needs 3 weeks of consistent sleep data. | Status display; feeds Training Readiness. | No numeric cutoffs published. https://www8.garmin.com/manuals/webhelp/GUID-2366BA73-C5B3-4189-B75F-EFA9B2402BD5/EN-US/GUID-9282196F-D969-404D-B678-F48A13D8D0CB.html | Primary, fetched |
| Garmin Daily Suggested Workouts | Training status, VO2 max estimate, training habits, recovery time. | Suggests a run or bike workout; user can do, dismiss, preview, change target or disable. Manual does not say HRV is an input; behaviour reports conflict. | https://www8.garmin.com/manuals/webhelp/GUID-2492EDA1-1182-400B-8F43-D8B3211E4F3C/EN-US/GUID-1F857C7A-31A2-46AF-A639-2C3F5ECC3AF1.html | Primary, fetched; behaviour claims from third parties are anecdotal |
| WHOOP Recovery and Strain Target | Resting HR, HRV, respiratory rate, sleep duration and quality, skin temperature, blood oxygen. Recovery 0 to 100: green 67 to 100, yellow 34 to 66, red 0 to 33. Strain 0 to 21. | Strain Target suggests a daily exertion level from Recovery and strain so far. | Recovery computed on waking from the previous day and sleep; WHOOP states strain is baseline specific. https://developer.whoop.com/docs/whoop-101/ Calibration: colored scores after 4 recoveries, full baseline at 30 (search snippet of https://support.whoop.com/hc/en-us/articles/360019453454-WHOOP-Recovery, not fetched). Strain Target details from whoop.com pages were blocked (403); search summary only. | Developer docs primary; rest secondary |
| Oura Readiness | Contributors: Resting Heart Rate (vs about 2 month average), HRV Balance (14 day vs 3 month average, recent days weighted more), Body Temperature, Recovery Index, Sleep, Sleep Balance, Sleep Regularity, Previous Day Activity, Activity Balance. Bands: 85 to 100 Optimal, 70 to 84 Good, 60 to 69 Fair, 0 to 59 Pay Attention. Averages take up to 2 weeks to establish. | Score and contributors. An Oura blog page frames under 70 as "not fully recovered". | https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors and https://ouraring.com/blog/readiness-score/ (the blog and support band labels differ) | Primary, fetched |
| Apple Vitals (Apple Watch) | Overnight heart rate, respiratory rate, blood oxygen, wrist temperature, sleep duration; personal "typical range" after about 7 nights. | Morning notification when several metrics are outside the typical range; suggests possible causes; "not intended for medical use". Not a training plan feature. | https://support.apple.com/120142 | Primary, fetched. The "at least two metrics" default came from a search summary of Apple support pages. |
| TriDot | FitLogic: pace, power, heart rate response, recovery signals, completion rate, consistency (App Store listing wording). | Re-evaluates after each logged workout. I could not confirm that it reads overnight HRV or readiness from wearables. | https://apps.apple.com/us/app/id6754208848 (search snippet) and the existing note docs/tri/tri-research-training.md | Vendor, snippet |
| Athletica | HRV, resting HR, and a well being check-in, as a "traffic light" (High, Low, Rest). | Advisory: the coach "gives advisory guidance" and does not change training load automatically; suggests lighter, similar or harder alternatives. Cites a 31 day study after a 9 day baseline where the group using all three signals improved most on 5 and 20 minute power. No numeric thresholds or windows published; journal attribution inconsistent across their own pages (not verified). | https://news.athletica.ai/posts/the-coaching-professor-train-smarter-with-the-readiness-triad-hrv-rhr-well-being-in-athletica | Vendor, fetched |
| Humango | HRV against a personal normal range (wearable); also mentions Body Battery and WHOOP recovery in reviews. | If HRV is below the personal range it asks whether you want a new plan; "doesn't change your plan automatically". No windows or thresholds. | https://granfondoguide.com/Contents/PopUp/7751/how-humango-uses-heart-rate-variability-hrv-to-adapt-your-training | Vendor content on a third-party site, fetched |
| TrainerRoad Adaptive Training | Performance in past workouts (cycling); for swim and run, missed sessions only. HRV use unconfirmed. | Adjusts which workouts the plan recommends; does not modify workouts. | https://support.trainerroad.com/hc/en-us/articles/4404060687387-Adaptive-Training-Overview (search snippet) | Vendor, snippet |
| TrainingPeaks | Ingests sleep, HRV and resting HR from WHOOP and Oura (one way); I found no native readiness driven plan change. | Display, not adaptation. | https://help.trainingpeaks.com/hc/en-us/articles/43936160193165-TrainingPeaks-and-Oura-Ring (403, search snippet) | Snippet only |
| Runna | I could not confirm any HRV or readiness input from Runna's own pages. Documented adaptation is skip and shift, realignment, pace nudges, unwell mode (spec B39). | Rules on completion data. | Competitor pages claim Runna lacks WHOOP and Oura recovery inputs; unverified. | Unconfirmed |
| Reps (Apple Watch app, 2026) | 0 to 100 score from sleep, subjective wellness, HRV (median SDNN over nights with 3 or more hours sleep, 8:7 split between last night and 7 night trend), training load, RHR, hydration, alcohol, protein and more. Domains graded green, amber, red set an intensity ceiling (Unrestricted, Moderate, Light, Rest Only). | Applies the ceiling to the day's workout, shown as accept or decline; labelled "calibrating" until a personal baseline exists; explicit user request overrides. Uses irregular rhythm notification and critical blood oxygen to force Rest Only, and cannot be dismissed. | https://the5krunner.com/2026/07/27/reps-apple-watch-recovery-score/ | Review article, fetched. Useful as a design foil: calibrating label and override are good; coupling training changes to heart rhythm or oxygen events is the pattern to avoid. |

Patterns worth copying: personal baselines everywhere; "calibrating" states; multi signal agreement (Apple Vitals needs several metrics outside range; Athletica and Reps cross check); advisory or accept/decline rather than silent rewrites (Athletica, Humango, Reps, Garmin DSW). Patterns not to copy: opaque weights, red/amber/green verdicts without stated reasons, and any link from heart rhythm or blood oxygen events to training logic.

---

## 5. Regulatory and platform constraints

### 5.1 FDA general wellness (guidance issued 2026-01-06, supersedes the 2019 version)

Primary: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices ; full text read from https://www.fda.gov/media/90652/download.

- General wellness claims include physical fitness ("measure aerobic fitness, improve physical fitness, develop or improve endurance, strength or coordination") and sleep management ("track sleep trends"), provided they do not reference diseases or conditions.
- New: FDA may treat non-invasive sensing that outputs estimated physiologic parameters, with HRV named alongside blood pressure, oxygen saturation and glucose, as general wellness when solely for wellness uses and: non-invasive, no safety risk without controls, not intended to diagnose, cure, mitigate, prevent or treat a disease, not a substitute for a cleared device, no outputs "that prompt or guide specific clinical action or medical management", and no values mimicking clinical values unless validated.
- Qualifying products "may display values, ranges, trends, baselines, or longitudinal summaries, and may contextualize these outputs in relation to sleep, activity, stress, recovery, or similar wellness domains."
- Out of scope if labeling, advertising, UI or functionality: references specific diseases or diagnostic thresholds; alerts or prompts that recommend or require clinical action; gives treatment guidance; claims clinical equivalence, clinical accuracy, medical or clinical grade; or targets screening or disease management.
- A notification that evaluation by a healthcare professional may be helpful is allowed when it names no disease or condition, does not call the output abnormal, pathological or diagnostic, includes no clinical thresholds, diagnoses or treatment recommendations, and is not ongoing alerting to manage a disease.
- Illustrative Example 7 is a wrist wearable "intended to assess activity and recovery" with sleep and pulse outputs, treated as low risk general wellness provided any blood pressure value is validated. Example 9 covers an athlete wearable labeled for exercise and fitness only.
- Context: FDA's July 2025 warning letter about WHOOP's Blood Pressure Insights, later closed out after labeling changes and the updated guidance (secondary: https://www.kslaw.com/insights/articles/fda-updates-general-wellness-and-clinical-decision-support-guidance-documents). Lesson: the line is crossed by clinical-looking outputs and disease linked claims, not by HRV trend contexts.

Application to Brickline:
- Display ranges and trends such as "lower than your usual". Never "abnormal", "low HRV risk", "stress score", a named condition, or thresholds expressed as health cut points.
- The statistical thresholds in section 7 are relative to the athlete's own baseline and drive training choices; they are not diagnostic thresholds. Say so on the Methods screen.
- Do not ingest or display SpO2, skin or wrist temperature, blood pressure, ECG or irregular rhythm outputs. The WHOOP recovery payload carries spo2_percentage and skin_temp_celsius; drop them at parse time and unit test that they never reach storage or UI.
- The spec already forbids diagnose, treat, doctor, injury, illness, prevention claims, named conditions, medical grade, clinical, AI coach outside three exempt strings (tri-spec.md section 6). That fence is consistent with the FDA conditions above. The unwell toggle's exempt string ("see a doctor if it lingers") is user initiated and attaches to no sensor output, so it does not make a sensor output a clinical prompt. Do not auto-suggest unwell mode from sensor data in words that imply a condition; at most offer "Feeling off? You can switch to easy only" as a neutral choice.
- Keep sleep copy to duration and consistency, not stages (stages are weakly validated, section 3.1).

### 5.2 Apple App Store

Primary: https://developer.apple.com/app-store/review/guidelines/ (fetched, first 100,000 characters).

- 1.4.1: medical apps that could provide inaccurate data may get greater scrutiny; "Apps must clearly disclose data and methodology to support accuracy claims relating to health measurements"; apps that measure blood pressure, body temperature, glucose or blood oxygen using only device sensors are not permitted; medical apps should remind users to check with a doctor. Brickline measures nothing itself and claims no accuracy, so the lever is disclosure: Methods lists each input, its source device, baseline method and limits.
- 5.1.3(i): health, fitness and HealthKit data may not be used or disclosed to third parties for advertising, marketing or data mining other than improving health management or research, and then only with permission. Keep recovery data out of any analytics or third-party code path (the spec already has none).
- 5.1.3(ii): no false or inaccurate data into HealthKit; no personal health information in iCloud. Baselines derived from HealthKit and provider data stay out of any sync container (spec section 9 already enforces this for derived HealthKit data; extend the schema test to recovery baselines).
- 2.5.1: HealthKit used for health and fitness purposes; request only the read types needed (HRV SDNN, resting heart rate, sleep analysis).
- 5.1.1(ix) (highly regulated fields such as healthcare must be submitted by a legal entity) is the reason to keep the product firmly fitness, never "health monitoring".
- App Privacy: "collect" means transmitting data off device in a way that lets you or partners access it longer than needed to service the request in real time; an authentication token sent on a server call and not retained need not be disclosed (https://developer.apple.com/app-store/app-privacy-details/). The OAuth proxy fits this only if the backend retains nothing, including platform request logs; verify before claiming Data Not Collected. Calls from the device straight to WHOOP, Oura or Garmin servers are data coming to the device, but should still be reviewed with Apple's definitions by whoever owns the privacy label.

### 5.3 Other US exposure

The FTC Health Breach Notification Rule, amended in 2024, covers health apps and connected devices outside HIPAA, and its definition keys on an app having the "technical capacity to draw information from multiple sources"; notice to individuals within 60 days of breach discovery, FTC notice at the same time for 500 or more people (https://www.ftc.gov/business-guidance/blog/2024/04/updated-ftc-health-breach-notification-rule-puts-new-provisions-place-protect-users-health-apps). An app that pulls WHOOP, Oura and HealthKit data fits that description. Keeping tokens in the device Keychain and storing no health data server side is the cheapest way to have nothing to breach. State consumer health privacy laws were not researched here; see open questions.

---

## 6. Design principles for a defensible free app

1. Personal baselines, in the athlete's own units, per source and per metric. No absolute HRV, bpm or sleep cut points, except a plainly described floor such as 6 hours of sleep that the cited meta-analysis uses to define sleep loss.
2. Calibrate before acting. No rule fires until the baseline has enough valid nights; show "Calibrating, night 9 of 14" instead of a verdict (Garmin needs 3 weeks, Oura up to 2 weeks, Apple 7 nights, WHOOP 4 recoveries then 30 days, Reps shows "calibrating").
3. Act on persistence, not single readings: 2 consecutive low mornings, or a 7 night mean, with at least 3 valid nights per week (Plews 2014, Le Meur 2013).
4. Corroborate: a trigger needs a second signal (resting HR, sleep time, or the athlete's own check-in). Subjective well being is at least as sensitive as objective measures (Saw 2016) and the best performing individualized trial used both (Nuuttila 2022).
5. Only ever back off, never add. Good numbers never promote a session. Protocols in the literature were asymmetric, and high HRV is ambiguous (Le Meur 2013, Plews 2013).
6. Every change states a reason line in plain words with the numbers behind it, and the Methods screen shows the baseline, the window and the thresholds. This is the credibility edge (Schaffarczyk and Sperlich 2026).
7. Override always: one tap "Keep my planned session", remembered. Repeated overrides quiet the feature for a week rather than nagging. Never block, never guilt.
8. Never prescribe rest. The most the app does is swap a quality session for an easy one of similar length, or defer it by up to a day inside the week. Rest days are the athlete's choice.
9. Never medical. No cause attribution, no condition words, no heart rhythm, oxygen or temperature data, no accuracy claims for vendor numbers.
10. Data quality gates: stale data (older than 36 hours), too few valid nights, a device change, or a "calibrating" flag from the vendor (WHOOP user_calibrating) disable the rules and say why.
11. Apple Watch only athletes get a lighter version: weak HRV validity (MAPE about 29 to 31%) and irregular sampling mean HRV should be displayed as context, while sleep time, resting HR and the check-in drive any suggestion. This is a design inference from section 3, not from a trial.
12. Keep it a proposal by default. Industry practice (Athletica, Humango, Reps, Garmin DSW) is advisory or accept/decline. Practical reason for Brickline: the planned session is already on the watch from Sunday Sync, so the easy version is scheduled on demand when accepted (whether WorkoutScheduler can replace or remove a same-day scheduled item reliably is a spike item).

---

## 7. Five candidate rules

All rules are downward only, ordered, deterministic, and write a reason line. They slot into annex C after rule 4 (unwell) and before rule 6 (acute load spike), share the "one structural change per day" budget, are suspended by rule 7 only for anything that would add load (a swap to easy is still allowed in the taper window), and never fire for sessions already easy. Thresholds go in the single constants file. "HRV" below means the nightly value from that source, natural-log transformed, and "SD" means standard deviation of that athlete's own baseline nights.

### R1. Personal baseline and calibration gate (precondition)

- Definition: per source and metric, baseline is the mean and SD over the 35 nights before the most recent 7 nights (so a decline does not poison its own baseline). Needs at least 14 valid nights in that window and at least 3 valid nights in each of the last 2 weeks. Nights the athlete tags (alcohol, travel, unwell) are excluded. Before the gate opens the UI says "Calibrating" and no rule fires. Reset on device change.
- Evidence: Plews 2014 (3 valid nights per week minimum); Manresa-Rocamora 2021 (baselines from fixed or rolling windows, 10 day to 4 week, all individual); Oura (14 day vs 3 month, up to 2 weeks to establish), Garmin (3 weeks), Apple Vitals (about 7 nights), WHOOP (4 recoveries, 30 for full baseline) as industry precedents. The exact 35 plus 7 night split and the 14 night minimum are design choices; no trial compares window lengths (Manresa-Rocamora: methods "require further study").
- Strength: STRONG for the principle (personal, averaged, calibrated); WEAK for the specific numbers (tunable).

### R2. Trend rule: a 7 night HRV average below the athlete's normal range defers hard sessions

- Trigger: 7 night mean HRV is below baseline mean minus 0.5 SD (the smallest worthwhile change convention, used as mean plus or minus 0.5 SD in fixed reference protocols), with at least 3 valid nights in the 7, and a quality session is planned today.
- Action: propose moving today's quality session to the next day where the 7 night mean is back inside the range, within the same week and not onto another quality day (reuse annex C rule 1 slotting). If no slot, or the 7 night mean stays below range for 3 days in a row, convert it to the easy version of the same sport and length. At most 2 recovery driven changes in any 7 days.
- Reason line pattern: "Moved your hard run to Thursday. Your 7 night HRV average from WHOOP is lower than your usual range, so the plan gave it an extra day. Keep today's session instead?"
- Evidence: Vesterinen 2016 (40 runners; moderate or hard sessions only when HRV within the individual SWC; 13.2 vs 17.7 hard sessions; 3000 m speed plus 2.1% vs plus 1.1%, ES 0.42); 3 of 8 reviewed studies used a 7 day rolling average against a fixed mean plus or minus 0.5 SD (Manresa-Rocamora); Düking 2021 (fewer non-responders, submaximal g = 0.296); weekly means beat single days (Le Meur 2013, Plews 2014). Caveats: running and cycling, 4 to 12 week trials, no triathletes, effect on performance not significant in pooled data.
- Strength: MODERATE for the protocol shape; the main verified benefit is fewer hard sessions at equal fitness, not faster. Do not claim performance gains.

### R3. Acute rule: two low mornings plus a second signal swap today's quality session

- Trigger: HRV below baseline mean minus 1 SD on 2 consecutive mornings, and a second signal agrees: resting heart rate at least 1 SD above its baseline on either morning, or the athlete's check-in today is 2 or lower on a 5 point "how do your legs and energy feel" scale. No second signal available means the app shows an information card only.
- Action: propose replacing today's quality session with an easy session of the same sport and about 80% of the duration; the original stays on the watch until accepted. Frequency cap shared with R2 (2 per 7 days). Not offered within 48 hours after a test session already moved.
- Reason line pattern: "Easy ride today. Two mornings in a row your HRV was lower than your usual and your resting heart rate was higher. You can keep the planned ride."
- Evidence: Kiviniemi 2007 (26 men, 4 weeks): hard training withheld when HRV fell below the 10 day mean minus 1 SD or trended down for 2 days; max running speed rose 0.9 vs 0.5 km/h (P = 0.048), VO2peak not different. Nuuttila 2022 (30 runners): combining nocturnal HRV, perceived recovery and a heart rate to speed index gave a 6.2% vs 2.9% 10 km improvement and 0% vs 21% low responders. Saw 2016: subjective measures are at least as sensitive as objective ones. Altini and Plews 2021: low HRV with high resting HR is the common signature of hard training, alcohol or sickness, which is why a cause is never named. Wearable HRV error (WHOOP ln rMSSD limits of agreement about 5.9% vs 1.5 to 6.5% SWC; Apple Watch MAPE about 29%) is why one night is never enough.
- Strength: MODERATE to WEAK. Single small RCTs, short duration, healthy mostly male samples, and the second signal rule is my design inference from Nuuttila and Saw rather than a tested protocol.

### R4. Short night note: sleep time informs, it does not restructure

- Trigger: total sleep time last night 6.0 hours or less and at least 1 hour below the athlete's own median of the last 28 nights (total time only, never stages).
- Action: a one line note on the Today card and an optional "easier version" button. No automatic swap. If R2 or R3 also fire, they act as written. Two short nights in a row add "Two short nights. An early, easier day can help" style copy, still without changing the plan.
- Reason line pattern: "Short night: 5 h 40 min against your usual 7 h 20 min. Your session is unchanged. Tap for an easier option."
- Evidence: Craven 2022 meta-analysis (sleep of 6 hours or less lowered performance by 7.56% on average, about 0.4% per hour awake, afternoon and evening tasks affected, morning tasks largely not; very high heterogeneity); Walsh 2021 consensus (individual sleep needs, no universal number); Miller 2022 (sleep time valid on all six wearables, stages are not). No evidence found that swapping a session after a short night improves adaptation.
- Strength: WEAK to MODERATE for the performance cost; NONE found for a plan restructuring benefit. Advisory only is the defensible position.

### R5. Guardrails and override (applies to R2 to R4)

- Never add load or intensity because readiness looks high; no "ready to push" prompts.
- Cap: 2 recovery driven changes in any rolling 7 days, and never more than one structural change per day (annex C).
- "Keep my planned session" is always shown; after 2 overrides in 7 days the feature stays quiet for 7 days; a Settings switch turns recovery driven changes off while keeping the data display.
- Never remove a session or schedule a rest day for recovery reasons; never touch race week beyond easing (rule 7).
- Disabled when data is stale (over 36 hours), baseline incomplete, device changed, or the vendor reports calibrating.
- All numbers shown to the athlete in plain units with the source named ("from your WHOOP"), and the Methods screen lists baseline window, thresholds and limits, and states that the app does not know why a number moved.
- Evidence: asymmetry and ambiguity of HRV (Le Meur 2013, Plews 2013, Bellenger 2016); consensus that no marker is sufficient (Meeusen 2013); industry norm of accept/decline (Athletica, Humango, Reps); FDA and Apple limits above.
- Strength: design principle; the evidence is indirect but the downside protection is unambiguous.

Interaction with existing annex C: R2 and R3 are new structural rules (rule 4's unwell mode outranks them); R4 is copy only and is not structural; rule 6 (acute load spike) can fire on the same day but only one structural change applies, chosen by rule number. If annex C rule 8 inserts a retest on the same day a recovery swap fires, the swap wins and the retest waits for the next block boundary slot. Load, Fitness and Form are unchanged: planned and completed Load still drive them, recovery data never alters Fitness math.

---

## 8. Copy and Methods screen guidance (words that survive the spec's forbidden list)

- Use: "lower than your usual", "your usual range", "your own numbers", "the plan waited a day", "easier option", "you can keep your session".
- Avoid: abnormal, low HRV risk, stress score, readiness verdicts framed as health, fatigue diagnosis words, any condition, the forbidden list in tri-spec.md section 6, and "recover" as a command. "AI" and "coach" claims stay out.
- Methods text (draft): "Brickline compares your recent nights with your own earlier nights. It does not know why a number changed. Hard training, alcohol, travel, heat, a late night and stress outside training can all lower HRV. Numbers come from your device and can be off by several percent. Brickline only ever makes your plan easier, never harder, and you can always keep your planned session."

---

## 9. Open questions and unverified items

1. Which Garmin route supplies HRV, sleep and resting heart rate to a free iPhone app after the 2026 program relaunch, and what fields (overnight HRV average, sleep time) each tier returns. Garmin does not export HRV to Apple Health per a secondary source only.
2. WHOOP's Apple Health statement about HRV and the Strain Target mechanics are secondary or blocked (whoop.com returned 403). Confirm from WHOOP's support articles in a browser.
3. Oura's readiness band labels differ between the blog (under 70 "pay attention") and the support page (60 to 69 Fair, 0 to 59 Pay Attention). Use the support page.
4. TriDot, Runna and TrainingPeaks HRV or readiness behaviour could not be confirmed from first party pages; do not make comparative claims (guideline 2.3, spec section 6).
5. Athletica's cited readiness study journal is inconsistent across its pages; not verified in PubMed.
6. Manresa-Rocamora: VO2max SMD 0.20 (abstract) versus 0.13 from a full text pass; confirm in a browser before quoting a single number. Duking 2021 printed CI for performance does not centre on g.
7. No controlled evidence in triathletes, in women specifically, or in masters athletes for any of R2 to R4. An internal four week field test by the developer is useful for plumbing, not for evidence.
8. Whether a same-day session replacement can be scheduled and the original removed reliably through WorkoutScheduler (week 1 spike).
9. Privacy label: confirm Vercel platform logs and the OAuth proxy retain nothing (including client IP and token request metadata) before claiming Data Not Collected; confirm treatment of provider API calls from the device; confirm state consumer health data laws (for example Washington's) do not impose duties on a token-only proxy. Not researched here.
10. Provider developer terms (WHOOP, Oura, Garmin) on caching, deriving metrics and displaying their data in a plan engine are outside this topic and need the platform notes.
11. Menstrual cycle handling: the evidence supports luteal phase shifts in HRV and heart rate; whether to offer an optional cycle aware baseline adds data collection and a health category. Recommend not in the first release; the "tag a night" mechanism and a slow baseline are the 1.0 answer.
12. The coefficient of variation of HRV as a decision variable has only case level support (Plews 2012); omit from rules.

---

## 10. Source list

Primary studies and reviews (abstract read through Europe PMC unless noted):
- https://pubmed.ncbi.nlm.nih.gov/34489178/ Duking 2021 meta-analysis
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/ Manresa-Rocamora 2021 (full text read)
- https://pubmed.ncbi.nlm.nih.gov/34639599/ same, abstract
- https://pubmed.ncbi.nlm.nih.gov/33143175/ Granero-Gallegos 2020
- https://pubmed.ncbi.nlm.nih.gov/32785959/ Duking 2020 (runners)
- https://pubmed.ncbi.nlm.nih.gov/42724227/ Schaffarczyk and Sperlich 2026
- https://pubmed.ncbi.nlm.nih.gov/17849143/ Kiviniemi 2007
- https://pubmed.ncbi.nlm.nih.gov/26909534/ Vesterinen 2016
- https://pubmed.ncbi.nlm.nih.gov/29809080/ Javaloyes 2019
- https://pubmed.ncbi.nlm.nih.gov/35975912/ Nuuttila 2022
- https://pubmed.ncbi.nlm.nih.gov/35894977/ and https://pubmed.ncbi.nlm.nih.gov/39503915/ Nuuttila nocturnal HRV
- https://pubmed.ncbi.nlm.nih.gov/22367011/ Plews 2012
- https://pubmed.ncbi.nlm.nih.gov/23852425/ Plews 2013
- https://pubmed.ncbi.nlm.nih.gov/24334285/ Plews 2014
- https://pubmed.ncbi.nlm.nih.gov/24136138/ Le Meur 2013
- https://pubmed.ncbi.nlm.nih.gov/26888648/ Bellenger 2016
- https://pubmed.ncbi.nlm.nih.gov/24578692/ Buchheit 2014
- https://pubmed.ncbi.nlm.nih.gov/34883936/ Altini and Plews 2021
- https://pubmed.ncbi.nlm.nih.gov/32106458/ Schmalenberger 2020
- https://pubmed.ncbi.nlm.nih.gov/26423706/ Saw 2016
- https://pubmed.ncbi.nlm.nih.gov/23247672/ Meeusen 2013
- https://pubmed.ncbi.nlm.nih.gov/33144349/ Walsh 2021
- https://pubmed.ncbi.nlm.nih.gov/35708888/ Craven 2022
- https://pubmed.ncbi.nlm.nih.gov/27855740/ Baron 2017
- https://pubmed.ncbi.nlm.nih.gov/38668986/ Ibrahim 2024
- https://pubmed.ncbi.nlm.nih.gov/34065516/ Bellenger WHOOP 2021
- https://pubmed.ncbi.nlm.nih.gov/35040799/ Cao Oura 2022
- https://pubmed.ncbi.nlm.nih.gov/40834291/ Dial 2025
- https://pubmed.ncbi.nlm.nih.gov/36016077/ Miller 2022
- https://pubmed.ncbi.nlm.nih.gov/39409260/ O'Grady 2024
- https://pubmed.ncbi.nlm.nih.gov/40285070/ Bonneval 2025
- https://doi.org/10.1101/2024.01.04.24300784 Khodr 2024 preprint
- https://doi.org/10.1101/2023.10.06.561160 Nilsson 2023 preprint
- https://pubmed.ncbi.nlm.nih.gov/41265431/ Grosicki 2026; https://pubmed.ncbi.nlm.nih.gov/39788069/ Perrone 2025

Product and platform pages:
- Garmin Training Readiness, HRV Status, Daily Suggested Workouts manuals (URLs in section 4)
- https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors ; https://ouraring.com/blog/readiness-score/ ; https://ouraring.com/blog/data-sharing-partner-integrations/
- https://developer.whoop.com/docs/whoop-101/ ; https://developer.whoop.com/api/
- https://support.apple.com/120142 (Vitals)
- https://news.athletica.ai/posts/the-coaching-professor-train-smarter-with-the-readiness-triad-hrv-rhr-well-being-in-athletica
- https://granfondoguide.com/Contents/PopUp/7751/how-humango-uses-heart-rate-variability-hrv-to-adapt-your-training
- https://the5krunner.com/2026/07/27/reps-apple-watch-recovery-score/
- https://support.trainerroad.com/hc/en-us/articles/4404060687387-Adaptive-Training-Overview (snippet)
- https://www.sensai.fit/blog/wearable-apple-health-integration-what-syncs-oura-whoop-garmin (secondary)
- HealthKit docs: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn , .../restingheartrate , https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/sleepanalysis

Regulatory and store:
- https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices and https://www.fda.gov/media/90652/download
- https://www.kslaw.com/insights/articles/fda-updates-general-wellness-and-clinical-decision-support-guidance-documents (secondary)
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/app-privacy-details/
- https://www.ftc.gov/business-guidance/blog/2024/04/updated-ftc-health-breach-notification-rule-puts-new-provisions-place-protect-users-health-apps

Repo files read: docs/specs/tri-spec.md sections 3, 4, 6, 8, 9; docs/specs/tri-annex.md section C; /Users/akshay/Documents/GitHub/liftspark/backend/lib/providers.ts, README.md, PLAN.md.
