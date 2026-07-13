# LSTM AI

The neural opponent for Tactical battles: a convolutional LSTM policy
that plays any `.ai` seat, bundled as `PG/policy.pgw` and toggled with
*Neural opponent* in the Tactical menu (heuristic fallback when the resource is missing
or invalid). It was trained by behavior-cloning the heuristic `run(ai:)` and then
REINFORCE fine-tuning against it — entirely with `MetalPerformanceShadersGraph` (OS
built-in, no Python, no packages). Inference is dependency-free Swift in COR, so the
shipping app never touches MPSGraph.

Training rests on properties of the core: `reduce` is a pure function of
`(sim, action)` (test-proven, `COR/Tests/MultiplayerTests.swift`), a whole battle
bitwise-serializes via `encode`/`decode`, and the AI interface is one `TacticalAction`
per call — exactly a policy's step function. Battles are therefore stored as *replays*
and regenerated deterministically instead of storing states.

## File map

| Where | What |
|---|---|
| `COR/Tactical/AI/Encoding.swift` | `SimObservation` tensor (shared by training and inference) |
| `COR/Tactical/AI/ActionSpace.swift` | Factored action heads + legality masks |
| `COR/Tactical/AI/LSTMWeights.swift` | `PGW1` weight format: IO, spec catalog, seeded random init |
| `COR/Tactical/AI/LSTMPolicy.swift` | Pure-Swift forward pass + masked argmax |
| `COR/Tactical/AI/TacticalAI.swift` | `AI.heuristic` / `AI.lstm(_:)` — the app-side hooks |
| `Train/` | macOS CLI (not shipped): rollouts, BC, RL, parity, eval |
| `COR/Tests/PolicyTests.swift` | Fog, mask, weight-IO, and legality contracts |
| `PG/policy.pgw` | Bundled weights (synchronized folder group → app resource) |

## Architecture

### `SimObservation` — `Encoding.swift`

Everything the acting player may know, immediately before each of its actions, as
32×32×**51** planes (HWC, index `(y*32 + x)*51 + plane`) plus **12** global scalars,
all normalized to 0…1. Planes: on-map, terrain one-hot (11 mechanic groups) +
entrenchment/income, control (own / ally / enemy), unit presence and scalars (hp,
ammo, entrenchment, mp, ap, level), `UnitType` one-hot (14), normalized model stats,
vision. Globals: prestige, day, seat, tier, base level, unit/settlement counts,
objective, deadline, map size.

**Fog rule (load-bearing)**: enemy units are drawn iff `isVisible`; embarked cargo only
as the transport's cargo flag. The policy sees exactly what a human sees.

The `Plane`/`Global` enums are the index contract — **append-only**; any change
invalidates existing weights and replay-derived corpora.

### Action space — `ActionSpace.swift`

Factored heads, tile-indexed (UIDs are arbitrary slot numbers a conv net can't see;
`unitsMap` gives the tile ↔ UID bijection). Tile index = `x + y*32`, fixed stride for
both map sizes:

- **kind** (7: move / embark / disembark / attack / resupply / purchase / end)
- **actor tile** (1024), **target tile** (1024), **shop slot** (40)

`actionIndices(_:)` / `action(_:)` map `TacticalAction` ↔ head indices (`.takeover`
excluded). `actionMasks()`, `targetMask(_:actor:)`, `slotMask(actor:)` are built from
the same sim-level `can*` predicates that guard the reducers (`canMove`, `canAttack`,
`canEmbark`, `canDisembark`, `canResupply`, `canBuy` — see
`Docs/Architecture.md`), so a masked sample can never no-op — reducers silently
ignoring illegal input is what makes "state mutated" a legality oracle in tests.

### Network (~188k params, 31 tensors)

