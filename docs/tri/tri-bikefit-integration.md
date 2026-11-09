# Bike fit module integration map

Saddlemark into the triathlon app. Prepared 2026-11-06 for Akshay Kalapgar.

Decision recorded: the bike fit ships as its own tab inside the triathlon app (working name TriSpike, pending trademark and App Store checks), not as a standalone app. Sources: bikefit-spec.md version 0.2 and bikefit-annex.md, both 2026-11-04, and tri-synthesis.md, 2026-11-06. The synthesis already placed the module at 1.1; this map holds that placement and works out the seams.

## 1. What moves in unchanged

These parts of the Saddlemark spec transfer as written. They are self contained, and nothing on the tri app side gives a reason to touch them. Both sides already sit on iOS 17: the module for the 3D request's yaw hint and its tested device floor, the tri app for WorkoutKit.

1. The CV pipeline, spec 4.1 to 4.5 with annex A and B. Vision 2D body pose run twice (live gate pass at about 15 fps, offline per frame pass on the recorded file), the 3D request used only for the yaw hint, ankle track stroke segmentation with the fixed parameters (0.3 confidence to start, 5 frame interpolation, 6 Hz zero phase Butterworth, prominence and separation rules, 60 to 110 rpm per cycle), clean cycle gating per joint, the six angle table with its conventions and published context, the known bias list, the under 60 second processing target with the every second frame fallback, video deleted the moment processing finishes with no exception, joint tracks and one thumbnail as the only stored imagery, the stick figure replay rendered from tracks. The golden clip fixtures and the release gate (one reference clip on two iOS versions, every angle within 1 degree) come with it.
2. Saddle height card logic, spec 5.1, every clause. Fires only on an in app dynamic capture, road or gravel bike, 12 or more clean cycles, four gates passed, effort and pain answered, no pain tag, and the median plus or minus 1.96 SEM entirely outside 30 to 40. Direction only phrasing, 5 mm steps, one change per session, the step lock on a later qualifying capture within effort 2, confirmation only at 10 mm cumulative, the 2 cm cap with its reset rules, the effort qualifier lines, the fixed adjustment footer. TT and tri bikes still never get the card; sitting inside a triathlon app changes none of the evidence behind that rule.
3. Noise floor math, spec 3.5 and 4.4 with annex B. A and B pairs on the first three sessions and after equipment or placement resets, pairs only feeding the SEM, the 2.2 degree floor under three pairs and the larger of pooled SEM and 2.0 after, reference as the mean of the A and B medians, the difference noise formula, the verdict thresholds (1.96 noise, 2.77 SEM detectable change, two consecutive same side checks, one sided 1.64 with a logged direction), and the worked numbers.
4. Language rules, spec 5.3. The allowed and forbidden lists, the three Safety.strings exemptions (the acknowledgement, the pain tag line, the adjustment footer), the Retul naming restrictions (cited source or reported comparison on the Methods surfaces only, never in metadata or share images), and the unit test that fails on any forbidden word outside that one file. The scan now runs over the merged app's string tables, metadata and site copy; the tri app's own copy rules (never "AI coach", no TSS, IF or NP) join the same scan as a second word list.
5. The Methods screen. Pipeline description with the bench filter cutoff, the landmark convention and 2D biases, the ankling note, the measured SEM once the bench writes it, and the comparison subsection rules: nothing published under n of 10, the fixed non validation opening line, no bias correction. The screen lives in the module; its web twin becomes a page on the tri app site.

Carried along with them, unchanged in substance: the three confidence levels (3.1), the capture protocol, gates and hands free voice recording with the visible indicator (3.2 to 3.4), the clean cycle refusal tiers (under 8 refused, 8 to 11 short capture, 12 full), photos import rules and the "placement and stabilization not verified" label (3.6), the failure paths (annex C), the estimate layer bracket math, the share artifact contents (stick figure clip, fit card, fitter hand off card, no camera frames ever), the no microphone and no Photos purpose string tripwire, and the week 1 to 2 bench protocol with its kill criteria (spec section 10), which keep gating the module (5.3 below).

## 2. What adapts, and exactly how

