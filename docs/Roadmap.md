# Roadmap

## Scenario

- Better supply model for reinforcements and resupply.
- Surrender if can't retreat.
- Allow helicopters to resupply ammo in a field in a presence of supply truck.

## Map

- Supply map mode (gray gradient 8 values).
- Keep roads/buildings in political/supply map mode.

## Multiplayer

- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Optimistic client-side apply to hide LAN latency.
- Allow to choose a port when hosting a game.
- Bonjour discovery so clients pick a host instead of typing `ip:port`.

## Editor

- Replace/Bucket tool replaces the same tiles under cursor with the current brush tile.
- Undo stack for tile edits.
- Map validation on save — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country). Surface as inline diagnostics, not a crash.

## Game manual

- Controls — list of actions with associated buttons for keyboard/gamepad.
- Rules — `GameMechanics.md` but without referencing engine internals.

## iOS

- On-screen touch controls.
