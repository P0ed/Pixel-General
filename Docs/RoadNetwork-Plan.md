# Road network generation

## Context

`connectCities` (`COR/Tactical/MapGeneration.swift`) is the weak pass of map
generation now that rivers follow valleys (see `MapGeneration-Plan.md`):

- **Disconnected networks.** Pass 1 greedily pairs each city with its nearest
  *unconnected* city, producing isolated 2-city segments. Pass 2 makes at most
  one merge attempt per segment, and only when the candidate is within a hard
  `manhattan < 22` cutoff — so maps routinely end with two or more road
  networks that never join, or cities whose pair-partner was taken and who
  never get a road at all.
- **Terrain-blind pairing.** "Nearest" is manhattan distance, so a city just
  across a mountain ridge or an unbridgable river elbow beats a slightly
  farther neighbor on open plain; the carved road then detours enormously (or
  `connect` fails outright and the city stays roadless).
- **Order-dependent topology.** Cities are processed in placement order, so
  the pairing — and therefore the whole network shape — is an artifact of the
  jittered-grid iteration, not of geography.
- **No loops.** Real road networks are a tree plus a few redundancy links
  between mutually-close cities; the current output is only ever fragments of
  a tree.

## Design (implemented)

Roads grow the way real networks do: local links first, trunks shared, a few
loops closed at the end. All in `COR/Tactical/MapGeneration.swift`; public
init signature unchanged; generation stays deterministic per seed (no new
`d20` draws — MST and detour selection are pure functions of the terrain).

1. **Shared Dijkstra core.** `shortestPath(from:reached:cost:)` splits into a
   `dijkstra` core returning the distance/predecessor fields plus the goal
   tile, with two thin wrappers: the existing path reconstruction, and a new
   `distances(from:)` full flood over `stepCost`.
2. **Terrain-aware city distances.** `travelCosts(between:)` floods from each
   city on the pristine (pre-road) map — n−1 floods for n ≤ 16 cities on a
   ≤ 32×32 grid, trivial — giving an all-pairs travel-cost matrix.
   `UInt16.max` marks pairs with no route (opposite banks of an uncrossable
   river): exactly the pairs no road should attempt.
3. **Minimum spanning forest.** `spanningEdges(costs:)` runs Prim's over the
   matrix. Every city joins the cheapest tree reachable from it; when rivers
   split the map, each side grows its own tree instead of silently failing.
4. **Trunk reuse.** Tree edges carve in ascending weight order with the
   existing `connect` (roads cost 1 to Dijkstra), so longer routes merge into
   already-carved local roads — Y-junctions emerge naturally and `shapeRoads`
   turns 3-way junctions into villages, as before.
5. **Loop closing.** `detourEdges(costs:carved:)` compares each non-tree
   pair's network distance (Floyd–Warshall over the abstract carved graph,
   n ≤ 16 so n³ is nothing) against its direct cost and carves the worst
   detours — ratio ≥ 1.8, at most `max(1, n / 5)` extras, recomputing after
   each addition. This closes C-shapes into rings the way beltways and
   valley-to-valley links do, without redundant spaghetti.

## Verification

- `roadsConnectAllCities` (new, `Tests/MapGenerationTests.swift`): for pinned
  seeds at sizes 16/24/32, flood-fill the `hasRoad` tile graph from one city
  and expect every city reached. Full suite green as of 2026-07-10.
- Scratch scan (48 seeds, size 32, since deleted): every seed produced a
  single road component containing all 16 cities — zero disconnections, vs
  routine fragmentation before. Road-graph cyclomatic numbers ran 0–5
  (mostly 1–3), confirming the detour pass adds loops without spaghetti.
- ASCII dumps (`tmp/road-dumps.txt`) of seeds 0/3/7/21/42 at 32 and 16–24
  spot checks: trunk sharing with village Y-junctions, bridges over rivers,
  no orphan fragments.
- `PolicyTests/randomWeightPolicyPlaysLegally` repinned from sim seed 9 to 8:
  the better-connected seed-9 map ends its battle at exactly the test's
  20-policy-step floor (the map itself is healthy — scanned seeds run 16–66
  steps; seed 8 sustains 66).
- `XY.manhattanComparator` removed — the old pairing pass was its last user.
