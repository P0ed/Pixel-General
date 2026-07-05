## Architecture

The codebase is split into two modules:

- **COR** — the headless, deterministic game core (data structures, model, state, reducers, AI). Pure logic, no UI/SpriteKit dependency. Its public API is consumed via `import COR`.
- **PG** — the app/presentation layer: SpriteKit scenes and nodes, rendering, input wiring, networking, editor, and save/load. Built on UIKit, it ships as a single universal app — iOS/iPadOS natively and macOS via Mac Catalyst. The app shell is an `AppDelegate` + `SceneDelegate` + `ViewController` (`PG/App.swift`) hosting one global `SKView`; `PG/App.swift` also owns the global root state `core: Core` and `settings`. The view controller forwards hardware-keyboard `UIPress` events to the active scene, while touches and trackpad/scroll panning are handled in `Scene` itself.

Three game modes:
- **HQ** (unit management),
- **Strategic** (campaign),
- **Tactical** (32×32 grid combat).

### Mode Pattern

Each game screen is wired up as a `SceneMode<State: ~Copyable, Action, Event, Nodes>` (defined in `PG/Scene/SceneMode.swift`):

1. **Input** → `State.apply(input)` → `Reaction<Action, Event>` (may mutate the UI half of the state)
2. **Reduce** → `State.reduce(action)` → `[Event]` — delegates to `Sim.reduce` (the only mutation of deterministic state), then reconciles the UI half (e.g. re-selection)
3. **Process** → async `Nodes.process(event, state)` (visuals, audio)

The four instantiations are declared as typealiases alongside their nodes: `HQMode`, `TacticalMode`, `StrategicMode`, and `EditorMode`.

#### Reaction

`input` returns a `Action|[Event]` enum (`COR/Foundation/Reaction.swift`) — a two-way sum of what a gesture resolves to:

```swift
public enum Reaction<Action, Event> {
    case action(Action)   // run through Reduce
    case events([Event])  // bypass Reduce, process directly
}
```

The cases are mutually exclusive by design — `input` only *interprets* the gesture, it never both mutates and emits:

- **`.action`** is fed through **Reduce**, the only stage that mutates game state by applying an `Action`. Any presentation feedback that results from *applying* an action (e.g. a purchase animation) is emitted there, as a reduce `Event`.
- **`.events`** *bypass* Reduce and go straight to **Process**. These are presentation-only effects that don't depend on a state change — e.g. opening a menu or the shop.

`Scene.send` switches on the reaction (`PG/Scene/Scene.swift`): `.action` calls `reduce`, `.events` is taken verbatim, `.none` yields no events — and the resulting `[Event]` is dispatched to `Process`. Reduce helpers that emit events thread an `into events: inout [Event]` accumulator rather than mutating shared state.

The split between the two modules follows this pipeline: `State`, `Input`, and the `Action` + `Event` payloads live in **COR** — each mode colocates its `Action` enum, `Event` enum, and `reduce` in one `COR/<Mode>/<Mode>Reaction.swift` file (`TacticalReaction.swift`, `HQReaction.swift`, `StrategicReaction.swift`). The `Nodes` and presentation-side `Event` *handling* (the `process`/`update` rendering) live in **PG**.

### Sim / UI split

Each mode's state is split in two (e.g. `TacticalState = { sim: TacticalSim, ui: TacticalUI }`, likewise `HQState`/`HQSim`/`HQUI` and `StrategicState`/`StrategicSim`/`StrategicUI`):

- **`Sim`** (`~Copyable`) is the deterministic simulation: the map, units, players, turn counter, and the in-state `D20`. It owns `reduce` — by construction it *cannot* reference the UI half, so the reducer is a pure function of `(sim, action)`.
- **`UI`** is an ordinary (copyable) presentation-only struct: cursor, camera, selection, scale, map mode. It is mutated by `apply(input)` and reconciled after `reduce`, but is **never read by the simulation**, so it may freely diverge between peers.

`State.reduce(action)` runs `sim.reduce(action)` for the game-relevant mutation, then patches the UI (e.g. keeping a moved unit selected). This makes the multiplayer determinism guarantee *structural* rather than a discipline: networked peers relay only `Action`s into identical `Sim`s, while each peer's `UI` is its own.

### Noncopyable State (`~Copyable`)

The `Sim` halves — and the `State` wrappers — are `~Copyable` structs: they cannot be implicitly copied, only moved or explicitly cloned via `clone(borrowing A) -> A` in `COR/Foundation/Swift.swift`. This function uses `withUnsafePointer` bitwise copy internally and is the only sanctioned way to duplicate state.

The same file provides `encode(borrowing A) -> Data` and `decode(Data) -> A?` for UserDefaults persistence.

### Key Data Structures

| Type | File | Purpose |
|------|------|---------|
| `CArray<N, Element>` | `COR/Foundation/CArray.swift` | Fixed-capacity array, must be used in game mechanics instead of `Array<Element>` |
| `Speicher<N, Element: DeadOrAlive>` | `COR/Foundation/Speicher.swift` | Same as CArray + quick elements removal and slot reuse |
| `Map<Element>` | `COR/Foundation/Map.swift` | 32×32 grid |
| `SetXY` | `COR/Foundation/XY.swift` | Efficient coordinate set for visibility/movement |
| `D20` | `COR/Foundation/D20.swift` | PRNG for combat resolution |

### State

