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

	/// Total factory levels excluding `fort` — the province's productive
	/// capacity, as shaded by the strategic industry map mode.
	public var industry: Int {
		BuildingType.allCases.reduce(0) { $0 + ($1 == .fort ? 0 : Int(self[$1])) }
	}
}

public extension StrategicSim {

	func buildingsTotal(_ t: BuildingType, of c: Country) -> Int {
		var total = 0
		for xy in owner.indices where owner[xy] == c {
			total += Int(provinces[xy][t])
		}
		return total
	}

	/// Shop-gating bitmask for `c`: bit `BuildingType.rawValue` is set when the
	/// country fields at least one building level of that type.
	func buildingsMask(of c: Country) -> UInt8 {
		var mask: UInt8 = 0
		for t in BuildingType.allCases where buildingsTotal(t, of: c) >= 1 {
			mask |= 1 << t.rawValue
		}
		return mask
	}

	func canBuild(_ building: BuildingType, at xy: XY) -> Bool {
		owner.contains(xy)
			&& owner[xy] == player.country
			&& provinces[xy][building] < 3
			&& battle == nil
	}

	func buildingCost(_ building: BuildingType, above level: UInt8, at xy: XY) -> UInt16 {
		(UInt16(level) + 1) * {
			switch terrain[xy] {
			case .mountain: 300
			case .hill: 240
			default: 200
			}
		}()
	}
}

extension StrategicSim {

	/// Starting factories for a fresh campaign: per country a civil budget of
	/// `tiles/8` levels and a military budget of `tiles/6` levels cycled
	/// through army/armor/air/aa/army/armor/uav, spread over distinct
	/// provinces nearest the country's centroid. Deterministic — fixed-seed
	/// `D20`, countries in rawValue order, tiles in index order — so
	/// `europe()` produces identical output every call.
	mutating func placeStartingFactories() {
		var d20 = D20(seed: 7)
		for country in Country.playable {
			var tiles: [XY] = []
			for xy in owner.indices where owner[xy] == country {
				tiles.append(xy)
			}
			guard !tiles.isEmpty else { continue }

			let center = centroid(for: country)
			let ordered = tiles
				.map { xy in (xy, xy.stepDistance(to: center) * 4 + d20() % 4) }
				.sorted { a, b in a.1 < b.1 }
				.map { $0.0 }

			place(max(1, tiles.count / 8), cycling: [.civil], over: ordered)
			place(
				max(1, tiles.count / 6),
				cycling: [.army, .armor, .air, .aa, .army, .armor, .uav],
				over: ordered
			)
		}
	}

	private mutating func place(_ levels: Int, cycling types: [BuildingType], over tiles: [XY]) {
		for i in 0 ..< levels {
			let xy = tiles[i % tiles.count]
			let t = types[i % types.count]
			if provinces[xy][t] < 3 {
				provinces[xy][t] += 1
			}
		}
	}
}
