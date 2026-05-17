# Game Mechanics

Panzer-General-style wargame. Combat plays out on a 32×32 tactical grid;
units are purchased with prestige, fight, gain experience, and capture cities.
All mechanics use integer arithmetic on inline state (see [Architecture](./Architecture.md)).

## Turn Structure

`Tactical/State/TacticalTurns.swift`

- Players act in a fixed rotation. `playerIndex = turn % players.count`,
  `day = turn / players.count + 1`.
- `endTurn()` captures cities under the acting player's units, then advances
  `turn`. When `playerIndex` wraps to `0`, a new **day** starts.
- **Start of day** (per living player): vision is recomputed and prestige
  income is paid. Per living unit: regen → entrench → resupply → rest.
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
| `ent` | Entrenchment, 0–7 (defensive bonus). |
| `exp` | Experience, drives `stars` (0–4). |
| `mov` | Move range. |
| `rng` | Attack range (tiles = `rng*2+1` in grid distance). |
| `ini` | Initiative — extra fire round + rugged-defence rolls. |
| `softAtk`/`hardAtk`/`airAtk` | Attack vs soft / armored / air targets. |
| `groundDef`/`airDef` | Defense vs ground / air attackers. |

**Unit types** (`UnitType`): `soft`, `softWheel`, `lightWheel`, `lightTrack`,
`heavyTrack`, `heli`, `jet`. `heli`/`jet` are air units (`isAir`). Attack value
is chosen by target type via `atk(_:)`; defense by attacker via `def(_:)`.

**Traits** (`Traits` option set): `aux`, `art` (artillery — defensive support
fire, no counterattack received in melee), `aa` (anti-air support), `supply`,
`elite`, `transport`, `radar` (spot 3 vs 2), `leadership`/`recon` (adjacent
friendly aura: +1 atk/def), `crit` (chance to double damage), `evasion`
(chance to negate damage), `regen` (heal 1 HP/day), `mountaineer` (highground
def), `mhtn`/`diag` (directional defense vs straight/diagonal attacks).

**Experience & promotion.** `stars = 4 - leadingZeroBitCount(exp)`, capping at
4. Killing/damaging enemies grants `exp`; on a kill `promote(using:)` may roll
to add a random combat trait. Healing costs `exp` (`healLoosingXP`).

## Movement

`Tactical/State/TacticalMove.swift`

- BFS from the unit's tile within `mov` range. Orthogonal step costs
  `terrain.moveCost*2`, diagonal `*3`, plus +1 per adjacent enemy (zone of
  control); a unit with ≥2 adjacent enemies cannot move diagonally.
- Air units always pay `moveCost` 1 per tile.
- Moving resets `ent` to 0 and spends 1 `mp`. Soft artillery can not attack after move.
- Moving through a hidden enemy triggers an interrupting **surprise attack**.
- Movement reveals fog of war along the route.

**Vision / fog of war** (`TacticalAction.swift`): each player sees the union of
unit vision discs (`2*spot`, spot = 3 with `radar` else 2) and a radius-3 disc
around owned buildings.

## Combat

`Tactical/State/TacticalAttack.swift`

`attack(src:dst:)` requires same-country attacker, enemy target, `ap>0`,
`ammo>0`, and target within `rng*2+1`. Sequence:

1. Spends 1 `ap`.
2. **Support fire** before the duel: if a melee land attack, an adjacent
   friendly `art` of the defender fires on the attacker; if an air attack and
   defender lacks `aa`, an adjacent friendly `aa` fires on the attacker.
3. **Rugged Defence** check (unless attacker is `art`/surprise): if
   `d20 + (ini+stars)*2 < (ent+ini+stars)*2 [+10 surprise]`, defender fires
   first and attacker's shot is delayed.
4. Attacker fires (`fire`), reducing defender `ent` by 1.
5. Defender counterattacks if alive, in range and can hit the attacker. Counter defMod includes close-combat terrain penalty, a −3 if rugged defence triggered, and +5 if the attacker is out of ammo.
6. Low-HP defenders may **retreat** (`hp*2 + ini + d20 < 20`, not vs artillery)
   to the farthest reachable tile away from the attacker.

**`fire(src:dst:defMod:)`** — the damage core:

- `atk = atk(target) + stars + fullAmmoBonus + leadershipAura + reconAura`
- `def = def(attacker) + stars + defMod + leadershipAura + reconAura`
  where `defMod = ent + terrain.def + closeCombat + mountaineer + mhtn + diag
  − encirclement` (encirclement = friendly-of-attacker count around defender
  beyond the first).
- `dif = atk − def`. Three thresholds `t1=max(0,7−dif)`,
  `t2=max(5,15−dif)`, `t3=max(10,24−dif)`.
- Rounds = `(hp+3)/3 + (ini>d20(max 2) ? 1 : 0)`. Each round rolls `d20`
  (0–19): `>t3`→3, `>t2`→2, `>t1`→1, else 0 damage. `crit` may double a
  round (`d20>16`); `evasion` may zero it (`d20>16`).
- Damage hits the unit (and its cargo). Kills award prestige (`cost/16`) and a
  promotion roll. `estimateDamage` is the AI's deterministic preview.

`D20` is a SplitMix64 PRNG (`Engine/Foundation/D20.swift`) seeded per battle so
combat is reproducible.

## Terrain

`Model/Terrain.swift`

- **Move cost** varies by `UnitType` (roads always 1; rivers cost full `mov`
  for ground; mountains block wheels).
- **Defense** `def`: field 0, forest/hill/airfield +2, forestHill/mountain/city
  +3, rivers −3, bridges −2, roads −1.
- **Base entrenchment**: forest/hill/airfield 2, city 3 — units passively
  entrench up to 7 (+1/turn) capped by terrain when standing still.
- **Close-combat penalty**: light/heavy armor attacking into rough terrain at
  range 1 loses part of the terrain defense bonus.
- **Highground** (hill/forestHill/mountain): `mountaineer` attackers +2, defenders −1.

## Supply, Repair, Entrench

`Tactical/State/TacticalAction.swift` (start-of-day, per unit)

- **resupply**: untouched units regain ammo and HP. Bonuses for no adjacent
  enemy and for an adjacent friendly `supply` unit. Air units only resupply
  next to an owned airfield. Healing spends experience.
- **regen**: `regen`-trait units +1 HP/day (air needs a building).
- **entrench**: ground units +1 `ent` up to terrain cap (max 7).
- **rest**: refresh `ap`/`mp` to max.

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
  cost half (consumed from the pool when bought).
- **Unit `cost`** = `(expCost + typeCost + traitCost + statSum*2) / (aux ? 2:1)`
  — scales with experience, type, trait count, and combat stats.

## Players & Victory

`Model/Player.swift`, `TacticalTurns.swift`

- `Country` maps to one of three `Team`s: **axis** (swe/den/ned/ukr),
  **allies** (isr/pak/usa), **soviet** (ind/irn/rus). Friendly fire is
  impossible within a team; combat requires cross-team.
- `PlayerType`: `human`, `remote` (network), `ai` (`Tactical/State/TacticalAI`).
- Capturing every tile-occupying ground unit reflags buildings to the
  occupier's country. A player with no remaining cities is eliminated
  (`alive = false`). Last team standing wins.
