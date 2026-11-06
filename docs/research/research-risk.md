# Research: legal, platform and safety risks for a camera based bike fit iPhone app

Date of research: 2026-11-03. Researcher: Fable subagent. Scope: Apple review and privacy rules, FDA, EU MDR, GDPR and US biometric statutes, FTC, product liability, competitor disclaimers, UCI and triathlon position rules, mechanical change risks, camera and trainer safety.

Method note: primary sources were fetched directly. Several PDFs (FDA, UCI, World Triathlon, MDCG, EDPB, Wahoo) were downloaded and text extracted locally with pdftotext. The shared web search budget ran out part way through, so a few items (Zwift terms, Retul terms, Fitbit class action, Ironman official page, EUR-Lex text) could not be verified and are listed under Open questions. Nothing below is legal advice.

---

## 1. Apple App Store Review Guidelines

Source (all of this section): https://developer.apple.com/app-store/review/guidelines/ (fetched 2026-11-03)

### 1.4 Physical harm
- 1.4.1: "Medical apps that could provide inaccurate data or information, or that could be used for diagnosing or treating patients may be reviewed with greater scrutiny." Apps "must clearly disclose data and methodology to support accuracy claims relating to health measurements, and if the level of accuracy or methodology cannot be validated, we will reject your app." Examples of what is not permitted: apps claiming to take x-rays, measure blood pressure, body temperature, blood glucose or blood oxygen "using only the sensors on the device." Apps "should remind users to check with a doctor in addition to using the app and before making medical decisions." If regulatory clearance exists, submit the link.
- 1.4.5: "Apps should not urge customers to participate in activities (like bets, challenges, etc.) or use their devices in a way that risks physical harm to themselves or others."
- Reading for a fit app: joint angles and saddle height are not "health measurements" in the blood pressure sense, but any claim of accuracy ("within 1 degree", "as accurate as a pro fit") is the kind of claim 1.4.1 says must be backed by disclosed data and methodology. Safest path: publish a methodology page (what the model measures, validation set, known error ranges) and link it in the app and in review notes.

### 2.3 Accurate metadata
- Intro: all metadata including privacy information, description, screenshots and previews must "accurately reflect the app's core experience."
- 2.3.1(a): "marketing your app in a misleading way, such as by promoting content or services that it does not actually offer ... is grounds for removal of your app from the App Store."
- 2.3.7: app subtitles "must follow our standard metadata rules and should not include inappropriate content, reference other apps, or make unverifiable product claims." Also do not pack metadata with trademarked terms or popular app names.
- 2.3.10: metadata must be focused on the app itself; no imagery of other mobile platforms; "Don't include irrelevant information."
- 2.3.14 (per the fetched summary): prohibits "references to other apps with an intent to mislead" and "unverifiable product claims."
- Reading: naming Retul, MyVeloFit or Zwift in the listing, or saying "as accurate as a $300 pro fit", is a 2.3.7 problem and a 2.3.1 removal risk unless it can be verified.

### 2.5 Software requirements
- 2.5.1: use APIs for their intended purposes; HealthKit only for health and fitness purposes and integrating with the Health app.
- 2.5.14: "Apps must request explicit user consent and provide a clear visual and/or audible indication when recording, logging, or otherwise making a record of user activity. This includes any use of the device camera, microphone, screen recordings, or other user inputs." A visible recording indicator and an explicit start button satisfy this.
- 2.5.18: ads may not be targeted on health/medical data (not relevant, no ads).

### 4.3 Spam
- 4.3(b): "Don't submit apps that are indistinguishable from what's already widely available." Certain categories (dating, flashlight, sound effects, wallpaper, simple timers, fortune telling) are closed to new submissions unless "meaningfully different or improved." Bike fit is not a listed closed category; an on-device video fit tool is distinguishable from the existing web based tools, but the listing should lead with what is unique.
- 4.3(a): no multiple Bundle IDs of the same app (one app for road, TT and gravel, not three).

### 5.1.1 Data collection and storage
- (i) privacy policy link required in App Store Connect and in the app; must identify what data is collected, retention and deletion, and how to revoke consent.
- (ii) "Ensure your purpose strings clearly and completely describe your use of the data."
- (iii) "Apps should only request access to data relevant to the core functionality of the app" and where possible use the out-of-process picker (for importing an existing video, the Photos picker avoids a Photos permission entirely).
- (iv) respect permission settings; offer alternatives where consent is declined.
- (v) if the app has no significant account based features, "let people use it without a login."
- (ix) "Apps that provide services in highly regulated fields (such as banking and financial services, healthcare, gambling ...) or that require sensitive user information should be submitted by a legal entity that provides the services, and not by an individual developer." Risk note: a solo developer whose listing frames the app as injury prevention or medical could be pushed toward this clause. Framing as fitness and comfort, not healthcare, keeps it out of (ix).

### 5.1.2 Data use and sharing
- (vi): "Data gathered from the HomeKit API, HealthKit, Clinical Health Records API, MovementDisorder APIs, ClassKit or from depth and/or facial mapping tools (such as ARKit, Camera APIs, or Photo APIs) may not be used for marketing, advertising or use-based data mining, including by third parties."
- (i): must obtain permission before using, transmitting or sharing personal data; must disclose sharing with third parties "including with third-party AI."

### 5.1.3 Health and health research
- Applies to data "gathered in the health, fitness, and medical research context" including HealthKit and Motion and Fitness. (ii): apps "may not store personal health information in iCloud." If the app never touches HealthKit or Motion and Fitness and only stores fit measurements, 5.1.3 is mostly not triggered, but body measurements and pain notes are still "especially sensitive" in Apple's framing; keep them local and do not write them to a shared iCloud container.

