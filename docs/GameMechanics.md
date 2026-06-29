# Game Mechanics

Panzer-General-style wargame. Combat plays out on a 32×32 tactical grid;
units are purchased with prestige, fight, gain experience, and capture cities.
All mechanics use integer arithmetic on inline state (see [Architecture](./Architecture.md)).

## Turn Structure

`COR/Tactical/TacticalTurns.swift`

- Players act in a fixed rotation. `playerIndex = turn % players.count`,
  `day = turn / players.count + 1`. A **day** ends when `playerIndex` wraps
  to `0`.
- `endTurn()` for the acting player runs in this order:
  1. **captureCities** — reflag settlements under the acting player's
     ground units; players with no remaining settlements are marked dead.
  2. **Prestige income** — the acting player is paid income from the
     settlements it controls (so each player earns once per day, on its turn).
  3. **Per living unit** of the acting player: resupply (ammo top-up if
     adjacent to a friendly `type == .supply` unit and no enemy nearby) →
     regen (`regen` skill, +1 HP) → entrench (ground only, towards terrain
     base) → rest (refresh `ap`/`mp` to max).
  4. Advance `turn` to the next living player and recompute its vision.
- If no more than one team is alive, no turn is advanced and the battle ends
  (`.end` event); `TacticalSim.winner` then interprets the result against the
  active `Objective`. See [Objectives & victory](#objectives--victory).

## Units

`COR/Model/Unit.swift`, `COR/Model/Units.swift`, `COR/Model/UnitStats.swift`

A `Unit` is a small value struct holding only **per-instance runtime state**
plus a `model` index; the model's fixed *stats* live in a static table:

```swift
public struct Unit: Equatable {
    public var model: UnitModel    // index into UnitStats.table
    public var country: Country
    public var hp, mp, ap, ammo, ent: UInt8
    public var exp, kills: UInt16
    public var skills: Skills       // earned on promotion
    public var bits: Bits           // per-instance flags (aux)
}
```

`unit.stats` is `UnitStats.table[model.rawValue]`, a 256-entry table built once
at load. Each `UnitModel` names a real platform (`.ranger`, `.leo2a6`, `.t90m`,
`.f35`, …) and maps to one `UnitStats` row; the stat accessors on `Unit`
(`type`, `tier`, `mov`, `rng`, `ini`, `softAtk`, `hardAtk`, `airAtk`,
`groundDef`, `airDef`, `traits`) just forward to that row. So all units of a
model share identical stats and differ only in runtime fields. The catalogue is
organised by team in `COR/Model/{Allied,Axis,Soviet}Units.swift`.

| Runtime field | Meaning |
|---------------|---------|
| `hp` | Health 0–15 (`maxHP = 0xF`). 0 = dead. |
| `mp` | Movement points this turn (`maxMP` = 2 air, else 1). |
| `ap` | Attack points this turn (`maxAP` = 1, or 0 if `rng == 0`). |
| `ammo` | Shots remaining; `maxAmmo` depends on type and `rng`. |
| `ent` | Entrenchment in quarter-units. Bonus `entDef = ent/4`, capped at `terrain.baseEntrenchment*4 + 20`. |
| `exp` | Experience; drives `lvl` (0–8) and `subLvl` (0–9 progress to next level). |
| `kills` | Lifetime kill count. |
| `skills` | `Skills` earned on promotion (see [Skills](#skills)). |
| `bits` | Per-instance flags; only `aux` today. |

| Model stat (`UnitStats`) | Meaning |
|--------------------------|---------|
| `type` | `UnitType` (drives most branching). |
| `tier` | Tech tier; gates the shop against `player.tier`. |
| `mov` | Move range. |
| `rng` | Attack range (reachable iff grid distance ≤ `rng*2+1`); `rng == 0` ⇒ no attack. |
| `ini` | Initiative — extra fire round + rugged-defence rolls. |
| `softAtk`/`hardAtk`/`airAtk` | Attack vs soft / armored / air targets. |
| `groundDef`/`airDef` | Defense vs ground / air attackers. |
| `traits` | Fixed `Traits` of the platform. |

**Unit types** (`UnitType`): `supply`, `inf`, `art`/`wheelArt`/`trackArt`,
`aa`/`wheelAA`/`trackAA`, `lightWheel`/`lightTrack`/`heavyTrack`, and three air
types `heli`/`fighter`/`cas`. Computed groupings: `isAir` (heli/fighter/cas),
`isArt` (any artillery type), `isAA` (any AA type plus `fighter`), `isArmor`
(any light/heavy wheeled or tracked vehicle), `transportable` (inf/art/aa).
`canAttackAfterMove` is false for foot `art`/`aa`.

`atk(_:)` picks the attack stat by the *target's* type: softAtk vs
`inf`/`supply`/`art`/`aa`/`wheelAA`/`wheelArt`; hardAtk vs
`trackArt`/`trackAA`/`lightWheel`/`lightTrack`/`heavyTrack`; airAtk vs
`heli`/`fighter`/`cas`. It then adds experience `lvl`: full `lvl` vs soft; vs
hard full `lvl` if the attacker `isArmor` else `lvl/2`; vs air full `lvl` if the
attacker `isAA` else `lvl/2`. A zero base stat means the attacker cannot damage
that class at all (returns 0). `def(src:)` is `groundDef` vs ground attackers or
`airDef` vs air attackers, plus `lvl/2`; all terrain modifiers live on
`Terrain`.

**Traits** (`Traits`, fixed per model in `UnitStats`):
- `transport` — can carry one transportable cargo (see Transport).
- `elite` — premium flag; also the required cargo type for *air* transports.
- `engineer` — faster entrenchment (higher `entRate`) and more fortification
  damage (`entDamage` 8 vs 4).
- `optics` — `spot = 3` (vision uses the precomputed n36 disc) instead of 2.
- `radar` — when firing on an air target, a friendly radar aura (self or
  8-neighbour) adds +2 attack.
- `atgm`, `aam` — reserved trait bits (see [Roadmap](./Roadmap.md)).

**Bits** (`Bits`, per-instance): only `aux` today — marks an auxiliary unit
(cheaper, drawn from a fixed pool, filtered out of campaign writeback).

**Experience & promotion.** `lvl = 8 - leadingZeroBitCount(exp)`, capping at 8;
`subLvl` (0–9) is the progress toward the next level. Damaging/killing enemies
grants `exp`; on a kill `promote(using:)` may roll to add one random `Skills`
bit — likelier the fewer skills the unit holds and the higher its level (a unit
can hold at most `lvl` skills). Healing costs `exp`. `Skills` are a separate
option set from the model's `Traits`.

## Movement

`COR/Tactical/TacticalMove.swift`

- BFS from the unit's tile within a budget of `mov*2 + 1`. Orthogonal step
  costs `terrain.moveCost(unit)*2`, diagonal `*3`, plus `n` per step where
  `n` is the number of enemies adjacent to the *source* tile (zone of
  control). A unit standing next to ≥2 enemies cannot step diagonally.
- `moveCost(_:)` is per-type. Roads/bridges/villages/cities/airfields are
  always 1 for ground units. Forests and hills run 2–3 (worse for wheels
  and heavy tracks); mountains and rivers cost the unit's full `mov`
  (one tile and done); mountains block wheeled types entirely.
- Air units pay 1 per tile and are blocked from no-fly zones (city,
  villages). Air and ground units cannot share tiles.
- Moving resets `ent` to 0 and spends 1 `mp`. Foot `art`/`aa` lose `ap` after
  moving (`!canAttackAfterMove`); wheeled and tracked variants do not.
- Walking onto a tile occupied by a hidden enemy interrupts the move and
  triggers a **surprise attack** on the blocker.
- Movement reveals fog of war along the route (vision disc each step).

**Vision / fog of war** (`COR/Tactical/TacticalState.swift`): each player sees the union
of unit vision discs (precomputed `n20` for `spot = 2`, `n36` for `optics`'s
`spot = 3`) plus the tile and 8-neighbourhood of every owned settlement. Per-player
vision lives in `TacticalSim.vision: [4 of SetXY]`, recomputed on each turn change.

## Combat

`COR/Tactical/TacticalAttack.swift`

`attack(src:dst:)` requires same-country attacker, enemy target, `ap>0`,
`ammo>0`, and target within `rng*2+1`. Sequence:

1. Spends 1 `ap`.
2. **Support fire** before the duel: if both sides are ground *and* the
   attacker is not artillery, an adjacent friendly artillery (`isArt`)
   of the defender fires on the attacker; if the attacker is air and the
   defender is not itself an AA type (`isAA`), an adjacent friendly AA
   (`isAA`) of the defender fires on the attacker.
3. **Rugged Defence** check (skipped only if attacker `isArt` *and* this
   is not a surprise): if
   `d20 + (su.ini+su.lvl)*2  <  (du.ent+du.ini+du.lvl)*2 + (surprise ? 10 : 0)`,
   defender fires first and the attacker's shot is delayed until after the
   counter. The +10 surprise bonus goes to the defender's side.
4. Attacker fires (`fire`), reducing defender `ent` by `entDamage`.
5. Defender counterattacks if alive, in range, can hit the attacker, and
   the matchup isn't (`isArt` attacker vs non-`isArt` defender without
   surprise). Counter `defMod` for the attacker (now being shot at) is
   `(isArt ? 0 : defenderTile.closeCombat(attackerType))
    + (ruggedDef ? −3 : 0) + (defenderOutOfAmmo ? +5 : 0)` —
   the +5 makes the out-of-ammo counter weaker.
6. Low-HP defenders may **retreat** (`du.hp*2 + du.ini + d20 < 20`) to the
   reachable tile farthest from the attacker.

**`fire(src:dst:defMod:)`** — the damage core:

- `atk = atk(target) + leadershipAura + reconAura + radarAura` (leadership /
  recon auras = +1 if the firing unit or a friendly neighbour has the skill;
  `radarAura` = +2 when the target is air and the firing side has the `radar`
  trait nearby). `lvl` is already folded into `atk(target)`.
- `def = def(attacker) + defMod + leadershipAura + reconAura`, with `lvl/2`
  folded into `def(attacker)` and `defMod = entDef + terrain.def(defType)
  + mountaineer + mhtn + diag − encirclement`.
  `entDef = ent/4`; `terrain.def(_:)` is a per-type bonus/penalty
  (negative on roads, bridges, rivers; positive on cover for foot/wheeled
  arty/AA; negative for wheels and tracks in cover, worst for heavy
  tracks); `encirclement` = `max(0, enemiesAround − 1)` so the first
  surrounder is free.
- `dif = atk − def`. Four thresholds `t1=max(0,7−dif)`, `t2=max(1,13−dif)`,
  `t3=max(2,19−dif)`, `t4=max(3,26−dif)`.
- Rounds = `(hp+2)/3 + (ini + lvl/2 > d20(max of 2) ? 1 : 0)`. Each round
  rolls `d20` (0–19): `>t4`→4, `>t3`→3, `>t2`→2, `>t1`→1, else 0 damage.
  `crit` may double a round (`d20>16`); `evasion` may zero it (`d20>16`).
- Damage hits the unit (and its cargo). Each shot grants
  `dmg * du.cost / 32` exp if the defender survives, `dmg * du.cost / 24`
  if the shot kills. A kill also grants a flat `du.cost / 16` prestige
  bounty and rolls for promotion. `estimateDamage` is the AI's
  deterministic preview.

`D20` is a SplitMix64 PRNG (`COR/Foundation/D20.swift`) seeded per battle so
combat is reproducible.

## Terrain

`COR/Model/Terrain.swift`

- **Tile kinds** include `field`, `forest`, `hill`, `forestHill`,
  `mountain`, `water` (rivers), `bridgeWE`/`bridgeSN`, a 7-way road
  system (`roadNW`/`roadNE`/`roadWE`/`roadSN`/`roadSW`/`roadSE`/`roadX`),
  and the settlements `city`, `airfield`, and 4-direction villages
  (`villageE`/`villageN`/`villageW`/`villageS`). `isSettlement` is true
  for cities, airfields, and villages — all three are capturable.
- **Move cost** varies by `UnitType`. Roads, bridges, and settlements are
  always 1 for ground units. Rivers cost the full `mov` (one tile, then
  done). Forests/hills cost 2–3 for foot and wheeled units, less for
  tracked. Mountains block wheels entirely (`0x10`) and cost foot units
  their full `mov`. Air units pay 1 per tile unless the tile is a
  no-fly zone (city, village).
- **Base entrenchment** (per tile, before the `*4` scaling):
  field 0; hill/airfield 1; forest/forestHill/mountain/villages 2;
  city 3. Standing still, ground units gain `entRate` per turn
  (supply/inf 4; foot art/aa, wheeled vehicles, light tracks 3;
  heavy/track variants 2; air 0 — all doubled by `engineer`) up to
  `base*4 + 20`.
- **`terrain.def(unitType)`** is a per-tile defensive modifier applied
  to whoever sits on the tile. Roads -1, bridges -2, rivers -2 to -5
  by type, hill/airfield +1 / -1 / -2 (foot-ish / light / heavy track),
  forest/village +2 / -2 / -4, city/mountain/forestHill +3 / -3 / -6.
  Air units ignore terrain. **`terrain.closeCombat(unitType)`** is the
  attacker-side penalty applied during a counter: rough terrain
  penalizes wheeled and tracked attackers (heavy track worst), and is 0
  for foot/artillery/AA and air.
- **Highground** (hill/forestHill/mountain) with `mountaineer`: defender
  with the skill gets +2 to `defMod`; attacker with the skill subtracts 1
  from `defMod` (i.e. +1 effective attack). The two stack.

## Supply, Repair, Entrench

`COR/Tactical/UnitResupply.swift`

The `resupply(unit:endOfTurn:into:)` routine drives both the player-initiated
`.resupply` action *and* the per-unit end-of-turn pass. Behavior differs:

- **Ammo**. Player-initiated (untouched only) restores
  `(noEnemy ? 2 : 1) * (supplyBonus + 1)`. End-of-turn restores 1 only when
  `noEnemy && supplyBonus > 0`. `supplyBonus` = (adjacent friendly
  `type == .supply` ? 1 : 0) + (adjacent owned settlement of matching
  airfield/non-airfield kind ? 1 : 0). Air units only gain ammo adjacent
  to such a building.
- **Healing**. *Only* on the player-initiated path (untouched units).
  Heal cap = `(noEnemy ? 3 : 2) * (supplyBonus + 1)`. Each HP healed
  spends `3 << lvl` exp and `cost/32` prestige. Air heals only adjacent
  to an owned building.
- **Regen**. End-of-turn only; the `regen` skill grants +1 HP (air
  needs a building).
- **Entrench**. End-of-turn only; ground units `ent ← min(base+20, max(base, ent + entRate))`
  where `base = terrain.baseEntrenchment * 4`.
- **Rest**. End-of-turn only; `ap`/`mp` refresh to max.

## Transport

`COR/Tactical/TacticalTransport.swift`

Transportable types (`inf`, `art`, `aa`) can `embark` an adjacent friendly
unit carrying the `transport` trait (one slot, `cargo`). Air transports
additionally require the cargo to be `elite`. The transport carries the
unit; `disembark` drops it on an empty adjacent tile (with movement and
attack spent that turn, and `ap` zeroed for foot `art`). Damage to a
loaded transport also damages its cargo; destroying it kills the cargo.

## Economy & Shop

`COR/Tactical/TacticalShop.swift`, `COR/Model/Shop.swift`, `COR/Model/Templates.swift`

- Each player has **prestige** (default `0xF00`; campaigns set `.poor` = `0x0A00`
  / `.rich` = `0x1F00`). Income per day = sum of owned settlements' income
  (`Terrain.income` in `COR/Tactical/TacticalState.swift`: city 24, village 8,
  airfield 4).
- Buying at an owned, enemy-free settlement (`shopUnits`/`buy`) spawns a
  unit if prestige ≥ `unit.cost`. Airfields sell air units; cities (and
  villages) sell ground. Bought units start at `lvl += player.baseLevel`.
- **Catalogue**: the core list is `Shop(country:air:tier:).units` — the full
  per-country roster (`COR/Model/Shop.swift`) filtered by the building's
  air/ground kind and by `player.tier` (units above the player's tech tier are
  hidden). Auxiliary units come from the per-player `auxilia` pool (seeded from
  `[Unit].aux(country)`), filtered by air/ground; an aux unit is consumed from
  the pool when bought.
- **Slots**: up to 16 core + 16 auxiliary units per player.
- **HQ upgrades** (`Shop.upgrades(for:)`, `HQAction.upgrade`): a deployed roster
  unit can be re-equipped with another model in the same shop **family** (inf,
  recon, ifv, tank, art, aa, air) that the current tier unlocks — select the
  unit (`.a`) and press `.c` to open the upgrade menu (`.d` sells it; `.c` over
  an empty slot opens the purchase shop). The crew's veterancy
  (`exp`, `kills`, skills, bits) carries over; the upgrade is charged the full
  cost of the resulting unit (`Unit.upgradeCost` = the new platform at the
  unit's current level), with no credit for the old platform. Supply (the
  truck) has no family and cannot be upgraded.
- **Unit `cost`** =
  `(typeCost + traitCost + skillCost + weightedStats) / (aux ? 7 : 4)`:
  - `typeCost`: inf/aa/art 10; supply/wheelAA/wheelArt/lightWheel 100;
    trackAA/lightTrack 150; trackArt/heavyTrack 220; heli 270; fighter/cas 330.
  - `traitCost = traitsCount * 15`; `skillCost = skillsCount * 15`.
  - `weightedStats = (lvl + 4) * (softAtk*4 + hardAtk*5 + airAtk*6 + groundDef*4
    + airDef*4 + ini*4 + mov*4 + rng*7)`.
  - `lvl + 4` makes veterans (and the skills they earn) linearly pricier; `aux`
    divides by 7 instead of 4.

## Players & Victory

`COR/Model/Player.swift`, `COR/Tactical/TacticalTurns.swift`

- `Country` (a `UInt8` enum: `.none` plus 23 playable nations) maps to one of
  three `Team`s via `Country.team`: **axis** (swe/den/ned/ukr/ger/pol/cze/aut/nor),
  **allies** (isr/pak/usa/fin/ltu/svk/hun), **soviet** (ind/irn/rus/est/lva/bel/rom/mol).
  `.none` maps to `Team.none`. Friendly fire is impossible within a team; combat
  requires cross-team. The European nations back the campaign map (see
  [Campaign](./Campaign.md)).
- `PlayerType`: `human`, `remote` (network), `ai` (`COR/Tactical/AI/TacticalAI.swift`).
- A ground unit standing on a settlement controlled by a different team
  reflags it to the unit's country. A player with no remaining
  settlements is eliminated (`alive = false`). Last team standing wins,
  unless an `Objective` decides the battle first.

### Objectives & victory

`COR/Tactical/TacticalState.swift`, `COR/Tactical/TacticalTurns.swift`

Every battle carries an `Objective` on `TacticalSim`:

- `none` — last team standing (the default; scenarios and multiplayer use
  it, so they behave exactly as before).
- `survive(Team, day: UInt16)` — the named team wins by staying alive until the
  day count passes the deadline. If that team is annihilated first, the opposing
  team wins immediately; otherwise, once `day` exceeds the deadline, the surviving
  team is the winner. (`day` is `Int(turn) / players.count + 1`.)

Campaign battles are 1v1, so a single objective covers both sides: `survive` is
the defender's goal and, from the attacker's view, the deadline it must beat by
annihilating the defender (capturing every settlement eliminates a player). The
result is the computed property `TacticalSim.winner` (`TacticalTurns.swift`),
returning `Team?`; it stays `nil` while the battle is undecided. `Core.complete`
reads `won = sim.winner == humanTeam`, so a repulse is `winner` being the
surviving defender or `nil` (a player-driven abandon/draw).

> **Not yet wired:** `winner` is read only by `Core.complete`, not by the
> end-of-turn pass. `endTurn` still emits `.end` purely on last-team-standing,
> so a `survive` deadline does not by itself end a live battle — it is decided
> when the battle ends by annihilation or a manual Retreat/Abandon/Draw.

### Map mode

`TacticalUI.mapMode` (presentation-only; `state.ui.mapMode`) toggles between
`.terrain` and `.political` — the political view recolors tiles by `control`
(country/team), the terrain view shows the underlying tile sprite. Bound to the
`.mode` input event.

### Skills:

16 bit option set, each skill is rolled randomly on successful unit promotion

- `leadership`: aura — self and 8-neighbours get +1 atk/def while in range.
- `recon`: aura — self and 8-neighbours get +1 atk/def while in range.
- `crit`: 15% chance (`d20>16`) to double a round's damage.
- `evasion`: 15% chance (`d20>16`) to zero a round's incoming damage.
- `regen`: +1 HP at end of own turn (air needs an owned building).
- `mountaineer`: on highground (hill/forestHill/mountain), defender with
  this skill +2 defMod; attacker with this skill −1 defMod (i.e. +1 atk).
- `mhtn`: −1 defMod when the attack is along a row/column (`dx == 0` or
  `dy == 0`).
- `diag`: −1 defMod when the attack is on a pure diagonal (`|dx| == |dy|`).


### Proposed skills:

- `armor`: only takes dmg that is > 1 per round.
- `pillage`: prestige on dmg.

### Proposed traits:

- `atgm`, `aam`: boosts hard/air attack of the unit at the expence of higher ammo consumption.
