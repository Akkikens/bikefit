# Saddlemark engineering annex

Companion to bikefit-spec.md (version 0.2). Implementation level detail that the spec references but does not need to carry: pipeline parameters, failure paths, the privacy policy checklist and the test plan. Same rules apply: no em or en dashes, no forbidden words outside Safety.strings.

## A. Stroke segmentation parameters (spec 4.2)

- Input: camera side ankle keypoint vertical position in Vision normalized image coordinates (origin bottom left, ankle highest at the signal maximum), one sample per processed frame, with frame index and timestamp.
- Missing frames: ankle confidence below the threshold (0.3 to start, tuned on the bench). Gaps of up to 5 frames at 60 fps (about 80 ms, the chainring occlusion case) are linearly interpolated; longer gaps end the track and a new track starts after the gap.
- Filter: zero phase (forward and backward) second order Butterworth low pass, cutoff 6 Hz to start, fixed on the week 1 bench and printed on the Methods screen. The same filter is applied to every per frame angle before frame selection.
- Cycle boundaries: local maxima of the smoothed ankle signal (top dead centre), prominence at least 25 percent of the track's median peak to peak amplitude, separation at least 0.45 s. One cycle is maximum to maximum; frames before the first and after the last boundary are not a cycle.
- Cadence: 60 times the processing frame rate divided by the cycle's frame count. Outside 60 to 110 rpm inclusive the cycle is dropped on its own and does not fail the capture.
- Clean cycle: hip, knee and ankle on the camera side each clear the confidence threshold on at least 90 percent of the cycle's frames and on every frame of the 5 frame window centred on the maximum extension frame. Upper body joints gate separately.
- Maximum extension frame: frame of minimum filtered knee flexion within the cycle; the reported value is the filtered value at that frame. The same rule applies to the per cycle knee maximum and the hip minimum. Torso, elbow and shoulder use the cycle mean of the filtered signal.
- Live pass: half resolution, every fourth frame of the 1080p60 preview (about 15 fps), feeds the four gates and the cadence hold only; never produces a stored number.

## B. Noise and verdict arithmetic (spec 3.5 and 4.4)

- Pairs: sessions one to three on a bike record A and B. Per metric difference d = median(A) minus median(B). SEM = sqrt(sum of d squared over 2n) for n pairs. Only pairs feed the SEM; compare results never do.
- Floor: 2.2 degrees under three pairs (A24 in the spec appendix); from three pairs on, the larger of the pooled SEM and 2.0 degrees. The week 2 bench SEM for knee flexion at maximum extension replaces the floor once measured.
- Reference value: mean of the A and B medians. Displayed spread: the larger of the two interquartile ranges. Ghost outline and thumbnail: capture B.
- Single reading interval: plus or minus 1.96 times SEM.
- Difference noise: SEM times sqrt(1 over reference count plus 1 over check count). Reference count is 2; a plain check is 1; a change window check (mean of ride 1 and ride 3) is 2.
- Verdicts: Matches reference when the absolute difference is under 1.96 times the difference noise. Possible change, measure again between that and 2.77 times SEM. Changed above 2.77 times SEM, or when two consecutive checks sit beyond 1.96 times the difference noise on the same side. With a logged change direction the test is one sided at 1.64 in that direction, and copy compares the measured delta with the expected delta from the bench sensitivity table.
- Worked numbers at the 2.2 floor: single reading plus or minus 4.3; difference noise for a plain check 2.69, threshold 5.3; detectable change 6.1, shown as 6.
- Saddle height card gate: median plus or minus 1.96 times SEM entirely below 30 or entirely above 40. At the floor, 25.7 or below fires, 26 does not; 44.3 or above fires.

## C. Failure paths (spec 6, step 8)