### Is a bike fit app a "health app" for Apple?
- App Store categories page: https://developer.apple.com/app-store/categories/
  - Health & Fitness: "Apps related to healthy living, including stress management, fitness, and recreational activities. For example: yoga, muscle diagrams, workout tracking, running, cycling ..."
  - Medical: "Apps that are focused on medical education, information management, or health reference for patients or healthcare professionals. For example: ... companion devices (blood pressure, pulse, and so on), health tracking."
  - Sports: "Apps related to professional, amateur, collegiate, or recreational sporting activities ... instruction, sports news."
- Reading: Health & Fitness (cycling is named) or Sports are the natural primary categories. Avoid Medical. Nothing in the guidelines defines "medical app"; 1.4.1 is triggered by claims, not category.
- Comparator: Retül Fit (Specialized) is listed under Health & Fitness, 4+, with a "Data Linked to You" label covering Health & Fitness, Contact Info, User Content, Usage Data, Diagnostics (crash data). https://apps.apple.com/us/app/-/id1434354462

### Camera purpose string and permission UX
- NSCameraUsageDescription: "A message that tells people why the app is requesting access to the device's camera." "This key is required if your app uses APIs that access the device's camera." https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription
- HIG Privacy: "Write copy that clearly describes how your app uses the ability, data, or resource you're requesting." Good example style: "The app records during the night to detect snoring sounds." Bad: "Microphone access is needed for a better experience." Also: "Request permission only when your app clearly needs access" and "Avoid requesting permission at launch unless the data or resource is required for your app to function." https://developer.apple.com/design/human-interface-guidelines/privacy
- Draft purpose string for this app: "The camera records a short side view of you pedaling so the app can measure your riding position on this phone. Video never leaves your device."

---

## 2. App Privacy nutrition label and "Data Not Collected"

Source: https://developer.apple.com/app-store/app-privacy-details/ (fetched 2026-11-03)

- Definition: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time."
- On-device: "Data that is processed only on device is not 'collected' and does not need to be disclosed in your answers. If you derive anything from that data and send it off device, the resulting data should be considered separately."
- Also listed as a case needing no disclosure: "You use location, device identifiers, and other sensitive data, but only on device, and the data is never sent to a server."
- Transient server use: "You collect data to service a request but do not retain it after servicing the request" need not be disclosed (for example a token sent and discarded). Note this is about non-retention, so a cloud inference call that discards the video immediately would technically be exempt from the label, but it is still "transmission" for GDPR and biometric statute purposes and would break the "all processing on device" promise. Recommendation: do not use it.
- Apple services: "You use Apple frameworks or services, such as MapKit, CloudKit, or App Analytics." "If you collect data about your app from Apple frameworks or services, you should indicate what data you collect and how you use it. You are not responsible for disclosing data collected by Apple."
- Third party SDKs: you must disclose "the practices of third-party partners whose code you integrate into your app." With zero third-party SDKs this is moot.
- Diagnostics category includes "Crash Data: Such as crash logs", "Performance Data", "Other Diagnostic Data."
- Product Improvement Programs optional disclosure: data is optional to disclose if it is used only to improve the app, collected only after an explicit in-UI opt in with two clear choices, choice does not affect features or cost, can be changed in settings, not linked to identity, not used for tracking or advertising or other purposes. All criteria must be met.
- Health data type: "Health and medical data, including but not limited to data from the Clinical Health Records API, HealthKit API, Movement Disorder API, or health-related human subject research or any other user provided health or medical data." Fitness: "Fitness and exercise data, including but not limited to the Motion and Fitness API." Photos or Videos: "The user's photos or videos." These only matter if transmitted off device.

Label meaning: https://www.apple.com/privacy/labels/ : "Data Not Collected: The developer does not collect any data from this app."

### Crash logs via Apple's opt in
- Apple App Analytics & Privacy: Apple may share with developers "a subset of analytics information that is relevant to that partner's or developer's app, product, or service" and usage statistics, "as long as the analytics information and statistics are aggregated or in a form that does not personally identify you." Users opt out at Settings > Privacy & Security > Analytics & Improvements > "Share With App Developers." https://www.apple.com/legal/privacy/data/en/app-analytics/
- Combined with "You are not responsible for disclosing data collected by Apple" (above), crash logs that reach you only through Xcode Organizer / App Store Connect under the user's Apple opt in do not require a Diagnostics entry. Any crash SDK of your own (Crashlytics, Sentry, MetricKit payloads you upload yourself) would. Sibling apps shipped as Data Not Collected on the same reasoning.

### iCloud sync of user data
- Apple's page does not mention iCloud explicitly. A 2022 Apple Developer Forums thread asking whether NSPersistentCloudKitContainer sync to the user's private CloudKit database must be declared has zero replies. https://developer.apple.com/forums/thread/710456
- The definition turns on whether you "and/or your third-party partners" can access the data. Data in a user's private CloudKit database is not accessible to the developer, which is the argument that it is not "collected." No Apple statement confirming this was found. Treat as unresolved: for 1.0 keep data local only (no iCloud sync) to make Data Not Collected unambiguous; add private CloudKit sync later only after an Apple Developer Support answer.

---

## 3. FDA: general wellness and software functions

