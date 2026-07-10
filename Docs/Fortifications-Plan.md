# Fortifications Plan

Roadmap item (Scenario):
> Add fortifications at map gen, add 4 value toggle in new scenario menu.
> New tile: fortifications (`.fort`). Rendered in decoration layer.
> Set base entrenchment to 3. Def bonus and close combat same as city.
> Add move cost penalty for tracks and wheels.

## Context

A `.fort` tile gives map gen a defensive-line vocabulary and gives the
upcoming campaign Province feature (see `Province-Plan.md`) a way to express
strategic fortification levels on the tactical map. The `Fort.png` asset
already exists in `PG/Assets.xcassets/Tiles.spriteatlas/Fort.imageset/`.

## 1. Terrain case — `COR/Model/Terrain.swift`

Append `case fort` **after** `.roadX` (raw value 22 — appending keeps every
existing saved byte meaningful; never reorder).

Behavior (all in `Terrain.swift`):

- `baseEntrenchment`: `.fort` → 3 (join the `.city` row).
- `def(_:)`: add `.fort` to the `.city, .mountain, .forestHill` case.
- `closeCombat(_:)`: add `.fort` to the `.city, .mountain, .forestHill` case.
- `moveCost(_:)`:
  - inf/aa/art (leg): 1 — like field, no penalty.
  - supply/wheelArt/wheelAA/lightWheel (wheels): 3.
  - trackArt/trackAA/lightTrack/heavyTrack (tracks): 2.
  - air: unchanged (`.fort` is not no-fly → cost 1).
- Everything else stays at defaults: **not** a settlement (no capture, no
  income, no shop/spawn), not highground, elevation 0, not bridgable.
- `COR/Model/Strings.swift` `Terrain.description` (~line 145): `case .fort: "fort"`.

## 2. Rendering — decoration layer

- `PG/Scene/TileSprites.swift:38-57` `Terrain.decoration` (exhaustive switch,
  compile error until handled): `case .fort: .fort`.
- `PG/Scene/TileSprites.swift:162-166` `SKTileSet.decorated` array: add
  `.fort` — **without this the decoration silently never renders.**
- `tileSurface` default already gives `.fort` a field base — keep.

## 3. Editor

- `PG/Editor/EditorNodes.swift:102-126` `Terrain.image` (exhaustive): add `.fort`.
- `PG/Editor/EditorState.swift:173-177` `Terrain.palette`: add `.fort` brush.
- `PG/Editor/EditorState.swift:179-211` ASCII `code` / `init?(code:)`: map
  `.fort` ↔ `"T"` so editor save/load round-trips (`"f"` is taken by forest).

## 4. AI encoding

- `COR/Tactical/AI/Encoding.swift:186-201` `Terrain.plane` (exhaustive): map
  `.fort` to the **same plane as `.city`** — do NOT add a new plane
  (`planeCount` 51 is a trained-weights contract). Entrenchment feature flows
  automatically via `baseEntrenchment` (Encoding.swift:112).

## 5. Map generation — `COR/Tactical/MapGeneration.swift`

- `Map<32, Terrain>.init(size:seed:players:terrain:)` gains `forts: Int = 0`
  (0…3).
- New `placeForts(d20:level:)` called **last**, after `shapeRoads()`, so
  roads/cities/rivers are unaffected and road routing never sees forts.
- **`level == 0` must return before drawing from `d20`** — default output
  stays byte-identical to today for a given seed.
- Placement (deterministic via the passed `d20`):
  - target tile count = `level * size / 8` (size 32 → 4/8/12).
  - eligible tile: `.field`, `.forest` or `.hill`; no settlement in `n8`.
  - loop (bounded attempts, e.g. `target * 8`): pick a random anchor; if
    eligible, lay a short line of 2–4 tiles (random N–S or W–E orientation),
    extending only through eligible tiles; count placed tiles toward target.

## 6. Scenario menu toggle — `PG/HQ/HQScenario.swift`

- `var forts: UInt8 = 0` captured alongside `size` (line ~18).
- Replace the `.space` at start-block index **29** (next to the Size cycler
  at 28) with a 4-value toggle following the exact Size/Tier idiom:
  icon `.toggle4(forts)`, status `"Forts: \(forts)"`, update does
  `forts.toggle4()` and refreshes `m.items[29]`.
- Start button passes `forts: Int(forts)` into `TacticalSim(...)`.

## 7. Threading — `COR/Tactical/TacticalStateFactory.swift`

`TacticalSim.init(players:units:size:seed:terrain:objective:)` gains
`forts: Int = 0`, forwarded to the `Map` init at line 11.

Out of scope: LAN lobby toggle, `netVersion` bump (TacticalState layout is
unchanged; forts ride inside the existing map bytes), UserDefaults
persistence of the toggle (Size isn't persisted either).

## 8. Tests

`Tests/MapGenerationTests.swift`:
- default gen (`forts` omitted) produces zero `.fort` tiles across seeds.
- `forts: 3` produces > 0 forts on several seeds/sizes; no fort on
  water/settlement/road/bridge/mountain tiles; fort count(level 3) ≥ count(level 1).
- same seed + `forts: 3` twice → identical maps (determinism).

`Tests/UnitTests.swift` (or TacticalTests): `.fort.baseEntrenchment == 3`,
`.fort.def(.inf) == Terrain.city.def(.inf)`, `.fort.closeCombat(.heavyTrack)
== Terrain.city.closeCombat(.heavyTrack)`, move costs 1/3/2 for leg/wheel/track.

## Verification

```bash
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst'
xcodebuild test -scheme PG -destination 'platform=macOS'
```

Manual: new scenario → set Forts to 3 → forts visible on map (decoration),
infantry entrenches to 3 on a fort, wheels/tracks pay the movement penalty;
editor can paint/save/load forts.
