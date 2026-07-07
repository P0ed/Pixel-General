# Legality predicates, settlement index, allocation-free hot paths — Plan

Implements candidates A, C, D from the 2026-07-07 architecture review.
Constraint for every change: **behaviorally identical action streams** for legal
play — same `D20` consumption, same iteration order (row-major), same
first-among-equals tie-breaking (`min(by:)`/`max(by:)` both keep the first) —
so `MultiplayerTests` and `PolicyTests` verify equivalence for free.

## A — One home for action legality

Sim-level predicates, colocated with their reducers (the `canEmbark` /
`canDisembark` pattern from `TacticalTransport.swift`):

- `canMove(unit:)` — `TacticalMove.swift`; guard of `move`, actor mask.
- `canAttack(src:dst:)` — `TacticalAttack.swift`; guard of `attack`
  (non-surprise path), attack masks, `AxisAI.bestAttack`, `SovietAI` targets.
  Includes `isVisible(dst)`: input, masks, and both AIs already require it;
  the reducer tightens (a fairness fix for relayed intents). The surprise
  attack out of `move` keeps its own relaxed guard — its target is hidden by
  definition. Side effect: fixes a live SovietAI hang (ground unit with
  `ap>0, ammo==0` proposes a forever-no-op attack — `targets` never checked
  ammo).
- `canResupply(unit:)` — `UnitResupply.swift`; player-initiated guard of
  `resupply` (end-of-turn keeps its relaxed inline guard), resupply mask,
  `AxisAI.needsResupply`, `SovietAI.nextReinforce`.
- `canBuy(slot:at:)` + `canBuy(at:)` — `TacticalShop.swift`; guard of `buy`,
  purchase actor mask. Also guards negative slot indices (previously a crash).
- Document the load-bearing contract on `TacticalSim.reduce`: illegal input
  leaves the sim bitwise-unchanged (masks-as-oracle, host intent
  re-validation, AI probing all rely on it).

## C — Settlement index + `hasBuildings` fix

- `hasBuildings(near:)` scans `p.c5` (5 tiles) instead of all 1024
  (`manhattanDistance <= 1` ≡ c5 membership; pattern proven in
  `AxisAI.hasAirfield`).
- New `TacticalSim.settlements: SetXY` — built once at battle creation
  (`indexSettlements()`; the map never changes during a battle, only
  `control` does). The chess constructor calls it explicitly.
- New `SetXY` iteration API (`forEach` / `contains` / `firstMap` /
  `reduce(into:)`) — word-skipping, row-major, i.e. exactly `map.indices`
  order, so all swaps preserve iteration-order determinism.
- Adopters: `income`, `assignControl` (also loses its `[XY]`/`[Country]` heap
  arrays), `countryHasSettlements`, `vision(for:)`, `supplySources`
  (buildings half), `actionMasks` purchase loop, `AxisAI.preplan`/`purchase`,
  `SovietAI.target`/`nextPurchase`/`nextRetreat`.

## D — Allocation-free hot paths

- `Duel.resolve`: two heap arrays → one `[5 of Int]` inline buffer
  (`rounds ≤ 5` since `maxHP = 15`); the load-bearing two-phase roll order is
  untouched.
- `Moves.route(to:)` returns `CArray<16, XY>` (was `[XY]` + per-step
  `compactMap`); `Moves.ordered` is deleted — its three callers
  (`AxisAI.pick`, `SovietAI.move`, `retreat`) iterate `moves.indices`
  directly in the same row-major order; the hash-seed determinism rationale
  moves to the `Moves` doc comment.
- `AxisAI.attackOrder`/`bestMove` sorts → priority-bucket passes over the
  roster (roster is UID-ascending, so bucket order ≡ the old
  `(priority, rawValue)` sort).
- `AxisAI.purchase`: `filter().sorted(by: frontDistance)` over the map →
  settlement-set scan into fixed arrays + selection loop; `frontDistance`
  computed once per spot instead of per comparison.
- `SovietAI`: `compactMap`/`sorted`/`[(UID, Unit)]` scans → manual
  min/max tracking with first-among-equals semantics.
- `shopUnits` keeps returning `[Unit]` (public UI API; `Shop.units` allocates
  internally anyway) — its settlement/control guard is hoisted above the
  unit-slot scan. Residual, deliberately out of scope.

## Docs

- Fix `GameMechanics.md` cost formula drift (`/(aux ? 11 : 7)`, `lvl + 7`).
- `Architecture.md`: note the `settlements` index; `LSTM-AI.md`: masks now
  share the `can*` predicates with the reducers.

## Verification

Build Train (compiles COR directly), run the full test suite. Green =
equivalence: `MultiplayerTests` (determinism), `PolicyTests` (mask oracle),
`RNGTests.damageCalculation` (Duel), `TacticalTests`, plus
`TacticalPerformanceTests` before/after numbers.

### Post-merge note: compilation mode

The first `TacticalPerformanceTests` after-numbers showed a ~8% *regression*
(0.655s → 0.705s avg). Cause: the PG scheme tests the Debug configuration,
where COR forced `-O` but not `SWIFT_COMPILATION_MODE`, so COR compiled
per-file — and this change moved the hot inner-loop checks into shared
cross-file predicates (`canAttack`, `SetXY.forEach`, …) that per-file
compilation cannot inline. Under whole-module optimization the same commit is
~10% *faster* (0.343s → 0.309s avg), and WMO itself is worth a flat 2× here
(0.637s → 0.343s at the pre-change commit). Fixed by setting
`SWIFT_COMPILATION_MODE = wholemodule` on COR's Debug config, same rationale
as its Debug `-O` override. Perf numbers measured before that setting are not
comparable to numbers measured after.
