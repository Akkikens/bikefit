# Brickline design spec: Contour

Final spec from the four direction panel. Base: Direction D, Contour (summed 145). Grafts: A's Fill versus Ink rule, Increase Contrast mapping and Dynamic Type collapses; B's always black player, paused dimming, live heart rate and settings style Lab; C's Readout, time ruler, planned versus done grid and honest watch footnote. Judge fixes are in section 8; copy follows the tri spec.

## 1 Concept and signature

Triathletes already read one drawing: the course profile, time along the bottom, effort up the side. Contour makes it the whole interface. A session is a Profile: blocks whose width is duration, height is intensity, color is sport. The week is seven small Profiles, the season is the ArcBar with four phase bands, race day is three Profiles joined by T1 and T2 notches, and the player is the Profile stretched across a black screen with a playhead.

Color is two hues plus ink: swim lane blue, bike saffron, run graphite. Under Machado 2009 simulation of all three deficiencies, blue and saffron are the most separable pair and a neutral stays 37 dE or more from both; the rejected violet run fell to 5 dE from swim under deutan.

Register: calm, adult, honest. Done is a solid shape, planned hollow, skipped hollow with a slash. The reason line exists only when a rule changed something, so its presence is the signal. Light first on warm stone; the player is always true black.

## 2 Tokens

WCAG 2.x relative luminance, computed by script. Text needs 4.5:1, graphics and control edges 3:1. Light ratios are on background/surface; dark ratios on background/surface/elevated.

| Token | Light | Dark |
| --- | --- | --- |
| background | #F4F2EC | #121214 |
| surface | #FFFFFF, 1.12 vs background | #1C1C1F, 1.10 vs background |
| surfaceElevated | #FFFFFF plus shadow | #27272B, 1.14 vs surface |
| separator | #D9D6CE, 1.30/1.45 | #2E2E33, 1.39/1.26/1.10 |
| separatorHC | #7F7B74, 3.76/4.21 | #7A7A82, 4.36/3.99/3.50 |
| textPrimary | #1B1C1F, 15.22/17.04 | #F2F0EA, 16.42/14.92/13.06 |
| textSecondary | #5B5E66, 5.79/6.49 | #9D9B94, 6.73/6.11/5.35 |
| accent | #1B1C1F, as textPrimary | #F2F0EA, as textPrimary |
| onAccent | #F2F0EA, 14.95 on accent | #1B1C1F, 14.95 on accent |
| swimInk | #1A6698, 5.52/6.18 | #8FC6F0, 10.25/9.31/8.15 |
| swimFill | #2E86C4, 3.52/3.94 | #4FA3E0, 6.81/6.19/5.42 |
| bikeInk | #8A5A00, 5.29/5.93 | #F2C25C, 11.27/10.24/8.96 |
| bikeFill | #A8760A, 3.57/3.99 | #D9A030, 8.04/7.30/6.39 |
| runInk | #1B1C1F, as textPrimary | #F2F0EA, as textPrimary |
| runFill | #2B2D32, 12.31/13.78 | #E2DFD8, 14.06/12.77/11.18 |
| success | #246B42, 5.76/6.45 | #6FC792, 9.14/8.31/7.27 |
| warning | #9E4612, 5.62/6.29 | #F0A548, 9.07/8.24/7.21 |
| destructive | #B8342A, 5.27/5.89 | #F2736A, 6.63/6.02/5.27 |
| playerBackground | #000000 | #000000 |

Roles: Ink tokens color symbols, words and targets; Fill tokens color blocks and strokes only; accent fills primary buttons, toggles, selection and the tab tint; warning is text only; the player uses dark tokens on black in both modes.

Sport ink on its 12 percent chip tint (swim/bike/run): light 5.35/5.17/13.65, dark 7.76/8.30/11.03. Player on black: textPrimary 18.43, textSecondary 7.55, swimFill 7.65, bikeFill 9.02, runFill 15.78, paused text at 55 percent 5.61. runFill against textSecondary: 2.12 light, 2.09 dark (D shipped 1.32 and 1.23). Below 3:1 by design: separator (decorative) and warm up fills at 0.55 (light swim 2.02, bike 2.01, run 3.37; dark 2.78, 3.14, 4.75), which carry a 1pt full fill stroke so the edge clears 3:1 while height carries the level. Text on fills is forbidden (white on dark swimFill 2.75, textPrimary on dark bikeFill 2.04); a debug assertion in SportMark and an asset catalog unit test reject any Fill token as a foreground.

