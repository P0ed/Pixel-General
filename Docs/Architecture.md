## Architecture

The codebase is split into two modules:

- **COR** — the headless, deterministic game core: data structures, model, simulation state, legality rules, reducers, meaningful domain results, and AI. It is the `COR` product of the local `GameCore` Swift package in `COR/`, with no UI/SpriteKit dependency.
- **PG** — the app/presentation layer: composite scene state, input interpretation, presentation intents, SpriteKit scenes and nodes, rendering, networking, editor, and save/load. Built on UIKit, it ships as a single universal app — iOS/iPadOS natively and macOS via Mac Catalyst. The app shell is an `AppDelegate` + `SceneDelegate` + `ViewController` (`PG/App.swift`) hosting one global `SKView`; `PG/App.swift` also owns the global root state `core: Core` and `settings`.

A third target, **Train**, is a macOS-only command-line tool for the LSTM opponent's
training pipeline. PG, Train, and the tests all build the same local-package `COR`
product; see [AI](./AI.md).

Three game modes:
- **HQ** (unit management),
- **Strategic** (campaign),
- **Tactical** (32×32 grid combat).

### Mode Pattern

Each game screen is wired up as a `SceneMode<State, Action, Event, PresentationIntent, Nodes>` (defined in `PG/Scene/SceneMode.swift`):

1. **Input** → `State.apply(input)` → `InputReaction<Action, PresentationIntent>`; this may mutate PG-owned cursor/camera/selection state.
2. **Reduce** → `State.reduce(action)` → `[Event]`; this delegates deterministic mutation to `Sim.reduce`, then reconciles presentation state.
3. **Process** → async `Nodes.process(event, state)` for domain results such as paths, damage, spawns, and campaign changes.
4. **Present** → async `Nodes.present(intent, state)` for PG-only effects such as opening a menu, shop, or army roster.

The four instantiations are declared as typealiases alongside their nodes: `HQMode`, `TacticalMode`, `StrategicMode`, and `EditorMode`.

#### Input reaction

`input` returns `InputReaction` from `PG/Scene/InputReaction.swift`:

```swift
enum InputReaction<Action, PresentationIntent> {
    case action(Action)
    case presentation(PresentationIntent)
    case none
}
```

`.action` is the only case fed through Reduce. `.presentation` bypasses Reduce and cannot enter COR. `.none` represents an ignored input or a presentation-state-only change. `Scene` dispatches reducer results only to Process and presentation intents only to Present, so menus and shops cannot masquerade as reducer output.

The module boundary follows this pipeline: `Sim`, domain `Action`, legality, reducers, and domain `Event` payloads live in **COR**. Composite scene `State`, `UI`, device `Input`, input interpretation, `PresentationIntent`, and rendering live in the corresponding **PG** feature folders.

### Sim / UI split

Each PG mode state wraps a COR sim and PG-owned presentation state (for example, `TacticalState = { sim: TacticalSim, ui: TacticalUI }`):

- **`Sim`** (`~Copyable`) is the deterministic simulation: the map, units, players, turn counter, and the in-state `D20`. It owns `reduce` — by construction it *cannot* reference the UI half, so the reducer is a pure function of `(sim, action)`.
- **`UI`** lives under `PG/<Mode>/` and owns cursor, camera, selection, scale, and map mode. It is mutated by `apply(input)` and reconciled after `reduce`, but is **not part of the COR module**, so it may freely diverge between peers.

`State.reduce(action)` runs `sim.reduce(action)` for the game-relevant mutation, then patches the UI (e.g. keeping a moved unit selected). This makes the multiplayer determinism guarantee *structural* rather than a discipline: networked peers relay only `Action`s into identical `Sim`s, while each peer's `UI` is its own.

### Noncopyable State (`~Copyable`)

The `Sim` values and PG `State` wrappers are `~Copyable` structs: they cannot be implicitly copied, only moved or explicitly cloned via `clone(borrowing A) -> A` in `COR/Foundation/Swift.swift`. This function uses `withUnsafePointer` bitwise copy internally and is the only sanctioned way to duplicate state.

The same file provides `encode(borrowing A) -> Data` and `decode(Data) -> A?` for UserDefaults persistence.

### Key Data Structures

| Type | File | Purpose |
|------|------|---------|
| `CArray<N, Element>` | `COR/Foundation/CArray.swift` | Fixed-capacity array, must be used in game mechanics instead of `Array<Element>` |
| `Speicher<N, Element: DeadOrAlive>` | `COR/Foundation/Speicher.swift` | Same as CArray + quick elements removal and slot reuse |
| `Map<Element>` | `COR/Foundation/Map.swift` | 32×32 grid |
| `SetXY` | `COR/Foundation/SetXY.swift` | Efficient coordinate set (visibility, movement, the settlement index); iterates row-major like `Map.indices` |
| `D20` | `COR/Foundation/D20.swift` | PRNG for combat resolution |

### State

