# Roadmap

## Scenario

- Better supply model for reinforcements and resupply.
- Surrender if can't retreat.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.
- Defensive AI.
- Weather.
- Bridging engineers.

## Map

- ~~Supply map mode (gray gradient 8 values).~~ Done: visualizes the
  resupply bonus (0/1/2) on the gray gradient; deepen once the better
  supply model lands.
- ~~Keep roads/buildings in political/supply map mode.~~ Done: decorations
  and fog render on their own tile-map layers in every mode.

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

## Game manual

- Controls — list of actions with associated buttons for keyboard/gamepad.
- Rules — `GameMechanics.md` but without referencing engine internals.

## iOS

- On-screen touch controls.
