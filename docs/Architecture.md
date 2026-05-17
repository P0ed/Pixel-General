## Architecture

Three game modes:
- **HQ** (unit management),
- **Strategic** (campaign),
- **Tactical** (32×32 grid combat).

### Mode Pattern

Each game screen is wired up as a `SceneMode<State: ~Copyable, Action, Event, Nodes>`:

1. **Input** → `State.apply(input)` → `Action?`
2. **Reduce** → `State.reduce(action)` → `[Event]`
3. **Process** → async `Nodes.process(event, state)` (visuals, audio)

The four instantiations are `HQMode`, `TacticalMode`, `StrategicMode`, and `EditorMode`. See `Engine/Scene/SceneMode.swift`.

### Noncopyable State (`~Copyable`)

All game states are `~Copyable` structs — they cannot be implicitly copied. Only moved or explicitly cloned via `clone(borrowing A) -> A` in `Engine/Extensions/Swift.swift`. This function uses `withUnsafePointer` bitwise copy internally and is the only sanctioned way to duplicate state.

The same file provides `encode(borrowing A) -> Data` and `decode(Data) -> A?` for UserDefaults persistence.

### Key Data Structures

| Type | File | Purpose |
|------|------|---------|
| `CArray<N, Element>` | `Engine/Foundation/CArray.swift` | Fixed-capacity array |
| `Speicher<N, Element: DeadOrAlive>` | `Engine/Foundation/Speicher.swift` | Same as CArray + quick elements removal and slot reuse |
| `Map<Element>` | `Engine/Foundation/Map.swift` | 32×32 grid |
| `SetXY` | `Engine/Foundation/XY.swift` | Efficient coordinate set for visibility/movement |
| `D20` | `Engine/Foundation/D20.swift` | PRNG for combat resolution |

### Global State

`Core` class (`PG/Core.swift`) manages save/load. The root `State` struct holds `.hq`, `.strategic`, `.tactical` sub-states and a `.location` enum that drives which scene is active. All state is persisted to UserDefaults on location transitions.

### Concurrency

Strict concurrency is enabled project-wide. All scene/node code runs on `@MainActor`.

## Module Map

```
Engine/     Core framework: SpriteKit scenes, input, rendering, serialization, data structures
Model/      Shared game data: Unit, Player, Terrain, network messages
Tactical/   Combat simulation: state, AI, attacks, movement, turns, map generation
HQ/         Unit management UI: state, unit shop, campaign selection
Strategic/  Campaign layer: state and progression (in progress)
Editor/     Map editor (in progress)
```
