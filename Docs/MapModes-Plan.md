# Map modes: Country coloring (Scenario) + Zoom/pan/modes (Campaign)

## Context

`Docs/Roadmap.md` lists four related items:

```
## Scenario
- Country map mode.
- - Add `Country.color`.

## Campaign
- Zoom, pan controls.
- Map modes.
```

Investigation found the codebase already half-built most of this:

- `Country.color: SKColor` already exists (`PG/Tactical/UnitSprites.swift:82-105`), used today for unit-sprite tinting, but only 10 of 24 countries have a bespoke color — the rest fall back to a team color via a `default:` case explicitly commented `// Placeholder: campaign nations are tinted by team until bespoke colors land.` "Add `Country.color`" means finishing this, not creating it from scratch.
- Tactical already has a `MapMode` concept (`terrain / political / supply`, `COR/Tactical/TacticalState.swift:50-52`), toggled with `§`/gamepad Options, cycling through tile-coloring styles. Its `.political` mode colors by **player slot** (0-3, a fixed 4-color palette), not by the actual controlling `Country` — that distinction is exactly what "Country map mode" adds.
- The 2-finger pan gesture and `z/x/c` zoom keys are wired generically on the shared `Scene` class (`PG/Scene/Scene.swift`, `PG/Scene/SceneInput.swift`) and already fire for the Campaign/Strategic screen today — they're just silently dropped because `StrategicState.apply` (`COR/Strategic/StrategicInput.swift`) doesn't handle `.scale`/`.pan`, and `StrategicUI` has no `scale` field. "Zoom, pan controls" is about wiring already-arriving input, not building new gesture code.
- Campaign's map is always drawn in one fixed "political-by-team" style (`PG/Strategic/StrategicNodes.swift:41-70`). "Map modes" adds a toggle there too, reusing the same country-coloring infra built for the Scenario task.

Because B (Scenario) and D (Campaign map modes) share the same underlying `Country.color` / tile-coloring mechanism, and C (Campaign zoom/pan) touches the same files as D, this was implemented as one connected change.

**Decision from user:** Campaign pan decouples the camera from the cursor — panning moves only the camera, and cursor moves (arrow keys / tile tap) stop force-snapping the camera back, matching how Tactical already behaves (its `moveCursor` never touches `ui.camera`). This makes manual pans "stick" instead of being undone by the next keypress.

## A. Finish `Country.color`

**File:** `PG/Tactical/UnitSprites.swift:82-105`

Replace the `default:`-terminated switch with an exhaustive one (no `default`), matching the style of the sibling `var flag: UIImage` switch just below it, which already lists all 25 cases explicitly. Keep the 10 existing bespoke colors (`usa, isr, pak, swe, ukr, den, ned, rus, irn, ind`); add the missing 14 (`nor, fin, ger, est, lva, ltu, pol, cze, aut, bel, svk, rom, hun, mol`) plus an explicit `.none` fallback (e.g. `.gray`). Use `Country.team` only as a starting hue family per team, then vary shade/saturation within each team so countries that can face off in the same battle stay visually distinct.

## B. Tactical "Country map mode"

1. `COR/Tactical/TacticalState.swift:50-52` — add a 4th `MapMode` case: `case terrain, political, supply, country`.
2. `COR/Tactical/TacticalInput.swift` (`toggleMapMode()`) — extend the cycle: `terrain → political → supply → country → terrain`.
3. `PG/Scene/TileSprites.swift`:
   - Add `case country(Country)` to `TileSurface` (line ~9-12), with `.color` arm `country.color` (reuses part A).
   - Extend the eager bake loop in `SKTileSet.terrain` (lines ~170-185): inside the existing `for elevation in 0...2`, add `for c in Country.allCases { ts.append(.base(surface: .country(c), elevation: elevation)) }`. `SKTileMapNode` only renders tile groups that belong to its `SKTileSet`, so new surfaces must be pre-baked here the same way `.political`/`.supply` are — this adds 75 tile groups (25 countries × 3 elevations), roughly tripling the palette, one-time at launch. `SKTileSet.terrain` is shared by both Tactical and Strategic, so part D's country mode reuses this bake for free.
