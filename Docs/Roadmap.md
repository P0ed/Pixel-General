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
- Spawn locations, specified in XY to [3x3] per player in `Scenario`.
- - All settlements are assigned from specified locations.
- - - At map gen ensure the cities at spawn point has airfield.
- - Passed from campaign layer.
- - For custom scenarios set to: `[XY(1, 0), XY(1, 2), XY(2, 1), XY(0, 1), XY(1, 1)]`.
- - - Each seat gets a toggle in menu that selects a spawn point with 6 options: `I, II, III, IV, V, Random`.
- Map validation — refuse maps that violate gen invariants
  (orphan rivers, isolated cities, no spawn tiles per country, settlements > 64).

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
