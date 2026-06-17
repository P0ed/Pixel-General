# Roadmap

## Scenario

- Better supply model for reinforcements and resupply.
- Supply map mode.
- Better way of assigning sprites/strings to units than a switch over stats.

## Campaign

- Setup menu (two difficulty knobs: prestige, experience).
- `StrategicState` design + a new graph-walking strategic AI.
- `Objective` / `BattleOutcome` types and turn-limited win checks in Tactical.
- Anti-snowball model (supply-distance budget, permanent casualties, defender
  consolidation, turn limits) and the loss/draw/abandon rules.

## General

- Native alerts with proper focus.

## Map

- Keep roads/buildings in political/supply map mode.
- Fix city tile clipping it's top part.

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

## Architecture

- Separation of UI state from simulation state.

## iOS

- On-screen touch controls: a touch-only iPhone/iPad has no way to send the
  action buttons (a/b/c/d), target cycling, menu, or scale — add on-screen
  buttons (or gestures) for devices without a keyboard/gamepad.
