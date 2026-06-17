# Roadmap

## Scenario

- Better supply model for reinforcements and resupply.
- Supply map mode.
- Better way of assigning sprites/strings to units than a switch over stats.

## Campaign

Phase 1 (province conquest) and the Phase 2 Tactical `Objective` layer are in:
`StrategicSim` Europe map, `canAttack` / `resolveBattle`, the HQ → battle →
annex loop (`Core.startCampaignBattle` / `Core.complete`), and turn-limited
`capture` objectives that resolve to `TacticalSim.winner` — a campaign offensive
must take the province by `TacticalSim.captureDeadline` or be repulsed.
Remaining:

- Setup menu (two difficulty knobs: prestige, experience).
- A new graph-walking strategic AI (the AI offensives are not wired yet — the
  reducer's `endTurn` just advances the turn; wiring them also unlocks the
  "enemy attacks you / you lose a province" outcome).
- Anti-snowball model (supply-distance budget, permanent casualties, defender
  consolidation) and the remaining loss/abandon rules.
- Surface the objective and result in Tactical: an in-battle objective indicator
  and a victory/defeat screen (today the result is shown only by returning to
  the strategic map).

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

## iOS

- On-screen touch controls: a touch-only iPhone/iPad has no way to send the
  action buttons (a/b/c/d), target cycling, menu, or scale — add on-screen
  buttons (or gestures) for devices without a keyboard/gamepad.
