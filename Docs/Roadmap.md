# Roadmap

## Scenario

- Add sea tiles `Terrain.sea`. Not passable for land units. Darker color than river.
  Also used for sea tiles in all strategic map modes.
- Generate map based on `[9 of Terrain]`. Compose using the following pattern:
  ```
  xxx
  ADx
  xxx
  ```
  A: Attacker, D: Defender on strategic map. Can contain sea tiles.

- Do not transfer prestige after scenario to HQ.
  Instead pay fixed reward on victory.

- Allow buying units in a `.c5` region around city/village/airfield.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.

- Add unit deployment phase before day 1.
- Unit surrenders if can't retreat.
- Ships.
- Separate layer for air units.
- Weather.
- Bridging engineers.
- Explosion animations (three levels).
- Movement sounds depending on unit type (leg, wheel, track, heli, jet).

## Campaign (HoI lite)

- Add `struct Scenario`: `players: [Player], units: [Unit], terrain: [9 of Terrain], fortLevel: Int`, etc.
  Serving as `TacticalSim` factory.
- Train a simple model that predicts battle outcome with casualties for auto resolutions in strategic layer given a `Scenario`.

- Dynamic diplomacy.
- - Rename `Country` to `Flag` [or `Tag`?].
- - Add `struct Country { var flag: Flag, var team: Team }`.
- - - Bitpack into `rawValue: UInt8`, 64 flags, 4 teams.
- - - Allow to select a team in new scenario / LAN lobby.
- - Allow to join a team if current team is `.none`.

- Tier unlock mechanics.
- - Has enough factories/buildings + fixed cost.

## Controls

- Display action hints depending on current input method
  (gamepad is connected / fallback to keyboard).

## AI

- Strengthen the neural opponent further (`Train ppo` — PPO-clip + value baseline +
  KL anchor — broke the REINFORCE ceiling at 25.7% vs BC's 21.6%, 832-battle paired
  eval): continue PPO from ckpt-90 at difficulty 1.5, try `--lam < 1` / a bigger BC corpus for a
  stronger prior; self-play once it consistently beats the heuristic.

## Multiplayer

- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Remove `.takeover`, require to reconnect.
- Allow to choose a port when hosting a game.
- Optimistic client-side apply to hide LAN latency.
- Bonjour discovery so clients pick a host instead of typing `ip:port`.

## Editor

- Replace/Bucket tool replaces the same tiles under cursor with the selected tile.
- Undo stack for tile edits.
- Map validation on save — refuse maps that violate gen invariants
  (orphan rivers, isolated cities, no spawn tiles per country).
