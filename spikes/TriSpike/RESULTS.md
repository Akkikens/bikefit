# Week 1 spike results

TriSpike, 2026-11-06. Gate for tri-spec section 11. Xcode 27.2, iOS 26.5 simulator ("TriSpike iPhone 17 Pro", shut down after each run), iOS 18 deployment target. Raw log: simulator-results.json.

## Verdict so far

Simulator half: pass. Every production session shape builds, encodes and decodes losslessly, the capability matrix answers six questions the docs leave open, and the phone player's timing loop, cues and Live Activity work. The go or no go decision still waits on the device half below, because only a real iPhone with a paired Apple Watch shows whether scheduled workouts land, run and report back.

## Answered in the simulator

| Question | Answer | Effect on the spec |
|---|---|---|
| Scheduler maximum count | `maxAllowedScheduledWorkoutCount` = 50 | Was "undocumented, read at runtime". 50 covers about seven weeks of daily sessions, so a one week Sunday Sync is far inside it |
| Pool swim sets | `poolSwimDistanceWithTime` supported for swimming in CustomWorkout, any location; not in SingleGoalWorkout | Confirms the flagship. The older watch tier must use a plain distance goal |
| Swim alerts | Only heart rate range and zone alerts. No speed, pace, power or cadence | CSS pace can never be a swim alert. It rides on the rep's distance with time goal ("100 on 2:00") |
| Energy goals | Not supported in CustomWorkout for any sport; supported in SingleGoalWorkout | Annex E listed energy as a step goal. Steps use time or distance only |
| Run pace | Speed range and speed threshold alerts supported indoor and outdoor | Confirms pace as speed ranges. Run power alerts work outdoor only; power zone alerts never for running |
| Bike alerts | Power range (current and average), power zone, heart rate range and zone, cadence, speed: all supported | Confirms the bike path |
| Multisport orderings | Swim bike run (open water and pool), duathlon run bike run, and aquathlon swim run all supported; a single leg is not | Duathlon and aquathlon race days are free. Runna says "no duathlon plans yet" |
| Composition | All 8 production shapes (threshold run, sweet spot bike, HR bike, pool sets, goal only swim, race day, two part brick) round trip with step names intact, 69 to 272 bytes each | Plans can be stored and shared as WorkoutKit data |
| Phone player, foreground | Three cues each 0.4 s after their wall clock boundary; Live Activity starts; the session ends itself | The timing loop works. The background behavior still needs a device |

## Findings from the SDK itself (Xcode 27.2 WorkoutKit interface)

- **`HKWorkout.workoutPlan` (get async throws)** returns the WorkoutPlan a completed workout came from. Completion matching can use the plan's UUID, exact, instead of matching by type, time and duration. Spec section 4.2 assumed only the heuristic.
- **Zone alerts use the watch's own zones.** `HeartRateZoneAlert(zone:)` and `PowerZoneAlert(zone:)` take a zone number, not bounds, so they follow whatever zones the watch holds, not the app's LTHR or FTP zones. The app should send `HeartRateRangeAlert` and `PowerRangeAlert` with explicit bpm and watts.
- `WorkoutPlan.dataRepresentation` throws, `authorizationState` and `scheduledWorkouts` are async. Minor, but the compiler caught both.
- Average power alerts (`metric: .average`) need iOS 17.4, inside the iOS 18 minimum.

## Still needs the device (iPhone with paired Apple Watch)

Steps, in the app, on a real iPhone:

1. **Scheduler.** Tap "1. Scheduler", allow access. It schedules a week, probes 8, 14 and 30 days out, measures the real count limit, then leaves a test week on the watch.
2. **On the watch.** Open Workout, find TriSpike's section. For each session check the steps, the step names and the alert targets. Check the pool swim shows 8 x "100 on 2:00" and the race day shows three legs.
3. **Run two for real.** One pool swim (the 8 x 100) and one threshold run. Note whether the pool length prompt converts, whether pace alerts fire, and whether reps advance only when distance and time are both met.
4. **Health read back.** Tap "5. Health read back". The two real workouts should show "plan id ...": that confirms exact completion matching.
5. **Phone player, locked.** Tap "Spec test: 30 min", lock the phone, put it away. Every step change should speak or ding. Check the lock screen countdown at least twice. Unlock at the end.
6. **Share the results file** from the app and drop it into this folder as device-results.json.

What to watch for in the player log: "in process cue N" entries with large "late by" values or app "background" mean iOS suspended the app and the notification carried the cue, which is the designed fallback. Missing dings would fail the gate. Also check whether the Live Activity countdown froze at a step end while the phone stayed locked: if so, the spec should switch it to a whole session countdown.

## Device run 1, 2026-11-06, iPhone 18 Pro Max (iOS 26)

Raw log: device-results.json (161 entries). Capability matrix and composition matched the simulator exactly.

- **Scheduler authorization returned notDetermined** without a decision. No Apple Watch appears among the phone's devices, and none of the 20 most recent Health workouts came from an Apple Watch (all from third party apps). `WorkoutScheduler.isSupported` is true regardless, so it is a static capability flag, not a paired watch check. The scheduler, watch, pool swim and threshold run checks cannot run until a paired Apple Watch is available.
- **`HKWorkout.workoutPlan` throws `WorkoutKit.ImportError` code 3** for every workout not started from a WorkoutKit plan (all 20 here). The completion matcher must treat that error as "no plan, use the heuristic", never as a failure. Annex E updated.
- **Health read works on device:** authorization completed and 20 workouts read, including third party sources, which is the path Garmin and other non Apple Watch athletes take.

## Device run 2, 2026-11-08: no Apple Watch is paired to this iPhone

A WatchConnectivity probe (WatchProbe.swift) reads the pairing state from the phone itself: `WCSession.isPaired` is false and `isWatchAppInstalled` is false, with the session activated normally. That settles why `WorkoutScheduler.requestAuthorization()` returns notDetermined with no prompt: there is no watch to schedule to. The scheduler, pool swim, threshold run and exact plan matching checks remain open until an Apple Watch is paired to the phone running the spike. The phone player, Health read and codec checks are unaffected.

## Go or no go rule (unchanged from the spec)

Stop if scheduling is unreliable (sessions missing or duplicated on the watch in normal use) or pool swim sets cannot be expressed. Either would drop the watch wedge from all positioning before any product code is written.