```
obs 32×32×51 ── conv3×3 51→32 ReLU ×3 (same-pad) ──► trunk 32×32×32
trunk ── full-grid mean pool (32) ⊕ globals (12) ── fc 44→128 ReLU ── LSTM H=128 ──► h
kind    h ── fc 128→7
actor   per tile [trunk(32) ⊕ proj(h→16)] ── 1×1 48→16 ReLU ── 16→1
target  cond = ReLU(fc [h ⊕ trunk[actor]] 160→16); per tile [trunk ⊕ cond] ── same 1×1 stack
slot    fc [h ⊕ trunk[actor]] 160→32 ReLU ── 32→40
value   h ── fc 128→32 ReLU ── 32→1        (in the spec; not yet trained — see RL notes)
```

Contract details (must match between `Train/Net.swift` and `LSTMPolicy`): matmuls are
`y = x@W + b` with `W [in, out]`; convs HWIO; LSTM gate order **i, f, g, o** in
`lstm.wx [128,512]` / `lstm.wh` / `lstm.b`, forget bias initialized +1; both
conditioned heads take `[h ⊕ trunk[actor]]` in that order. `Train/Net.swift` is the
ONE MPSGraph expression of this network — parity, BC, and RL all build on it.

### Weights — `PGW1` (`LSTMWeights.swift`)

Flat binary: magic `0x31574750`, version, tensor count, then records of
name + rank + dims + float32 LE payload. `LSTMWeights.spec` is the fixed catalog;
`init?(data:)` rejects any deviation (extra/missing/reshaped tensors, truncation),
falling back to the heuristic rather than crashing the app. `random(seed:)` provides
the training init (SplitMix64, ±√(3/fanIn)).

### Inference — `LSTMPolicy.swift`

Accelerate (`im2col` + `vDSP_mmul`) forward pass; hierarchical **masked argmax**
(kind → actor → target/slot) — deterministic, never touches the sim's `D20`, so
multiplayer/replay determinism is preserved. `h`/`c` persist across the battle and
reset when `sim.turn` goes backwards (a reused policy meeting a new battle). A
256-actions-per-turn cap forces `.end` (runaway-turn guard); undecodable indices fall
back to `.end`. One inference per action in a turn-based game — perf is a non-issue.

### App integration

