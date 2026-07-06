# LSTM AI: Implementation Plan

Roadmap item ([Roadmap](./Roadmap.md) § AI): *"Train an LSTM model to play against."* The goal
is a neural opponent for Tactical battles, trained against the existing heuristic AI —
`func axis(ai:) -> TacticalAction` on `TacticalSim` (`COR/Tactical/AI/AxisAI.swift`; the
dispatch in `COR/Tactical/AI/TacticalAI.swift` routes `.axis`/`.allies` AI seats to it,
`.soviet` to the weaker `soviet(ai:)`).

## Decisions

1. **Imitation → RL fine-tune**: behavior-clone `axis(ai:)` from headless rollouts first,
   then policy-gradient fine-tune playing full battles vs the frozen heuristic.
2. **MPSGraph** (`MetalPerformanceShadersGraph`, OS built-in) for training — no Python,
   no third-party packages.
3. **Pure-Swift inference in COR** — weights exported to a flat binary bundled as an app
   resource; COR gets a dependency-free forward pass behind the same AI-hook shape as
   `TacticalState.ai`.

**Why this is tractable here:** the core is already a deterministic headless RL
environment. `(state, action) → state'` purity is test-proven
(`Tests/MultiplayerTests.swift`), a full AI-vs-AI battle loop exists verbatim
(`Tests/TacticalPerformanceTests.swift`), the whole `TacticalState` bitwise-serializes to
fixed-size `Data` (`encode`/`decode`, `COR/Foundation/Swift.swift`), and the AI interface
is "one `TacticalAction` per call" — exactly a policy's step function.

## Ground truth

- **Action space** (`COR/Tactical/TacticalReaction.swift`): `.move(UID, XY)`,
  `.embark(UID, UID)`, `.disembark(UID, XY)`, `.attack(UID, UID)`, `.resupply(UID)`,
  `.purchase(Int, XY)`, `.end` — plus `.takeover` (multiplayer bookkeeping, excluded from
  the policy). `UID` = Int8 slot into `Speicher<128, Unit>`; grid `Map<32, Terrain>`
  (actual size 24/32 set at init).
- **Legality queries** (masks mirror reducer guards; reducers silently no-op on illegal
  input): `moves(for:) -> Moves` (`TacticalMove.swift`, `Moves.ordered` is deterministic),
  `unitCanHit(_:_:)` + `canAttack`/`ammo` (`TacticalAttack.swift`), `shopUnits(at:)` +
  prestige/occupancy guards (`TacticalShop.swift`), `canEmbark`/`canDisembark`
  (`TacticalTransport.swift`), `resupply` guards (`UnitResupply.swift`), fog via
  `isVisible(_:)` / `vision[playerIndex]` (`TacticalState.swift`).
- **End signals**: `aliveTeams.nonzeroBitCount <= 1`, `day`, `winner: Team?`
  (`TacticalTurns.swift`).
- **Project**: `PG.xcodeproj` is objectVersion 77 (synchronized folder groups); targets
  COR (framework), PG (app), Tests. No CLI target exists — the trainer is net-new.

## Design

### New `Train` macOS command-line target