### General Wellness: Policy for Low Risk Devices (final, January 6, 2026)
Source PDF: https://www.fda.gov/media/90652/download ; landing page https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices ; docket FDA-2014-N-1039.
- "This document supersedes 'General Wellness: Policy for Low Risk Devices' issued on September 27, 2019."
- Policy: "CDRH does not intend to examine low risk general wellness products to determine whether they are devices ... or, if they are devices, whether they comply with the premarket review and post-market regulatory requirements."
- Two factors: products that "(1) are intended for only general wellness use ... and (2) present a low risk to the safety of users and other persons." "General wellness products may include exercise equipment, audio recordings, video games, software programs ..."
- First category of general wellness intended uses (no disease reference) includes "physical fitness, including products intended for recreational use." Example claims: "Claims to promote physical fitness, such as to help log, track, or trend exercise activity, measure aerobic fitness, improve physical fitness, develop or improve endurance, strength or coordination"; "Claims that address a specific body structure or function, such as to increase or improve muscle size or body tone"; "Claims to improve general mobility."
- Low risk test: product is NOT low risk if the answer to any is yes: "1) Is the product invasive?" (penetrates or pierces skin), "2) Is the product implanted?", "3) Does the product involve an intervention or technology that may pose a risk to the safety of users and other persons if specific regulatory controls are not applied, such as risks from lasers or radiation exposure?"
- Illustrative Example 2: software that monitors exercise "to allow awareness of one's exercise activities to improve or maintain good cardiovascular health" is not a device function; "although the monitoring or recording of exercise activities present risks (such as inaccuracy), when made in the absence of disease or medical condition claims, the technology does not pose a risk."
- New 2026 text on non-invasive sensing: such products are not general wellness if labeling, advertising, UI or functionality includes "references to specific diseases, clinical conditions, or diagnostic thresholds"; "alerts, alarms, or prompts that recommend or require specific clinical action"; "treatment guidance"; "claims of clinical equivalence, clinical accuracy, medical or clinical grade, or substitution for an FDA-authorized, cleared, or approved medical device"; or intended use statements targeting diagnosis, screening, monitoring or management of a disease.
- Reading for the app: a camera fit tool that recommends saddle height, setback, reach and cleat position for comfort and performance, without naming diseases or injuries as things it diagnoses or treats, sits squarely in category 1 (physical fitness) and is non-invasive. Avoid "prevents patellofemoral pain", "treats knee pain", "fixes your back pain", "clinically accurate." "Reduce discomfort" and "more comfortable, more efficient position" are safe framings. Avoid "medical grade" wording anywhere.

### Policy for Device Software Functions and Mobile Medical Applications (September 28, 2022)
Source PDF: https://www.fda.gov/media/80958/download
- "Document issued on September 28, 2022." Supersedes the September 27, 2019 version.
- Appendix A examples of software functions that are NOT medical devices, under the general fitness, health or wellness heading, include: "Track general daily activities or make exercise or posture suggestions"; "Actively monitor and trend exercise activity"; "Provide dietary logs, calorie counters, or make dietary suggestions."
- This is the clearest FDA statement that posture suggestions are not device functions.

---

## 4. EU Medical Device Regulation (MDR 2017/745)

- Recital 19: software "when specifically intended by the manufacturer to be used for one or more of the medical purposes set out in the definition of a medical device, qualifies as a medical device, while software for general purposes, even when used in a healthcare setting, or software intended for life-style and well-being purposes is not a medical device." https://www.legislation.gov.uk/eur/2017/745/introduction/adopted (UK mirror of the adopted EU text; EUR-Lex returned empty pages to the fetcher)
- Article 2(1) "medical device" means software etc. "intended by the manufacturer to be used ... for one or more of the following specific medical purposes": "diagnosis, prevention, monitoring, prediction, prognosis, treatment or alleviation of disease", "diagnosis, monitoring, treatment, alleviation of, or compensation for, an injury or disability", "investigation, replacement or modification of the anatomy or of a physiological or pathological process or state" ... https://www.legislation.gov.uk/eur/2017/745/article/2/adopted
- MDCG 2019-11 (Guidance on Qualification and Classification of Software, October 2019; a Rev.1 was issued June 2025 per secondary sources): Decision step 3: software that only does "storage, archival, communication, simple search, lossless compression" is not MDSW; Step 4: "is the action for the benefit of individual patients?"; Step 5: does it meet the MDSW definition (a medical purpose per Article 2(1)). https://ec.europa.eu/docsroom/documents/37581/attachments/1/translations/en/renditions/native (redirects to a circabc download)
- Reading: intended purpose is everything. "Prevention ... of disease" and "alleviation of ... an injury" are medical purposes. So the EU risk is the same as the US one: if the app's stated purpose is to prevent or treat cycling injuries, it is arguably a medical device (Rule 11 would make it at least Class IIa, requiring a notified body). If the stated purpose is comfort, efficiency and fit for sport, it is a lifestyle and well-being product under Recital 19. Keep injury language out of the intended purpose, the listing, the onboarding and the support pages. Do not accept uploads from physiotherapists "for patient assessment" as a marketed use.

---

## 5. GDPR, biometric data, BIPA, CUBI

