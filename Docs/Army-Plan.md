# Army Plan (Campaign, HoI lite)

Roadmap items:
> Add army (up to 16 units).
> - max 4 armies per country.
> - each new army costs more to maintain.
> - main army stored to / loaded from `Core.hq`.
> - has limited move speed.
> - allows attack enemy tiles in `.n4`.
> - when defending, nearest army (if not too far) joins aux forces.
> - use HQMode to display / update an army.

**Depends on `Province-Plan.md`** (factories/aux already wired into battles).

## Context

Campaign attacks today launch from any border tile (`canAttack` checks `.n8`
adjacency to *any* owned tile) and always field the full `Core.hq` roster.
Armies make position matter: up to 4 rosters of 16 units each, attacks only
from tiles `.n4`-adjacent to an army, slow movement, extra armies drain
prestige every turn.

Constraints (Docs/Architecture.md): `StrategicSim` and `Core` are raw
bitwise encode/decode — `Army` must be `BitwiseCopyable`, fully inline.
Layout changes reset old saves via the existing `decode` size guard.
Accepted, no migration.

Only the human acts on the strategic map today (Simple AI is a later
roadmap item), so `armies` holds the *human* country's armies. The
defender-reinforcement rule is implemented generally but only fires once
AI attacks exist.

## 1. `Army` — new file `COR/Strategic/Army.swift`

```swift
@frozen public struct Army: BitwiseCopyable {
	/// Roster for army slots 1...3. Slot 0 is the main army: its roster
	/// lives in `Core.hq.units` and this field stays zeroed.
	public var units: [16 of Unit]
	public var position: XY
	/// Tiles this army may still move this turn.
	public var mp: UInt8
	public var active: Bool
}
```

- `StrategicSim` gains `armies: [4 of Army]` (max 4 per country) and
  `battleArmy: UInt8` — the slot fighting the running battle.
- Constants: `Army.moveSpeed = 2` tiles/turn;
  `Army.upkeep(slot:) = 50 * slot` prestige/turn (0/50/100/150 — the main
  army is free, each new army costs more to maintain);
  `Army.auxJoinRange = 2` (Chebyshev).
- Helpers on `StrategicSim`:
  - `armyIndex(at: XY) -> Int?` — active army on a tile (one per tile).
  - `canFound(at: XY) -> Bool` — own land tile, no army there, a free slot,
    no battle running.
  - `reachable(by slot: Int) -> SetXY` — BFS over `.n4` through own land,
    depth `mp`, skipping tiles occupied by other armies.
  - `hasCoreForce(_ slot: Int) -> Bool` — slot 0 always (roster is
    `Core.hq`), otherwise any alive rostered unit.
- `europe(human:)` founds the main army on the owned tile nearest the
  country centroid (deterministic tile order), `mp = moveSpeed`.

## 2. Rules & reducer — `COR/Strategic/*`

- `canAttack(xy)` (StrategicState.swift): enemy-team land tile
  `.n4`-adjacent to an active army with `mp > 0` and a core force —
  replaces the `.n8` border rule.
- `StrategicAction`: add `case move(Int, XY)`, `case found(XY)`.
  `StrategicEvent`: add `.move`, `.found`, `.upkeep(UInt16)`,
  `.army(Int)` (open roster in HQ — emitted by the input layer only).
- `reduce(.move(slot, xy))`: guard `xy ∈ reachable(by: slot)`; walk costs
  1 mp per tile (BFS depth), set position, emit `.move` (PG persists).
- `reduce(.found(xy))`: guard `canFound`; activate a free slot with an
  empty roster, `mp = 0` (moves from next turn), emit `.found`.
- `reduce(.attack(xy))`: guard `canAttack` (was unconditional), emit.
- `reduce(.endTurn)`: `turn += 1`; reset every active army's `mp`;
  auto-disband slots 1–3 with no alive rostered unit; emit
  `.upkeep(total)` when the active slots' summed upkeep > 0.
- `resolveBattle(at:won:by:)`: on a win move `armies[battleArmy]` onto the
  tile; always clear `battleArmy`.

## 3. Input & UI — `COR/Strategic/StrategicInput.swift`, `PG/Strategic/*`

- `StrategicUI` gains `selected: Int?` + `selectable: SetXY?`.
- `.action(.a)`: enemy tile → `.attack` (as today, army-gated); own army
  tile → toggle selection and compute `selectable`; tile in `selectable`
  with a selection → `.action(.move(selected, xy))`, then deselect.
- `.action(.c)`: own army tile → `.events([.army(slot)])`; else
  `canFound(cursor)` → `.action(.found(cursor))`.
