# Roadmap

## Known bugs

### Map generation hangs for some seeds
`Tactical/State/MapGeneration.swift:51` — `placeRivers`'s `while true` BFS can fail to reach `end` when previously placed rivers (via `hasNoRivers(at:)` on diagonal neighbors) wall off every path. Confirmed for seeds **42** and **77** at size 32. Also: `pressure[xy] += 1` on a `Map<UInt16>` will trap if the loop drags on past 65 535 iterations.

Fix options:
- Add a hard iteration cap; on overflow, retry with a different `(start, end)` pair or fall back to a Bresenham line carve.
- Relax the `hasNoRivers(at:)` constraint once pressure exceeds a threshold.
- Make the init failable: `Map<32, Terrain>(size:seed:) -> Map<32, Terrain>?` so callers can retry the seed.

### `placeCities` divides by zero for size < 16
`Tactical/State/MapGeneration.swift:96` — `dw = (size - 8) / (div - 1) - 1` with `div = size / 8`. For `size < 16`, `div - 1 == 0`. Either guard with `precondition(size >= 16)` in `Map<32, Terrain>.init` or rewrite the layout math to handle small maps.

### `connect()` has the same unbounded loop pattern
`MapGeneration.swift:241` — same `while true` with no termination guarantee. Bound and return `false` on cap.

### Possible AI non-termination
`TacticalAI.runAI` plus the outer driver in `TacticalMode` will loop forever if no team can be eliminated and no player runs out of meaningful actions. Add a stalemate detector (e.g. N consecutive `.end` actions with no state change → declare draw).

## Determinism

- `TacticalAI.nextPurchase` calls `shopUnits(at:).enumerated().randomElement()` — uses Swift's default RNG, not `state.d20`. Pipe `D20` through every randomization site so AI play is reproducible from a seed.
- `TacticalStateFactory.make`'s default `seed: Int = .random(in: 0...1023)` defeats reproducibility unless callers pass a seed. Make it explicit at every call site.

## Architecture

### `BitwiseCopyable` constraints
- `clone(_:)` in `Engine/Extensions/Swift.swift` does an `unsafe` bitwise copy and is the only sanctioned duplication path. It silently breaks if a field becomes non-`BitwiseCopyable` (e.g. someone adds a `String` or class reference). Add a static-assert helper or a doc comment listing the constraint.
- `encode(_:) / decode(_:)` is bitwise; warn that adding a non-`BitwiseCopyable` field to any persisted state silently corrupts saves.

### `MapGeneration.swift` is a 367-line monolith
Split into:
- `MapGenTerrain.swift` — height/humidity → terrain
- `MapGenRivers.swift` — `placeRivers`, `shapeRivers`
- `MapGenCities.swift` — `placeCities`
- `MapGenRoads.swift` — `connectCities`, `connect`, `shapeRoads`

### `UID = Int8` with `-1` sentinel
Spread across the codebase as `< 0` checks, `id.index`, `i.uid`, `unitsMap[xy] < 0`, `cargo[idx] == -1`. Wrap as a struct:
```swift
struct UID: Hashable { var raw: Int8 }
extension UID { static let none = UID(raw: -1); var isValid: Bool { raw >= 0 } }
```
Replace sentinel reads with `Optional<UID>` returns where call sites already pattern-match.

### `fatalError` in `TacticalState.init`
`TacticalState.swift:49` aborts when two units land on the same starting tile. Spawn-placement is data-driven (`capitals`, `allocatedUnits`); convert to a recoverable failure (skip placement / log) so editor-supplied scenarios can't crash the app.

### `Map.indices` allocates an `AnySequence`
`Engine/Foundation/Map.swift:15` returns a type-erased iterator on every access. Hot loops in `placeRivers`/`shapeRoads` iterate it repeatedly. Provide a custom `IndexingIterator`-style struct or a `for x, y` two-loop accessor.

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
