# Train Optimization Plan

Goal: cut PPO iteration wall time (ppo11 config: 32 episodes ≈ 2.2 min/iter,
~80 min per 36-iter run). Profiled the live run (`sample` of pid 72155,
windows phase): main thread splits 54% `graph.step` (48% pure GPU wait) /
46% `Batcher.window()` building the next window on the CPU. The window build
is dominated by `TacticalSim.actionMasks()` → `moves(for:)` — a **full
pathfinding flood fill per alive own unit per sample** (via `hasMoveTarget`),
and the fill itself drowns in `Map.subscript._read` coroutine frame heap
allocations (`swift_coroFrameAlloc` → malloc/free per tile read) plus
per-read memmoves. The same masks path runs per inference step in collection
(`LSTMPolicy.traced` → `actionMasks()`) and in eval.

## Changes

1. **`Map.subscript` `_read` → `get`** (`COR/Foundation/Map.swift`).
   All Elements in use are small copyable values (Terrain, Country, UID,
   UInt8). A plain `get` kills the coroutine frame malloc + memmove per
   read across the whole sim (fill, encoding, heuristic, reducers).
   `_modify` stays. Same treatment for `CArray.subscript` only if the
   re-profile still shows it (Element can be ~Copyable there, needs a
   constrained overload).

2. **Early-exit `hasMoveTarget`** (`COR/Tactical/TacticalMove.swift` +
   `ActionSpace.swift`). New `hasMoves(for:)` runs the same fill but
   returns `true` at the first reached tile that is stoppable — i.e. not
   `start` and not occupied by a visible alive unit (the fill already never
   assigns tiles under visible same-domain enemies; the trailing pass in
   `moves(for:)` zeroes tiles under *any* visible alive unit — the per-tile
   equivalent is `uidAt(xy) != nil && visible[xy]`). Common case: one
   adjacent free tile ⇒ ~4 tile checks instead of full fill + 1024-tile
   `hasMoves` scan. Equivalence with `moves(for:).hasMoves` proven by a new
   COR test over replayed battle states.

3. **Overlap window building with the GPU** (`Train/Streams.swift`,
   `Train/PPOTrainer.swift`). Split `Batcher.window()` into content build
   (expensive, advances streams) and h0/c0 finalize (cheap, reads lane
   carry). PPO builds window k+1 on a background queue while the GPU runs
   window k, for both the read pass and the epoch loops. Lane bookkeeping
   moves to explicit `restarted`/`ended` flags per built window so the
   carry rule no longer depends on build order; dead/restarted lanes feed
   h0 = 0 exactly as today. BC/RL keep the old `window()`/`carry()` API
   (reimplemented on top of the split), only PPO opts into the overlap.

## Invariants

- Masks are behavior-identical (mutation oracle, eval hard-gates illegal
  actions); `Train eval` before/after must produce identical tallies.
- Windows stay byte-identical across read pass and epochs (the existing
  asserts stay live); collection determinism untouched.
- No contract files touched (`Plane`/`Global`, ActionSpace indices, PGW1,
  replay format). `Net.swift`/graph code untouched.
- tmp/build is the **live ppo11 run's binary** — all builds go to a scratch
  SYMROOT until that run exits.

## Verification

- COR tests (`swift test`, includes new equivalence test).
- `Train parity` (contract insurance), `Train eval --weights PG/policy.pgw
  --n 8` identical pre/post.
- PPO smoke (2 iters × 8 episodes, vwarm 1, fixed seed): kl exactly 0
  during warmup, window asserts clean, phase timings before/after.

## Results (2026-07-17, all timings contended with the live ppo11 run)

- `Train eval --n 8`: **byte-identical output** (same battles, tallies,
  action counts, 0 illegal), 6.8 s → 4.9 s wall, 41.6 s → 31.2 s CPU —
  and eval is the *least* mask-bound path.
- Full COR suite: 121 tests pass, including the new
  `hasMovesMatchesFullFill` equivalence test. `Train parity`: PASS,
  max |Δ| ~1e-7, 0 argmax flips.
- PPO smoke (3×8 episodes, vwarm 1, same seed on both binaries):
  identical per-iteration stats, identical final arena, `kl` exactly
  0.000 during warmup, window asserts clean. Read pass 5.0 s → 2.2 s
  (~2.3×); windows phase 38–40 s → 28–30 s (~1.35× under GPU
  contention).
- Re-profile of the optimized windows phase: main thread is ~96%
  `graph.step` (GPU); window building runs on the `batcher.prefetch`
  queue off the critical path and is ~10× cheaper than before
  (`swift_coroFrameAlloc` no longer appears at all). The trainer is now
  GPU-bound — further speedups would have to come from the graph itself
  (batch size, fewer targets, async double-buffered steps), not the CPU.

Follow-up candidates, deliberately not done: BC still uses the serial
`window()` path (its loop is step-bounded, not drain-until-exhausted —
needs a bounded variant of `drain`); `CArray.subscript` keeps its `_read`
coroutine (never showed in the profile after the `Map` fix).
