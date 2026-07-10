# Province Plan (Campaign, HoI lite)

Roadmap items:
> Add `struct Province`.
> Add build fortifications action for province with 0...3 levels.
> Add factories 0...3 levels in each province — Civil, Army (inf/art),
> Armor (ifv, tanks, sp art and aa), Air, UAV, AA, Navy types.
> Military factories determine aux army size and quality, available units in `Shop`.
> Civil factories affect overall income and starting scenario prestige.
> Display province stats in status string.
> Place starting factories at new campaign phase.

**Depends on `Fortifications-Plan.md`** (uses the `forts:` map-gen parameter).

## Context

The strategic layer today is only `owner` + `terrain` grids with an attack
action — no economy. Provinces (one per strategic tile) add the HoI-lite
build-up loop: factories shape what armies fight with, forts shape the
battlefield, civil economy feeds prestige.

Constraint (Docs/Architecture.md): everything inside `StrategicSim` is raw
bitwise encode/decode — `Province` must be fully inline, no heap, no padding
surprises (`Tests/StrategicTests.swift:166` asserts byte-identical re-encode).
Adding fields to `StrategicSim`/`Core` changes `MemoryLayout` size → old saves
silently reset via the existing `decode` guard. Accepted, no migration.

## 1. `Province` — new file `COR/Strategic/Province.swift`

(New files auto-join targets — synchronized groups.)

```swift
@frozen public enum BuildingType: UInt8, CaseIterable {
	case civil, fort, army, armor, aa, air, uav, navy
}

/// Per-tile campaign state beyond ownership: fortification level and
/// factory levels, all 0...3. Fully inline for raw encode/decode.
@frozen public struct Province: BitwiseCopyable {
	/// Factory levels indexed by `BuildingType.rawValue`.
	public var buildings: [8 of UInt8]

	public init() {
		buildings = .init(repeating: 0)
	}

	public subscript(_ t: BuildingType) -> UInt8 {
		get { buildings[Int(t.rawValue)] }
		set { buildings[Int(t.rawValue)] = newValue }
	}
}
```

`StrategicSim` (`COR/Strategic/StrategicState.swift`) gains
`public var provinces: Map<32, Province>` (init default: all-zero). Helpers:

- `func buildingsTotal(_ t: BuildingType, of c: Country) -> Int` — sum over owned tiles.
- `func canBuild(_ xy: XY) -> Bool` — `owner[xy] == human`, `provinces[xy].fort < 3`, `battle == nil`.
- `func buildingCost(_ building: BuildingType, above level: UInt8, at xy: XY) -> UInt16`.

## 2. Build-fortification action

Follow the attack pattern (input → reduce emits event → PG processes with `core`):

- `COR/Strategic/StrategicReaction.swift`: add `case build(XY)` to both
  `StrategicAction` and `StrategicEvent`. `reduce(.build(xy))`: guard
  `canBuild(xy)`, emit `.build(xy)` — **no sim mutation** (cost lives in
  `Core.hq`).
- `COR/Strategic/StrategicInput.swift`: `action(.b)` → `.action(.build(cursor))`
  when `canBuild(cursor)` (mirror how `.a`/attack is wired).
- `PG/Strategic/StrategicEvent.swift`: `processBuild(xy)` — mirror
  `processAttack`: if `core.hq.player.prestige >= cost`, deduct it
  (via a small `Core.payForFort(...)`-style mutator in `COR/Model/Core.swift`),
  increment `scene.state.sim.provinces[xy].fort`, persist the sim to core,
  `core.save()`, refresh the map/status.
- Status action hint (`PG/Strategic/StrategicMode.swift:24-33`): attack and
  build are mutually exclusive (enemy vs own tile) — show
  `"A: attack"` or `"B: fortify (\(cost))"` accordingly.

## 3. Starting factories — `StrategicSim.europe(country:)`

After parsing owner/terrain (`StrategicState.swift:98-117`), run a
deterministic placement pass (fixed-seed `D20`, countries in rawValue order,
tiles in index order — `europe` must produce identical bytes every call):

