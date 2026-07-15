# LSTM AI

The neural opponent for Tactical battles: a convolutional LSTM policy
that plays any `.ai` seat, bundled as `PG/policy.pgw` and toggled with
*Neural opponent* in the Tactical menu (heuristic fallback when the resource is missing
or invalid). It is trained by behavior-cloning the heuristic `run(ai:)` — BC scale
(corpus × steps) has been the reliable strength lever; PPO fine-tuning (clipped
surrogate, value-head baseline, KL anchor to the BC prior) lifted a weak BC prior
once but stopped adding over strong ones, and an earlier REINFORCE learner
plateaued at the BC level — entirely
with `MetalPerformanceShadersGraph` (OS built-in, no Python, no packages). Inference is dependency-free Swift in COR, so the
shipping app never touches MPSGraph.

Training rests on properties of the core: `reduce` is a pure function of
`(sim, action)` (test-proven, `COR/Tests/MultiplayerTests.swift`), a whole battle
bitwise-serializes via `encode`/`decode`, and the AI interface is one `TacticalAction`
per call — exactly a policy's step function. Battles are therefore stored as *replays*
and regenerated deterministically instead of storing states.

## Heuristic teacher

`run(ai:)` is a deterministic, objective-aware tactical teacher rather than a
nearest-city script. Its fixed-capacity `AI.Plan` separates own, allied, and hostile
settlements; assigns compatible retreat havens, threatened garrisons, combat support,
and distributed offensive objectives; and selects attacks through one global scan of
the acting roster against visible enemies. Expected value removed, kills, focus fire,
objective pressure, counterfire, and visible artillery/AA support all contribute to
the integer score. Movement likewise scores capture progress, actual post-move weapon
range, terrain, friendly support, congestion, and visible threat. It never clones the
sim, advances `D20`, or reads hidden enemy units.

The battle objective sets its stance: open battles balance capture and destruction,
a survival defender preserves and screens, and the opposing attacker accepts more
risk as the deadline approaches. Its reactive action order is critical resupply,
global attack, transport, planned movement, purchase after deployment tiles clear,
then end turn.

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
32×32×**53** planes (HWC, index `(y*32 + x)*53 + plane`) plus **12** global scalars,
all normalized to 0…1. Planes: on-map, terrain one-hot (13 mechanic groups; fort and
sea appended after the fog plane, previously folded into city / river) +
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
`unitsMap` gives the tile ↔ UID bijection). Tile index = `x + y*32` on the fixed
32×32 map:

- **kind** (7: move / embark / disembark / attack / resupply / purchase / end)
- **actor tile** (1024), **target tile** (1024), **shop slot** (40)

`actionIndices(_:)` / `action(_:)` map `TacticalAction` ↔ head indices (`.takeover`
excluded). `actionMasks()`, `targetMask(_:actor:)`, `slotMask(actor:)` are built from
the same sim-level `can*` predicates that guard the reducers (`canMove`, `canAttack`,
`canEmbark`, `canDisembark`, `canResupply`, `canBuy` — see
`Docs/Architecture.md`), so a masked sample can never no-op — reducers silently
ignoring illegal input is what makes "state mutated" a legality oracle in tests.

### Network (~295k params, 35 tensors)

```
obs 32×32×53 ── conv3×3 ReLU ×5 (same-pad, 53→48 then 48→48, dilations 1,2,4,8,1) ──► trunk 32×32×48
trunk ── mean pools: full grid (48) ⊕ four 16×16 quadrants (4×48) ⊕ globals (12) ── fc 252→128 ReLU ── LSTM H=128 ──► h
kind    h ── fc 128→7
actor   per tile [trunk(48) ⊕ proj(h→16)] ── 1×1 64→16 ReLU ── 16→1
target  cond = ReLU(fc [h ⊕ trunk[actor]] 176→16); per tile [trunk ⊕ cond] ── same 1×1 stack
slot    fc [h ⊕ trunk[actor]] 176→48 ReLU ── 48→40
value   h ── fc 128→48 ReLU ── 48→1        (trained by `Train ppo` only; inference ignores it)
```

