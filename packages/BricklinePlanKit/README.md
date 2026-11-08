# BricklinePlanKit

BricklinePlanKit is the pure Swift engine behind Brickline, a free triathlon training app. It builds Sprint, Olympic and 70.3 plans from templates, adapts them with eight transparent rules that each write a reason line, computes Load, Fitness and Form, produces the race window timeline with pacing and fueling cards, and compiles sessions to a platform neutral workout representation that a WorkoutKit bridge converts on device. It depends on Foundation only, never reads the clock (every function takes dates and a calendar), never traps on input, and builds and tests on macOS with `swift build` and `swift test`. The product spec is `docs/specs/tri-spec.md`; the canonical parameters are in `docs/specs/tri-annex.md`.

## Module map

Each module has one owner. Only edit files inside the paths you own. Shared types and protocols live in `Core/` and are owned by the architect; change them only by agreement.

| Module | Owns (source) | Owns (tests) | Protocol | Concrete type | Annex |
|---|---|---|---|---|---|
| Core (shared types) | `Sources/BricklinePlanKit/Core/` | `Tests/BricklinePlanKitTests/CoreTests.swift` | none | none | all |
| Zones | `Sources/BricklinePlanKit/Zones/` | `Tests/BricklinePlanKitTests/ZonesTests.swift` | `ZoneCalculator` | `DefaultZoneCalculator` | A |
| Templates | `Sources/BricklinePlanKit/Templates/` | `Tests/BricklinePlanKitTests/TemplatesTests.swift` | `TemplateEngine` | `DefaultTemplateEngine` | B, J |
| Adaptation | `Sources/BricklinePlanKit/Adaptation/` | `Tests/BricklinePlanKitTests/AdaptationTests.swift` | `AdaptationEngine` | `DefaultAdaptationEngine` (thresholds in `AdaptationConstants`) | C |
| Load | `Sources/BricklinePlanKit/Load/` | `Tests/BricklinePlanKitTests/LoadTests.swift` | `LoadModel` | `DefaultLoadModel` | D |
| Race | `Sources/BricklinePlanKit/Race/` | `Tests/BricklinePlanKitTests/RaceTests.swift` | `RaceWindow` | `DefaultRaceWindow` | F, H |
| Compile | `Sources/BricklinePlanKit/Compile/` | `Tests/BricklinePlanKitTests/CompileTests.swift` | `SessionCompiler` | `DefaultSessionCompiler`, WorkoutKit bridge inside `#if canImport(WorkoutKit)` | E |

## Rules for every module

- Swift 5 language mode, Foundation only. WorkoutKit may be imported only inside `#if canImport(WorkoutKit)` with `@available(iOS 18, macOS 15, watchOS 11, *)`.
- Deterministic: no `Date()` in engine logic, seed any randomness explicitly, ids come from `SessionID.make`.
- No `fatalError`, `precondition` or force unwrap on inputs. Return values or throw `PlanKitError`.
- Metric names are Load, Fitness, Fatigue (internal) and Form. No other brand's metric names appear anywhere, including comments.
- No em or en dashes in code, comments or strings. Doc comments cite the annex section they implement.
- Tests use XCTest, stay fast, and never trap.

## Host contract notes (review fixes)

- Weeks are calendar weeks: `Plan.startDate` is the first day (by `calendar.firstWeekday`) of the week holding the requested start, and the days of week 0 before the requested start stay empty. Set `firstWeekday` on the calendar you pass in.
- A plan records its time zone (`Plan.timeZoneIdentifier`). Every engine entry point reads days in that zone, so travelling does not move sessions.
- Keep the plan with its logs in one `AdaptationState` and call `PlanKit.adapt(_:today:...)`. It appends the engine events to `history` for you.
- Zone nudges are stored with the benchmark date they were measured against. `Plan.effectiveZoneNudgeSteps(benchmarks:)` drops a nudge once a newer tested benchmark exists, and the engine clears it on its next pass.
- `PlanKit.compileAll` returns one result per session in date order, so one bad session does not block the week.
- `PlanKit.moveSession` is the drag to reschedule call. Append the returned `weekEdited` event to the athlete's log.
- `CompletedWorkout` carries optional work interval averages (`workIntervalAveragePower`, `workIntervalAveragePacePerKm`, `workIntervalAveragePacePer100m`). Annex C rule 3 compares those with the target of the hard steps, and skips a session that only has whole workout averages when it also holds easy parts.
- `Plan.warnings` lists what the generator changed from what the athlete asked for. Show it on the plan preview.
- The golden plan fixture is rewritten only with `UPDATE_GOLDEN=1 swift test`.