`AI.lstm(_:)` (`TacticalAI.swift`) mirrors `AI.heuristic`: nil weights
⇒ heuristic; otherwise each `.ai` seat gets **its own** `LSTMPolicy` (recurrent state is
that seat's memory under its own fog and must not mix). `Settings.aiKind` selects
neural/classic per battle in `TacticalMode.tactical`; `LSTMWeights.bundled` loads
`policy.pgw` from the bundle. No `Player` or save-format changes.

### Replays — `PGRP` (`Train/Replay.swift`)

Per battle: magic, version, `MemoryLayout<TacticalAction>.size` sanity field,
size/seats/winner/days/seed, then the raw `encode(action)` stream (~10–100 KB).
`makeState()` rebuilds the exact initial state; `check()` = rebuild + replay + compare
outcome. Replays are **same-build artifacts** — the versioned header guards toolchain
drift, and regeneration is cheap.

## Training runs

### Build

```
xcodebuild -project PG.xcodeproj -target Train -configuration Release \
  SYMROOT=tmp/build OBJROOT=tmp/build build
```

Binary: `tmp/build/Release/Train`. The Train target imports the same `COR`
product from the local `COR` package as PG and the tests, and builds `-O` in both configurations
(`-Onone` InlineArray code is 10–30× slower). Stdout is line-buffered even when
redirected, so `tail -f run.log` works and nothing is lost on a kill.

### Pipeline

```
Train rollout --n 160 --out tmp/runs/replays --verify        # heuristic corpus
Train bc      --data tmp/runs/replays --out tmp/runs/bc      # behavior cloning
Train eval    --weights tmp/runs/bc/policy.pgw               # baseline arena
Train rl      --weights tmp/runs/bc/policy.pgw --out tmp/runs/rl \
              --iters 80 --episodes 32 --lr 1e-4             # REINFORCE fine-tune
Train eval    --weights tmp/runs/rl/ckpt-80.pgw --n 50       # pick the winner
cp tmp/runs/rl/ckpt-80.pgw PG/policy.pgw                     # ship it
```

### Subcommands

**`rollout --n 8 --out tmp/runs/replays --seed 0 [--verify]`** — heuristic-vs-heuristic
battles as `.pgr` files. The config is derived purely from the index (country pairs
ger/usa, fin/isr, swe/pak, ned/usa × sizes 24/32 × prestige and baseLevel/tier
variants), so corpora are reproducible byte-for-byte; `--verify` replays each battle
after writing. Budget: 65k actions / 128 days.

**`replay <file> ...`** — rebuild + verify recorded winner/days; use after toolchain or
core changes to check whether a corpus is still valid.

**`parity [--steps 1000] [--seed 0] [--wseed 13]`** — plays live battles and compares
every MPSGraph head + h/c/value against the pure-Swift policy step by step. Gate: max
|Δ| ~1e-7 and **0** argmax flips. Run after any change to `Net.swift`,
`LSTMPolicy.swift`, or `Encoding.swift`.

**`bc --data tmp/runs/replays --out tmp/runs/bc [--steps 600] [--b 16] [--t 16]
[--lr 3e-4] [--holdout 8] [--ckpt 200] [--wseed 13] [--resume <pgw>]`** — behavior
cloning. Each battle yields two streams (one per seat, each under its own fog);
truncated BPTT over `b` lanes × `t` steps with h/c carried across windows; masked CE
per head weighted by applicability; Adam + warmup/cosine lr + grad clip 1.0. Every
`holdout`-th file is never trained on and scored at checkpoints. Artifacts:
`policy.pgw`, `ckpt-N.pgw`, `bc-log.csv`
(`step,lr,loss,kind_ce,kind_acc,…,slot_ce,slot_acc`).
Reference (160-battle corpus, defaults, ~3 min): held-out accuracy kind 0.66 /
actor 0.29 (1024-way) / target 0.39 / slot 0.67; eval win rate ≈ 8%.

**`eval --weights <pgw> [--n 32] [--seed 0] [--wseed <n>]`** — the arena: pure-Swift
`LSTMPolicy` (the shipping path) vs `run(ai:)`, each config played from both sides
(⇒ `2n` battles). Reports wins/losses/draws, avg days, and **hard-gates on 0 illegal
actions** (mutation oracle). `--wseed` plays random weights instead — the sanity floor.

**`rl --weights <pgw> [--out tmp/runs/rl] [--iters 100] [--episodes 16] [--b 16]
[--t 16] [--lr 2e-5] [--temp 1] [--seed 1000] [--ckpt 10] [--evaln 8]
[--curriculum 0] [--anneal 0.35]`** — REINFORCE
vs the frozen heuristic. Per iteration: parallel episode collection with masked-softmax
sampling at `--temp` (own SplitMix64 seeded by battle index — the sim's `D20` is never
touched, and each episode is fully determined by its index, so runs are reproducible);
leave-one-out baseline within each difficulty-level group (an EMA baseline goes stale
after a policy shift and un-learns everything — within-batch advantages always straddle
zero; a *shared* mean over a mixed-difficulty batch grades episodes by their matchup,
not their play — harder-level episodes sit systematically below it and the update
leaks "push down whatever the policy does at the harder level"; a singleton group
contributes no gradient); advantages
normalized to mean |A| = 1, clamped to ±3, and **length-normalized** (an episode's
gradient mass is ∝ its action count, and losses/draws run to the day cap while wins
end early — unscaled, the update is dominated by "stop doing what long episodes do",
i.e. acting at all); then the episodes replay through the BC graph as
advantage-weighted CE (Σ|w| normalization ≡ the policy gradient).

Terminal reward = dense, symmetric progress terms (weights are the `w…` constants at
the top of `RLTrainer.swift`), each ~[−1, 1] — win/loss alone starves REINFORCE at
~0% sampled wins:

| Term | Weight | Meaning |
|---|---|---|
| settlements | 1.0 | Δ(own − enemy settlement count) over the episode / total on map |
| units | 0.5 | enemy value killed − own value lost, as fractions of each side's start (hp-weighted cost, accumulated per step so purchases don't pollute it) |
| prestige | 0.25 | (mine − theirs) / (mine + theirs) at episode end |
| outcome | 0.5 | ±0.5 on a decided battle; timeouts score 0 and are judged by the dense terms |