The dilation ladder (1, 2, 4, 8, then a dense finish that smooths the d8
gridding artifacts) gives a 33×33 receptive field — effectively the whole map,
which the teacher's global-scan decisions require; the quadrant pyramid gives
the LSTM a coarse *where*, not just the full-grid *how much*. Quadrant order is
(yHalf, xHalf) row-major — q00 q01 q10 q11, channels inner.

Contract details (must match between `Train/Net.swift` and `LSTMPolicy`): matmuls are
`y = x@W + b` with `W [in, out]`; convs HWIO; LSTM gate order **i, f, g, o** in
`lstm.wx [128,512]` / `lstm.wh` / `lstm.b`, forget bias initialized +1; both
conditioned heads take `[h ⊕ trunk[actor]]` in that order; the fc1 input concat
is full-pool ⊕ quadrants ⊕ globals. `Train/Net.swift` is the
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

Version 4 stores magic, version, `MemoryLayout<TacticalAction>.size`,
seats/winner/days/seed, the objective kind/team/deadline, fort level, and then the
raw `encode(action)` stream (~10–100 KB).
`makeSim()` rebuilds the exact initial state; `check()` = rebuild + replay + compare
outcome. Replays are **same-build artifacts** — the versioned header guards toolchain
drift, and regeneration is cheap. Older versions are deliberately rejected: all
existing corpora must be regenerated before BC or RL so demonstrations from different
teachers or battle recipes cannot be mixed. v3 (same layout as v2) marks the factory
contract change (`a25d286`): the factory places exactly the units it is given, so
`makeSim()` composes every seat's `.base` roster itself (training battles carry no aux).
v4 removes the runtime map-size byte because every tactical map is 32×32.

## Training runs

### Build

```
xcodebuild -project PG.xcodeproj -scheme Train -configuration Release -destination 'platform=macOS' \
  SYMROOT=$PWD/tmp/build OBJROOT=$PWD/tmp/build build
```

Binary: `tmp/build/Release/Train` (links `COR.framework` from
`tmp/build/Release/PackageFrameworks` via `@executable_path/PackageFrameworks` rpath).
SYMROOT/OBJROOT must be **absolute**: a relative path is resolved per-project, so the
`COR` package would build into `COR/tmp/build` and the Train link step would not find it.
The Train target imports the same `COR`
product from the local `COR` package as PG and the tests, and builds `-O` in both configurations
(`-Onone` InlineArray code is 10–30× slower). Stdout is line-buffered even when
redirected, so `tail -f run.log` works and nothing is lost on a kill.

### Pipeline

```
Train rollout --n 160 --out tmp/runs/replays --suite mixed --verify
Train bc      --data tmp/runs/replays --out tmp/runs/bc      # behavior cloning
Train eval    --weights tmp/runs/bc/policy.pgw --suite mixed # objective-mixed arena
Train ppo     --weights tmp/runs/bc/policy.pgw --out tmp/runs/ppo \
              --iters 150 --curriculum 3 --suite mixed
Train eval    --weights tmp/runs/ppo/ckpt-90.pgw --n 416     # pick the winner
                                # (~0.85 s/battle; 832 battles resolves ~4pt at z≈2 —
                                # configs are inhomogeneous, only compare paired runs)
cp tmp/runs/ppo/ckpt-90.pgw PG/policy.pgw                    # ship it

# Compare the bundled PGW1 policy with the strengthened teacher on the old arena:
Train eval --weights PG/policy.pgw --n 32 --suite classic
```

### Subcommands

