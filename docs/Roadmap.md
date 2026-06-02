# Roadmap

## Known bugs

### `placeRivers` can silently abort
`COR/Tactical/MapGeneration.swift:51` — the `while true` BFS now bails out cleanly when `pressure[start] >= 1024`, but on abort it leaves the river half-carved (no rollback) and falls through to `placeCities` with whatever partial water tiles were laid. Detect the abort and either retry with a different `(start, end)` pair, fall back to a Bresenham line carve, or make the initializer failable so callers can retry the seed.

### Possible AI non-termination
`TacticalAI.runAI` plus the outer driver in `TacticalMode` will loop forever if no team can be eliminated and no player runs out of meaningful actions. Add a stalemate detector (e.g. N consecutive `.end` actions with no state change → declare draw).

## Determinism

- `TacticalAI.nextPurchase` calls `shopUnits(at:).enumerated().randomElement()` — uses Swift's default RNG, not `state.d20`. Pipe `D20` through every randomization site so AI play is reproducible from a seed.
- `TacticalStateFactory.make`'s default `seed: Int = .random(in: 0...1023)` defeats reproducibility unless callers pass a seed. Make it explicit at every call site.

## Architecture

### `BitwiseCopyable` constraints
- `clone(_:)` in `COR/Swift.swift` does an `unsafe` bitwise copy and is the only sanctioned duplication path. It silently breaks if a field becomes non-`BitwiseCopyable` (e.g. someone adds a `String` or class reference). Add a static-assert helper or a doc comment listing the constraint.
- `encode(_:) / decode(_:)` is bitwise; warn that adding a non-`BitwiseCopyable` field to any persisted state silently corrupts saves.

### `MapGeneration.swift` is a 430-line monolith
Split into:
- `MapGenTerrain.swift` — height/humidity → terrain
- `MapGenRivers.swift` — `placeRivers`
- `MapGenCities.swift` — `placeCities`, `placeAirfield`
- `MapGenRoads.swift` — `connectCities`, `connect` (Dijkstra), `shapeRoads`

### `fatalError` in `TacticalState.init`
`TacticalState.swift:87` aborts when a unit's allocated placement square is full. Spawn-placement is data-driven (`cities`, `allocatedUnits`); convert to a recoverable failure (skip placement / log) so editor-supplied scenarios can't crash the app.

## Tests

- **CI hang detection** — current test suite uses `runWithDeadline` (DispatchSemaphore + abandoned thread). Works, but leaks threads on hang. Once `placeRivers` is bounded, drop the deadline machinery and run plain synchronous tests.
- **Property tests** — every river tile has an orthogonal river/bridge neighbor (already covered for 3 seeds; widen). Every city is reachable by road from at least one other city (after `shapeRoads`). No `.none` after gen.
- **Snapshot a known-good map** — pin `seed=1, size=32` to a tile fingerprint and detect unintended noise/algorithm drift.
- **Tactical end-to-end smoke** — driver loop with all-AI players, capped at N reduce cycles, asserts no crash and turn advances. Currently `aiCanRunAndEndTurnWithoutCrash` covers turn advance only.
- **Replace `Tests` struct's all-or-nothing distribution check** — `randomDistribution` uses `bins[i] > expected` which fails on tail variance even for a uniform sample. Use a chi-squared test with a generous tolerance.

## Editor

- **Map validation on save** — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country). Surface as inline diagnostics, not a crash.
- **Undo stack** for tile edits.
- **Live preview** of which seeds reproduce a given hand-edited terrain layout (debug aid).

## Tooling

- **Scheme test plan** with parallel testing **disabled by default** — current `xcodebuild test` defaults to parallel and silently drops tests when one process hangs. Set per-test timeout to 60 s.
- **`swiftlint` / `swift-format`** — sources mix tab indentation conventions in a few places; lock one in.
- **CI workflow** — `xcodebuild -scheme PG test -parallel-testing-enabled NO` on every PR.

## Documentation

- **`Architecture.md`** stops at module-level. Add a sequence diagram for `Input → State.apply → Action → State.reduce → [Event] → process` so contributors understand the loop.
