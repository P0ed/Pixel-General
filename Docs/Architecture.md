## Architecture

The codebase is split into two modules:

- **COR** — the headless, deterministic game core: data structures, model, simulation state, legality rules, reducers, meaningful domain results, and AI, with no UI/SpriteKit dependency.
- **PG** handles composite scene state, input interpretation, presentation intents, SpriteKit scenes and nodes, rendering, the editor, and save/load. Built on UIKit, it ships as a single universal app — iOS/iPadOS natively and macOS via Mac Catalyst. The app shell is an `AppDelegate` + `SceneDelegate` + `ViewController` (`PG/App.swift`) hosting one global `SKView`; `PG/App.swift` also owns the global root state `core: Core` and `settings`.

PG and the tests build the same local-package `COR` product.

Two game modes:
- **HQ** (unit management),
- **Tactical** (64×64 grid combat).

### Mode Pattern

Each game screen is wired up as a `SceneMode<State, Action, Event, PresentationIntent, Nodes>` (defined in `PG/Scene/SceneMode.swift`):

1. **Input** → `State.apply(input)` → `InputReaction<Action, PresentationIntent>`; this may mutate PG-owned cursor/camera/selection state.
2. **Reduce** → `State.reduce(action)` → `[Event]`; this delegates deterministic mutation to `Sim.reduce`, then reconciles presentation state.
3. **Process** → async `Nodes.process(event, state)` for domain results such as paths, damage, and spawns.
4. **Present** → async `Nodes.present(intent, state)` for PG-only effects such as opening a menu or shop.

The three instantiations are declared as typealiases alongside their nodes: `HQMode`, `TacticalMode`, and `EditorMode`.

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
- **`UI`** lives under `PG/<Mode>/` and owns cursor, camera, selection, scale, and map mode. `apply(input)` updates it in response to input.

`State.reduce(action)` runs `sim.reduce(action)` for the game-relevant mutation, then updates the UI to reflect it. For example, it keeps a moved unit selected.

### Noncopyable State (`~Copyable`)

The `Sim` values and PG `State` wrappers are `~Copyable` structs: they cannot be implicitly copied, only moved or explicitly cloned via `clone(borrowing A) -> A` in `COR/Foundation/Swift.swift`. This function uses `withUnsafePointer` bitwise copy internally and is the only sanctioned way to duplicate state.

The same file provides `encode(borrowing A) -> Data` and `decode(Data) -> A?` for UserDefaults persistence.

### Key Data Structures

| Type | File | Purpose |
|------|------|---------|
| `CArray<N, Element>` | `COR/Foundation/CArray.swift` | Fixed-capacity array, must be used in game mechanics instead of `Array<Element>` |
| `Speicher<N, Element: DeadOrAlive>` | `COR/Foundation/Speicher.swift` | Same as CArray + quick elements removal and slot reuse |
| `Map<size, Element>` | `COR/Foundation/Map.swift` | Fixed-size grid used at 64×64 for tactical battles and the editor |
| `SetXY` | `COR/Foundation/SetXY.swift` | Coordinate set with 64 rows of 64 bits for visibility, movement, and settlements. Iterates in the same row-major order as `Map.indices`. |
| `D20` | `COR/Foundation/D20.swift` | PRNG for combat resolution |

### State

The root `Core` struct (`COR/Model/Core.swift`) holds the HQ sim and an optional
tactical sim. The active scene is Tactical when that sim exists, otherwise HQ.
The single live instance is the global `core: Core` in `PG/App.swift`.

`Core.hq` owns the roster and treasury between scenarios. `startScenario` stores
the running battle in `Core.tactical` and switches to Tactical; `complete`
returns surviving non-auxiliary units and remaining prestige to HQ, clears the
battle, and switches back. `store` persists edits to either sim; storing HQ
clears the active battle.

Save slots contain the native `Core` layout. Battles saved with remote seats
resume with those seats controlled by AI. Slots written with the 32×32
layout open a fresh HQ through `UserDefaults.load(slot:)`. Sound and animation
preferences are stored separately. Older settings data loads with the default
sound and animation levels. The editor loads older maps
in the northwest corner of its 64×64 grid and fills the extra space with fields.

Game mechanics are implemented using integer arithmetics. All game state is stored inline, no heap references allowed. For performance reasons `CArray<capacity, Element>` should be used instead of `Array<Element>`. A `Unit` keeps only its runtime fields plus a `model: UnitModel` index; the fixed per-platform stats live in the global `UnitStats.table` (`COR/Model/UnitStats.swift`), so identical models share one stats row and the inline state stays small.

Each `TacticalAction` reducer opens with a guard on its sim-level legality predicate — `canMove` / `canAttack` / `canEmbark` / `canDisembark` / `canResupply` / `canBuy`, colocated with the reducer it mirrors — and an illegal action leaves the sim bitwise-unchanged (see the `reduce` doc in `COR/Tactical/TacticalReaction.swift`). The heuristic AI consults the same predicates. `TacticalSim.settlements: SetXY` indexes settlement tiles at battle creation. Turn bookkeeping and the AI use this index while ownership changes in `control`. See [Tactical AI](./AI.md).

### Concurrency

Strict concurrency is enabled project-wide.