**`rollout --n 8 --out tmp/runs/replays --seed 0 [--suite classic|mixed] [--verify]`** — heuristic-vs-heuristic
battles as `.pgr` files. The config is derived purely from the index (country pairs
ger/usa, fin/isr, swe/pak, ned/usa × prestige and baseLevel/tier
variants), so corpora are reproducible byte-for-byte; `--verify` replays each battle
after writing. `classic` is the exact historical `.none` mapping. The default `mixed`
suite rotates `.none`, seat-0 survival defender, and seat-1 survival defender; survival
deadlines are 40 days on 32×32 maps, with fort level 1. Budget: 65k
actions / 80 days. Every loop stops as soon as `sim.winner` is non-nil, including a
survival win with both teams alive.

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
Scale reference — corpus and steps scaled together (windows/epoch grows with
the corpus; the warmup/cosine schedule stretches with `--steps` automatically),
paired 832-battle win rates: 1× (240 battles / 1000 steps) **25.4%** · 4×
(960 / 4000, ~12 min) **29.1%** · 16× (3840 / 16000, ~47 min) **37.4%** —
gains per 4× step growing so far. At 16× the best checkpoint was ckpt-14000,
not the final: held-out CE flattens and goes noisy near the end of a long run
and is a poor proxy for arena strength — arena-eval the best-held-out AND
final checkpoints.

**`eval --weights <pgw> [--n 32] [--seed 0] [--wseed <n>] [--suite classic|mixed]`** — the arena: pure-Swift
`LSTMPolicy` (the shipping path) vs `run(ai:)`, each config played from both sides
(⇒ `2n` battles). Reports separate policy and heuristic wins/draws/losses, average
days, action counts, and illegal-action counts, and **hard-gates on 0 illegal actions**
(mutation oracle). Independent battles run concurrently while results remain ordered
by config. `--wseed` plays random weights instead — the sanity floor.

**`rl --weights <pgw> [--out tmp/runs/rl] [--iters 100] [--episodes 16] [--b 16]
[--t 16] [--lr 2e-5] [--temp 1] [--seed 1000] [--ckpt 10] [--evaln 8]
[--curriculum 0] [--anneal 0.35] [--suite classic|mixed]`** — REINFORCE
vs the frozen heuristic. Per iteration: parallel episode collection with masked-softmax
sampling at `--temp` (own SplitMix64 seeded by battle index — the sim's `D20` is never
touched, and each episode is fully determined by its index, so runs are reproducible);
collection and checkpoint arenas both use the selected suite (default `mixed`);
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

`--curriculum <0-3>` starts collection with the policy seat economically boosted;
fractional values are accepted so a checkpoint can continue from its exact difficulty.
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

**`ppo --weights <pgw> [--ref <pgw>] [--out tmp/runs/ppo] [--iters 100]
[--episodes 32] [--epochs 3] [--clip 0.2] [--vcoef 0.5] [--kl 0.1] [--ent 0]
[--vwarm 5] [--lam 1] [--b --t --lr --temp --seed --ckpt --evaln --curriculum
--anneal --suite]`** — the stronger learner (`PPOTrainer.swift`), sharing
collection, reward, curriculum, and arena machinery with `rl`. Three upgrades,
each matched to a REINFORCE failure class:

- **PPO-clip** — each batch is reused for `--epochs` optimization passes; the
  per-sample importance ratio is clipped at 1±ε so a sample whose probability
  has already moved that far stops contributing gradient. Per-iteration policy
  movement is bounded in distribution space, retiring the hand-tuned
  windows × lr displacement invariant (update-shock runs 4/5/10) — watch the
  `clipfrac` column instead.
