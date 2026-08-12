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
		[
			CatalogEntry(name: "Tank", model: Units.tank, renderer: .unit),
			CatalogEntry(name: "Truck", model: Units.truck, renderer: .unit),
			CatalogEntry(name: "Carrier", model: Units.carrier, renderer: .unit),
			CatalogEntry(name: "Artillery", model: Units.artillery, renderer: .unit),
			CatalogEntry(name: "Launcher", model: Units.launcher, renderer: .unit),
		]
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
		]
		+ Direction.allCases.map {
			CatalogEntry(name: "Village-\($0)", model: Settlements.village(facing: $0), renderer: .building)
		}
	}

	public static var all: [CatalogEntry] {
		tiles + settlements + units
	}
}
