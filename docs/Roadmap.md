# Roadmap

## Multiplayer

- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Optimistic client-side apply to hide LAN latency.
- Bonjour discovery (`NWListener` service + `NWBrowser`) so clients pick a host
  instead of typing `ip:port`.

## Scenario

- Better supply model for reinforcements and resupply.
- Supply map mode.
- Better way of assigning sprites/strings to units than a switch over stats.

## Campaign

- Setup menu (two difficulty knobs: starting prestige + enemy base level).
- `StrategicState` design + a new graph-walking strategic AI.
- `Objective` / `BattleOutcome` types and turn-limited win checks in Tactical.
- Anti-snowball model (supply-distance budget, permanent casualties, defender
  consolidation, turn limits) and the loss/draw/abandon rules.

## Map

- Keep roads/buildings in political/supply map mode.
- Fix city tile clipping it's top part.

## Editor

- **Replace/Bucket tool** replaces the same tiles under cursor with the current brush tile.
- **Undo stack** for tile edits.
- **Map validation on save** — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country). Surface as inline diagnostics, not a crash.

## Game manual

- **Controls** — list of actions with associated buttons for keyboard/gamepad.
- **Rules** — `GameMechanics.md` but without referencing engine internals.

## iOS target

- Migrate to UIKit/SwiftUI to make the App universal.
