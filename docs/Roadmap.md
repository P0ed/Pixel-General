# Roadmap

## Multiplayer (LAN, TacticalMode)

Goal: play a Tactical battle between several machines on a LAN/VPN, joined via a
provided `ip:port`. Two-to-four seats, any mix of local human, networked human,
and AI. See [Architecture](./Architecture.md) and [Mechanics](./GameMechanics.md)
for the types referenced below.

### Design: deterministic action relay

The core is already a deterministic, headless function: `TacticalState.reduce(_:)`
is a pure function of `(state, action)`, the only randomness is the per-battle
seeded `D20` (SplitMix64) that lives *inside* `TacticalState`, and `TacticalAction`
is a small enum (`move`/`embark`/`disembark`/`attack`/`resupply`/
`purchase`/`end`) whose payloads are all `UID`/`XY`/`Int`. (Verified: nothing in
`TacticalAttack`/`Move`/`Shop`/`Transport` reads `cursor`/`selectedUnit`/`camera`,
and there are no `Date`/`random`/`Set`-ordering sources in the reduce path.)

That makes the cheap, robust model a **deterministic action relay**, not state
replication:

1. **Host generates the battle** once (`TacticalState.make(...)`, map seed and
   `D20` seed included) and ships the *whole encoded state* to each client with
   `encode(borrowing:)` (`COR/Foundation/Swift.swift`). Clients `decode(_:)` it.
   All peers now hold byte-identical state and the same `D20` seed.
2. **Only `TacticalAction`s travel during play.** When the seat whose turn it is
   produces an action, every peer applies that same action through `reduce` and,
   because `reduce` is deterministic, all states stay identical — including
   combat rolls.
3. The transport is the existing length-prefixed TCP `Connection`
   (`PG/Networking/Connection.swift`); reliable, in-order delivery is all the
   relay needs.

This leans directly on the existing **Reaction split** (`COR/Foundation/Reaction.swift`):
`input` returns `.action` (mutating, must be networked), `.events` (presentation
only — menu/shop, never networked), or `.none` (cursor/selection/`mapMode`, never
networked). UI state (`cursor`, `selectedUnit`, `selectable`, `camera`, `scale`,
`mapMode`) may freely diverge between peers — it is never read by `reduce`.

### Topology and turn arbitration

Star topology, host is the hub and the single authority for AI seats:

- The game is strictly turn-rotated (`playerIndex = turn % players.count`), so
  **exactly one seat acts at a time** — there are no simultaneous inputs and no
  lockstep tick is needed. The active seat's owner is the sole action producer.
- **Host** owns its local human seat **and runs the AI for all `.ai` seats**,
  broadcasting each resulting action. Running AI on the host only sidesteps any
  AI-determinism requirement entirely (we transmit AI *actions*, never re-run AI
  per peer).
- **Client** owns its assigned human seat. It sends its action to the host; the
  host applies and rebroadcasts to the other clients.

Recommended baseline: **host-authoritative, clients apply only confirmed
actions** (client sends intent → host applies → host broadcasts to all incl.
sender → everyone applies on receipt). One LAN round-trip of input latency,
zero optimistic-divergence risk. (Optimistic local apply is a later option.)

### Peer-relative `PlayerType`

`PlayerType` (`COR/Model/Player.swift`) already has `human`/`remote`/`ai`;
`remote` is currently unhandled. Make `PlayerType` **peer-relative** in MP: each
peer marks *its own* seats `.human` and *every other* seat `.remote`; only the
host keeps `.ai` seats as `.ai`. After decoding the initial state, the session
"localizes" it:

| Seat            | On host | On client |
|-----------------|---------|-----------|
| this peer human | `.human`| `.remote` |
| other human     | `.remote`| `.human` |
| AI              | `.ai`   | `.remote` |

This reuses the existing `self[country].type == .human` guards in
`TacticalInput.swift` for free: a peer can only generate actions for a seat it
sees as `.human`, i.e. its own. `.remote` uniformly means "someone else drives
this — wait for the wire," and `mode.ai` returns `nil` for non-`.ai` seats, so
clients never run AI.