### GDPR
- Article 4(14): "'biometric data' means personal data resulting from specific technical processing relating to the physical, physiological or behavioural characteristics of a natural person, which allow or confirm the unique identification of that natural person." Article 4(15) "data concerning health" means personal data related to physical or mental health that reveal information about health status. https://gdpr-info.eu/art-4-gdpr/
- Article 9(1) prohibits processing of, among others, "biometric data for the purpose of uniquely identifying a natural person" and "data concerning health" unless an exception such as explicit consent in 9(2)(a) applies. https://gdpr-info.eu/art-9-gdpr/
- Recital 51: "The processing of photographs should not systematically be considered to be processing of special categories of personal data as they are covered by the definition of biometric data only when processed through a specific technical means allowing the unique identification or authentication of a natural person." https://gdpr-info.eu/recitals/no-51/
- EDPB Guidelines 3/2019 on processing of personal data through video devices, Version 2.0 adopted 29 January 2020 (2.1 of 26 February 2020 fixed a material mistake): para 74 "The video footage of an individual cannot however in itself be considered as biometric data under Article 9, if it has not been specifically technically processed in order to contribute to the identification of an individual." Para 76 three criteria: nature of data, "resulting from a specific technical processing", and "purpose of processing: data must be used for the purpose of uniquely identifying a natural person." Example 4: a shop detecting gender and age from video to tailor ads without generating templates to identify people "would not fall under Article 9." https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices_en_0.pdf (summary April 2026: https://www.edpb.europa.eu/system/files/2026-04/summary_edpb_guidelines_201903_video_devices_en.pdf)
- Reading: pose estimation to measure joint angles is "specific technical processing" of physical characteristics, but it is not done "for the purpose of uniquely identifying" anyone, so it is not Article 9 biometric data. Pain notes or injury history typed by the user would be health data. When everything stays on the device and the developer never receives any of it, the developer does not process personal data at all for that activity; the user is doing it on their own device. No authority confirming the "developer is not a controller" point was found (see Open questions), so the privacy policy should still describe the on-device processing plainly. Do not add any feature that identifies or re-identifies the rider from body shape (for example "recognize which family member is riding").

### Illinois BIPA (740 ILCS 14)
- Section 10: "'Biometric identifier' means a retina or iris scan, fingerprint, voiceprint, or scan of hand or face geometry. Biometric identifiers do not include writing samples, written signatures, photographs, ... demographic data, tattoo descriptions, or physical descriptions such as height, weight, hair color, or eye color." "Biometric information" is information "based on an individual's biometric identifier used to identify an individual." https://codes.findlaw.com/il/chapter-740-civil-liabilities/il-st-sect-740-14-10/
- Section 20: negligent violation "liquidated damages of $1,000 or actual damages, whichever is greater"; intentional or reckless "$5,000 or actual damages." 20(b) (added by SB 2979, signed August 2, 2024): repeated collection of the same identifier from the same person by the same method "has committed a single violation" with one recovery. https://codes.findlaw.com/il/chapter-740-civil-liabilities/il-st-sect-740-14-20/ ; amendment coverage: https://www.gtlaw.com/ko/insights/2024/8/bipa-update-illinois-limits-liability-and-clarifies-electronic-consent-for-biometric-data-collection
- Reading: BIPA regulates a "private entity" that collects, captures or possesses identifiers. Full body pose keypoints (hips, knees, ankles) are not face or hand geometry; the statute's named identifiers are retina, iris, fingerprint, voiceprint, hand geometry, face geometry. If processing is on device and the developer never possesses anything, exposure is minimal. The exposure appears if (a) video or keypoints are uploaded to a server and (b) a plaintiff argues that face geometry was scanned (a side view of a rider includes the face). Blurring or cropping the head region before any upload, and never uploading in 1.0, removes that argument. BIPA class actions have been the most expensive privacy risk for camera apps in the US, so "no cloud, ever" is the single highest value design decision here.

### Texas CUBI (Bus. & Com. Code 503.001)
- "'biometric identifier' means a retina or iris scan, fingerprint, voiceprint, or record of hand or face geometry." A person "may not capture a biometric identifier of an individual for a commercial purpose unless the person: (1) informs the individual before capturing the biometric identifier; and (2) receives the individual's consent." Must "destroy the biometric identifier within a reasonable time, but not later than the first anniversary" of when the purpose expires. "civil penalty of not more than $25,000 for each violation." "The attorney general may bring an action to recover the civil penalty." No private right of action. https://texas.public.law/statutes/tex._bus._and_com._code_section_503.001
- Same reading as BIPA: only relevant if anything is captured server side.

---

## 6. FTC: accuracy and health claims

### Health Products Compliance Guidance (December 2022)
Source: https://www.ftc.gov/business-guidance/resources/health-products-compliance-guidance
- Replaces the 1998 dietary supplement guide; the FTC notes more than 200 cases involving "health equipment, diagnostic tests, and health-related apps" and states "the same legal principles apply to the marketing of any health-related product."
- Substantiation standard: "competent and reliable scientific evidence" meaning "tests, analyses, research, or studies that (1) have been conducted and evaluated in an objective manner by experts" and "generally accepted in the profession to yield accurate and reliable results." "Randomized, controlled human clinical trials (RCTs) are the most reliable form of evidence."
- Disclaimers: "the DSHEA disclaimer or similar statements won't cure an otherwise deceptive ad"; a disclosure "can't directly contradict a claim"; "Vague qualifying terms are inadequate"; footnote 26 "pro forma statements or disclaimers may not cure otherwise deceptive messages."
- Example 14: an acne app whose store description calls the phone's light a substitute for in-office treatment, with a disclaimer "This app is for entertainment purposes only and is not intended for the treatment of any disease or medical condition." The guidance says the disclaimer "directly contradicts" the claim and is ineffective.
- Example 39: customer testimonials that an app cured insomnia are not substantiation; the advertiser needs "competent and reliable scientific evidence that its product is effective in treating insomnia."
- Footnote 37: testimonials "are not a form of proof."
- Footnote 59: "citation to clinical studies can contribute to a clinically proven claim" (establishment claims need the level of proof implied).
- Reading: "Reduces knee pain", "prevents injury", "as accurate as a professional fit", "pro fitters agree" each need evidence of the kind described. A one-line disclaimer does not rescue them. Claims that are safe without a study: what the app measures, that it runs on device, that it gives a starting position in the ranges fitters commonly use, with citations.

### FTC v. Aura Labs (Instant Blood Pressure app), December 12, 2016
Source: https://www.ftc.gov/news-events/news/press-releases/2016/12/marketers-blood-pressure-app-settle-ftc-charges-regarding-accuracy-app-readings
- App marketed as able to replace a cuff and be as accurate as a traditional device; readings were "significantly less accurate." Sold for $3.99 to $4.99 with more than $600,000 in sales in one year. Order bars health-benefit claims "without scientific evidence to support them"; $595,945.27 judgment suspended for inability to pay; founder had posted five-star reviews without disclosing his connection. Jessica Rich: "health-related claims should not go beyond the scientific evidence available to support them."
- This is the closest FTC precedent for a phone-camera measurement app making an accuracy equivalence claim. Note the endorsement angle too: no self reviews, and disclose any relationship if a fitter or coach promotes the app.

---

## 7. Product liability and advice that causes injury

- Strava (Flint v. Strava, San Francisco Superior Court): suit filed June 2012 by the family of William "Kim" Flint over a 2010 crash while chasing a KOM; dismissed in June 2013. Judge Marla Miller: "Mr. Flint assumed the risks of bicycling"; "bicycling is an inherent risky activity." Strava's terms, accepted at sign-up, included language "absolving Strava from liability." https://cdn.road.cc/content/news/84948-judge-dismisses-lawsuit-against-strava-relating-death-rider-trying-recapture-kom (article dated June 6, 2013)
- Peloton (Furtado, Brooklyn, filed March 2023): bike alleged "defective and unreasonably dangerous in design, instruction, and warning" after it tipped and severed a user's carotid artery when he used it to steady himself. Peloton's answer: the incident "was caused by the negligence or other culpable conduct of one or more parties for which Peloton is not responsible." No outcome found. https://www.nbcnews.com/news/us-news/peloton-bike-instantly-kills-new-york-man-severing-artery-family-says-rcna103881 (September 7, 2023)
- Takeaways: US courts have applied primary assumption of risk to cycling. Software that gives a recommendation is weaker ground for a plaintiff than hardware that fails, but "instruction and warning" is exactly the theory that would be pleaded against a fit app (the app told me to raise my saddle 3 cm and I hurt my hamstring). Mitigations that matter more than a disclaimer: small incremental change limits, "ride a few sessions before the next change" pacing, refusal to recommend outside guardrails, clear "stop if pain" copy, and an in-app acknowledgement at onboarding.
- EU: Directive (EU) 2024/2853 on liability for defective products treats stand-alone software as a product under a strict liability regime (claimant must show defect, damage, causal link; no fault). Member States must implement by December 9, 2026 and it applies to products placed on the market after that date. Where the manufacturer is outside the EU, liability can extend to importers, an authorised representative, fulfilment service providers, and distributors or online platforms that do not identify the responsible operator within one month. Source (law firm summary; EUR-Lex returned empty pages to the fetcher): https://www.gibsondunn.com/wp-content/uploads/2026/03/eu-product-liability-directive-responding-to-software-ai-and-complex-supply-chains.pdf . Several secondary sources state that free and open-source software supplied outside a commercial activity is excluded; whether a free app from a non-EU solo developer distributed through the App Store (Apple as the EU "importer" or platform) is in scope is an open question worth a lawyer's hour before expanding EU marketing.

---

## 8. Disclaimer language used by comparable products

- MyVeloFit Terms & Conditions (updated June 11, 2024): https://www.myvelofit.com/terms/
  - "You expressly agree that your use of, or inability to use, the service is at your sole risk."
  - "We do not warrant that the results that may be obtained from the use of the service will be accurate or reliable."
  - "We are not responsible if information made available on this site is not accurate, complete or current" and it "should not be relied upon or used as the sole basis for making decisions."
  - Not liable for "any injury, loss, claim, or any direct, indirect, incidental" damages; indemnification clause for individual users.
  - Notably no "not medical advice" or "consult a physician" clause was found in the terms. Their marketing says: "Get bike fit recommendations consistent with some of the top professional fitters in the world" and "the world's #1 online bike sizing and fitting tools" (https://www.myvelofit.com/). A fitter testimonial calls it "comparable to other fit systems such as Retul." That is the kind of comparative claim Apple 2.3.7 and the FTC guidance would scrutinize in an App Store listing.
- Retül / Specialized: terms page returned 403; not verified. The Retül Fit App Store description says the tool helps fitters advise riders on "comfort, injury prevention, and performance" (note that Retül is a fitter-operated tool, not consumer advice). https://apps.apple.com/us/app/-/id1434354462
- Zwift: zwift.com/terms redirects to a support.zwift.com legal hub that rendered empty; the terms text could not be fetched. Not verified.
- Wahoo KICKR BIKE SHIFT manual (the closest hardware analogue, since it has a "Fit" feature): "Improper or excessive exercise can result in serious injury. Always consult your physician before beginning or modifying any exercise program." "The Wahoo KICKR BIKE SHIFT Fit algorithm does not guarantee injury prevention." "This product is intended for recreational use only and is not intended for medical purposes." https://au.wahoofitness.com/media/wysiwyg/instructions/Wahoo_KICKR_BIKE_SHIFT_QSG.pdf
- Suggested disclaimer set for this app (plain language, no dashes):
  1. Onboarding: "This app measures your riding position and suggests changes for comfort and efficiency. It is not medical advice and does not diagnose or treat injuries. If you have pain, numbness or a past injury, talk to a doctor or a professional bike fitter before changing your position."
  2. Every recommendation card: "Make one change at a time and ride a few sessions before the next. Stop if anything hurts."
  3. Listing: describe what is measured and that processing stays on the phone; no comparisons to named fit systems; no accuracy equivalence claims.

---

## 9. UCI and triathlon position rules

### UCI (Clarification Guide of the UCI Technical Regulation, "As from 01.02.2025")
Source: https://assets.ctfassets.net/761l7gh5x5an/36HocrJva5dgK9VloO9GVN/2b3af5b68604dc51521dbec0f60f8fbf/Clarification_Guide_of_the_UCI_Technical_Regulation_-_20250201_-_ENG.pdf
Previous version for comparison (10.01.2024): https://assets.ctfassets.net/761l7gh5x5an/6cmP3f8KY4mTfI6hAYCduP/f4d7b5639b8e5f2b0dec6db551589fd4/Clarification_Guide_of_the_UCI_Technical_Regulation_-_20240110_-_ENG.pdf
- Article 1.3.013, 2024 text: "The tip of the saddle shall be a minimum of 50 mm to the rear of a vertical plane passing through the bottom bracket spindle."
- Article 1.3.013, 2025 text (the PDF carries tracked changes; extracted text merges struck and inserted words): "The tip of the saddle shall be [a minimum of 50 mm to the rear of a] positioned behind the vertical plane passing through the center of the bottom bracket spindle axle and must under no circumstances cross this plane." The guide keeps the exemption text: "Only one (1) of the following two (2) exemptions can be requested ... 1. Either the tip of the saddle can be moved forward to a distance equal to or less than 50 mm. 2. The fixed time trial extensions handlebar can be adapted ..." and "In no case the peak of the saddle can exceed the vertical line passing through the bottom bracket spindle."
- Article 1.3.023 (time trial position), 2025: measurement S is "the horizontal distance between the tip of the saddle and the vertical plane passing through the center of the bottom bracket axle"; for each rider height category "S may not be less than 50 mm" (Category 1 under 180 cm: E max 800 mm, H max 100 mm; Category 2 180 to 189 cm: E 830, H 120; Category 3 190 cm or taller: E 850, H 140; default E 750 mm, H under 100 mm, "S shall comply with article 1.3.013").
- Reading (medium confidence, confirm against UCI Part 1 current PDF): from 2025 the general road rule is saddle tip behind the bottom bracket plane (zero minimum), while the 50 mm minimum setback remains part of the time trial and pursuit position rules, with a morphological exemption down to the bottom bracket plane. Forum reports from late 2025 say the same.
- Article 1.3.014: "The plane passing through the highest points at the front and rear of the saddle can have a maximum angle of nine degrees from horizontal. The length of the saddle shall be 24 cm minimum and 30 cm maximum. A tolerance of 5 mm is allowed."
- Product implication: a "UCI legal" toggle that warns when a recommended setback puts the saddle tip ahead of the BB plane (road) or inside 50 mm (TT), and when saddle tilt exceeds 9 degrees. Only a small minority of users race under UCI rules; the toggle should default off and never block a recommendation.

### World Triathlon Competition Rules (version dated 13 December 2025, with 2026 amendments)
Source (mirror of the master document; triathlon.org document library rendered empty to the fetcher): https://www.triathlonmanitoba.ca/wp-content/uploads/World-Triathlon_Competition-Rules_20260429.pdf
- Section 5.2 a): draft-legal events follow "UCI road race rules"; draft-illegal events follow "UCI time trial rules" (as adapted below).
- 5.2 c) draft-legal (Elite, U23, Junior, Youth), (ii) "Saddle position for U23 and Elite events: There will be a vertical line touching the front-most point of the saddle which will be no less than 5 cm for the men, and 2 cm for the women, behind a vertical line passing through the centre of the chain wheel axle, and an athlete must not have the capability of adjusting the saddle beyond these lines during competition." Clip-ons are not allowed in draft-legal (including Age-Group draft-legal).
- 5.2 d) draft-illegal, (ii) "Saddle-position: There will be a vertical line touching the front-most point of the saddle which will be no more than 5 cm in front of, and no more than 15 cm behind, a vertical line passing through the centre of the chain wheel axle." Bikes with the UCI TT homologation label are always allowed.
- (iii) draft-illegal handlebars: "Only handlebars and clip-on bars not extending beyond the leading edge of the front wheel will be permitted." Fairings prohibited. Hydration on steering components max 2 litres combined; rear mounted max two bottles of 1 L each.
- Reading: so triathlon is not entirely without a saddle rule. Non-drafting (age group long course) allows the saddle tip up to 5 cm in front of the BB, which is far more permissive than UCI and covers the steep tri positions the app would recommend. Draft-legal elite is UCI like (5 cm men, 2 cm women).