- Camera denied or restricted: one line on the capture tab and a one tap link to Settings; estimate layer, Setup Card and import stay usable.
- Capture A banked, capture B failed three times: A is kept and can be set as reference at the SEM floor with a "noise pair pending" tag; the next session opens on capture B.
- Phone call, lock or app backgrounded during countdown or recording: clip discarded, voice says "capture cancelled", nothing stored, placement guide reopens.
- Free storage under 200 MB: capture refused with the amount needed.
- Thermal state serious or critical: capture allowed; processing waits with "phone is warm, processing will resume" and uses the every second frame fallback.
- Rider does not mount and pedal within 90 seconds of tapping Start: disarm with a spoken line, no clip.
- Gate fails during countdown or recording: stop, name the gate by voice, re-arm once; second failure disarms with "come and check the frame" and opens the retake screen for that gate.
- Processing error or no pose found at all: counts as a failed retake with the generic placement and clothing text.
- Three failed retakes in a row: offer the static check or the estimate layer.
- Effort or pain answer skipped: angles shown, saddle height card and compare withheld with "add an effort rating to compare"; the answers can be added later from the capture.
- Compare refused for an effort gap over 2: both captures' angles side by side, no delta, "effort differed by more than 2, no comparison".
- Phone falls mid capture: discard.
- Second person in frame: countdown stops; during recording the clip is discarded.
- Level, squareness or yaw gate that will not pass on a given shelf: after 60 seconds the guide offers the static check and a tip card for the failing gate.
- Import with ultra wide or under 20 mm equivalent focal length in metadata: refused with the reason. No metadata: accepted with the "placement and stabilization not verified" label.

## D. Privacy policy checklist (spec 8)

The policy, on the Vercel site and in the app, states:

1. What is measured and what is stored on the phone: joint tracks, thumbnails, Setup Cards, pain tags, change log, local notification dates.
2. That no data is transmitted; no accounts, analytics or third party SDKs; the only traffic is the App Store.
3. Retention: video is deleted as soon as processing finishes; derived data stays on the phone until Delete everything or the app is removed; it is included in the user's own iPhone backup under the user's backup settings.
4. Deletion: the Delete everything button; clips the rider shared are outside the app and are deleted by the rider.
5. Revoking consent: camera access and notifications can be turned off in iOS Settings at any time; the estimate layer and import keep working.
6. Support address: anything emailed is used only to answer that message, deleted once resolved, and cannot be linked to anything in the app because the app has no identifier.

Camera purpose string: "The camera records a short side view of you pedaling so the app can measure your riding position on this phone. Video never leaves your device." No microphone or Photos purpose strings; a build that touches either fails at first use.

## E. Notification rules (spec 6, step 10)

One scheduler, local notifications only, at most two a month per rider, quiet hours 21:00 to 08:00 local, every pending notification cancelled when the rider completes the check it asked for. Rules: change window prompts at ride 1 and ride 3 after a logged change (rides counted by the rider tapping "I rode it", not inferred); Pack and Rebuild Check the day before and the day after one typed travel date; monthly drift check on a day the rider picks. No remote notifications, no APNs token.

## F. Test plan (spec 14)

- Golden clips checked in as fixtures: reference clip (run on two iOS versions, every angle within 1 degree), yaw 0, 10 and 20 degrees, loose clothing, TT aero, heel down and toes down at one saddle height. Each carries expected cycle boundary and maximum extension frame indices (tolerance 1 frame) and expected angles with tolerances.
- Segmentation on synthetic ankle tracks at 59, 60, 90, 110 and 111 rpm (59 and 111 drop the cycle, not the capture); a 5 frame gap (interpolated) and a 6 frame gap (track split).
- Verdict rule: at the 2.2 floor a 4 degree difference is Matches, 5.5 is Possible change, 7 is Changed; two consecutive 5.5 degree checks on the same side are Changed.
- Saddle height card: one unit test per firing clause (in app capture, road or gravel, 12 clean cycles, four gates, effort and pain answered, no pain tag, interval outside the window), each asserting no card when only that clause fails; 26 plus or minus 4 does not fire, 23 plus or minus 4 does; a TT bike never fires; the step lock and the 2 cm cap.
- Forbidden word scan over every string table, the App Store metadata files and the site copy, exempting exactly the three strings in Safety.strings.
- Info.plist: the sales flag is false; no microphone or Photos purpose strings present.
- Effort and pain answers required before processing.
- UI tests: the acknowledgement, the camera permission moment, delete everything.
- No test path traps (no fatalError or precondition in tested code); tests run on a named simulator that is shut down afterwards.
