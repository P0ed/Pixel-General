# Roadmap

## Scenario

- Adjust the damage curve.
- Allow buying units in a `.c5` region around city/village/airfield.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.
- Add unit deployment phase before day 1.
- Unit surrenders if can't retreat.
- Defensive AI.
- Sea tiles and ships.
- Separate layer for air units.
- Weather.
- Bridging engineers.

## Campaign

- Add hills and mountains to the map of Europe.
- Pass terrain type to map generation.
- Dynamic diplomacy.
- Economy.

## Multiplayer

- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Optimistic client-side apply to hide LAN latency.
- Allow to choose a port when hosting a game.
- Bonjour discovery so clients pick a host instead of typing `ip:port`.

## Editor

- Replace/Bucket tool replaces the same tiles under cursor with the selected tile.
- Undo stack for tile edits.
- Map validation on save — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country).

## iOS

- On-screen touch controls.

## AI

- Train an LSTM model to play against.