- **Value-head baseline** — GAE (γ = 1, `--lam`, default 1 ⇒ A_t = R − V(s_t))
  from the value head, trained here with `--vcoef` MSE. V sees
  prestige/tier/baseLevel in the observation globals, so it learns the matchup
  correction per state — replacing the stratified LOO baseline and the
  length-normalization hack. `--vwarm` iterations train the value head *alone*
  first (random-init V backpropagating into the shared trunk would shift the
  policy heads' inputs under them); the curriculum is frozen meanwhile. The
  `ev` column (explained variance vs the Monte-Carlo return) is the baseline's
  health metric.
- **KL anchor** — β = `--kl` times the full-distribution per-head
  KL(π‖π_ref) toward `--ref` (default: the starting weights, i.e. the BC
  prior), computed against an in-graph frozen constant copy of the network
  with its own recurrent state. The policy can improve on the prior but cannot
  silently unlearn it (the run-2/3 kiting drift).

Old log-probs come from a **read pass** per iteration (the batch replayed once
through the graph at the collection weights, per-sample logπ and V cached per
window ordinal) rather than collection-time recording — episode-mode `Batcher`
is deterministic, so every epoch reproduces byte-identical windows (asserted),
and ratios are exact by construction even across runaway-turn-guard steps.
Self-checks: during `--vwarm` the `kl` column must read ~0 (policy ≡ ref
validates both the warmup freeze and the ref branch); `clipfrac`/`akl` near 0
at epoch starts. `ppo-log.csv`:
`iter,wins,losses,draws,meanR,ev,madv,settle,units,prestige,days,samples,loss,surr,vloss,kl,ent,clipfrac,akl,windows,level,arenaWin`.

Loss mechanics (`PPOGraph`): joint logπ = Σ heads applicability-weighted −CE
(the BC graph's masked softmaxCE, reduction none); ratio r =
exp(clamp₍±20₎(logπ − logπ_old)); surrogate −Σ valid·min(r·A,
clip(r, 1−ε, 1+ε)·A) / Σ valid; advantages batch-normalized to mean 0 / std 1
and clamped ±5; value target = the λ-return; the KL branch is teacher-forced
on the same actor labels as the policy; entropy is logged even at `--ent 0`.
Value warmup runs a second value-only gradient/Adam path (moment variables
shared by name, own grad clip) so random-init V cannot shift the shared trunk
under the policy heads. Smoke recipe: 3 iters × 4 episodes, epochs 2, vwarm 1
— `kl` must log 0.0 *exactly* during warmup, no NaN, RSS bounded.

**Verdict (runs ppo1–ppo3, 2026-07-14/15)**: PPO broke the REINFORCE ceiling
from a weak prior (ppo1 ckpt-90 25.7% vs bc3 21.6%, paired 832 battles, z≈2)
but added nothing over strong priors twice (ppo2 continuation of ckpt-90 +5W
n.s.; ppo3 from bc4 +7W n.s.), and parking at the difficulty frontier after
the descent *erodes* even-matchup strength (ppo3 ckpt-110/150 lost ~25W vs
ckpt-50) — pick checkpoints from the descent, not the park. BC scale has been
the reliable lever since; RL is worth revisiting only at even matchups
(`--curriculum 0`) from a prior strong enough to sample wins there.

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
- **The replay version is a hard corpus boundary**: objective, fort configuration,
  and the roster recipe are part of the deterministic battle recipe. Regenerate every
  older corpus; do not combine demonstrations across versions. Format changes do not
  alter PGW1, observations, or action indices, and the bundled `PG/policy.pgw` is not
  automatically replaced.
- **MPSGraph autodiff gaps** (macOS 26.5): `split` and `broadcast` have no registered
  gradient, and `gradients(of:with:)` asserts on variables that aren't predecessors of
  the loss. `Net.swift` therefore slices LSTM gates and broadcasts via
  implicit-broadcast addition; `clamp` and `reductionMaximum` gradients are
  unverified — the PPO loss paths use min/max compositions and
  `log(softMax + 1e-10)` instead. Keep new graph code inside this
  known-good op set.
- The value head is trained only by `Train ppo` (BC and `rl` exclude it from their
  gradient requests — autodiff asserts on variables that aren't predecessors of the
  loss); inference never reads it beyond `lastValue` logging.