### IRONMAN Global Competition Rules 2025 (effective March 17, 2025)
Source (secondary; ironman.com blocked the fetcher): https://www.slowtwitch.com/triathlon/ironman-tweaks-drafting-cycling-equipment-rules-for-2025/ (February 25, 2025)
- Rule 5.3(c): "aero bar extensions must not extend beyond the leading edge of the front wheel"; violation is disqualification. Front hydration max two liters combined; rear two bottles of one liter each; four liters total.
- No saddle position rule is mentioned in the coverage. Confirm on https://www.ironman.com/resources/rules-and-policies/competition-rules before shipping an "Ironman legal" check.
- Product implication: for TT/tri users, an extension reach check (tip of extensions vs front wheel leading edge) is more useful than a saddle check. The app can estimate this from the side video if the front wheel and extension tips are in frame.

---

## 10. Crank length, cleats and what the app should refuse to recommend

Evidence (all via Europe PMC records):
- Bini, Hume, Croft, "Effects of bicycle saddle height on knee injury risk and cycling performance," Sports Medicine 2011, doi 10.2165/11588740-000000000-00000: "methods for determining optimal saddle height are varied and not well established"; "we suggest the saddle height may be set using the knee flexion angle method (25-30 degrees)" to reduce knee injury risk and oxygen uptake; "There is limited information on the effects of saddle height on lower limb injury risk." https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:21615188&resultType=core&format=json
- Ferrer-Roca et al., "Acute effects of small changes in crank length on gross efficiency and pedalling technique during submaximal cycling," J Sports Sci 2017;35(14):1328-1335, PMID 27484153: comparing 170, 172.5 and 175 mm, "the biomechanical changes due to a longer crank did not alter the metabolic cost of pedalling," but "maximum flexion and range of motion of the hip and knee joints were significantly increased" (about 1.8 to 3.4 degrees); authors suggest the shorter crank when a rider is between two lengths. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22crank%20length%22%20AND%20AUTH:%22Ferrer-Roca%22&resultType=core&format=json
- Reynolds, Chidley, Briley, Outram, "The impact of minor crank length adjustments on lower body cycling kinematics," Sports Biomechanics 2026;25(3):454-467, PMID 40464620: "Minor reductions in crank length can decrease hip and knee flexion"; "Changes in crank length had no effect on the mean power output." https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22crank%20length%22%20AND%20cycling%20AND%20(knee%20OR%20kinematics)%20AND%20PUB_YEAR:[2015%20TO%202026]&resultType=core&format=json&pageSize=10
- Chartogne et al., "Acute effects of small changes in antero-posterior shoe-cleat position on physiological and biomechanical variables in road cycling," Sports Biomechanics 2023;22(4):510-521, PMID 35129429: 15 mm fore-aft shifts did not change physiological or kinetic variables but changed joint kinematics, "particularly knee extension angle which could be related to the risk of overuse injuries." Firminger and Asmussen, "Cycling Cleat Positioning Influences Achilles Tendon Strains, but at What Energetic Cost?", Med Sci Sports Exerc 2026;58(9):2063-2073, PMID 41975639: a 20 mm posterior cleat position reduced peak Achilles tendon strain with patellar tendon strain unchanged. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%22cleat%20position%22%20AND%20cycling%20AND%20(knee%20OR%20Achilles)&resultType=core&format=json&pageSize=10

