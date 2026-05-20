# Game Mechanics

Panzer-General-style wargame. Combat plays out on a 32×32 tactical grid;
units are purchased with prestige, fight, gain experience, and capture cities.
All mechanics use integer arithmetic on inline state (see [Architecture](./Architecture.md)).

## Turn Structure

`Tactical/State/TacticalTurns.swift`

- Players act in a fixed rotation. `playerIndex = turn % players.count`,
  `day = turn / players.count + 1`. A **day** ends when `playerIndex` wraps
  to `0`.
- `endTurn()` for the acting player runs in this order:
  1. **captureCities** — reflag buildings under the acting player's ground
     units; players with no remaining cities are marked dead.
  2. **Per living unit** of the acting player: resupply (ammo top-up if
     adjacent to a friendly `supply` and no enemy nearby) → regen (`regen`
     trait, +1 HP) → entrench (ground only, towards terrain base) → rest
     (refresh `ap`/`mp` to max).
  3. **Player upkeep**: vision is recomputed and prestige income is paid.
  4. Advance `turn` to the next living player.
- The battle ends when only one team remains alive (`.end` event).

## Units

`Model/Unit.swift`, `Model/Units.swift`

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
| `mov` | Move range (BFS depth in steps). |
| `rng` | Attack range (tiles reachable = grid distance ≤ `rng*2+1`). |
| `ini` | Initiative — extra fire round + rugged-defence rolls. |
| `softAtk`/`hardAtk`/`airAtk` | Attack vs soft / armored / air targets. |
| `groundDef`/`airDef` | Defense vs ground / air attackers. |

**Unit types** (`UnitType`): `soft`, `softWheel`, `lightWheel`, `lightTrack`,
`heavyTrack`, `heli`, `jet`. `heli`/`jet` are air units (`isAir`). Attack value
is chosen by target type via `atk(_:)`; defense by attacker via `def(_:)`.

**Traits** (`Traits` option set):
- `aux` — auxiliary unit, half cost; bought from a fixed pool.
- `art` — artillery; provides defensive support fire when an adjacent ally
  is attacked, and shrugs off counterattacks from non-art defenders unless
  it's a surprise. Soft-type artillery loses `ap` after moving.
- `aa` — anti-air; provides support fire to an adjacent ally attacked from
  the air (when that ally lacks `aa` itself).
- `supply` — adjacent friendlies get a supply bonus to ammo/HP refills.
- `elite` — flag for premium templates.
- `transport` — can carry one `soft` cargo (see Transport).
- `radar` — `spot = 3` (vision radius `2*spot = 6`) instead of 2.

**Experience & promotion.** `lvl = 8 - leadingZeroBitCount(exp)`, capping at
8. Killing/damaging enemies grants `exp`; on a kill `promote(using:)` may roll
to add a random combat skill. Healing costs `exp`.

## Movement

`Tactical/State/TacticalMove.swift`

- BFS from the unit's tile within a budget of `mov*2 + 1`. Orthogonal step
  costs `terrain.moveCost*2`, diagonal `*3`, plus `n` per step where `n`
  is the number of enemies adjacent to the *source* tile (zone of control).
  A unit standing next to ≥2 enemies cannot step diagonally.
- Air units pay `moveCost` 1 per tile regardless of terrain; they cannot
  share tiles with ground units and vice versa.
- Moving resets `ent` to 0 and spends 1 `mp`. Soft-type artillery cannot
  attack after moving (`ap` is zeroed).
- Walking onto a tile occupied by a hidden enemy interrupts the move and
  triggers a **surprise attack** on the blocker.
- Movement reveals fog of war along the route (vision disc each step).

**Vision / fog of war** (`TacticalAction.swift`): each player sees the union of
unit vision discs (`2*spot`, spot = 3 with `radar` else 2) and a radius-3 disc
around owned buildings.

## Combat

`Tactical/State/TacticalAttack.swift`

`attack(src:dst:)` requires same-country attacker, enemy target, `ap>0`,
`ammo>0`, and target within `rng*2+1`. Sequence:

1. Spends 1 `ap`.
2. **Support fire** before the duel: if both sides are ground *and* the
   attacker is not artillery, an adjacent friendly `art` of the defender
   fires on the attacker; if the attack is from the air and the defender
   lacks `aa` itself, an adjacent friendly `aa` of the defender fires on
   the attacker.
3. **Rugged Defence** check (skipped only if attacker is `art` *and* this
   is not a surprise): if
   `d20 + (su.ini+su.lvl)*2  <  (du.ent+du.ini+du.lvl)*2 + (surprise ? 10 : 0)`,
   defender fires first and the attacker's shot is delayed until after the
   counter. The +10 surprise bonus goes to the defender's side — ambushed
   units are more likely to dig in.
4. Attacker fires (`fire`), reducing defender `ent` by 1 (one quarter-unit).
5. Defender counterattacks if alive, in range, can hit the attacker, and
   the matchup isn't (attacker art vs non-art defender without surprise).
   Counter `defMod` for the attacker (now being shot at) is
   `(art ? 0 : defenderTile.combatPenalty(attackerType))
    + (ruggedDef ? −3 : 0) + (defenderOutOfAmmo ? +5 : 0)` —
   the +5 makes the out-of-ammo counter weaker.
6. Low-HP defenders may **retreat** (`du.hp*2 + du.ini + d20 < 20`, never
   against artillery) to the reachable tile farthest from the attacker.

**`fire(src:dst:defMod:)`** — the damage core:

- `atk = atk(target) + lvl + fullAmmoBonus + leadershipAura + reconAura`
  (fullAmmoBonus = 1 if attacker had full ammo entering the shot).
