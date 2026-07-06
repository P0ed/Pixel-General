# Campaign

A turn-based strategic layer over the tactical battles — "Hearts of Iron by
vibes". You command one country on a political map of
Europe, push offensives against adjacent enemy provinces,
and each offensive resolves as a [tactical battle](./GameMechanics.md). The
hook is **RPG progression**: a *persistent roster* that gains experience,
skills, and upgrades across the whole campaign — and that you can later stake
in multiplayer, where you can lose all of it.

This lives in the `Strategic` module (`COR/Strategic/`, `PG/Strategic/`). See
[Architecture](./Architecture.md) for the `SceneMode` pipeline, the `Sim`/`UI`
split, the `~Copyable` / `BitwiseCopyable` constraints, and the `Core` root
state these build on.

## Design pillars

- **Fixed teams for now.** The dynamic-diplomacy / `Country`→`Team` redesign is
  deferred (see [Open items](#open-items--prerequisites)). Campaign teams use
  the existing hardcoded `Country.team`.
- **Every campaign battle is 1v1** (two teams). Free-for-all is reserved for
  scenario and multiplayer.
- **Fronts, not stacks.** No movable strategic army pieces. A country attacks
  across a border; strength *is* the roster + predeployed aux units from current front.
- **Multiple simultaneous fronts** are allowed and are a core pressure source.
- **The roster is permanent and precious.** Survivors carry forward; the dead
  stay dead; losing the campaign can cost it entirely.

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
  the turn counter, and the strategic AI. Picking an adjacent (`XY.n4`) enemy province
  and committing units launches a battle.
- **Tactical** generates the battle via the
  `TacticalState(players:objective:units:size:seed:terrain:)` initializer
  (`COR/Tactical/TacticalStateFactory.swift`) seeded by the contested border,
  carrying an `Objective` and the contested province's dominant terrain
  (`StrategicSim.terrain`), which biases map generation toward hills or
  mountains.
- **`Core.complete()`** does the writeback: it returns the
  surviving core units and the player's prestige to HQ
  (`Core.complete` filters `u[.aux]`), and applies the result to the strategic
  map via `resolveBattle(at:won:by:)` with `won = sim.winner == humanTeam`.

## Strategic map

- **Ownership** changes by flipping province tiles when `resolveBattle` records a win.

**Supply-distance budget (the main anti-snowball lever).** Each offensive draws
a reinforcement/prestige budget that **shrinks with province-graph distance
from your own territory.** Attacking a border province is well-supplied;
pushing several provinces deep is a shoestring force with no reinforcements.
This is what physically prevents a blitz across a large country — you must
consolidate a front before the next push.

## Battles: the bridge to Tactical

A campaign battle is a `TacticalState` with `.survive` objective. The
objective lives on `TacticalSim` (`COR/Tactical/TacticalState.swift`,
`COR/Tactical/TacticalTurns.swift`):

```swift
@frozen public enum Objective: Equatable, BitwiseCopyable {
    case none                       // FFA (scenarios, multiplayer)
    case survive(Team, day: UInt16) // `Team` wins by staying alive through `day`
}
```

## Difficulty

Two orthogonal knobs, set at campaign start (alongside the existing
starting-prestige toggle in `PG/HQ/HQScenario.swift`):

- **Starting prestige** — how *much* the AI can field and reinforce
  (`.poor` / `.rich`, already implemented).
- **Enemy base level** — how *good* each enemy unit is (`0` / `2` / `4`).

## The capital fight

The climactic assault on a country's capital gets a one-time intensity spike:
extra **leveled `aux` units** drawn from the existing `.aux(country:)` pool.

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

## State design

`StrategicSim` obeys the same constraints as the rest of the core: fully
inline, `BitwiseCopyable`, no heap/`String`/class fields (so `clone` / `encode`
/ `decode` stay valid — see [Architecture](./Architecture.md)).

```swift
public struct StrategicSim: ~Copyable {
    public var owner: Map<32, Country>   // province ownership (political map)
    public var terrain: Map<32, Terrain> // dominant terrain (field/hill/mountain)
    public var human: Country            // the country the player commands
    public var turn: UInt32
    public var battle: XY?               // contested tile while a battle runs; nil otherwise
}
public struct StrategicUI {              // never read by reduce; may diverge per peer
    public var cursor: XY
    public var camera: XY
}
```