Why these are risky to recommend from a phone video:
- Crank length is a purchase and an installation (bottom bracket compatibility, chainline, pedal thread torque, bolt torque on spider or direct mount). A wrong install can fail under load. The evidence says small changes do not change efficiency or power, so the upside of recommending it is small while the mechanical and liability downside is real. The app can observe "your hip is very closed at top dead center" and say "some riders in this situation try shorter cranks; this is a shop job," without specifying a length.
- Cleat changes alter knee tracking and tendon loads in ways a 2D side camera cannot see (rotation, stance width, varus/valgus). A 2D side view can only estimate fore-aft. Rotation and float cannot be measured, and cleat bolts loosening or a mis-set cleat causing an unexpected release is a crash mechanism. Recommend only "check your cleats are tight and symmetric" and, at most, flag that the foot looks very far forward or back; send the user to a fitter for rotation.
- Saddle height and fore-aft are reversible with one Allen key and are the two variables with the best evidence base. Limit single step changes (for example no more than 5 mm height per session) and give explicit torque and "mark your old position" instructions.

Suggested refusal list (the app should not output these as recommendations):
1. A specific crank length to buy.
2. Cleat rotation, float, or stance width changes; shims and wedges.
3. Any change framed as treating a named injury, numbness or pain (patellofemoral, IT band, Achilles, saddle sores, hand numbness, back pain). Offer "see a professional" instead.
4. Stem, handlebar or extension changes that require cutting steerer tubes or new parts without a "have a mechanic do this" line.
5. Recommendations when the video quality gate fails (camera not level, rider not fully in frame, fewer than N pedal strokes, wrong side), or for riders who report current pain in onboarding (route to fitter, still allow measurement).
6. Anything for children (the measurement models and fit ranges are adult; keep age rating 4+ but gate with an age question if minors are plausible).
7. Repeated large changes: cap cumulative change per week and require the user to confirm they rode the previous change.