Spacing 4, 8, 12, 16, 24, 32, 48; gutter 20; card padding 16; card gap 12; section gap 24. Radii (.continuous): cards and week strip 14, chips and buttons 8, sheets 28, Profile blocks 2, player plate 20. Materials: solid cards; light cards 0.5pt separator stroke, no shadow; dark cards lighter than background, no stroke. surfaceElevated (player plate, popovers, sheets) adds a light shadow, black 12 percent, radius 24, y 8. Liquid Glass (iOS 26) only on the tab bar and player plate via `.glassEffect(.regular)`; iOS 18 falls back to solid surfaceElevated.

## 3 Typography

SF Pro only, text styles throughout, no bundled font. Width is the only flourish.

- Hero numeral (player remaining time, race T minus): `Font.system(size: hero, weight: .semibold).width(.expanded).monospacedDigit()`, `@ScaledMetric(relativeTo: .largeTitle) var hero: CGFloat = 112`, `.kerning(-1)`, `.lineLimit(1)`, `.minimumScaleFactor(0.5)`.
- ArcBar countdown: `.title.weight(.semibold).width(.expanded).monospacedDigit()`. Expanded appears nowhere else.
- Large value (duration, player target): `.title.weight(.semibold).monospacedDigit()`.
- Session name: `.title2.weight(.semibold)`.
- Purpose sentence: `.title3` regular, textPrimary, `.lineSpacing(2)`, three lines maximum.
- Body `.body`; reason line and metadata `.subheadline` textSecondary.
- Labels and units: `Font.footnote.weight(.semibold).lowercaseSmallCaps()`, textSecondary, textPrimary for the active item (today, current phase). Never lighter or smaller.
- Readout value `.title3.weight(.semibold).monospacedDigit()`; row numerals `.body.weight(.medium).monospacedDigit()`. A `NumeralText` wrapper applies `monospacedDigit()` to every number.
- Lab only: `Font.footnote.monospaced()` rows, `.subheadline.weight(.semibold)` headers.

## 4 Sport identity

Always three channels together: color, SF Symbol, word.

| Identity | Ink / Fill | Symbol | Word | Pattern |
| --- | --- | --- | --- | --- |
| Swim | swimInk / swimFill | figure.pool.swim, figure.open.water.swim for open water | Swim | reps drawn by distance, rests 1.5pt gaps |
| Bike | bikeInk / bikeFill | figure.outdoor.cycle, figure.indoor.cycle on the trainer | Bike | watts or bpm |
| Run | runInk / runFill | figure.run | Run | graphite blocks; run walk alternates solid and hollow |
| Brick | each leg its own sport | figure.outdoor.cycle, arrow.right, figure.run | Brick | arrow textSecondary; 4pt gap, 1pt tick, small caps t2 |
| Rest | textSecondary | moon.zzz | Rest | 6pt baseline dot in the cell, never a bar |
| Race | accent | flag.checkered | Race | three blocks, T1 and T2 notches, predicted durations |

## 5 Components

**Profile** (Canvas). Input: steps with duration, level 1 to 5, kind and sport. Width proportional to duration, 3pt floor, 1.5pt gaps; repeats drawn individually (6 by 400 is six blocks) under a hairline bracket and small caps 6x. Heights 0.30, 0.475, 0.65, 0.825, 1.0 of frame height H, bottom aligned on a 0.5pt baseline. Work solid; warm up and cool down 0.55 plus 1pt full fill stroke; recovery hollow 1.5pt. H: 28 compact, 56 standard, 120 detail, 160 player. States: planned hollow 1.5pt, done solid, skipped hollow with a 1.5pt corner to corner slash at full opacity; past days never dimmed. Detail and player add a 0.5pt ruler, 4pt ticks every 5 minutes, 8pt every 15, small caps labels (distance for swims), so a 3 hour steady ride still reads. Player: completed solid, remaining 0.35, current block 2pt taller, playhead 2pt accent with a 6pt cap.