The root `Core` struct (`COR/Model/Core.swift`) holds the HQ sim, optional strategic/tactical sims, and a `.location` enum that drives which scene is active. The single live instance is the global `core: Core` in `PG/App.swift`; `Core.complete`/`startCampaignBattle`/`store` are the load-bearing transitions between modes.

App-level `Settings` (e.g. sound level) live separately in `PG/Scene/Settings.swift`.

Game mechanics are implemented using integer arithmetics. All game state is stored inline, no heap references allowed. For performance reasons `CArray<capacity, Element>` should be used instead of `Array<Element>`. A `Unit` keeps only its runtime fields plus a `model: UnitModel` index; the fixed per-platform stats live in the global `UnitStats.table` (`COR/Model/UnitStats.swift`), so identical models share one stats row and the inline state stays small.

Each `TacticalAction` reducer opens with a guard on its sim-level legality predicate — `canMove` / `canAttack` / `canEmbark` / `canDisembark` / `canResupply` / `canBuy`, colocated with the reducer it mirrors — and an illegal action leaves the sim bitwise-unchanged (see the `reduce` doc in `COR/Tactical/TacticalReaction.swift`). The LSTM action masks and the heuristic AIs consult the same predicates, so mask/reducer/AI legality cannot drift. `TacticalSim.settlements: SetXY` indexes the settlement tiles once at battle creation (the map never changes during a battle, only `control` does); turn bookkeeping, the AIs, and the masks iterate it instead of rescanning the map.

### Concurrency

Strict concurrency is enabled project-wide.

## Multiplayer (LAN)

A Tactical battle can be played across machines as a **deterministic action
relay**, coordinated by `NetSession` (`PG/Networking/NetSession.swift`, global
`net`): the host generates the battle once and ships the whole encoded
`TacticalSim`; afterwards only `TacticalAction`s travel, and every peer
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
  keeps `.ai`. The existing `.human` guards in `PG/Tactical/TacticalState.swift` then stop a
  peer from driving seats it doesn't own, and the per-peer `TacticalUI`
  (`cursor`, `selectedUnit`, `camera`, …) may freely diverge — it lives
  outside `TacticalSim`, so `reduce` cannot read it (see [Sim / UI split](#sim--ui-split)).
- **Pipeline hooks** — `SceneMode.relay` inspects every locally produced
  `.action` before Reduce (host: broadcast + apply; client: send intent +
  suppress). The `ai` hook becomes `NetSession.nextAction`, which drains
  actions queued from the wire and falls back to the local AI driver on the
  host. PG-only `.presentation` reactions are never networked.
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
COR/                  Local GameCore package; shared COR product, no UI dependency
  Package.swift       One module/product consumed by PG, Train, and tests
  Foundation/         Data structures & primitives: CArray, Speicher, Map, SetXY, XY, D20;
                      Swift.swift = clone / encode / decode for ~Copyable state
  Model/              Shared game data: Core, Unit/Units, UnitStats (model → static stats table),
                      {Allied,Axis,Soviet}Units (per-team catalogue), Player, Terrain, Templates, Shop, Strings
  Tactical/           Combat sim, domain actions/results/reducers,
                      AI (heuristic axis/soviet + LSTM: Encoding, ActionSpace, LSTMWeights (PGW1 IO),
                      LSTMPolicy — pure-Swift masked-argmax inference), attacks + Duel (damage curve),
                      movement, resupply, transport, turns, shop,
                      placement (place/vacate/spawn — the spatial invariant over position/unitsMap/cargo),
                      map generation, chess (debug scenario)
  HQ/                 Roster-management sim, domain actions/results/reducer
  Strategic/          Campaign sim (Europe map, province ownership, battle launch/resolution),
                      domain actions/results/reducer

PG/                   App & presentation layer
  App.swift           @main AppDelegate / SceneDelegate; owns global `core` + `settings`
  App/                App helpers: ViewController, UserDefaults (save/load), Colors, Images, SpriteKit,
                      AlertController, HelpMenu (macOS Help menu: About / Controls / Rules)
  Scene/              SpriteKit scenes, SceneMode, device input, InputReaction, menus, rendering, settings
  Networking/         Client, Connection, Server, Messages, NetSession (LAN relay)
  Tactical/           Tactical State/UI/input intents, nodes, domain-result rendering, status, unit sprites
  HQ/                 HQ State/UI/input intents, nodes, campaign & scenario selection, LAN lobby
  Strategic/          Strategic State/UI/input intents, nodes, domain-result rendering
  Editor/             Map editor (in progress)
  Scenes.swift        Scene construction / mode wiring
  policy.pgw          Bundled LSTM opponent weights (PGW1; heuristic fallback when absent)

Train/                Headless macOS CLI (not shipped): LSTM training pipeline — rollout generation,
                      behavior cloning + RL fine-tune (MPSGraph), model parity, arena eval;
                      imports the same COR package product as PG
```