---

## 11. Camera and trainer safety

- Wahoo KICKR BIKE SHIFT manual, General Safety Information: "Instability of the KICKR BIKE SHIFT could result in serious injury. Only use the KICKR BIKE SHIFT on stable, level surfaces." "Contact with the moving parts ... could result in serious injury." "Keep children and pets away." "Do not wear loose clothing or shoes with loose laces." https://au.wahoofitness.com/media/wysiwyg/instructions/Wahoo_KICKR_BIKE_SHIFT_QSG.pdf
- Wahoo KICKR AXIS Quick Start Guide, Caution block: "Before beginning or modifying any exercise program please consult your physician." "Do not attempt to dismount the bicycle while the flywheel is in motion." "Only use the KICKR on a stable, level surface with properly adjusted leveling feet." "Use caution when standing while riding on the KICKR." "Keep children and pets away from the KICKR while in use." https://support.wahoofitness.com/hc/en-us/article_attachments/4648101171218
- App design implications:
  1. Never ask the rider to touch or look at the phone while pedaling. Use a countdown, voice prompts and auto stop. A hands-free capture (set phone, walk to bike, start pedaling, recording starts after N seconds of detected pedaling and ends automatically) is both a safety and a quality feature.
  2. Tell the user to place the phone on a stable surface or tripod at hip height, 2 to 3 m away, outside the swing area of the bike and away from the flywheel and cables.
  3. Advise doing fit changes with the trainer on a level floor, bike clamped or through-axle tight, and after dismounting with the flywheel stopped.
  4. Apple 2.5.14: show a recording indicator and get explicit consent before each capture; also announce "recording" by voice since the rider cannot see the screen.
  5. Outdoor or rollers capture should be discouraged in copy (balance risk on rollers; traffic outdoors).
  6. Apple 1.4.5: do not gamify position changes (no "aggressive position" challenges or leaderboards for drop or saddle height).