**SportMark.** Symbol (.medium) plus word `.subheadline.weight(.medium)` in the sport ink. Chip: 28pt capsule, padding 10, sport fill at 0.12. Day cell: symbol only, 11pt, word via VoiceOver.

**WeekStrip and DayCell.** One card, seven 44 by 64 buttons, padding 12 by 8. Cell: weekday small caps (textPrimary today), 11pt sport symbol, compact Profile or 6pt textSecondary rest dot; double sessions stack two 12pt Profiles. Today wrapped in a 1.5pt accent rounded rect, radius 8.

**Today hero card.** Surface, radius 14, padding 16: standard Profile, duration Readout left ("48" min), headline target right ("1:52" /100m in sport ink), ReasonLine when present. Primary and secondary buttons beneath; when finished they become a Readout grid of planned, done, load.

**Readout.** Small caps label over `HStack(alignment: .lastTextBaseline, spacing: 2)` of value and small caps unit; optional Estimated badge (warning, e.circle). Grids of 3 with 0.5pt dividers.

**Countdown.** Hero numeral over small caps days, or the step time in the player, with `.contentTransition(.numericText(countsDown: true))`; `.title` expanded inside the ArcBar card.

**ArcBar.** 2pt separator track; bands base, build, peak, taper in small caps sized by weeks; elapsed in accent; recovery weeks 1pt surface notches; test weeks 1pt ticks above; 6pt accent triangle under today; race day a 2pt cap; countdown right. Tap a band for a one sentence popover.

**StepRow.** 56pt minimum: step number small caps, name `.body`, duration or distance `.body.weight(.medium).monospacedDigit()`, trailing target in sport ink monospaced with small caps unit ("205 to 225 w", "148 to 156 bpm"). Recovery rows textSecondary; repeats indented 12pt under a bracket and 6x header.

**ReasonLine.** arrow.triangle.branch 13pt and one `.subheadline` sentence, both textSecondary ("Moved from Tuesday, Tuesday was missed"). Tap expands the rule name and threshold in `.footnote` with Undo when allowed.

**ChecklistRow.** 44pt, 22pt circle with 1.5pt accent stroke, checkmark.circle.fill accent when done, `.body` label; card headers count in monospaced ("9 of 14").

**LabResultRow.** 44pt: checkmark.circle.fill success, xmark.circle.fill destructive or info.circle textSecondary; name `Font.footnote.monospaced()`; value beneath in textSecondary mono; tap expands the raw log.

**Buttons.** Primary: accent fill, onAccent `.body.weight(.semibold)`, 50pt, full width, radius 8. Secondary: surface, 1pt textSecondary stroke (6.49:1 edge), accent label, same metrics. Pressed 0.6 opacity.

**Watch card.** 72pt rounded rect, radius 18, separator stroke: stock Workout step name, alert in plain words ("Speed range alert 1:48 to 1:56 /100m"), one small caps gating line ("this watch lands the swim as a timed workout").

## 6 Screens

`TabView`: Today (sun.max), Week (calendar), Race (flag.checkered), Methods (book.closed), tint accent; each tab a `NavigationStack`. Session detail, checklists and Lab (Developer footer on Methods) push; the player is a `.fullScreenCover`; end session and pool swap use `.confirmationDialog`; the ArcBar phase is a `.popover` with `.presentationCompactAdaptation(.popover)`. Bike Fit joins as a tab in 1.1.

**Today.** No bar title. Date `.subheadline` textSecondary, session name `.title2`, SportMark chip, purpose `.title3`, hero card, "Send to watch" primary, "Start on phone" secondary. After Sunday Sync a checkmark.circle success row reads "On your watch, scheduled 6:30" and the phone button becomes primary; no watch paired: watch button absent. Then the compact WeekStrip card and one textSecondary engine note. Rest day: moon.zzz chip, "Rest day", purpose sentence, no buttons. Fits an iPhone 15 at default type without scrolling.