The root `Core` struct (`COR/Model/Core.swift`) holds optional `.hq`, `.strategic`, `.tactical` sub-states and a `.location` enum that drives which scene is active. The single live instance is the global `core: Core` in `PG/App.swift`; `Core.complete`/`startCampaignBattle`/`store` are the load-bearing transitions between modes.

App-level `Settings` (e.g. sound level) live separately in `PG/Scene/Settings.swift`.

Game mechanics are implemented using integer arithmetics. All game state is stored inline, no heap references allowed. For performance reasons `CArray<capacity, Element>` should be used instead of `Array<Element>`. A `Unit` keeps only its runtime fields plus a `model: UnitModel` index; the fixed per-platform stats live in the global `UnitStats.table` (`COR/Model/UnitStats.swift`), so identical models share one stats row and the inline state stays small.

### Concurrency

Strict concurrency is enabled project-wide.

## Multiplayer (LAN)

A Tactical battle can be played across machines as a **deterministic action
relay**, coordinated by `NetSession` (`PG/Networking/NetSession.swift`, global
`net`): the host generates the battle once and ships the whole encoded
`TacticalState`; afterwards only `TacticalAction`s travel, and every peer
applies the same action stream through `reduce`. Because `reduce` is a pure
function of `(state, action)` — the only randomness is the in-state seeded
`D20` — all peers stay identical, combat rolls included. The invariant is
guarded by `Tests/MultiplayerTests.swift`.

- **Topology** — star, host-authoritative. The game is strictly turn-rotated
  (`playerIndex = turn % players.count`), so exactly one seat acts at a time.
  The host drives its local seats and the AI for `.ai` seats, broadcasting
  every applied action; a client sends its action as an intent and applies it
  only when the host echoes it back (no optimistic apply). The host drops
  out-of-turn intents.
- **Peer-relative `PlayerType`** — after decoding the `start` state each peer
  marks its own seat `.human` and every other seat `.remote`; only the host
  keeps `.ai`. The existing `.human` guards in `TacticalInput` then stop a
  peer from driving seats it doesn't own, and the per-peer `TacticalUI`
  (`cursor`, `selectedUnit`, `camera`, …) may freely diverge — it lives
  outside `TacticalSim`, so `reduce` cannot read it (see [Sim / UI split](#sim--ui-split)).
- **Pipeline hooks** — `SceneMode.relay` inspects every locally produced
  `.action` before Reduce (host: broadcast + apply; client: send intent +
  suppress). The `ai` hook becomes `NetSession.nextAction`, which drains
  actions queued from the wire and falls back to the local AI driver on the
  host. Presentation-only `.events` reactions are never networked.
- **Protocol** (`PG/Networking/Messages.swift`) — `hello(version)` →
  `joinRequest` → `joinAccept(seat)` + `lobby(snapshot)` → `start(state)` →
  `action(…)` relay → `leave`. Payloads are `encode(_:)` native bytes; peers
  must run the same build on the same architecture (see `Connection.swift`).
- **Lobby** — HQ menu *Host LAN* / *Join LAN* (`PG/HQ/HQLobby.swift`). The
  host configures four seats (country, human–AI–open cycle, prestige, map
  size), sees joins live and starts; clients enter `ip:port` (default port
  9899) and mirror the seat table.
- **Failure handling** — a disconnected or leaving seat is handed to the host
  AI through the relayed `.takeover` action; when the host vanishes, clients
  degrade to local play by taking over every seat they don't own. Saved
  multiplayer battles load standalone the same way (`.remote → .ai` in
  `Scenes.swift`).

## Module Map

```
COR/                  Headless game core (import COR), no UI dependency
  Foundation/         Data structures & primitives: CArray, Speicher, Map, SetXY, XY, D20, Input, Reaction;
                      Swift.swift = clone / encode / decode for ~Copyable state
  Model/              Shared game data: Core, Unit/Units, UnitStats (model → static stats table),
                      {Allied,Axis,Soviet}Units (per-team catalogue), Player, Terrain, Templates, Shop, Strings
  Tactical/           Combat sim + UI: state (TacticalSim/TacticalUI), reaction (action+event+reduce),
                      AI, attacks + Duel (damage curve), movement, resupply, transport, turns, shop,
                      placement (place/vacate/spawn — the spatial invariant over position/unitsMap/cargo),
                      map generation, chess (debug scenario)
  HQ/                 Roster management: state (HQSim/HQUI), reaction (action+event+reduce), input
  Strategic/          Campaign map: state (StrategicSim/StrategicUI — Europe map, province ownership,
                      battle launch/resolution), reaction, input

PG/                   App & presentation layer
  App.swift           @main AppDelegate / SceneDelegate; owns global `core` + `settings`
  App/                App helpers: ViewController, UserDefaults (save/load), Colors, Images, SpriteKit,
                      AlertController, HelpMenu (macOS Help menu: About / Controls / Rules)
  Scene/              SpriteKit scenes, SceneMode, input, menus, map/tile rendering, settings
  Networking/         Client, Connection, Server, Messages, NetSession (LAN relay)
  Tactical/           Tactical nodes, mode, event rendering, status, unit sprites
  HQ/                 HQ nodes, mode, campaign & scenario selection, LAN lobby
  Strategic/          Strategic nodes, mode, event rendering
  Editor/             Map editor (in progress)
  Scenes.swift        Scene construction / mode wiring
```