---

## 12. Consolidated recommendations for the spec

1. Positioning: "camera bike fit for comfort and speed", category Health & Fitness (cycling is named in Apple's definition) or Sports; never Medical. No disease or injury words in intended purpose, listing, onboarding, push copy or support site.
2. Privacy: all inference on device; no network calls except App Store; no third-party SDKs; no analytics; no iCloud sync in 1.0; crash logs only via Apple's opt in. Label: Data Not Collected. Privacy policy still required (5.1.1(i)) and should say video is processed on the phone and deleted or kept only in the user's own Photos library at the user's choice.
3. Camera: NSCameraUsageDescription that states purpose and on-device processing; request at first capture, not at launch; recording indicator plus voice cue; PHPicker for importing existing video (no Photos permission).
4. Claims: publish a methodology page (what is measured, how, validation sample size and error); no "as accurate as", "pro level", "clinically", "medical grade", "prevents injury", no competitor names in metadata, no testimonials as proof.
5. Recommendations: guardrails and refusal list in section 10; incremental steps; "stop if pain"; onboarding acknowledgement; "see a fitter" exits.
6. Race rules: optional toggles for UCI road (tip behind BB), UCI TT (50 mm), World Triathlon non-drafting (tip not more than 5 cm ahead of BB, not more than 15 cm behind), extension tips not past front wheel leading edge (World Triathlon and Ironman). Default off; never blocks.
7. Legal entity: consider publishing under an LLC rather than as an individual before any health adjacent framing creeps in (Apple 5.1.1(ix)) and for product liability insulation; check the owner's personal constraints with counsel (not researched here).
8. EU: keep the lifestyle and well-being framing (MDR Recital 19); before active EU marketing, get an hour of advice on Directive 2024/2853 scope for a free app.

---

## Open questions (not resolved by sources found)

1. Apple has no public statement on whether sync to a user's private CloudKit database counts as "collected" for the privacy label; the only developer forum thread on it is unanswered. Ask Apple Developer Support before adding iCloud sync.
2. Zwift's Terms of Service could not be fetched (zwift.com/terms redirects to a support hub that rendered empty; other guessed URLs returned 404). Retül / Specialized terms returned 403. Their exact disclaimer wording is unverified.
3. The UCI 2025 Clarification Guide PDF contains tracked changes, so the final wording of Article 1.3.013 (whether the 50 mm minimum now applies only to TT and pursuit positions) should be confirmed against the current UCI Regulations Part 1 PDF, which the uci.org regulations page did not expose to the fetcher.
4. IRONMAN's official competition rules page blocked the fetcher; the aerobar and hydration rules come from Slowtwitch coverage. The absence of a saddle rule in Ironman rules is inferred from that coverage, not confirmed.
5. EUR-Lex returned empty pages for Directive (EU) 2024/2853 and Regulation 2017/745; the PLD summary relies on a Gibson Dunn note and the MDR text on the legislation.gov.uk mirror of the adopted EU text. Confirm Article 2 and Recitals 13 and 14 of the PLD (free and open-source software and non-commercial supply exclusions) for a free app.
6. No authority was found on whether an app developer is a GDPR "controller" at all when processing happens only on the user's device and nothing is transmitted. Draft the privacy policy as if the developer is a controller for any data it does receive (support email) and simply describe on-device processing.
7. Fitbit heart rate accuracy class action (McLellan v. Fitbit) and any negligence precedent against a professional bike fitter were not researched; the web search budget was exhausted.
8. Asia privacy regimes (Japan APPI, Korea PIPA, China PIPL, Singapore PDPA) and whether on-device body video triggers any notification duties there were not covered.
9. Apple's App Store Connect help page describing the "No, we do not collect data from this app" questionnaire choice returned 404 at the guessed URLs; the Data Not Collected definition above comes from apple.com/privacy/labels and the developer app privacy details page instead.
10. MDCG 2019-11 Rev.1 (June 2025) was not read; secondary sources say it clarified borderline wellness apps but the exact text was not retrieved.