4. `PG/Tactical/TacticalNodes.swift` (`baseGroup(for:at:supply:)`, lines ~147-178) — add: `case .country: return .base(surface: .country(state.sim.control[xy]), elevation: state.sim.map[xy].elevationLevel)`, reading the real controlling `Country` from `sim.control[xy]` directly (unlike `.political`, no player-slot resolution).
5. `PG/App/HelpMenu.swift:104` — update `"§  Cycle map mode (terrain · political · supply)"` to include `· country`.

## C. Campaign "Zoom, pan controls"

1. `COR/Strategic/StrategicState.swift`:
   - `StrategicUI` (lines 32-40) — add `public var scale: Int = 2` (matches today's hardcoded `camera.setScale(2)`, so `x` reproduces current behavior; `z`=1 zooms in further, `c`=4 zooms out for a campaign overview — same 1/2/4 range as Tactical, no need to diverge).
   - `StrategicSim.europe(human:)` (lines ~85-112) already computes a `sx/sy/count` centroid of the human player's territory but never uses it — finish this: expose it so a sensible initial camera position exists.
2. `COR/Strategic/StrategicInput.swift`:
   - Add `case .scale(let value): { ui.scale = value; return .none }()`.
   - Add `case .pan(let dxy): handlePan(dxy)` with a new `handlePan` that updates **only `ui.camera`** (clamped via `.clamped(sim.owner.size)`), leaving `ui.cursor` untouched.
   - In `moveCursor` and `select`, **remove** the `ui.camera = xy` lines — cursor movement no longer force-follows the camera (this is the decoupling decision above; camera now moves only via `.pan`).
3. `PG/App/Scenes.swift:19` — pass an initial `StrategicUI(cursor: centroid, camera: centroid)` (from the new `StrategicSim` centroid) instead of the default `StrategicUI()` (which starts at `.zero`), so decoupling doesn't leave the campaign screen opening on a blank map corner.
4. `PG/Strategic/StrategicNodes.swift`:
   - `addCamera` (lines 23-30) — drop the hardcoded `camera.setScale(2)`; scale is now driven by `update`, matching Tactical's `addCamera` (which sets no scale at all).
   - `update(_:)` (lines 43-58) — add the same animated-scale block Tactical's `updateView` has: `let cameraScale = CGFloat(state.ui.scale); if camera.xScale != cameraScale { camera.run(.scale(to: cameraScale, duration: 0.15)) }`.

## D. Campaign "Map modes"

1. `COR/Strategic/StrategicState.swift` — add `@frozen public enum StrategicMapMode: UInt8, Hashable { case team, country }` and `public var mapMode: StrategicMapMode = .team` on `StrategicUI` (named distinctly from Tactical's `MapMode` since it's a different, COR-module-level type with different cases).
2. `COR/Strategic/StrategicInput.swift` — add `case .mode: toggleMapMode()`, flipping `team ⇄ country`.
3. `PG/Strategic/StrategicNodes.swift` (`update(_:)`, lines ~52-57) — branch the per-tile `setBase` call on `state.ui.mapMode`: `.team` keeps the existing `Self.political(state.sim.owner[xy], elevation:)` path unchanged; `.country` calls `.base(surface: .country(state.sim.owner[xy]), elevation:)` (reuses part B's already-baked tile groups, no new baking needed).
4. `PG/App/HelpMenu.swift:104` — genericize the shared line to `"§  Cycle map mode"` (drop the mode-name enumeration), since Tactical and Strategic now cycle different mode sets and one shared help string can't literally list both.

## Verification

- Build the app target and run in the simulator.
- **Scenario:** start/resume a battle, press `§` four times to confirm the cycle is terrain → political → supply → country → terrain, and that `.country` mode shows visually distinct per-nation colors on controlled tiles (not just 4 team-bucket colors), matching `Country.color`.
- **Campaign:** open the Campaign screen, confirm it opens centered on the player's territory (not a blank corner). Two-finger drag to pan — confirm the view moves and *stays* where panned after pressing an arrow key (no snap-back). Press `z/x/c` to confirm zoom levels. Press `§`/gamepad Options to confirm it toggles team ⇄ country coloring.
- Confirm existing Tactical behavior (terrain/political/supply modes, zoom, pan) is unchanged.
