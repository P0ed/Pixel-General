# Campaign

A turn-based strategic layer over the tactical battles — "Hearts of Iron by
vibes," deliberately shallower. You command one country on a political map of
Europe, push offensives against adjacent enemy provinces,
and each offensive resolves as a [tactical battle](./GameMechanics.md). The
hook is **RPG progression**: a *persistent roster* that gains experience,
skills, and upgrades across the whole campaign — and that you can later stake
in multiplayer, where you can lose all of it.

This lives in the `Strategic` module (`COR/Strategic/`, `PG/Strategic/`). See
[Architecture](./Architecture.md) for the `SceneMode` pipeline, the `Sim`/`UI`
split, the `~Copyable` / `BitwiseCopyable` constraints, and the `Core` root
state these build on.

**Implementation status (Phase 1, province conquest — largely wired):**
`StrategicSim` holds the Europe political map (`owner: Map<32, Country>`), the
player country, a turn counter, and the contested `battle` tile.
`StrategicSim.canAttack` gates offensives to bordering enemy provinces;
`Core.startCampaignBattle(at:)` deploys the HQ roster into a `make()` battle and
`Core.complete` → `StrategicSim.resolveBattle(at:won:by:)` flips ownership of
land tiles within `captureRadius` (Chebyshev 2) on a win. `Country` has been
expanded to the European nations (so `fin` exists). Still **proposed** below:
`Objective`/`BattleOutcome` types (current resolution is a simple last-team
win bool), battle-budget plumbing, the two-pool economy, supply-distance
budget, enemy retreat/consolidation, the strategic AI, and slot persistence.

## Design pillars (locked decisions)