- Per country: `civil budget = max(1, tiles/8)` levels,
  `military budget = max(1, tiles/6)` levels cycled through
  `[army, armor, air, aa, army, armor, uav]` (navy stays 0 until ships exist).
- Spread levels across distinct provinces near the country's `centroid`
  first; cap 3 per type per province.

## 4. Military factories → aux army & Shop

**Aux size/quality** — `COR/Model/Templates.swift`:
- New `static func aux(_ country: Country, tier: UInt8, army: Int, armor: Int, air: Int, aa: Int) -> [Unit]`
  (country-wide factory totals, each clamped 0…4): 1 truck (+1 if army+armor ≥ 4);
  `army`× infantry alternating inf1/inf2, +art1 at ≥2, +art2 at ≥3;
  `armor`× cycling ifv1/tank1/ifv2/tank2; `air`× alternating air1/air2;
  `aa`× alternating aa1/aa2; cap 16; `.veteran` for units whose factory
  total ≥ 3. Existing `aux(_:tier:)` stays for scenario battles.
- `TacticalSim.init` (`COR/Tactical/TacticalStateFactory.swift` /
  `TacticalState.swift:65-70`): new optional per-seat override
  `aux: [[Unit]] = []` — seat i uses `aux[i]` when provided, else the
  existing `.aux(country)` template.

**Shop gating** — `COR/Model/Shop.swift`:
- `Unit → BuildingType` mapping (extension near `Shop.filter`):
  inf/art → `.army`; recon/ifv/tank/sp art/sp aa (all wheel/track models)
  → `.armor`; heli/fighter/cas → `.air`; towed aa → `.aa`; truck/supply →
  always available.
- `Shop.factories: UInt8 = 0xFF` bitmask (bit = `BuildingType.rawValue`);
  `filter` also requires the unit's factory bit.
- `TacticalState` gains `buildingsMask: [4 of UInt8]` (default `0xFF`);
  `TacticalShop.swift:22` passes `factories: buildingsMask[playerIndex]` into
  `Shop`. Layout change → bump `netVersion` to 2
  (`PG/Networking/Messages.swift:7`).

## 5. Campaign battle wiring — `Core.startCampaignBattle` (`COR/Model/Core.swift:60-82`)

- Human prestige: `hq.player.prestige + 40 * civilTotal(human)`; defender
  prestige: `.poor + 40 * civilTotal(defender)`. (Post-battle prestige writes
  back in `complete` → the civil bonus recurs every battle = "overall income".)
- `aux:` overrides for both seats from `Templates.aux(country:tier:army:armor:air:aa:)`
  using country-wide totals.
- `buildingsMask` per seat: bit set where the country's total for that type ≥ 1
  (truck/supply unaffected).
- `forts: Int(strategic.provinces[tile].fort)` → threads into map gen.

## 6. Status string — `PG/Strategic/StrategicMode.swift:24-33`

For land tiles append province stats via the existing `.makeStatus` builder:
`fort: n` when > 0 and nonzero factories as short tags, e.g.
`civ 2 · army 1 · air 1`.

## 7. Tests

`Tests/StrategicTests.swift`:
- `serializationRoundTrip` must still pass (byte-identity guards padding).
- `europe()` twice → identical bytes; big countries (ger, rus, pol) have
  ≥1 civil and ≥1 military factory level; all levels ≤ 3.
- `canBuild`: own tile true, enemy/sea tile false, false at fort 3.
- `reduce(.build)` emits `.build` and doesn't mutate.
- `buildingsTotal` sums correctly after `resolveBattle` flips owners.

New/extended:
- Templates: more factories → more aux units; totals ≥ 3 → veterans; cap 16.
- Shop: cleared `.armor` bit removes tanks/ifv/recon but keeps inf/art/truck.
- Core: `startCampaignBattle` prestige includes civil bonus (constructible via
  `Core.new` + `startCampaign(hq, .europe(...))`).

## Verification

```bash
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst'
xcodebuild test -scheme PG -destination 'platform=macOS'
```

Manual: New → Campaign → Start; cursor over own province shows factory/fort
stats and `B: fortify`; building deducts prestige and caps at 3; attacking a
fortified province generates a map with forts; campaign shop hides unit
classes the country has no factories for.