**Week.** Large title "Week 9 of 16", phase subtitle. ArcBar card, WeekStrip header, seven day rows: weekday and date `.body.weight(.medium)`, chip, name, standard Profile, 17pt trailing glyph (checkmark.circle.fill done, circle planned, minus.circle skipped, textPrimary). Done rows add small caps "planned 48 min, done 51 min"; test sessions add small caps benchmark; rest is one short row. Long press lifts, drop recomputes and shows a ReasonLine. Footer: planned versus done hours.

**Session detail.** Chip, name `.title2`, phase and week textSecondary, purpose `.title3`, detail Profile with ruler (tap a block to scroll to its step), Readout grid of duration, target, load, StepRows, watch card. Actions: primary, secondary, "Pool version" for open water, ellipsis.circle menu with Move, Mark done, Skip (destructive).

**Phone player.** Black, status bar hidden, idle timer off, portrait in 1.0 (landscape and Live Activity in 1.1). Top: xmark 44pt, session name and SportMark in textSecondary, speaker.wave.2 voice toggle. Center: hero remaining time, step name `.title2`, target `.title` monospaced in sport ink, live heart rate in textSecondary when present. Player Profile with playhead. Next row: arrow.right, name, duration, target in `.title3` textSecondary. Plate on surfaceElevated, 88pt, radius 20: backward.end.fill 64pt (previous step), pause.fill 72pt accent filled, forward.end.fill 64pt (next step). Paused: all but numeral and plate dim to 0.55, pause becomes play.fill. xmark asks once: "End and save" or "Keep going".

**Race.** Large title race name, hero T minus with small caps days, "Start 7:05, wake 4:30" in textSecondary. Race day Profile card with pace ranges per leg in sport ink and the hilly course honesty line. Timeline with small caps T minus headers, rows with wrench.and.screwdriver, fork.knife, shippingbox, alarm, done as checkmark.circle.fill. Three checklist cards (Pack by discipline, Transition bag, Race morning) with counts; Fueling as plain cards. Race morning: timeline, checklist, clock, one fixed sentence and the watch push as the single primary button.

**Lab.** Title "Lab", subtitle "Developer diagnostics. Nothing here affects your plan." Stock `List` grouped by WorkoutKit, Scheduler, HealthKit matching, Codec; LabResultRows; arrow.clockwise Run all in the toolbar, Copy results secondary at the bottom. Mono, no Profiles, no sport color.

## 7 Motion

All animation passes through an `Animations` helper returning nil under `accessibilityReduceMotion`. Playhead: `TimelineView(.animation(minimumInterval: 1/20))` redraws the Canvas from the date, so it glides without an Animatable modifier; Reduce Motion steps with `.periodic(by: 1)`. Step change: block lifts `.easeOut(duration: 0.25)`, one `.sensoryFeedback(.impact(weight: .medium))`, voice cue. `.numericText(countsDown: true)` falls back to a plain swap. Pause fades to 0.55 in 0.2 s. Send to watch: `.contentTransition(.symbolEffect(.replace))` on the glyph, 0.2 s crossfade on the label. HealthKit match on screen: hollow blocks fill `.easeInOut(duration: 0.35)`, staggered 20 ms. Week drag: system lift, `.spring(response: 0.3, dampingFraction: 0.85)`, ReasonLine fades 0.2 s. ArcBar fills once per launch, 0.6 s easeOut; WeekStrip and ArcBar never animate otherwise. Haptics: medium on step change, light on checklist toggle, `.success` when a sync lands.

## 8 Accessibility

Judge fixes to D: player always black; past days never dimmed; skipped slash at full opacity; rest dot in textSecondary (6.49:1), not separator (1.30:1); sport symbol inside day cells; bordered "Start on phone"; dark textSecondary and both runFills moved apart (2.1:1, was 1.3 and 1.2); warm up fills gain a 3:1 edge; AX week strip layout; previous step replaces the 15 second skip.