### Network protocol

Extend `Message`/`MessageType` (`PG/Networking/Messages.swift`); reuse
`encode`/`decode` for the `Data` payloads (`TacticalAction` and `TacticalState`
are bitwise-trivial — see constraints below):

| Message            | Dir   | Payload | Purpose |
|--------------------|-------|---------|---------|
| `hello(version)`   | C→H   | u8/u16  | protocol-version handshake (reject on mismatch) |
| `joinRequest(name)`| C→H   | bytes   | claim an open seat |
| `joinAccept(slot)` | H→C   | u8      | assigned seat index/country |
| `lobby(snapshot)`  | H→C   | Data    | current slot table so clients render the lobby |
| `start(state)`     | H→C   | Data    | `encode(TacticalState)` — begin battle |
| `action(act)`      | both  | Data    | `encode(TacticalAction)` — the in-game relay |
| `resync(state)`    | H→C   | Data    | full-state recovery / late join |
| `leave` / `disconnect` | both | —    | graceful teardown |

Lifecycle: **lobby** (host listens, assigns seats, broadcasts `lobby`) →
**start** (host ships `start(state)`, all peers present `TacticalScene`) →
**in-game** (action relay) → **teardown** (`.end` event or `leave`).

### Determinism constraints (must hold)

- `TacticalState` and `TacticalAction` must stay fully **bitwise-copyable** —
  no `String`/class/heap fields — or `encode`/`decode`/`clone` silently corrupt.
  (Already flagged under *Architecture → BitwiseCopyable constraints*; extend the
  static-assert helper to cover `TacticalAction`.)
- `reduce` must remain a **pure deterministic function of `(state, action)`** —
  no `Date`, no RNG except the in-state `D20`, no ambient I/O. This is the single
  invariant the whole scheme rests on; add a test that guards it.
- Peers are assumed **same arch/endianness** (macOS arm64) and **same build** —
  payloads are raw native bytes and there is no schema versioning today. The
  `hello(version)` handshake gates obvious mismatches; document the homogeneity
  assumption in `Connection.swift`.

### Work breakdown (file by file)

- **`PG/Networking/Messages.swift`** — add the message cases above with
  `encode`/`decode`-based payloads.
- **`PG/Networking/Server.swift`** — expose `broadcast`/`broadcast(except:)`,
  track per-`Connection` seat assignment, handle `joinRequest` → seat + `lobby`
  broadcast, surface listen port/errors for the lobby UI.
- **`PG/Networking/Client.swift`** — surface connection state
  (connecting/ready/failed) and a disconnect callback to the UI.
- **`PG/Networking/Connection.swift`** — fine as-is (already reassembles
  multi-chunk payloads, which the large `start`/`resync` blobs need); add the
  native-endian/homogeneity doc note and optional heartbeat.
- **New `PG/Networking/NetSession.swift`** — `@MainActor` coordinator holding
  role (host/client), the `Server`/`Client`, `localCountries`, and a weak
  `Scene` ref. Owns: lobby management, `start` (host builds & broadcasts state,
  everyone presents), the in-game relay (`relay(action)` out; on receive →
  `scene.send(action)`; host rebroadcast), state localization (table above), and
  disconnect handling. All callbacks are already on `MainActor`, so feeding the
  Scene is isolation-safe.
