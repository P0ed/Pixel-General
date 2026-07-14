# Map Modes Plan

## Tactical: Defense (Right+D)

Shade every tile by how defensible it is *for the selected unit's type*,
falling back to infantry when nothing is selected. Reuses the 8-step
red→green `.supply(level)` gradient surface.

The scalar is grounded in the real combat math (`defenderMod` in
`COR/Tactical/TacticalAttack.swift` = `entDef + terrain.def(type) + …`, with
`entDef` floored at the tile's base entrenchment by the end-of-turn entrench
rule): **`terrain.def(type) + terrain.baseEntrenchment`** — the defender
modifier a unit that just arrived enjoys after one end of turn. Range −5
(heavy armor in a river) … +6 (infantry in a city/fort), mapped linearly onto
gradient steps 0…7 (`(value + 5) * 7 / 11`; field = neutral 3). Air types
shade uniformly at the neutral level — they ignore terrain and never
entrench.

Changes:

- **COR** — `UnitType.isAir` becomes public (already exists, internal).
- **PG** `TacticalState.swift` — `MapMode` gains `.defense`; `setMapMode`
  `.d` selects it (keyboard "4", gamepad Hold R+Y — both already emit
  `.action(.d, modifiers: .right)`).
- **PG** `TacticalNodes.swift` — cache the resolved `UnitType` next to the
  cached `SupplySources` so a selection change repaints the base layer only
  when the *type* changes; new `.defense` case in `baseGroup`.
- **Docs** — Mechanics.md map-mode section; HelpMenu controls lines split so
  the four modes stay readable.

# Strategic Map Modes: Industry & Forts — Plan

## Goal

Two new presentation-only map modes for the Strategic (campaign) layer, on the
currently unused Right+C chord, toggling between each other the way Right+B
toggles country/team:

- **Industry** — shade each owned province by its total factory levels
  (all `BuildingType`s except `fort`). Answers "where do I build" and
  "where is the enemy's war economy".
- **Forts** — shade each owned province by its `fort` building level (0–3).
  Shows the defensive line and its gaps.

Both reuse the existing 8-step red→green `.supply(level)` tile surface, which
is already registered in the shared `SKTileSet.terrain` used by the strategic
map — no new textures or tile groups.

## Why it is cheap

- `StrategicMapMode` lives in `StrategicUI` (PG-only, never persisted, never
  networked) — adding cases cannot affect COR determinism or saves.
- Input is already wired end-to-end: keyboard "3" and gamepad Hold R+X emit
  `.action(.c, modifiers: .right)`; `setMapMode` currently ignores `.c` on
  Strategic.
- The render path is one `switch` in `StrategicNodes.baseGroup(for:at:)`.

## Changes

1. **COR** — `COR/Strategic/Province.swift`: add `Province.industry`, the sum
   of all building levels excluding `.fort`. A domain quantity (factory
   capacity), colocated with `Province`.
2. **PG** — `PG/Strategic/StrategicState.swift`:
   - `StrategicMapMode` gains `.industry` and `.forts`.
   - `setMapMode` `.c` case: `ui.mapMode = ui.mapMode == .industry ? .forts : .industry`.
3. **PG** — `PG/Strategic/StrategicNodes.swift` `baseGroup`:
   - Ownerless (sea) tiles render as water, exactly like terrain mode.
   - `.industry`: `.supply(min(7, industry))` at the tile's elevation.
   - `.forts`: `.supply(fort * 7 / 3)` — levels 0/1/2/3 map to gradient
     steps 0/2/4/7.
4. **Docs** — `Docs/Mechanics.md` map-mode section: describe the strategic
   Right+C toggle. `PG/App/HelpMenu.swift` controls text: extend the
   "1 / 2 / 3" and "Hold R + A / B / X" lines.

## Verification

- `xcodebuild build -scheme PG -configuration Release -destination
  'platform=macOS,variant=Mac Catalyst'`
- `swift test --package-path COR` (Province change only adds a computed
  property; no behavior change expected).
