# Roadmap

## Scenario

- Do not transfer prestige after scenario to HQ.
  Instead pay fixed reward on victory.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.
- Allow buying units in a `.c5` region around city/village/airfield.
- Add unit deployment phase before day 1.
- Unit surrenders if can't retreat.
- Separate layer for air units.
- Explosion animations (three levels).
- Movement sounds depending on unit type (leg, wheel, track, heli, jet).

## Campaign (HoI lite)

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

- Strengthen the neural opponent toward >60% vs the heuristic, then self-play for
  emergent behavior. Bundled: bc8 final — pure BC at 64× scale (15360-battle mixed
  corpus, 64000 steps) on the 49-plane/replay-v5/embark-fixed contract, 45.2% (376W)
  in the paired 832-battle mixed arena, seat 0 alone 50.7% (first to beat the
  heuristic); pre-break numbers (bc7 46.0% on 53 planes) are not comparable. Pure BC
  of a deterministic teacher caps near 50%, so >60% needs RL: revisit PPO at even
  matchups (`--curriculum 0`) from this prior, or DAgger to close the covariate-shift
  gap, then self-play.

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
