# PPO Plan — the stronger learner (PPO-clip / value-head baseline / KL-anchor)

REINFORCE-from-boosted-play hit its ceiling twice (runs 12 and 13: curriculum
descends cleanly, arena stays at the BC line). The three failure classes the
run history exposed map one-to-one onto the three PPO components:

| Failure (run) | Mechanism | Fix |
|---|---|---|
| Update shock wipes the BC prior (4, 5, 10) | one on-policy batch = 200+ correlated Adam steps; displacement ≈ windows × lr | **PPO-clip** — per-sample ratio clipped at 1±ε; once a sample's ratio leaves the clip band its gradient vanishes, so per-iteration policy movement is bounded in distribution space, not by lr arithmetic |
| Matchup-graded advantages (8) | shared baseline over mixed-difficulty batches grades "which level did you draw"; stratified LOO fixed it but a ~4-episode stratum is noise | **value-head baseline** — V(s_t) sees prestige/tier/baseLevel in the observation globals, so it *learns* the matchup correction per state instead of estimating it per 4-episode group; also removes the length-normalization hack (long timeout episodes get V ≈ R ⇒ A ≈ 0) |
| Slow drift off the prior across iterations (2, 3: "don't lose" kiting) | nothing anchors the policy to the teacher once REINFORCE starts pushing | **KL-anchor** — β · KL(π‖π_ref) per head toward the frozen starting weights (the BC prior), full-distribution, computed in-graph against a constant copy of the network |

## Design

New subcommand `Train ppo` (`Train/PPOTrainer.swift`: `PPOTrainer` + `PPOGraph`),
reusing `RLTrainer.collect/config/play/Episode` (collection + reward + curriculum
inputs unchanged), `Net` (one new additive helper), `Batcher` (two additive
extensions), `Eval.arena`. `BCGraph` and the REINFORCE path stay untouched.

### Old log-probs: a read pass, not an old-network branch

PPO needs π_old(a|s) per sample. Recording it at collection time is
misalignment-prone (the runaway-turn guard skips forward passes that the update
replay still yields as samples). Instead, per iteration:

1. **Read pass** — run the episodes through the graph once (no update) with the
   *current* (= collection) weights; read per-sample joint log-prob and V.
   `Batcher` is deterministic in episode mode, so window k of every subsequent
   pass contains byte-identical samples — cache `oldLogp/V/epi` per window
   ordinal (~KB scale; obs windows themselves are never cached).
2. **Advantages CPU-side** — GAE over per-episode value sequences
   (γ = 1 fixed, `--lam` default 1 ⇒ exactly A_t = R − V(s_t); returns are
   terminal-only). Batch-wide normalization to mean 0 / std 1, clamp ±5.
   Explained variance logged per iteration (the value-head health metric).
3. **`--epochs` training passes** — fresh `Batcher` each (identical window
   sequence, asserted against the cache), feeding cached oldLogp/adv/ret.
   First window of epoch 0 has ratio ≡ 1 by construction — a built-in
   correctness probe (clipFrac ≈ 0, approxKL ≈ 0 at iteration start).

Joint log-prob = Σ heads applicability-weighted (−CE) — the same masked
softmaxCE the BC graph uses, reduction none, labels are always mask-legal.

### PPOGraph losses

- **Surrogate**: r = exp(clamp₍±20₎(logpNew − oldLogp));
  L = −Σ valid·min(r·A, clip(r, 1−ε, 1+ε)·A) / Σ valid. All clamps via
  min/max compositions (the `clamp` op's gradient support is unverified;
  min/max are known-good).
- **Value**: MSE (V − R)² over valid samples, coefficient `--vcoef` (0.5).
  Value head vars join the trainable set (they were excluded in BC).
- **KL anchor** (built only when `--kl` > 0): a full forward branch of the
  network with the reference weights as graph *constants* (`Net.constants` —
  no variables ⇒ no autodiff involvement), teacher-forced on the same actor
  labels, with its **own recurrent state** (second h/c pair threaded through
  `Batcher` lanes). Per head: KL = Σ mask·p_new·(log(p_new+1e-10) −
  log(p_ref+1e-10)) — softMax + log(p+ε) rather than a hand-rolled LSE
  (reductionMaximum's gradient support is unverified; softMax's is certain).
  Reference = `--ref` (default: the `--weights` starting point = BC prior).
- **Entropy** (logged always, in loss only when `--ent` > 0): −Σ mask·p·log p.
- Total = polCoef·surrogate + vcoef·value + β·KL − ent·H; polCoef is a feed.
- Adam + global-norm clip 1.0 + bias-correction-in-lr, as in BC. Temperature
  `--temp` scales head logits in-graph so π_new matches the sampling
  distribution (default 1).

### Value warmup

`--vwarm N` (default 5): the first N iterations run a **value-only** update
path — gradients of the value loss w.r.t. value.fc1/fc2 only (second
gradients() call + its own clip; Adam moment variables shared by name).
Rationale: the value head is at random init, and letting its loss backprop
into the shared trunk would shift the policy heads' inputs under them before
the anchor/clip can react. The curriculum anneal is frozen until warmup ends
(the BC prior wins ~40% at level 3 — winEMA would fire the descent while the
policy isn't even training).

### Curriculum

Unchanged v3.1 machinery, copied into the PPO loop: continuous difficulty,
descent on winEMA > `--anneal`, ascent on starvation. The stratified-LOO
baseline is *replaced* by the value head — that was its whole job.

### Batcher extensions (additive, BC path unaffected)

- `Window.epi: [Int32]` — episode ordinal per sample (−1 padding), so the CPU
  side can map samples → returns/advantages and reconstruct per-episode value
  sequences for GAE.
- Optional second h/c pair (`Window.h0r/c0r`, `carry(h:c:hr:cr:)`, nil
  default) for the KL branch's independent recurrent state.

### CLI defaults

`--epochs 3 --clip 0.2 --vcoef 0.5 --kl 0.1 --ent 0 --vwarm 5 --lam 1`
`--lr 5e-6 --episodes 32 --curriculum 3 --anneal 0.30 --suite mixed` (the
proven run-13 recipe; the clip makes the windows×lr invariant a soft bound —
watch clipFrac in the log instead).

CSV: `iter,wins,losses,draws,meanR,ev,madv,settle,units,prestige,days,samples,
loss,surr,vloss,kl,ent,clipfrac,akl,windows,level,arenaWin`.

## Verification

1. Build + `Train parity` (Net touched only additively — must stay 0 flips).
2. PPO smoke (3 iters × 4 episodes, epochs 2, vwarm 1, kl 0.1): no NaN, RSS
   bounded (autoreleasepool around every graph step — the silent-SIGKILL
   gotcha), ckpt/arena/CSV written. Built-in invariants eyeballed:
   - vwarm iteration: **kl ≈ 0** (policy ≡ ref ⇒ validates both the value-only
     freeze and the ref branch in one number);
   - epoch 0, window 0: ratio ≡ 1, clipFrac ≈ 0;
   - `--lam 1` advantages equal R − V_t.
3. Launch the real run: bc3 start, seed 30000, iters 150 → `tmp/runs/ppo1`,
   detached, line-buffered log. Judge on: EV climbing through warmup, then
   d-descent with arena ≥ bc3's 18% at 128-battle evals of the best checkpoint.