- `StrategicNodes`: 4 flag sprites (`country.flag`, `TileZ.unit`), shown/
  positioned in `update`; `map.selection` marks the selected army.
- `StrategicEvent.swift`: `.move`/`.found` → `core.store(sim)` +
  `core.save()`; `.upkeep(cost)` → `core.payUpkeep(cost)` + store + save;
  `.army(slot)` → store, `core.openArmy(slot)`, save, `present(.auto)`.
- Status (StrategicMode.swift): army line
  `army N · M/16 · mp K` (slot 0 counts `core.hq` units); hints
  `A: attack` / `A: move` / `B: fortify` / `C: army` / `C: found army`.

## 4. HQMode reuse — `COR/Model/Core.swift`, `PG/*`

- `Core` gains `army: UInt8 = 0` — which roster the `.hq` location edits.
- `openArmy(_ slot:)`: from `.strategic`, set `army`, go `.hq`.
  `closeArmy()`: back to `.strategic`, `army = 0`. `goHQ()` resets `army`.
- `Scenes.hq` builds `HQState` from `core.hqSim`: slot 0 → `clone(hq)`;
  slot > 0 → `HQSim(player: hq.player, units: strategic.armies[slot].units)`
  (default 4×4 map). Purchases/sales spend the shared `hq.player` prestige.
- `Core.store(HQSim)` routes by `army`: slot > 0 writes `sim.player` back
  to `hq.player` and `sim.units` into `strategic.armies[slot].units`;
  slot 0 keeps today's `hq = clone(sim)`.
- `HQEvent.processMenu`: when `core.army > 0` show only a Back item
  (`closeArmy` + save + present) — scenario/campaign/LAN menus stay
  main-roster only.

## 5. Battle wiring — `Core.startCampaignBattle` / `complete`

- `startCampaignBattle(at:)`: pick the attacking slot (active, `mp > 0`,
  core force, tile in `.n4`) — first match, deterministic; bail if none.
  Set `battleArmy`, zero its `mp`, core units = slot 0 ? `hq.units` :
  `armies[slot].units` (alive only).
- Defender aux: factory aux + `auxReinforcement(for: defender, near: tile)`
  — the defender's nearest active army within `auxJoinRange`, excluding
  the fighting slot, its alive units marked `.aux`, total capped 16. Armies
  belong to the human, so this fires only when the human defends (future
  AI attacks); the helper is tested directly.
- `complete()`: survivors go back to the fighting slot's roster
  (`hq.units` for 0 — unchanged behavior); a wiped slot > 0 deactivates.

## 6. Tests — `Tests/StrategicTests.swift` (+ Core cases)

- `europe()` founds an active main army on an own tile, `mp == moveSpeed`;
  determinism test still passes (armies included in the compared bytes? —
  compare `owner`/`provinces` maps plus army positions).
- `canAttack`: border tile far from any army is *not* attackable; `.n4`
  tile of the army is; `.n8`-diagonal-only is not; `mp == 0` blocks.
- `reduce(.move)`: respects `reachable` (own land, no sea/enemy, range
  `mp`), decrements mp; move onto another army is rejected.
- `found`: works on own empty tile, refuses a 5th army / occupied tile;
  slots 1–3 with an empty roster disband at `endTurn`.
- `endTurn`: resets mp, emits `.upkeep(50)` with one extra army founded
  (and units added so it survives disband), nothing with the main army only.
- `resolveBattle` win moves the fighting army onto the target tile.
- Core: `startCampaignBattle` fields `armies[1]`'s roster when slot 1 is
  the adjacent attacker; `complete` writes survivors back to slot 1;
  `payUpkeep` clamps at zero; `auxReinforcement` returns the nearest
  army's units marked aux and `[]` beyond `auxJoinRange`.
- Update existing tests that assumed border attacks
  (`canAttackEnemyBorderTile`, `reduceAttackEmitsEvent`,
  `resolveBattleAnnexesOnWin`, …) to position an army first.

## Verification

```bash
xcodebuild build -scheme PG -configuration Release -destination 'platform=macOS,variant=Mac Catalyst'
xcodebuild test -scheme PG -destination 'platform=macOS'
```

Manual: New → Campaign → Start; the main army flag sits near the centroid;
A selects it, A on a highlighted tile moves it (2/turn); attacks only work
`.n4`-adjacent to it; C on an empty own tile founds army 2, C on its flag
opens the roster in HQ (Back returns); end turn charges 50 prestige while
army 2 lives; a battle launched from army 2 fields its (bought) roster.
