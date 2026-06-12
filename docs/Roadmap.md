# Roadmap

## Multiplayer (LAN, TacticalMode)

**Implemented** — see [Architecture → Multiplayer](./Architecture.md#multiplayer-lan)
for the design as built: a host-authoritative deterministic action relay over
the length-prefixed TCP `Connection`, peer-relative `PlayerType`, the
`hello`/`join`/`lobby`/`start`/`action`/`leave` protocol, the HQ lobby
(*Host LAN* / *Join LAN*), and disconnect handling via the relayed
`.takeover` action. The determinism and serialization invariants the relay
rests on are guarded by `Tests/MultiplayerTests.swift`.

Future / optional:

- Bonjour discovery (`NWListener` service + `NWBrowser`) so clients pick a host
  instead of typing `ip:port`.
- Optimistic client-side apply to hide LAN latency.
- Ship the joining player's HQ roster in `joinRequest` — clients currently play
  the stock `.base` roster of their assigned country.
- `resync(state)` sender: the message and the client handler exist, but the
  host never emits it yet (late join / desync recovery).
- Spectator seats; internet/VPN play (the relay is transport-agnostic).
- Framing/lobby unit tests (`Connection.processBuffer` chunk reassembly, seat
  assignment) — needs the PG app target to become importable from tests.

## Architecture

### `fatalError` in `TacticalState.init`
`TacticalState.swift:87` aborts when a unit's allocated placement square is full. Spawn-placement is data-driven (`cities`, `allocatedUnits`); convert to a recoverable failure (skip placement / log) so editor-supplied scenarios can't crash the app.

## Campaign mode

Full design in [Campaign](./Campaign.md) — a turn-based strategic layer over the
tactical battles ("HoI by vibes," shallower): a political map of Europe, a
persistent RPG roster, hand-picked fronts, objective-based battles, and a
two-pool prestige economy. Headline pieces:

- Setup menu (two difficulty knobs: starting prestige + enemy base level).
- Political map mode (`Map<32, Country>`, reusing Tactical's `.political` view).
- `StrategicState` design + a new graph-walking strategic AI.
- `Objective` / `BattleOutcome` types and turn-limited win checks in Tactical.
- Anti-snowball model (supply-distance budget, permanent casualties, defender
  consolidation, turn limits) and the loss/draw/abandon rules.

Prerequisite: expand `Country` to the `Map.md` European nations (`fin` etc. are
missing today) — independent of the deferred dynamic-diplomacy redesign.

## Editor

- **Replace/Bucket tool** replaces the same tiles under cursor with the current brush tile.
- **Undo stack** for tile edits.
- **Map validation on save** — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country). Surface as inline diagnostics, not a crash.

## Known bugs

### `placeRivers` can silently abort
`COR/Tactical/MapGeneration.swift:51` — the `while true` BFS now bails out cleanly when `pressure[start] >= 1024`, but on abort it leaves the river half-carved (no rollback) and falls through to `placeCities` with whatever partial water tiles were laid. Detect the abort and either retry with a different `(start, end)` pair, fall back to a Bresenham line carve, or make the initializer failable so callers can retry the seed.

### Possible AI non-termination
`TacticalAI.runAI` plus the outer driver in `TacticalMode` will loop forever if no team can be eliminated and no player runs out of meaningful actions. Add a stalemate detector (e.g. N consecutive `.end` actions with no state change → declare draw).

## Game manual

- **Controls** — list of actions with associated buttons for keyboard/gamepad.
- **Rules** — `GameMechanics.md` but without referencing engine internals.