- **`PG/Scene/SceneMode.swift` + `Scene.swift`** — give `Scene` an optional
  `net: NetSession?`. In `react`, when an `.action` is locally originated and a
  session is active, call `net.relay(action)`. In `advance()`, gate `mode.ai` to
  host-only and, when the current seat is `.remote`, solicit neither local input
  nor AI — wait for the wire. (Local-human input is already blocked for
  non-`.human` seats by `TacticalInput`'s guards once the state is localized.)
- **`PG/HQ/HQScenario.swift`** — turn the scenario menu into a lobby:
  *Host LAN* / *Join LAN* entry points; per-seat type now cycles
  human/ai/**open**(remote); host shows its `ip:port` (enumerate interfaces via
  `getifaddrs`) and reflects joins live; *Start* builds and broadcasts the state.
  Client needs an `ip:port` entry affordance (the current UI is icon menus +
  keyboard, so a minimal text/number entry is required) → connect → render the
  received lobby → wait for `start`. `PlayerType.toggle()` must learn the new
  open/remote step.
- **`PG/Tactical/TacticalMode.swift` / `TacticalMenu.swift` / `TacticalEvent.swift`** —
  "Waiting for `<country>`…" status while a `.remote` seat acts; broadcast
  `.end`/draw; send `leave` on Save/Load/Abandon/Retreat and window close
  (`saveAndExit`). Decide MP autosave policy (local save is fine).
- **`COR/Model/Player.swift` / `COR/Tactical/TacticalAction.swift`** — document
  the peer-relative `.remote` semantics and the bitwise-copyable constraint.

### Failure handling

- **Disconnect mid-battle** (`Connection.onDisconnect`): pause, show "player
  disconnected"; host option to convert that seat `.remote → .ai`, take over,
  and `resync` all peers, or abort.
- **Late join / desync**: host ships `resync(state)`.
- **Invalid / out-of-turn action**: host drops actions not from the active
  seat's owner.

### Tests

- **Determinism**: apply an identical `TacticalAction` sequence to two states
  built from the same seed; assert `encode(a) == encode(b)` after each step.
  This is the load-bearing guarantee.
- **Serialization round-trip**: `decode(encode(x)) == x` for `TacticalAction`
  and `TacticalState`.
- **Framing**: split/coalesced `Message` payloads reassemble correctly in
  `Connection.processBuffer` (incl. a `start`-sized multi-chunk blob).
- **Lobby**: seat-assignment and `joinRequest` → `joinAccept`/`lobby` logic.

### Future / optional

- Bonjour discovery (`NWListener` service + `NWBrowser`) so clients pick a host
  instead of typing `ip:port`.
- Optimistic client-side apply to hide LAN latency.
- Spectator seats; internet/VPN play (the relay is transport-agnostic).

## Architecture

### `BitwiseCopyable` constraints
- `clone(_:)` in `COR/Swift.swift` does an `unsafe` bitwise copy and is the only sanctioned duplication path. It silently breaks if a field becomes non-`BitwiseCopyable` (e.g. someone adds a `String` or class reference). Add a static-assert helper or a doc comment listing the constraint.

### `fatalError` in `TacticalState.init`
`TacticalState.swift:87` aborts when a unit's allocated placement square is full. Spawn-placement is data-driven (`cities`, `allocatedUnits`); convert to a recoverable failure (skip placement / log) so editor-supplied scenarios can't crash the app.

## Tests

- **Replace `RNGTests` struct's all-or-nothing distribution check** — `randomDistribution` uses `bins[i] > expected` which fails on tail variance even for a uniform sample. Use a chi-squared test with a generous tolerance.

## Campaign mode

- Setup menu.
- Political map mode.
- State design.

## Editor

- **Replace/Bucket tool** replaces the same tiles under cursor with the current brush tile.
- **Undo stack** for tile edits.
- **Map validation on save** — refuse maps that violate gen invariants (orphan rivers, isolated cities, no spawn tiles per country). Surface as inline diagnostics, not a crash.

## Known bugs

### `placeRivers` can silently abort
`COR/Tactical/MapGeneration.swift:51` — the `while true` BFS now bails out cleanly when `pressure[start] >= 1024`, but on abort it leaves the river half-carved (no rollback) and falls through to `placeCities` with whatever partial water tiles were laid. Detect the abort and either retry with a different `(start, end)` pair, fall back to a Bresenham line carve, or make the initializer failable so callers can retry the seed.

### Possible AI non-termination
`TacticalAI.runAI` plus the outer driver in `TacticalMode` will loop forever if no team can be eliminated and no player runs out of meaningful actions. Add a stalemate detector (e.g. N consecutive `.end` actions with no state change → declare draw).