1. Bike entity and Setup Card become shared app models. The tri app ships a minimal Bike record in 1.0 inside its gear and race layer: name, type (road, gravel, TT or tri), service notes; the race window's bike service reminder already wants that record. In 1.1 the fit module extends the same record rather than migrating anything: hand position, camera side, the full Setup Card (saddle height, setback, nose to bar centre, drop, crank length, pad stack and reach for TT, shoe and pedal system, photo), references scoped per bike and per hand position, the noise estimate, the change log. Saddlemark's Rider entity merges into the athlete profile the plan engine already keeps; inseam and crank length live there and feed the estimate layer. Editing any Setup Card field, or logging a change, still opens a change window per spec.

2. Pack and Rebuild Check merges into the race window. Standalone it keyed on one typed travel date because there was no race model. Merged, the date comes from the race record: marking a race as a travel race arms the pair. The Pack snapshot becomes an item on the race window packing checklist, taken before boxing, at home, where the trainer is. The Rebuild Check is offered after reassembly, at the venue when a trainer and the saved camera spot exist, otherwise after the flight home, and it stays soft: the copy says what it needs rather than pretending a hotel room works. Its notifications ride the existing race window timeline instead of spending separate pushes.

3. The come back loop merges with the training calendar. One scheduler, the tri app's; Saddlemark's scheduler dies as a system and survives as policy: fit prompts capped at two a month, quiet hours respected, every pending prompt cancelled when the rider completes the check it asked for. The change window improves in the merge: ride 1 and ride 3 were counted standalone by the rider tapping "I rode it"; merged they are counted from completed bike sessions via the plan and HealthKit completion matching, and the re-check prompt lands with the session recap instead of as a separate push. Fit lines prefer existing surfaces (Today card, Sunday recap) before any dedicated notification is spent.

4. The monthly drift check becomes part of recovery weeks. The plan engine runs 3 plus 1 loading blocks, so a recovery week arrives about monthly, which is exactly the standalone cadence; the "pick a day" setting dies. For bikes with a reference the plan inserts one fit check item per recovery week. One honest wrinkle carried from the spec: compares are refused when effort differs by more than 2, so the item tells the rider to ride the 20 second capture at the reference effort, which fits inside an easy week after the warm up; a rider who declines just waits for the next recovery week. "Nothing moved" stays a first class, expected result. Riders with no reference get the setup offer instead.

5. Camera permission sits behind the Bike Fit tab. Tri app onboarding never mentions the camera; HealthKit and notification permissions belong to the training side and keep their own moments. First entry into the Bike Fit tab shows the fit acknowledgement (the Safety.strings text, word for word). The camera request happens on the first capture attempt with the spec's purpose string. Camera denied leaves the estimate layer, Setup Card and import usable, per annex C.

6. Smaller adaptations. The standalone trigger picker onboarding dies in favour of the entry points in section 6. Share artifacts render through the tri app's share card system with content rules intact. The per capture effort rating can prefill from a logged trainer session's RPE when the capture coincides with one, editable and still mandatory before results. Delete everything splits into Delete bike fit data in the module and the app wide delete in settings. The forbidden word scan and the Info.plist tripwire tests run in the merged app's test suite, no trapping paths, named simulator shut down after, per the house rules.

## 3. Cost in build weeks, and where it lands

Mapping the standalone 12 week plan onto the merged app:

| Standalone | Work | In the merge | Why it changes |
|---|---|---|---|
| Weeks 1 to 2 | Capture and Vision spike, bench, kill decision | 2.0 | Unchanged; this is the gate |
| Weeks 3 to 4 | Data model, placement guide, gates, hands free recording, retakes | 1.5 | Bike, Setup Card and profile already exist; the capture UX is all new |
| Weeks 5 to 6 | Results, compare, noise floor flow, card logic, estimate layer | 2.0 | Logic unchanged, screens built in the app design system |
| Week 7 | Notification scheduler | 0.5 | Folds into the existing scheduler |
| Week 8 | Share | 0.5 | Rides the existing share card system |
| Week 9 | Methods screen, copy pass, privacy policy, site | 0.75 | Pages are additions to the existing site; the Retul session moves off the critical path (it waits for n of 10 before anything publishes anyway) |
| Week 10 | Settings, StoreKit scaffold, performance pass | 0.5 | Scaffold and settings exist; the iPhone 12 and SE pass remains |
| Week 11 | Project hygiene, listing, screenshots | 0.5 | The app exists; 1.1 listing update and new screenshots |
| Week 12 | Fable review, fixes, submission | 0.75 | One review covers the whole 1.1 build |

Total: about 9 solo weeks, honest range 8 to 10.

