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
			CatalogEntry(name: "\($0)".capitalized, model: $0.model, renderer: .unit)
		}
	}

	public static var tiles: [CatalogEntry] {
		(0 ... 2).map {
			CatalogEntry(name: "Base\($0)", model: Tiles.base(elevation: $0), renderer: .tile)
		}
		+ [CatalogEntry(name: "Slope", model: Tiles.slope(elevation: 0, rising: .xPlus), renderer: .tile)]
	}

	public static var settlements: [CatalogEntry] {
		[
			CatalogEntry(name: "City", model: Settlements.city, renderer: .building),
			CatalogEntry(name: "Fort", model: Settlements.fort, renderer: .building),
			CatalogEntry(name: "Airfield", model: Settlements.airfield, renderer: .building),
		]
		+ Direction.allCases.map {
			CatalogEntry(name: "Village-\($0)", model: Settlements.village(facing: $0), renderer: .building)
		}
	}

	public static var roads: [CatalogEntry] {
		[
			CatalogEntry(name: "Road-WE", model: Roads.road([.xMinus, .xPlus]), renderer: .decal),
			CatalogEntry(name: "Road-NE", model: Roads.road([.yMinus, .xPlus]), renderer: .decal),
			CatalogEntry(name: "Road-X", model: Roads.road(Direction.allCases), renderer: .decal),
			CatalogEntry(name: "Bridge-WE", model: Roads.bridge(along: .x), renderer: .building),
			CatalogEntry(name: "Bridge-SN", model: Roads.bridge(along: .y), renderer: .building),
		]
	}

	public static var all: [CatalogEntry] {
		tiles + settlements + roads + units
	}
}