- `productType com.apple.product-type.tool`, with the **COR folder** in its
  `fileSystemSynchronizedGroups` — COR sources compile directly into the tool (a macOS CLI
  can't link the Catalyst framework; COR is UI-free). No `import COR`; internal symbols
  (`unitCanHit`, `run`, …) are visible without `@testable`.
- Settings: `SDKROOT = macosx`, inherit `SWIFT_VERSION 6.0` + `SWIFT_STRICT_MEMORY_SAFETY`;
  **`-O` even in Debug** (rollouts run millions of `reduce` calls; `-Onone` InlineArray
  code is 10–30× slower). `import MetalPerformanceShadersGraph`;
  `MTLCreateSystemDefaultDevice()` works in a CLI.
- Gate the two `print()`s in `TacticalStateFactory.swift` behind a static flag (off in Train).

### Observation encoding — `COR/Tactical/AI/Encoding.swift`

One implementation shared by trainer and inference. From the acting player's
(`playerIndex`) perspective, immediately before each of its actions. Fixed 32×32 NHWC
Float tensor, row-major `x + y*32` (matches `Map.Indices`):

- **~51 spatial planes**: on-map; terrain one-hot (~11 mechanic groups of the 21 kinds) +
  `baseEntrenchment`/`income` scalars; control own/ally-team/enemy-team; own-unit and
  **visible**-enemy-unit presence; unit scalars (hp/15, ammo/max, ent/24, mp, ap, lvl/8);
  `UnitType` one-hot (14); transport/cargo flags; normalized model stats (soft/hard/airAtk,
  ground/airDef, mov, rng, ini — generalizes across the 256-row `UnitStats.table`);
  `vision[playerIndex]` plane.
- **~12 global scalars**: own prestige, day, playerIndex, tier, baseLevel,
  unit/settlement counts, objective + deadline, map size. No enemy prestige (fogged).
- **Fog rule (load-bearing)**: enemy units are drawn iff `isVisible(uid)`; own embarked
  cargo appears only as the transport's cargo flag. The policy sees exactly what a human sees.

### Action space & masks — `COR/Tactical/AI/ActionSpace.swift`

Factored heads, **tile-indexed** (not UID-indexed — UIDs are arbitrary slot numbers a
conv net can't see; `unitsMap`/`position` give the tile↔UID bijection):

- **type** (7: move/embark/disembark/attack/resupply/purchase/end), **actor-tile** (1024),
  **target-tile** (1024), **shop-slot** (36 = 20 core + 16 aux).
- Bidirectional `TacticalAction` ↔ head-indices mapping; hierarchical 0/1 masks computed
  from the legality queries above so a sampled action can never no-op. Masking =
  `logits + (mask − 1)·1e9` before softmax.

### Network (~1.5 M params) — `Train/Model.swift`

Conv 3×3 stack (51→64→64→64) → global-mean-pool ⊕ globals → FC 256 → **hand-composed
LSTM cell** (256 hidden; matmuls + sigmoid/tanh, gate order i,f,g,o, forget bias +1 — a
manual cell fixes the weight contract so pure-Swift parity is exact, vs reverse-engineering
MPSGraph's built-in LSTM op layout) → heads: type FC; actor via per-tile 1×1 convs over
trunk ⊕ broadcast hidden; target conditioned on the actor tile's trunk feature
(teacher-forced during training); shop FC; value head (Phase B).

Loss = sum of masked cross-entropies, each weighted by per-sample applicability (target
head only for types with a target, shop only for purchase, …).

### Data pipeline — `Train/Replay.swift`, `Train/Rollouts.swift`

- **Replays, not states**: per battle store `(version, size, players, seed, action stream,
  winner)` — `PGRP` format, raw `encode(action)` bytes, ~10–100 KB each. States are
  regenerated on the fly by deterministic replay through `reduce` (exactly what
  `MultiplayerTests` proves safe). Versioned header guards toolchain drift; regeneration
  is cheap.
- **Rollout generator** (`Train rollout --n 2000`): the perf-test loop generalized — both
  seats on `axis(ai:)` (pick axis/allies-team countries, e.g. `.ger` vs `.usa`, avoiding
  `.soviet` dispatch), varying seed, size {24, 32}, prestige {.poor, .rich}, baseLevel
  {0, 5}; budget `aliveTeams ≤ 1 || day > 128 || 65k actions`.
- **Batching**: each battle yields two streams (one per seat — different fog). Truncated
  BPTT, B≈32 streams × T≈32 steps, hidden state carried across windows (detached), fresh
  battles spliced in as streams end.

### BC training — `Train/BCTrainer.swift`

Weights as `graph.variable`; T-step unrolled forward; `graph.gradients(of:with:)`
autodiff; Adam (built-in op family or composed manually) + `assign` ops; lr 3e-4 cosine,
grad-clip 1.0. CSV/stdout loss + per-head accuracy. Checkpoints in **`PGW1`** flat weight
format (magic, version, named float32 tensor records) — the contract with the COR loader.

### Evaluation — `Train/Eval.swift`

Arena: one seat driven by the **pure-Swift `LSTMPolicy`** (exercises the shipping code
path), the other by `axis(ai:)`; N seeded battles, sides swapped; reports win %, avg days,
illegal-action rate (must be 0 by construction). Doubles as the Phase-B episode runner
(sampling instead of argmax).

### RL fine-tune (Phase B) — `Train/RLTrainer.swift`

REINFORCE with baseline vs frozen `axis(ai:)`: 32–64 parallel episodes (batched MPSGraph
inference, own SplitMix64 for sampling — never `sim.d20`), episodes stored as replays and
recomputed in-graph for the update. Terminal reward win +1 / loss −1 / timeout −0.2
(+small unit-value-margin bonus); EMA baseline → value-head upgrade if variance stalls;
entropy bonus, annealed; low lr (1e-5–3e-5); window subsampling for long episodes;
optional KL anchor to the BC policy. Reuses the BC graph with advantage-weighted CE
(≡ policy gradient).

### COR inference — `COR/Tactical/AI/LSTMPolicy.swift`

- `LSTMWeights` (loads/validates `PGW1` `Data`; plain `[Float]` — heap is fine for AI
  scratch, the no-heap rule is for game state) + `LSTMPolicy` (weights + h/c + per-turn
  action counter; **masked argmax**, deterministic, no RNG touched — multiplayer/replay
  determinism preserved; forces `.end` past 256 actions/turn). Convs/matmuls via
  Accelerate or plain loops — one inference per action in a turn-based game, perf is a
  non-issue.
- **Wiring — no `Player`/save-format change.** Mirror the existing hook shape next to
  `TacticalState.ai`:
  `static func ai(lstm: LSTMWeights?) -> (borrowing TacticalState) -> TacticalAction?` —
  AI seats route to `LSTMPolicy` when weights are present, else `run(&heuristic)`. Seat
  selection already lives at this closure layer (`PG/Tactical/TacticalMode.swift` composes
  `net.nextAction(state, ai)` the same way). App side: `aiKind` toggle in
  `PG/Scene/Settings.swift`, load `policy.pgw` from the bundle in `TacticalMode`, fall
  back to heuristic when missing.

## Milestones (each independently verifiable)

1. ✅ **M1 — Train target + rollouts**: target setup; `Train/main.swift`, `Rollouts.swift`,
   `Replay.swift`; gate factory prints. ✓ `Train rollout --n 8` byte-identical on re-run;
   replay reproduces recorded winner/days.
2. ✅ **M2 — Encoding + action space (COR)**: `Encoding.swift`, `ActionSpace.swift`. ✓ fog
   unit tests; every recorded axisAI action legal under our masks.
3. ✅ **M3 — Weights + pure-Swift forward**: `LSTMWeights.swift` (`PGW1` IO + `spec`
   catalog + seeded `random(seed:)`), `LSTMPolicy.swift` (im2col/`vDSP_mmul` forward,
   hierarchical masked argmax; both conditioned heads take `[h ⊕ trunk[actor]]`, the
   `target.cond` fc is ReLU'd). ✓ weight IO round-trip bit-exact + malformed-file
   rejection; random-weight policy plays vs axisAI with 0 illegal actions.
4. ✅ **M4 — MPSGraph model + parity**: `Train/Model.swift`, `Train/Parity.swift`
   (`Train parity`; 1×1 head convs as matmuls over the flattened trunk, conditioning
   actor tile as an `Int32` placeholder). ✓ measured max |Δlogit| ≈ 2.6e-7 over 1000
   steps / 24 battles, 0 masked-argmax flips.
5. ✅ **M5 — BC training**: `Train/BCTrainer.swift` + `Train/Streams.swift` (BPTT batcher);
   `Train/Net.swift` shared graph builder (LSTM gates as slices, broadcasts as
   implicit-broadcast additions — `split`/`broadcast` have no MPSGraph gradients).
   ✓ 600 steps × (16 streams × 16 BPTT) on a 160-battle corpus in 176 s: train loss
   7.5 → 5.25, held-out loss 6.28 → 5.81, held-out accuracy kind 0.66 / actor 0.29
   (1024-way) / target 0.39 / slot 0.67. Checkpoint: `tmp/runs/bc/policy.pgw`.
   (Also fixed a pre-existing UInt16 prestige-overflow crash in `AxisAI.purchase`.)
6. ✅ **M6 — Eval harness**: `Train/Eval.swift` (`Train eval`; each config played from
   both sides, mutation oracle, hard gate on 0 illegal actions). ✓ BC checkpoint over
   64 battles: 7.8% wins (5W 51L 8D), avg 52 days, 0 illegal in 78,669 policy actions;
   random-weight baseline 0% (mostly timeouts).
7. **M7 — RL fine-tune**: `Train/RLTrainer.swift`. ✓ win rate improves over the BC
   checkpoint.
8. **M8 — App integration**: `policy.pgw` resource + Settings toggle +
   `TacticalState.ai(lstm:)`. ✓ play against it in the app.

## File map

**New**: `COR/Tactical/AI/{Encoding,ActionSpace,LSTMWeights,LSTMPolicy}.swift` (weight IO
lives in COR — shared with `Train`, no separate `Weights.swift`);
`Train/{main,Rollouts,Replay,Model,BCTrainer,RLTrainer,Eval,Parity}.swift`;
`Tests/PolicyTests.swift`; `PG/policy.pgw` (M8).

**Touched**: `PG.xcodeproj/project.pbxproj` (Train target + COR membership),
`COR/Tactical/TacticalStateFactory.swift` (gate prints), and at M8 only:
`PG/Tactical/TacticalMode.swift`, `PG/Scene/Settings.swift`. `TacticalAI.swift` untouched.
Update [Roadmap](./Roadmap.md) / [Architecture](./Architecture.md) when landing.

## Verification

- Swift-testing tests in `Tests/PolicyTests.swift`: replay determinism
  (`encode(a) == encode(b)` after rebuild+replay), masking correctness (random-weight
  policy: every non-`.end` action changes `encode(state)` — valid oracle since reducers
  no-op on illegal input), fog/encoding spot checks, weight round-trip, golden parity
  fixture.
- Manual: `Train rollout` → `Train train-bc` → `Train eval --n 100` (win %, 0 illegal) →
  `Train train-rl` → eval again → play in-app vs the model.
- Existing suites (`xcodebuild test -scheme PG -destination 'platform=macOS'`) must stay
  green — COR changes are additive.

## Risks

- MPSGraph optimizer/assign ergonomics → fall back to manually composed Adam ops.
- REINFORCE variance on thousand-step episodes → terminal-return simplification, EMA
  baseline → value head, window subsampling, BC anchor.
- Raw-bytes replays are same-build-only → versioned header + cheap regeneration.
- BC ceiling ≈ axisAI strength → that's what Phase B is for.