Recommendation: 1.1, and the synthesis call stands.

- Not 1.0. Nine more weeks turns a 12 to 16 week plan into 21 to 25, couples two independent kill gates (the WorkoutKit spike and the CV bench) into one go or no go, dilutes the watch first launch story, and puts camera plus HealthKit in front of App Review on the first submission of a new app.
- Not 1.0.x. Point releases are for fixes. The module adds a camera permission, new privacy policy sections, a Methods screen and a new review surface; it needs its own Fable review, screenshots and what's new story. Burying it in a 1.0.x wastes the marquee and adds review friction to releases that need to stay boring.
- 1.1, with the bench pulled forward. The module's weeks 1 to 2 are spike code, not app code, so run the bench during the 1.0 App Review wait. Bench passes: about 7 to 8 further weeks after 1.0 ships, landing roughly two months after launch as the second beat. Bench fails: 1.1 ships a different beat (5.3 below) and nothing announced has to be walked back. If 1.0's cut list got exercised (70.3 or CloudKit sync slipped), ship the slipped scope first in a small release and keep bike fit as the 1.1 marquee rather than stacking both into one oversized submission.
- The hedge survives: if the tri app stalls, the spec still works standalone. Nothing in this integration forecloses that.

## 4. What dies

- The Saddlemark name, and Pedalmark behind it. The module is called Bike Fit, a plain feature name. Spec section 13's clearance work is filed unused; no domains, no Slowtwitch or TrainerRoad handles for a fit brand. If the standalone hedge is ever exercised, the name research gets a fresh recheck anyway.
- The separate Vercel site. The privacy checklist (annex D) and the methods page become pages on the tri app's site in the personal scope.
- The separate App Store footprint: bundle id com.akkikens.saddlemark, its App Store Connect app, listing, keywords, screenshots, App Privacy entry.
- Duplicated chrome: Saddlemark's own StoreKit 2 scaffold and OFF flag (one app level flag covers everything), its notification scheduler, its settings and delete plumbing, its share sheet plumbing, its standalone onboarding with the trigger picker, its Rider entity.
- The standalone 12 week plan and the standalone 90 day metrics (5,000 downloads, completion percentages). With no analytics those rates were never measurable anyway; section 6 replaces them with signals that are.
- The standalone market sizing and go or no go (spec section 12), superseded by the synthesis verdict. The bench kill criteria explicitly do not die.
- Housekeeping: the bikefit repo stops being a future app repo. Its specs and this map move into the tri app repo's docs tree; the repo is archived.

## 5. New risks from the merge

### 5.1 App Review sees camera plus health together

Standalone, Saddlemark was a camera app with on device math. Merged, one binary holds HealthKit read and write, WorkoutKit scheduling, and a camera pointed at the user, which widens the 1.4.1 surface (joint angles as a health measurement) and invites a reviewer to assume video is collected health data. Mitigations are cheap and already specified: the acknowledgement and Methods screen carry over; the 1.1 review notes link the methods page and state in one line that video is processed on device and deleted when processing finishes; purpose strings stay separate and specific per permission moment; screenshots and metadata keep the no accuracy equivalence rule; the 2.5.14 recording indicator is in the capture flow. One genuinely new coupling: a module rejection blocks the whole 1.1, training fixes included. Keep the 1.1 branch separable so the module can be pulled and the release resubmitted without it; never ship the module dark behind a flag as a hedge, because a hidden shipped feature is its own guideline problem. The merge also helps in one place: 4.3 spam risk falls, since a free tri training app with an on device fit instrument is harder to read as a template app than either half alone.

### 5.2 Privacy label: the merged app still qualifies, with one standing condition

The module adds nothing that transmits. Video is deleted on device, joint tracks, Setup Cards, pain tags and the change log stay in the app container, there are no new SDKs and no network calls, so under Apple's definition (collection means transmitting off device) the fit module preserves Data Not Collected. The standing condition sits on the training side: CloudKit private sync is the one unresolved label question (Apple has not said whether private database sync counts as collection; synthesis open question 3 and spec citation A36 agree). Hold Data Not Collected for 1.0 and 1.1 by keeping CloudKit sync out until that is clear; it is already second on the cut list. Independent of that outcome, fit data, pain tags above all, stays out of any sync container permanently, so the capture screen promise stays literal even if training data later syncs; add one unit test asserting the fit models are absent from the sync schema. Akshay re-confirms the App Privacy answers in the web UI at 1.1 with the camera addition in mind.

