# Map generation improvements

## Context

`Map<32, Terrain>.init(size:seed:players:terrain:)` (`COR/Tactical/MapGeneration.swift`)
builds battle maps in four passes: noise terrain → rivers → cities/airfields →
road network. The river pass was the weakest link:

- **Fixed endpoints.** River entry/exit points were hardcoded fractions of the
  map size (`(0, size/3) → (size-1, 2size/3)`, …), so every map of a given size
  had rivers in the same corridors; only the wiggle in between varied with seed.
- **Terrain-blind paths.** The pressure flood quantized height with
  `UInt16(height.value + 1.0)` — a 2-level cost on a field whose values span
  roughly −1…1 — so rivers crossed ridges almost as readily as plains instead
  of following valleys.
- **Silent bail.** When a flood failed to reach its endpoint it executed
  `return` rather than `continue`, dropping *all* remaining rivers, not just
  the failed one.
- **No variety.** River count was a pure function of map area; no tributaries,
  no confluences (rivers hard-avoided each other via an 8-neighbor exclusion).
- **Latent heap overflow.** `connect`'s Dijkstra used `CArray<1024, _>` for its
  binary heap, but lazy-deletion Dijkstra on a 32×32 4-neighbor grid can push
  one entry per relaxation — up to 3969. Overflow traps on the `InlineArray`
  bounds check.

## A. Rivers (implemented)

All in `COR/Tactical/MapGeneration.swift`; the public init signature is
unchanged (rivers now also consume `d20`, so layouts differ from previous
builds for the same seed, but generation stays deterministic per seed —
`isDeterministicForSameSeed` still holds).

1. **Shared Dijkstra core.** `connect`'s heap search is extracted into
   `shortestPath(from:reached:cost:)` — goal is a predicate (a fixed exit tile
   for roads and edge-to-edge rivers, "any river tile" for tributaries), cost
   is a `(from, to) → UInt16?` closure with `nil` = impassable. Heap capacity
   raised to 4096 ≥ 3969, closing the overflow. `connect` and river carving
   both ride on it; the dead `crossesRiver` helper is removed.
2. **Seeded mouths.** `riverMouth(on:…)` samples 3 random points on a random
   edge (inside the middle ⅔ band, away from other rivers' mouths) and keeps
   the lowest-lying one, so rivers tend to enter through valleys. The exit
   edge is usually the opposite edge, sometimes an adjacent one (corner
   rivers), and must be ≥ `size − 1` manhattan from the source so the river
   genuinely partitions the map.
3. **Valley-following cost.** `riverStep` prices a tile by a low-passed height
   (`s9` average blended 3:1 with the local sample), squared — macro ridges
   repel the river strongly, flat ground is nearly free. On flat terrain a
   shortest path degenerates into a dead-straight run (a 1-tile detour costs a
   full extra step, which small per-tile noise can never repay), so each river
   also gets its own **meander field** — a low-frequency Perlin map
   (`GKNoiseMap.meander`, seeded from the river's salt) whose squared value is
   weighted *above* the base step cost, making smooth multi-tile bends worth
   taking even where the real terrain offers none. A per-tile `wiggle(xy,
   salt)` (SplitMix64 hash of coordinates + the per-river salt drawn from
   `d20`) breaks ties without depending on RNG draw order; map-border tiles
   carry a penalty so rivers dive inland instead of hugging edges.
4. **Tributaries.** Rivers after the first have a 40% chance to target "any
   existing river tile" instead of an exit edge, forming a confluence. For
   those, land next to an existing river costs a penalty instead of being
   walled off, so they approach head-on and terminate at first touch.
   Non-tributary rivers keep the hard 8-neighbor gap.
5. **Count variety.** Base `max(1, count / 288)` rivers plus a random extra on
   maps ≥ 24×24; a river whose mouths or path can't be placed is skipped
   (`continue`-equivalent, not `return`), so one failure no longer cancels the
   rest. The first river is guaranteed: its mouths face opposite edges with no
   prior-river constraints and every land tile is passable, so
   `producesNonEmptyMapWithCitiesAndRivers` holds by construction.

Downstream passes are untouched: cities still refuse river tiles, roads still
bridge only straight one-wide segments (`bridgableRiver`), `shapeRoads` still
orients bridges.

## B. Follow-ups (not in this change)

- **Lakes** — widen a river where the low-passed height field bottoms out, or
  flood small closed basins; needs a look at how `moveCost`/`def` should treat
  open water vs river.
- **Bridge-friendly carving** — meandering rivers have more elbows, and elbows
  are unbridgable (`bridgableRiver` needs a straight water tile). If seeds
  show up where road `connect` fails across a river, add a turn penalty to
  river carving (node = tile × incoming direction) or a post-pass that
  straightens double-elbows.
- **Forest clustering** — humidity is Voronoi noise sampled per tile; forests
  would read better grown as blobs around wet cells.
- **Coastlines** — ties into Roadmap "Sea tiles and ships": one map edge
  becomes sea when the strategic province borders it.

## Verification

- `xcodebuild test -scheme PG -destination 'platform=macOS'` — map-generation
  suite covers termination, determinism, presence of cities/rivers across
  seeds and sizes 16–32, terrain bias, orthogonal river contiguity, and (new)
  rivers touching the map border. Full suite green as of 2026-07-09.
- Eyeballed ASCII dumps of seeds 0/3/7/21/42/77 at 32×32 and several 16–24
  maps: rivers wind through low ground, enter/exit at varied edges, fork/join
  at confluences, and roads still bridge them.