- `def = def(attacker) + lvl + defMod + leadershipAura + reconAura`
  where `defMod = entDef + terrain.combatPenalty(defType)
  + mountaineer + mhtn + diag − encirclement`.
  `entDef = ent/4`; `combatPenalty` is negative on unfavorable terrain (e.g.
  roads, bridges, rivers, open field for soft); `encirclement` =
  `max(0, friendlyEnemiesAround − 1)` so the first surrounder is free.
- `dif = atk − def`. Three thresholds `t1=max(0,7−dif)`,
  `t2=max(5,15−dif)`, `t3=max(10,24−dif)`.
- Rounds = `(hp+3)/3 + (ini > d20(max 2) ? 1 : 0)`. Each round rolls `d20`
  (0–19): `>t3`→3, `>t2`→2, `>t1`→1, else 0 damage. `crit` may double a
  round (`d20>16`); `evasion` may zero it (`d20>16`).
- Damage hits the unit (and its cargo). Every shot grants `dmg * du.cost / 24`
  exp; a killing shot grants `dmg * du.cost / 16` instead, plus a
  `cost/16` prestige bounty and a promotion roll. `estimateDamage` is the
  AI's deterministic preview.

`D20` is a SplitMix64 PRNG (`Engine/Foundation/D20.swift`) seeded per battle so
combat is reproducible.

## Terrain

`Model/Terrain.swift`

- **Move cost** varies by `UnitType` (roads always 1; rivers cost a ground
  unit its full `mov` — one tile and done; mountains block wheels).
- **Base entrenchment** (per tile, before the `*4` scaling):
  field 0; hill/airfield/T-road 1; forest/forestHill/mountain/cross-road 2;
  city 3. Standing still, ground units gain `entRate` per turn (soft 4,
  wheels & light tracks 3, heavy tracks 2, air 0) up to `base*4 + 20`.
- **`combatPenalty(unitType)`** is a per-tile defensive *penalty* applied
  to whoever sits on the tile. Road/bridge/river penalize crossing units;
  open field penalizes soft infantry; rough terrain (forest, city,
  mountain, forestHill) penalizes wheels and tracks, heavy tracks worst.
  Air units ignore terrain penalties.
- **Highground** (hill/forestHill/mountain) with `mountaineer`: defender
  with the skill gets +2 to `defMod`; attacker with the skill subtracts 1
  from `defMod` (i.e. +1 effective attack). The two stack.

## Supply, Repair, Entrench

`Tactical/State/TacticalAction.swift`

The `resupply(unit:endOfTurn:)` routine drives both the player-initiated
`.resupply` action *and* the per-unit end-of-turn pass. Behavior differs:

- **Ammo**. Player-initiated (untouched only) restores
  `(noEnemy ? 2 : 1) * (supplyBonus + 1)`. End-of-turn restores 1 only when
  `noEnemy && supplyBonus > 0`. `supplyBonus` = (adjacent friendly `supply` ? 1 : 0)
  + (adjacent owned airfield/city ? 1 : 0). Air units only gain ammo
  adjacent to an owned building.
- **Healing**. *Only* on the player-initiated path (untouched units).
  Heal cap = `(noEnemy ? 3 : 2) * (supplyBonus + 1)`. Each HP healed
  spends `3 << lvl` exp and `cost/32` prestige. Air heals only adjacent
  to an owned building.
- **Regen**. End-of-turn only; `regen`-trait units +1 HP (air needs a
  building).
- **Entrench**. End-of-turn only; ground units `ent ← min(base+20, max(base, ent + entRate))`
  where `base = terrain.baseEntrenchment * 4`.
- **Rest**. End-of-turn only; `ap`/`mp` refresh to max.

## Transport

`Tactical/State/TacticalTransport.swift`

`soft` infantry can `embark` an adjacent friendly `transport` unit (one slot,
`cargo`). The transport carries it; `disembark` drops it on an empty adjacent
tile (with movement/attack spent that turn). Damage to a loaded transport also
damages its cargo; destroying it kills the cargo.

## Economy & Shop

`Tactical/State/TacticalShop.swift`, `Model/Templates.swift`

- Each player has **prestige** (starts `0xF00`). Income per day = sum of owned
  buildings' income (city `0x12`, airfield `0x06`).
- Buying at an owned, enemy-free building (`shopUnits`/`buy`) spawns a unit if
  prestige ≥ `unit.cost`. Airfields sell air units; cities sell ground.
- **Slots**: up to 16 core + 16 auxiliary units per player. Core units come
  from `[Unit].shop`; auxiliary units are drawn from a fixed `aux` pool and
  cost less (consumed from the pool when bought).
- **Unit `cost`** =
  `(lvl + 3) * (typeCost + traitCost + statSum * sumMult) / (aux ? 6 : 3)`
  where `sumMult = 4` for artillery, `3` otherwise.
  - `typeCost`: soft 33, softWheel 47, lightWheel 100, lightTrack 120,
    heavyTrack 150, heli 180, jet 220.
  - `traitCost = traitsCount * 15`.
  - `statSum = softAtk + hardAtk + airAtk + groundDef + airDef + ini + mov + rng`.
  - `lvl + 3` makes veterans linearly pricier; `aux` halves the result.

## Players & Victory

`Model/Player.swift`, `TacticalTurns.swift`

- `Country` maps to one of three `Team`s: **axis** (swe/den/ned/ukr),
  **allies** (isr/pak/usa), **soviet** (ind/irn/rus). Friendly fire is
  impossible within a team; combat requires cross-team.
- `PlayerType`: `human`, `remote` (network), `ai` (`Tactical/State/TacticalAI`).
- Capturing every tile-occupying ground unit reflags buildings to the
  occupier's country. A player with no remaining cities is eliminated
  (`alive = false`). Last team standing wins.

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
