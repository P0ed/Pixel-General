public struct CatalogEntry: Sendable {
	public let name: String
	public let model: Model
	public let renderer: Renderer

	public init(name: String, model: Model, renderer: Renderer) {
		self.name = name
		self.model = model
		self.renderer = renderer
	}
}

/// Everything the library can draw today, for previewing and regression tests.
public enum Catalog {

	public static var units: [CatalogEntry] {
		Units.Shape.allCases.map {
			CatalogEntry(name: $0.name, model: $0.model, renderer: .unit)
		}
	}

	public static var tiles: [CatalogEntry] {
		(0 ... 2).map {
			CatalogEntry(name: "Base\($0)", model: Tiles.base(elevation: $0), renderer: .tile)
		}
		+ [
			CatalogEntry(name: "Slope", model: Tiles.slope(elevation: 0, rising: .xPlus), renderer: .tile),
		]
	}

	public static var settlements: [CatalogEntry] {
		Tiles.Variant.allCases.map { variant in
			let name = variant == .first ? "City" : "City \(variant.rawValue + 1)"
			return CatalogEntry(name: name, model: Settlements.city(variant: variant), renderer: .building)
		}
		+ Tiles.Variant.allCases.map { variant in
			let name = variant == .first ? "Fort" : "Fort \(variant.rawValue + 1)"
			return CatalogEntry(name: name, model: Settlements.fort(variant: variant), renderer: .decal)
		}
		+ [
			CatalogEntry(name: "Airfield", model: Settlements.airfield, renderer: .building),
		]
	}

	public static var roads: [CatalogEntry] {
		[
			CatalogEntry(name: "Road-WE", model: Roads.road([.xMinus, .xPlus]), renderer: .decal),
			CatalogEntry(name: "Road-NE", model: Roads.road([.yMinus, .xPlus]), renderer: .decal),
			CatalogEntry(name: "Road-X", model: Roads.road(Direction.allCases), renderer: .decal),
			CatalogEntry(name: "Bridge-WE", model: Roads.bridge(along: .x), renderer: .decal),
			CatalogEntry(name: "Bridge-SN", model: Roads.bridge(along: .y), renderer: .decal),
		]
		+ Direction.allCases.map { missingArm in
			let directions = Direction.allCases.filter { $0 != missingArm }
			return CatalogEntry(name: "Road-T-\(missingArm)", model: Roads.road(directions), renderer: .decal)
		}
	}

	public static var all: [CatalogEntry] {
		tiles + settlements + roads + units
	}
}
