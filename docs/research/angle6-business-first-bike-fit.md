# Angle 6 research notes: business first bike fit app (free now, switchable later)

Date: 2026-11-03. Designer: judge panel seat 6. No filename was supplied in the task text, so this file is named angle6-business-first-bike-fit.md.

Method note: the shared WebSearch budget for this turn was already exhausted when this agent started, so every claim below comes from a direct WebFetch of a URL this agent already knew. Pages that returned 404 or rendered only a title are listed under Unresolved so nobody mistakes memory for a source.

## Competitors (verified)

### MyVeloFit (web upload service)
- Read: https://www.myvelofit.com/ and https://www.myvelofit.com/pricing
- Capture: record a video pedaling on a trainer, rollers, smart bike or spin bike, upload in the browser. Any phone or camera. Views not specified on the home page. Separate AI body scan for sizing plus a mobility assessment.
- Pricing (pricing page): Starter $0 (one fit upload per week, basic analysis, no detailed report or specific recommendations); Enthusiast $35 USD one time for 2 weeks (5 uploads per day, detailed report, adjustment recommendations, 30 day better fit guarantee); Pro $75 USD per year (unlimited bikes and uploads). Expert Review add on from $75 USD, requires a paid plan. Business tier for retailers and fitters, prices by sales email.
- Claims on home page: "world's #1 online bike sizing and fitting tools", 200k active users, 450k fits processed. No validation study or error figures on the pages read. Processing is clearly server side (upload to website).
- Takeaway: the free tier exists but is deliberately crippled (no specific recommendations). Upload to cloud is the model.

### Bike Fast Fit (iOS)
- Read: https://www.bikefastfit.com/ and https://www.bikefastfit.com/academy
- Capture: iPhone mounted side on, bike on indoor trainer, short pedaling clip (EZ app uses a four second clip), markerless tracking, 240 fps mentioned, full pedal strokes. Road, gravel, MTB, TT, indoor bikes.
- Tiers (US, per year): EZ $9.99 with one week trial (side view only: saddle height, saddle fore/aft, riding position bucket Upright/Relaxed/Aggressive); Elite $29.99 (adds front view knee tracking, what-if drag tool, playback, saved sessions); Pro $139.99 for fitters and shops (LiveCheck real time, rear view pelvic angle and knee displacement, branded reports, client records).
- Metrics: knee angle at max extension, hip angle, torso and shoulder position vs recommended ranges. Recommendations in mm or inches, shown as ranges, not single numbers.
- Claims: 4.7 average App Store rating from 2,940 ratings, over 1.15 million rider videos as of July 2026. Qualitative accuracy wording only, no error rates. Academy page gives no numeric ranges and cites no sources.
- Takeaway: the closest analogue to an on-phone product. Cheap subscription, side view first, front view as upsell, fitter tier as B2B. Their public pages do not say whether processing is on device.

### Retul (Specialized, in person 3D fit)
- Read: https://www.retul.com/ and https://www.retul.com/fit
- Pages read are brochure level: "Data Driven, Personally Crafted", book a fit near you, Retul Fit, Retul Footbeds, saddle sizing, Retul Training. No pricing, no description of the LED marker 3D capture on the pages fetched. Contact bodygeometry@specialized.com.
- Takeaway: the premium in person benchmark that every phone app gets compared against in forums (a MyVeloFit testimonial literally compares to Retul).

## Apple Vision body pose (verified)
- Read: https://developer.apple.com/videos/play/wwdc2023/111241/ (WWDC23, Explore 3D body pose and person segmentation in Vision)
  - VNDetectHumanBodyPose3DRequest returns a 17 joint skeleton, positions in meters with origin at the root joint (hip center), not normalized.
  - One skeleton only, the most prominent person.
  - bodyHeight in meters: measured when depth metadata is present, otherwise a 1.8 m reference height; heightEstimation says which. cameraOriginMatrix gives camera position relative to the person. Works on a plain image, no ARKit needed; depth improves height.
  - Each point has position (relative to root) and localPosition (relative to parent joint), which the session says is useful for joint angles.
  - Session does not state minimum OS versions.
- Attempted: https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest, https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest, https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation. All three returned only the page title (JS rendered), so joint lists and OS availability for the 2D request (19 joints, iOS 14) and the 3D request (iOS 17) are from memory and must be confirmed in Xcode before anything is written down as fact.
- Design implication: 2D pose per frame is the workhorse for a side view; the 3D request is a sanity check for scale and camera perpendicularity, not the primary angle source, because its height is a 1.8 m guess without depth data.

## App Privacy (verified)
- Read: https://developer.apple.com/app-store/app-privacy-details/
- "Collect" means transmitting data off the device in a way that lets the developer or partners access it longer than needed to service the request in real time. On device only processing is therefore not collection. The page does not define the phrase "Data Not Collected"; that label is set in App Store Connect.

## Unresolved (no source found this turn)
- Bikefit.ai: https://bikefit.ai/ returned 404, https://www.bikefit.ai/ failed with a certificate mismatch (cert is for firebaseapp.com). Could not describe the product.
- Bike Fit Advisor: the App Store URL guessed from memory returned 404; could not verify the app exists under that name or its features.
- USA Triathlon membership and club counts: https://www.usatriathlon.org/ and /about-usa-triathlon gave no numbers (second URL 404).
- Peer reviewed validity of 2D phone video vs 3D marker systems for knee angle in cycling: not fetched this turn (no search budget, and I will not guess a PubMed URL). Must be found before the app cites any accuracy figure.
- Retul process details and pricing: brochure pages only.

## Design conclusions drawn from the above
1. Every verified competitor charges or uploads. A free, no account, on device app with specific recommendations is a gap the MyVeloFit Starter tier deliberately leaves open and Bike Fast Fit prices at $9.99 per year.
2. Side view on a trainer is the industry standard capture; front view is a known upsell. Copy the protocol shape, not the assets or names.
3. Showing ranges rather than single numbers is already the convention (Bike Fast Fit). Go one step further: show spread across strokes and refuse to recommend on bad captures.
4. The defensible asset cannot be a cloud dataset. It has to be the protocol plus engine, the shareable artifact, the club distribution channel, and an in person validation program Akshay runs himself with consent, offline.