VoiceOver: Profile is one element with a data built label ("Swim, 45 minutes, 6 by 400 at CSS pace, 30 seconds rest") and `accessibilityChartDescriptor` for Audio Graphs. DayCell: "Wednesday 12, bike, done". ArcBar: "Build phase, week 9 of 16, 52 days to race". Readout: "Target, 1:52 per 100 meters, estimated". ReasonLine is a button announcing "expands rule". The player posts an `AccessibilityNotification.Announcement` on each step change.

Dynamic Type: styles or `@ScaledMetric` everywhere, Canvas heights included. Hero numeral follows `.largeTitle`, capped 160, floored 72, one line at `minimumScaleFactor(0.5)`, tested with "59:59" on the 13 mini. WeekStrip becomes a vertical list of seven rows at `.accessibility1`; Readout grids drop to 2 then 1 columns; the player collapses Profile and Next into one line. Increase Contrast (`colorSchemeContrast == .increased`): textSecondary becomes textPrimary, separator becomes separatorHC at 1pt, remaining player blocks become full strength hollow strokes. Targets 44pt everywhere, Profile blocks via `contentShape`, player controls 64 and 72.

## 9 Do not

- No text on any Fill token or inside Profile blocks; the assertion and unit test enforce it.
- No bare text buttons; every tappable element has a container, chevron or symbol.
- No blue tint; accent is ink. No gradients, no materials on cards, no shadows in dark mode.
- No SF Pro Rounded, condensed width, mono outside Lab, or uppercase tracking labels.
- No rings, streaks, badges, confetti, celebration copy, checklist percentages, or dimming of undone sessions.
- No color only states; destructive never in session rows except the swipe action; never a red run target.
- No warning as a block, chip or fill; text plus exclamationmark.triangle only.
- No scroll driven or looping animation, no parallax, no haptics beyond section 7.
- No em or en dashes in copy; ranges say "to".

## 10 Plain language and onboarding (added after the first review)

Shorthand is never the headline. Session titles are plain with units ("Easy run, 40 min", "Swim: 8 fast hundreds", "Ride 60 min, then run 15 min"); the technical idea (Brick, Threshold, Sweet spot) sits in a JargonText line that opens a sheet. JargonText is the body text plus a 13 pt info.circle glyph in textSecondary, 44 pt tall, VoiceOver label "<term>. Explain". The glossary sheet uses the standard medium and large detents with a 28 pt corner and one short sentence over the longer explanation. Every number carries its unit.

Onboarding is eight full screens on the Contour background: a segmented progress bar, one large headline, one plain sentence on why we ask, selectable cards (surface, 14 pt radius, accent stroke when selected, never color alone), Back and a primary Next, Skip only where a default is fine. Tracker choice is a first class setting: without an Apple Watch the primary action on Today and Session detail is Start on phone, and the watch card is replaced by a card that says how the session will be followed.

## 11 Connections and readiness

Onboarding step 6 is Connect your devices: multi select cards (Apple Watch, WHOOP, Oura, Garmin, another watch or band, just my phone), each a surface card with a symbol, a plain line on what it gives ("Heart rate variability, resting heart rate and sleep through Apple Health"), and a selected state that is never color alone. Apple Health access is requested here with the reason. WHOOP and Oura rows carry a Beta label and appear only when their flag is on.

Today shows one readiness line under the session in subheadline textSecondary: "HRV on track. Resting heart rate normal. Sleep 7h 10m." or "Learning your baseline, night 9 of 14." Vendor data is credited in plain text ("Data by WHOOP"), no logos. When a rule changes the session, the reason line carries the change and the two facts, and a one tap Keep planned session is the only secondary action.

Methods gains a Connections screen with one row per source and these states: not connected ("Connect to adjust your plan from your sleep and HRV. Disconnect any time."), calibrating ("Learning your baseline, night 9 of 14. No plan changes yet."), connected ("Connected. Last synced 6:40 am."), stale ("No new data for 2 days. Plan changes are paused."), needs sign in ("Sign in again to keep adjusting your plan."), at capacity ("This connection cannot take more people right now."), and a disconnect that says "Removes the connection and deletes saved readings from this phone."
