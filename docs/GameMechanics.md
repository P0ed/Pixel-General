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
  2. **Per living unit** of the acting player: resupply (ammo top-up if
     adjacent to a friendly `type == .supply` unit and no enemy nearby) →
     regen (`regen` skill, +1 HP) → entrench (ground only, towards terrain
     base) → rest (refresh `ap`/`mp` to max).
  3. **Player upkeep**: vision is recomputed and prestige income is paid.
  4. Advance `turn` to the next living player.
- The battle ends when only one team remains alive (`.end` event).

## Units

`COR/Model/Unit.swift`, `COR/Model/Units.swift`

A `Unit` is a value struct of `UInt8` stats:

| Field | Meaning |
|-------|---------|
| `hp` | Health, 0–15. 0 = dead. |
| `mp` | Movement points this turn (`maxMP` = 1, air = 2). |
| `ap` | Attack points this turn (`maxAP` = 1). |
| `ammo` | Shots remaining; `maxAmmo` depends on type/traits. |
| `ent` | Entrenchment in quarter-units. Effective bonus `entDef = ent/4`. Capped at `terrain.baseEntrenchment*4 + 20`. |
| `exp` | Experience, drives `lvl` (0–8). |
| `kills` | Lifetime kill count. |
| `mov` | Move range. |
| `rng` | Attack range (tiles reachable = grid distance ≤ `rng*2+1`). |
| `ini` | Initiative — extra fire round + rugged-defence rolls. |
| `softAtk`/`hardAtk`/`airAtk` | Attack vs soft / armored / air targets. |
| `groundDef`/`airDef` | Defense vs ground / air attackers. |

**Unit types** (`UnitType`): `supply`, `inf`, `art`/`wheelArt`/`trackArt`,
`aa`/`wheelAA`/`trackAA`, `lightWheel`, `lightTrack`, `heavyTrack`, `heli`,
`jet`. `heli`/`jet` are air units (`isAir`). Computed groupings: `isArt`
(any artillery type), `isAA` (any AA type plus `jet`), `isArmor` (any
light/heavy wheeled or tracked combat vehicle). `atk(_:)` picks softAtk
for `inf`/`supply`/`art`/`aa`/`wheelArt`/`wheelAA` targets, hardAtk for
`trackArt`/`trackAA` and any `lightWheel`/`lightTrack`/`heavyTrack`
target, airAtk for `heli`/`jet`, then adds the attacker's experience
`lvl`: full `lvl` vs soft targets; vs hard targets full `lvl` if the
attacker `isArmor` else `lvl/2`; vs air targets full `lvl` if the
attacker `isAA` else `lvl/2`. `def(src:)` is `groundDef` vs ground
attackers or `airDef` vs air attackers, plus the defender's full `lvl`;
all terrain modifiers live on `Terrain`.

**Traits** (`Traits` option set):
- `aux` — auxiliary unit, half cost; bought from a fixed pool.
- `optics`, `atgm`, `aam` — reserved trait bits (see [Roadmap](./Roadmap.md)).
- `engineer` — faster entrenchment and increased damage to enemy fortifications.
- `elite` — flag for premium templates; also required cargo for air transports.
- `transport` — can carry one transportable cargo (see Transport).
- `radar` — `spot = 3` (vision uses the precomputed n36 disc) instead of 2.

**Experience & promotion.** `lvl = 8 - leadingZeroBitCount(exp)`, capping at
8. Killing/damaging enemies grants `exp`; on a kill `promote(using:)` may roll
to add a random combat skill. Healing costs `exp`.

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
- Moving resets `ent` to 0 and spends 1 `mp`. The foot `art` type loses
  `ap` after moving; wheeled and tracked artillery do not.
- Walking onto a tile occupied by a hidden enemy interrupts the move and
  triggers a **surprise attack** on the blocker.
- Movement reveals fog of war along the route (vision disc each step).

**Vision / fog of war** (`COR/Tactical/TacticalAction.swift`): each player sees the union
of unit vision discs (precomputed `n20` for `spot = 2`, `n36` for `radar`'s
`spot = 3`) plus the tile and 8-neighbourhood of every owned settlement.

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

- `atk = atk(target) + leadershipAura + reconAura` (each aura = +1 if the
  firing unit or a friendly neighbour has the skill). `lvl` is already
  folded into `atk(target)`.
- `def = def(attacker) + defMod + leadershipAura + reconAura`, with `lvl`
  folded into `def(attacker)` and `defMod = entDef + terrain.def(defType)
  + mountaineer + mhtn + diag − encirclement`.
  `entDef = ent/4`; `terrain.def(_:)` is a per-type bonus/penalty
  (negative on roads, bridges, rivers; positive on cover for foot/wheeled
  arty/AA; negative for wheels and tracks in cover, worst for heavy
  tracks); `encirclement` = `max(0, enemiesAround − 1)` so the first
  surrounder is free.
- `dif = atk − def`. Four thresholds `t1=max(0,9−dif)`, `t2=max(1,15−dif)`,
  `t3=max(2,21−dif)`, `t4=max(3,27−dif)`.
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
  heavy/track variants 2; air 0) up to `base*4 + 20`.
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

`COR/Tactical/TacticalAction.swift`

The `resupply(unit:endOfTurn:)` routine drives both the player-initiated
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

`COR/Tactical/TacticalShop.swift`, `COR/Model/Templates.swift`

- Each player has **prestige** (starts `0xF00`). Income per day = sum of
  owned settlements' income (city `0xF`, village `0x7`, airfield `0x3`).
- Buying at an owned, enemy-free settlement (`shopUnits`/`buy`) spawns a
  unit if prestige ≥ `unit.cost`. Airfields sell air units; cities (and
  villages) sell ground.
- **Slots**: up to 16 core + 16 auxiliary units per player. Core units come
  from `[Unit].shop`; auxiliary units are drawn from a fixed `aux` pool and
  cost less (consumed from the pool when bought).
- **Unit `cost`** =
  `(lvl + 3) * (typeCost + traitCost + statSum * sumMult) / (aux ? 6 : 3)`
  where `sumMult = 4` if the unit `isArt`, `isAA`, or `isAir`; `3` otherwise.
  - `typeCost`: supply 22, inf 33, art 47, aa 68, wheelArt 100, wheelAA 120,
    trackArt 150, trackAA 180, lightWheel 100, lightTrack 120, heavyTrack 150,
    heli 180, jet 220.
  - `traitCost = traitsCount * 15`.
  - `statSum = softAtk + hardAtk + airAtk + groundDef + airDef + ini + mov + rng`.
  - `lvl + 3` makes veterans linearly pricier; `aux` halves the result.

## Players & Victory

`COR/Model/Player.swift`, `COR/Tactical/TacticalTurns.swift`

- `Country` maps to one of three `Team`s: **axis** (swe/den/ned/ukr),
  **allies** (isr/pak/usa), **soviet** (ind/irn/rus). Friendly fire is
  impossible within a team; combat requires cross-team.
- `PlayerType`: `human`, `remote` (network), `ai` (`COR/Tactical/AI/TacticalAI.swift`).
- A ground unit standing on a settlement controlled by a different team
  reflags it to the unit's country. A player with no remaining
  settlements is eliminated (`alive = false`). Last team standing wins.

### Map mode

`TacticalState.mapMode` toggles between `.terrain` and `.political` —
the political view recolors tiles by `control` (country/team), the
terrain view shows the underlying tile sprite. Bound to the `.mode`
input event.

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

- `armor`: only takes dmg that is > 1 per round
- `pillage`: prestige on dmg

### Proposed traits:

- `engineer`: entrenches faster, ignores enemy ent
