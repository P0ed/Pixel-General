## Architecture

The codebase is split into two modules:

- **COR** — the headless, deterministic game core (data structures, model, state, reducers, AI). Pure logic, no UI/SpriteKit dependency. Its public API is consumed via `import COR`.
- **PG** — the app/presentation layer: SpriteKit scenes and nodes, rendering, input wiring, networking, editor, and save/load.

Three game modes:
- **HQ** (unit management),
- **Strategic** (campaign),
- **Tactical** (32×32 grid combat).

### Mode Pattern

Each game screen is wired up as a `SceneMode<State: ~Copyable, Action, Event, Nodes>` (defined in `PG/Scene/SceneMode.swift`):

1. **Input** → `State.apply(input)` → `Reaction<Action, Event>`
2. **Reduce** → `State.reduce(action)` → `[Event]`
3. **Process** → async `Nodes.process(event, state)` (visuals, audio)

The four instantiations are declared as typealiases alongside their nodes: `HQMode`, `TacticalMode`, `StrategicMode`, and `EditorMode`.

#### Reaction

`input` returns a `Reaction<Action, Event>` (`COR/Foundation/Reaction.swift`) — an optional `Action` plus a list of `Event`s:

```swift
public struct Reaction<Action, Event> {
    public var action: Action?
    public var events: [Event]
}
```

This separates the two ways an input can affect a screen:

- **`action`** is fed through **Reduce**, the only stage that mutates game state by applying an `Action`.
- **`events`** *bypass* Reduce and go straight to **Process**. These are presentation-only effects that don't change game state — e.g. opening a menu or the shop.

The scene runs both: `reaction.events + reduce(state, reaction.action)` are concatenated (input events first) and each is dispatched to `Process` (`PG/Scene/Scene.swift`). Helpers that emit events thread an `into events: inout [Event]` accumulator rather than mutating shared state.

The split between the two modules follows this pipeline: `State`, `Action`, `Input`, and the core `Event` payloads live in **COR**; the `Nodes` and presentation-side `Event` handling live in **PG**.

### Noncopyable State (`~Copyable`)

All game states are `~Copyable` structs — they cannot be implicitly copied. Only moved or explicitly cloned via `clone(borrowing A) -> A` in `COR/Swift.swift`. This function uses `withUnsafePointer` bitwise copy internally and is the only sanctioned way to duplicate state.

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

The root `State` struct (`COR/Model/State.swift`) holds `.hq`, `.strategic`, `.tactical` sub-states and a `.location` enum that drives which scene is active.

The `Core` class (`PG/Core.swift`) owns the root `State` and manages save/load; it `import`s COR. All state is persisted to UserDefaults on location transitions. App-level `Settings` (e.g. sound level) live separately in `PG/Scene/Settings.swift`.

Game mechanics are implemented using integer arithmetics. All game state is stored inline, no heap references allowed. For performance reasons `CArray<capacity, Element>` should be used instead of `Array<Element>`.

### Concurrency

Strict concurrency is enabled project-wide.

## Module Map

```
COR/                  Headless game core (import COR), no UI dependency
  Foundation/         Data structures & primitives: CArray, Speicher, Map, SetXY, XY, D20, Monoid, Shapes, Input, Reaction
  Model/              Shared game data: Unit, Player, Terrain, Templates, root State
  Tactical/           Combat simulation: state, AI, attacks, movement, turns, map generation
  HQ/                 Unit management logic: state, action, input, events
  Strategic/          Campaign logic: state, action, input, events
  Swift.swift         clone / encode / decode for ~Copyable state
  Strings.swift       Localized strings

PG/                   App & presentation layer
  Scene/              SpriteKit scenes, SceneMode, input, rendering, settings
  Extensions/         AppKit / SpriteKit / Colors / Images helpers
  Networking/         Client, Connection, Server, Messages
  Tactical/           Tactical nodes, mode, event rendering, status, unit sprites
  HQ/                 HQ nodes, mode, campaign & scenario selection
  Strategic/          Strategic nodes, mode, event rendering (in progress)
  Editor/             Map editor (in progress)
  Core.swift          Save/load, owns root State
  main.swift          Entry point
```