### 5.3 The bench still gates the module, inside the bigger app

The kill criteria transfer intact and still bind: pooled SEM of knee flexion at maximum extension above 2.2 degrees stops the module; a 10 mm saddle move reported as Changed in fewer than 8 of 10 trials stops it, with only the two named loosening options available at the week 2 decision; the TT pass rate decides only how TT capture ships. The merge adds a pressure the standalone app never had: a 1.1 that is expected or teased while the bench can still fail. So nothing about bike fit is announced until the bench passes, and a fallback 1.1 beat stays ready from the existing candidate list (70.3 if it slipped, the Strava write only upload, Carry, PDF export).

Two more risks the merge creates:

- Audience mismatch. The tri app's most motivated users ride TT and tri bikes, and the module's one directive never fires for those bikes. Inside a triathlon app that reads as a gap unless the copy sets it upfront: tri bikes get trend, compare, Pack and Rebuild Check; the saddle height card fires on road and gravel bikes, which is where most triathletes do the bulk of their training anyway. The TT hold test stays a bench gated later candidate.
- Notification trust. The tri app already sends Monday preview, Sunday recap and race window pushes. The module's cap (two a month, quiet hours, cancel on completion) becomes a per module budget inside the shared scheduler, and fit prompts ride existing surfaces first. The merged app keeps the quiet posture both specs promised or the come back loops stop being honest.

## 6. One page module spec

Tab name: Bike Fit. Its own tab, plain name, no sub brand.

Tab content, top to bottom: bikes with reference status (none, pair pending, set), last verdict (Matches reference, Possible change, Changed, or nothing moved), next scheduled check; per bike primary action (Set up reference or Check now); the estimate layer entry for riders without a trainer; links to Methods, what this measures and what it does not, and Delete bike fit data.

Consent and permissions: first entry shows the fit acknowledgement (Safety.strings, unchanged). Camera is requested on the first capture attempt with the spec purpose string, never at app onboarding. No microphone or Photos strings exist in the merged Info.plist; the tripwire test guards both.

Entry points from the training side:

| Trigger | What appears |
|---|---|
| New bike added in gear | Offer the Setup Card and a reference capture |
| Bike discomfort logged on a session or in a debrief | The pain routing line first, then a drift check offer and the fitter hand off card; a pain tag suppresses adjustment advice, so this path measures and documents, never prescribes |
| Race window opens, about T minus 21 | Checklist item: confirm position matches reference, on the race bike; travel races add Pack snapshot before boxing and Rebuild Check after reassembly, marked as needing the trainer and the saved camera spot |
| Recovery week generated | One fit check item per recovery week for bikes with a reference; capture ridden at reference effort (within 2); declining waits for the next recovery week |
| Setup Card change logged | Change window opens; re-checks attach to the first and third completed bike sessions after the change, counted from plan and HealthKit completion; before and after card names the logged change |
| Post race debrief, travel race | Offer the Rebuild Check for the return build |

Notifications: at most two fit pushes a month, quiet hours, cancelled on completion; the entry points above prefer existing tri surfaces (Today card, recaps, race window timeline) over new pushes.

Data: Bike and Setup Card are shared app models. Captures, joint tracks, noise estimates, change log and pain tags are module owned, on device only, excluded from any sync container permanently, covered by Delete bike fit data and the app wide delete, present only in the user's own device backup.

The module never: prescribes millimetres, shows the saddle height card for TT or tri bikes, retains video after processing, exports camera frames, makes a network call, or gamifies.

Ship gates inside 1.1: bench kill criteria passed and the measured numbers written into the Methods screen; golden reference clip within 1 degree on two iOS versions; forbidden word scan green across the merged app with the Safety.strings exemption; Info.plist tripwires green; sync schema test green; no trapping test paths, named simulator shut down after runs; Fable end to end review of the 1.1 build, fixes applied; Akshay's explicit go before submission.

90 day module read (replacing the standalone download metrics, which were never measurable without analytics): App Store Connect gives 1.1 adoption and update velocity; reviews, support mail and community threads answer the real question, whether people mention the fit module unprompted and whether share cards and fitter hand off cards show up in the wild. That read decides whether the later fit candidates (Carry, TT hold test, cleat tape flow, PDF fit card) earn their slot.