`--curriculum <0-3>` starts collection with the policy seat economically boosted.
Difficulty is **continuous**: each episode plays at level ⌊d⌋ or ⌈d⌉ with probability
from the fractional part (level 3 = rich + baseLevel 5 + tier 3 vs poor; 2 = rich +
baseLevel 2 vs poor; 1 = rich vs poor; at any boosted level, config tier asymmetry is
neutralized — a tier-0 seat facing tier 3 is unwinnable at any prestige). d anneals
down a quarter-step whenever the EMA sampled win rate clears `--anneal` (default
0.35, calibrated on noisy 16-episode EMAs — 32-episode EMAs are tighter and warrant
~0.30: run 11 sat at EMA 0.25–0.31 for 138 healthy iterations without firing), and back **up** a
quarter-step after 6 consecutive iterations with the EMA under 0.10 (restarting the
EMA at 0.2 — a fair evaluation window before the floor can re-trigger). Discrete level
steps proved to be cliffs (even the purely economic tier-equalized 3→2 step collapsed
the win rate); without the way back up a cliff means starvation, and a strict zero-win
ascent trigger left run 8 parked at W1–2/16 — too many wins for six consecutive zeros,
hopelessly short of the descent threshold. Pure REINFORCE needs to *experience*
captures and wins before it can reinforce them, and at even matchups the sampled win
rate is ~0 (measured: level 3 gives the BC policy ~50% sampled wins vs ~0% at level 0).
The boost only changes collection configs; the arena always plays the standard even
matchups. The `level` CSV column records d (fractional).

Every `--ckpt` iterations: `ckpt-N.pgw`, an **argmax** arena on eval configs
`0…evaln−1` (same configs as `Train eval`), and episode dumps (`episodes-N/`, replay
format — boosted seats are recorded in the header, so dumps stay replay-valid).
`rl-log.csv`:
`iter,wins,losses,draws,meanR,madv,settle,units,prestige,days,samples,loss,windows,level,arenaWin`
(`madv` = raw mean |advantage| before normalization — near the 0.1 floor means the
batch carries almost no signal).
Note `--resume` does not exist here: restarting from a checkpoint restarts Adam (pass
the reached `--curriculum` level explicitly when continuing an annealed run).

### Reading a run

- Sampled wins per iteration (`wins` column) is the noisy leading signal; the argmax
  `arenaWin` at checkpoints is real strength. Both stuck at the BC level means the run
  is too timid (raise `--lr` / `--episodes`); loss spikes or a win collapse mean the
  opposite (halve `--lr`).
- The `settle`/`units`/`prestige` columns are the batch-mean reward components — they
  show *what* the policy is trading. Rising `settle` with flat wins is real progress;
  rising `units` with falling `settle` means it's kiting for kills instead of taking
  ground.
- Pick `--seed` so RL battle indices don't overlap the eval configs (which start at 0).
- Illegal actions are a hard failure anywhere (eval throws; collection is
  masked-by-construction) — any nonzero count means an encoding/mask regression.

### Invariants when touching the pipeline

- **Contracts are append-only**: `Plane`/`Global`, `ActionSpace` indices, and
  `LSTMWeights.spec` — a change invalidates weights and corpora. Re-run `parity` and
  `COR/Tests/PolicyTests` after touching them.
- **MPSGraph autodiff gaps** (macOS 26.5): `split` and `broadcast` have no registered
  gradient, and `gradients(of:with:)` asserts on variables that aren't predecessors of
  the loss. `Net.swift` therefore slices LSTM gates and broadcasts via
  implicit-broadcast addition; keep new graph code inside the gradient-supported op set.
- The value head exists in the weight spec but is untrained (the RL baseline is EMA;
  upgrade to a value baseline / entropy bonus if variance stalls — Roadmap follow-up).
