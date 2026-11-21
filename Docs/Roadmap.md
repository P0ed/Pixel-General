# Roadmap

## General

- Remove/optimize hover.

## Scenario

- Do not transfer prestige after scenario to HQ. Pay fixed reward on victory.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.
- Unit surrenders if can't retreat.
- Separate layer for air units.
- Movement sounds depending on unit type (leg, wheel, track, fpv, helicpter, jet).
- Map validation — refuse maps that violate gen invariants
  (orphan rivers, isolated cities, no spawn tiles per country, settlements > 64).

## Controls

- Display action hints depending on current input method
  (gamepad is connected / fallback to keyboard).

## Multiplayer

- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Remove `.takeover`, require to reconnect.
- Allow to choose a port when hosting a game.
- Optimistic client-side apply to hide LAN latency.
- Bonjour discovery so clients pick a host instead of typing `ip:port`.