- **Fixed teams for now.** The dynamic-diplomacy / `Country`→`Team` redesign is
  deferred (see [Open items](#open-items--prerequisites)). Campaign teams use
  the existing hardcoded `Country.team`.
- **Every campaign battle is 1v1** (two teams). Free-for-all is reserved for
  scenario and multiplayer.
- **Fronts, not stacks.** No movable strategic army pieces. A country attacks
  across a border with a hand-picked slice of its roster; strength *is* the
  roster.
- **No strategic fog of war.** The whole political map is visible.
- **Multiple simultaneous fronts** are allowed and are a core pressure source.
- **Hand-picked commitment.** You choose which roster units deploy to each
  front's battle, up to a per-front cap; committed units are unavailable
  elsewhere that turn.
- **Objective-based victory** with turn limits, not just annihilation.
- **Two prestige pools** — a slow strategic economy and a per-battle budget —
  so battles can't be farmed for income.
- **The roster is permanent and precious.** Survivors carry forward; the dead
  stay dead; losing the campaign (or staking it in MP) can cost it entirely.

## The campaign loop

The flow reuses the existing `Core` plumbing
(`COR/Model/Core.swift` — `location`, `startCampaign`, `complete`, `goHQ`):

```
HQ  ──manage roster──┐
 ▲                   ▼
 │            Strategic (political map: pick a front, commit units)
 │                   │  launch offensive
 │                   ▼
 └──complete()── Tactical battle (objective + turn limit)
```

- **HQ** (`HQState`) owns the persistent roster (`HQState.units`) and the
  strategic prestige bank. This is the RPG "character sheet."
- **Strategic** (`StrategicState`) owns province ownership, per-country status,
  the turn counter, and the strategic AI. Picking an adjacent enemy province
  and committing units launches a battle.
- **Tactical** generates the battle via `TacticalState.make(...)`
  (`COR/Tactical/TacticalStateFactory.swift`) seeded by the contested border,
  carrying an `Objective` and a fixed prestige budget.
- **`complete()`** already does the load-bearing writeback: it returns the
  surviving non-`aux` core units (reset) and the player's prestige to HQ
  (`Core.complete` filters `u[.aux]`). The campaign extends this to also apply
  the `BattleOutcome` to the strategic map (annex / repulse / province loss).

The persistent-army half of the loop is therefore **already wired**; the
campaign mostly adds the strategic map, the battle bridge (objectives +
budget), and the strategic AI.

## Strategic map

The political map is literally a `Map<32, Country>` of province ownership — the
same data structure, the same 32×32 dimensions, and the same renderer already
used by Tactical's `MapMode.political`, which recolors tiles by `control`. See
[Map](./Map.md) for the reference layout.

- **Adjacency** is free via `XY.n4` / `XY.n8` (as used for ZoC in Tactical).
- **Ownership** changes by flipping province tiles on a `BattleOutcome`.
- **No fog** — the entire map and every country's holdings are visible.

## Roster & fronts

The persistent roster is the campaign's RPG character. Two changes from the
battle-local model:

- **A larger HQ roster pool.** Grow the HQ core capacity beyond the 16-slot
  battle cap (e.g. a 6×6 = 36-unit roster). `HQState.units` and the relevant
  `CArray` capacities grow; the per-battle cap stays at 16 core per side.
- **Hand-picked per-front commitment.** When launching an offensive you pick up
  to **16 core units** from the roster to deploy. Committed units are spent for
  that strategic turn and cannot also defend or attack on another front.

**Why fronts, not stacks:** a big roster does not mean every battle is a
curb-stomp — it means *choosing where your veterans go* while a thinner force
holds elsewhere. Overextension is punished: if the enemy attacks a second front
while your veterans are away conquering the first, that thin defense is the
price.

**Supply-distance budget (the main anti-snowball lever).** Each offensive draws
a reinforcement/prestige budget that **shrinks with province-graph distance
from your own territory.** Attacking a border province is well-supplied;
pushing several provinces deep is a shoestring force with no reinforcements.
This is what physically prevents a blitz across a large country — you must
consolidate a front before the next push.

## Prestige: two pools

The current battle income model (income per day from owned settlements) rewards
*staying longer in a battle* to farm prestige. The campaign decouples economy
from battle duration:

- **Strategic prestige** — accrues slowly from owned provinces, spent *between*
  battles to heal / reinforce the roster. This is the campaign economy.
- **Battle budget** — a fixed allotment the strategic layer hands to a battle;
  leftover does **not** persist (or refunds at a steep discount). Combined with
  turn-limited objectives, in-battle settlement income becomes irrelevant, so
  the farm-by-stalling exploit dies — without ripping out the existing income
  system, which scenarios and multiplayer keep as-is.

## Battles: the bridge to Tactical

A campaign battle is a normal `TacticalState` with two additions: an
**objective** and a **fixed budget**. Today victory is hardcoded to "last team
standing" in `COR/Tactical/TacticalTurns.swift`; the campaign needs explicit,
asymmetric goals.

```swift
// Proposed — COR/Tactical
@frozen public enum Objective {            // per player / per team
    case annihilate                        // current behavior (default)
    case capture(SetXY, by: UInt16)        // take these settlements by day N
    case hold(SetXY, until: UInt16)        // hold these through day N
    case survive(UInt16)                   // stay alive N days
}

@frozen public enum BattleOutcome {
    case attackerWins   // objective captured in time → annex province
    case defenderHolds  // timer expired / attacker wiped/withdrew → repulse ("draw")
    case defenderFalls  // (AI offensive vs you) you lose the province
}
```

`SetXY` and `UInt16` day-counts are already inline-friendly. The objective is
checked in the end-of-turn pass alongside `captureCities`. An offensive is
typically `capture(provinceCities, by: dayN)` for the attacker mirrored by
`hold(...)` / `survive(dayN)` for the defender — your "hold the cities for 16
days to win" is the defender's side of exactly this.

Turn-limited objectives do double duty: they **kill turtling** (no time to milk
income) and **stop the overwhelming-force grind** (you must *achieve* the
objective fast, not slowly attrit with numbers).

## Anti-snowball model

You are *supposed* to snowball your army — that is the RPG payoff. The thing
that must not snowball is **free territory**. Four levers, all emergent from
existing mechanics, keep the front's difficulty tracking your army's growth:

1. **Supply-distance budget** (above) — deeper pushes field smaller, unsupplied
   forces.
2. **Permanent casualties** — `complete()` carries only survivors, and healing
   costs resources/time, so even a *won* battle that bled you stalls the next
   push while you recover. Don't grant a free full-heal between battles.
3. **The enemy retreats and consolidates — it never evaporates.** Defeated
   survivors fall back one province inward instead of despawning. The next
   battle is a *smaller but concentrated, entrenched, home-terrain* force — and
   the interior favors the defender (city base entrenchment 3, capped at
   `base*4 + 20`). You keep fighting the same army, dug in harder each step; no
   "free province" feel.
4. **Turn-limited objectives** — an offensive that can't take the province in N
   days is a repulse.

Net rhythm: **advance → consolidate → heal → advance.** The deeper you are, the
thinner your supplied force and the stiffer the dug-in defense; they meet in the
middle.

### After a victory (e.g. Finland → Russia)

1. Objective met → **annex** the province (flip `owner[xy]`).
2. Your survivors return to the roster via `complete()`; your dead are gone.
3. The enemy's survivors **retreat one province inward and consolidate** (not
   despawned).
4. Strategic prestige ticks up from your larger territory — but spending it on
   heals/reinforcements costs a strategic turn, during which the enemy also
   reinforces *its* front from its own income.
5. The next target is farther from your supply → smaller budget. You feel
   strong, but you cannot be everywhere at full strength, especially across
   multiple fronts.

## Loss, draw, abandon

Separate **battle outcome** from **campaign outcome**:

- **You attack and lose / time out → repulse (`defenderHolds`).** The province
  stays enemy, your survivors retreat to your border, the dead stay dead. *The
  campaign continues.* This is the common "draw" — a failed offensive, not a
  game-over.
- **The enemy attacks and you lose → `defenderFalls`.** You lose that province;
  survivors fall back inward. Losing your **capital / last province** ends the
  campaign in defeat.
- **Abandon — two flavors:**
  - *Abandon a battle* (reuse the existing Tactical Retreat/Abandon path):
    resolves as a repulse or province loss; the campaign continues.
  - *Abandon the campaign:* there is no separate roster outside the slot, so
    "abandoning" is just **deleting the slot** (or starting a New game over it).
    Consistent with the high-stakes ethos, that discards the campaign and its
    roster — the army is lost. Note you don't *have* to abandon to play
    something else: Load a different slot and the campaign persists untouched
    (see [Persistence & slots](#persistence--slots)). That permanence is what
    gives the RPG loop its weight.

## Difficulty

Two orthogonal knobs, set at campaign start (alongside the existing
starting-prestige toggle in `PG/HQ/HQScenario.swift`):

- **Starting prestige** — how *much* the AI can field and reinforce
  (`.poor` / `.rich`, already implemented).
- **Enemy base level** — how *good* each enemy unit is, seeded via the existing
  `.lvl(_)` builder (`lvl = 8 - leadingZeroBitCount(exp)`); folds into attack,
  defense, initiative, and rugged-defence rolls.

**Tuning note — the exp feedback loop:** exp rewards scale with `du.cost`, and
`cost` scales with `lvl`, so higher-level enemies are worth *more* exp. Cranking
difficulty therefore also accelerates *your* progression. This is partly
self-balancing (hard fights pay out) but can overshoot; consider softening exp
gain at the top end, or accept it as "high difficulty = high-risk fast
leveling," which fits the RPG vibe.

## The capital fight

The climactic assault on a country's capital gets a one-time intensity spike on
**both sides**: extra **leveled `aux` units** drawn from the existing
`.aux(country:)` pool.

This is self-balancing because **aux are already excluded from carry-forward** —
`complete()` drops `u[.aux]` from the roster returned to HQ. So the bonus units
evaporate after the battle and cannot permanently inflate either army:

- *Defender:* a stiff, pre-leveled homeland garrison — a proper final-boss
  last stand.
- *Attacker:* a one-time allotment of leveled aux you may draft for the
  assault — an epic push that resets to your real roster afterward.

(Decide whether the attacker's bonus aux are automatic or purchased from the
battle budget.)

## Healing

Both modes you want already exist in the engine
(`COR/Tactical/UnitResupply.swift`) — they only need exposing:

- **Slow regen, no exp loss** — the end-of-turn / `regen`-style heal (+1 HP near
  supply). In-battle, with a supply truck adjacent, over a couple of days. The
  "let veterans recover" path.
- **Quick replacements, costs prestige + exp** — the current player-initiated
  `resupply` heal (`3 << lvl` exp + `cost/32` prestige per HP). Reframe it as
  *replacements dilute your veterans* — green troops refill the ranks and
  veterancy drops; thematically perfect for an exp cost.

**Tempo cost (the synergy with turn limits):** even "free" slow regen costs an
*attacker* its objective clock — every day healing is a day not capturing. For a
*defender* on `hold`/`survive`, healing is fine. So in-battle healing is
naturally an attacker's dilemma.

For forces that **retreated and are not currently in a battle**, a strategic-map
heal between turns mirrors the same two modes, paid from the strategic prestige
pool.

## Multiplayer stakes

The persistent HQ roster *is* the RPG character; multiplayer is the arena where
you stake it. The only requirement on the campaign side is that MP reads the
same `HQState` roster, and an MP loss runs a **punitive** `complete()`-style
writeback (prune/wipe instead of carry-forward). Keeping the roster format the
single source of truth across HQ / campaign / MP makes this a small branch on
machinery that already exists.

## Persistence & slots

**Four independent save slots, each a full `Core`** (its own HQ roster +
campaign). This is what lets a campaign coexist with casual scenario / MP play
without the campaign army leaking between them: a campaign lives in one slot; a
fair, low-stakes MP or scenario is simply *another slot* with a different (or
starting) roster. Because each slot is a separate `Core`, the battle writeback
(`Core.complete`) needs no special-casing — it always evolves the *active*
slot's roster. No per-battle "don't persist" flag, no roster-source picker.

**Operations (deliberately just two):**

- **Load** — a 4-slot picker; selecting a slot makes it active and resumes its
  latest committed state. This is the non-destructive way to switch between a
  campaign and other play, and it doubles as the path to an empty slot.
- **New game** — a fresh start in the *active* slot (overwrite). You target
  which slot a new game lands in by Load-selecting it first. With Load as the
  escape hatch, overwriting is always a deliberate choice, never the only way
  out of a campaign.

**Autosave commits in place.** State is autosaved to the active slot at the
existing transition points (today's `save(auto: true)` in the `*Mode` / `*Event`
files). There is no manual save, no quicksave / quickload, and no working-buffer
split — the legacy `auto` / `main` two-tier scheme
(`PG/Extensions/UserDefaults.swift`) collapses to a single committed save per
slot, and the Save / Load menu buttons (`PG/HQ/HQEvent.swift`,
`PG/Tactical/TacticalMenu.swift`, `PG/Strategic/StrategicEvent.swift`) are
removed. Net code delta in the menus is *negative*.

This enforces the "permanent and precious" roster **structurally**, not by
runtime checks:

- **No "Save as"** → a roster can never be copied into another slot → no
  duplicate armies.
- **No quickload** → a lost battle can't be rolled back → the dead stay dead.
- **Load only resumes** a slot's latest state, never an older snapshot.

Autosave is the *enforcer* here, not a threat: it writes losses irreversibly.
Manual saving would be the opposite — it hands the commit point to the player,
who could decline to save after a defeat and relaunch on the old state. (One
residual: force-quitting in the instant between a loss and its autosave. The
save already fires synchronously right after `complete()`; fold the writeback
into `complete()` itself if it ever needs to be airtight.)

**Gating.** While a slot's campaign is active, the casual scenario / MP entries
are hidden — you commit to the campaign in that slot, Diablo-style (*campaign
**or** scenarios, never both at once*). To play a one-off, Load a different
slot. This also removes the footgun where an off-hand scenario would silently
mutate a campaign roster mid-run.

## State design

`StrategicSim` obeys the same constraints as the rest of the core: fully
inline, `BitwiseCopyable`, no heap/`String`/class fields (so `clone` / `encode`
/ `decode` stay valid — see [Architecture](./Architecture.md)). Following the
[Sim / UI split](./Architecture.md#sim--ui-split), presentation-only fields live
in a separate `StrategicUI`. The current implementation is deliberately lean:

```swift
// COR/Strategic/StrategicState.swift (implemented)
public struct StrategicSim: ~Copyable {
    public var owner: Map<32, Country>   // province ownership (political map)
    public var human: Country            // the country the player commands
    public var turn: UInt32
    public var battle: XY?               // contested tile while a battle runs; nil otherwise
}
public struct StrategicUI {              // never read by reduce; may diverge per peer
    public var cursor: XY
    public var camera: XY
}
```

`StrategicAction` is `attack(XY)` / `endTurn` today; the design envisions it
growing `commit([UID])` (hand-picked per-front deployment), `heal(...)`, and a
strategic `d20` for auto-resolve. The persistent roster itself stays in
`HQState`, not duplicated here. Per-country status (alive/prestige) and
capitals are not yet modeled.

**Optional — auto-resolve.** A deterministic strength comparison (using the
in-state `d20`) for trivial/lopsided fronts, so the player isn't forced to play
every skirmish. The single biggest "keep it HoI-*lite*" lever.

## Open items / prerequisites

- **~~Expand `Country` to the European nations.~~** *Done.*
  `COR/Model/Player.swift`'s `Country` enum now carries `.none` plus 23 nations
  — the original modern set plus the European cases (`nor`, `fin`, `ger`, `est`,
  `lva`, `ltu`, `pol`, `bel`, `cze`, `svk`, `aut`, `rom`, `hun`, `mol`) — and
  `Country.team` covers them all. `StrategicState.europe(human:)` builds the
  political map from an ASCII legend.
- **`Objective` + win-condition check** in `TacticalTurns` (today: last team
  standing only).
- **Battle-budget plumbing** through `TacticalState.make` and the in-battle
  shop, plus suppressing/capping in-battle income for campaign battles.
- **Roster capacity bump** (`HQState.units` and related `CArray` capacities) for
  the larger HQ pool.
- **Strategic AI** — a *new, much simpler* graph-walking AI (pick weak adjacent
  borders), not the tactical `TacticalAI`.
- **Slot persistence** (see [Persistence & slots](#persistence--slots)) —
  generalize `UserDefaults.Slot` from `{auto, main}` to a 4-way index, add the
  Load slot-select screen, drop the manual Save / Load buttons, and gate
  scenario / MP entry while a slot's campaign is active.

## Suggested phasing

1. **Province conquest** — political `Map<32, Country>`, turn-based, hand-pick
   commit, attack adjacent → launch `make()` battle → annex on win. Fixed
   teams. Reuses almost everything.
2. **Objectives** — add the `Objective` type and turn-limited win checks to
   Tactical (useful standalone, e.g. for scenarios).
3. **Economy & healing** — split prestige pools, expose the two heal modes,
   supply-distance budget.
4. **Difficulty & finale** — base-level knob, capital aux bump (both sides),
   strategic AI offensives against your provinces.
