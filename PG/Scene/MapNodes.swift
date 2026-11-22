import SpriteKit
import COR

@MainActor
struct MapNodes {
	var terrain: SKTileMapNode
	var decorations: SKTileMapNode
	var overlay: SKTileMapNode
	var fog: SKTileMapNode
	var grid: SKTileMapNode
	var size: Int
	var cursor: SKNode
	var selection: SKNode
}

/// Units are ordered by diagonal above the map layers.
private enum TileZ {
	static let decoration: CGFloat = 0.4
	static let overlay: CGFloat = 0.45
	static let fog: CGFloat = 0.5
	static let grid: CGFloat = 0.55
	static let unit: CGFloat = 0.6
}

extension MapNodes {

	func tile(at point: CGPoint) -> Input? {
		guard let scene = terrain.scene else { return .none }

		let location = terrain.convert(point, from: scene)
		let x = terrain.tileColumnIndex(fromPosition: location)
		let y = terrain.tileRowIndex(fromPosition: location)
		guard (0 ..< size).contains(x), (0 ..< size).contains(y) else { return nil }
		return .tile(XY(x, y))
	}

	func setTile(_ tile: Terrain, at xy: XY) {
		terrain.setTileGroup(.terrain(tile, at: xy), at: xy)
		if decorations.parent != nil {
			decorations.setTileGroup(.decoration(tile, at: xy), at: xy)
		}
	}

	func setFog(_ fogged: Bool, at xy: XY) {
		fog.setTileGroup(fogged ? .fog : nil, at: xy)
		grid.setTileGroup(fogged ? .foggedGrid : .grid, at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(xy.x + size - 1 - xy.y) + TileZ.unit
	}

	static func make(
		root: SKNode,
		size: Int,
		terrain: SKTileSet = .terrain,
		decorations: SKTileSet? = nil,
		overlay: SKTileSet? = nil,
		fog: SKTileSet? = nil
	) -> MapNodes {
		func addTiles(_ tiles: SKTileSet?, z: CGFloat) -> SKTileMapNode {
			guard let tiles else { return SKTileMapNode() }
			let map = SKTileMapNode(tiles: tiles, size: size)
			map.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			map.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			map.zPosition = z
			root.addChild(map)
			return map
		}
		let grid = addTiles(.grid, z: TileZ.grid)
		grid.fill(with: .grid)
		grid.isHidden = !settings.gridLines
		return MapNodes(
			terrain: addTiles(terrain, z: 0.0),
			decorations: addTiles(decorations, z: TileZ.decoration),
			overlay: addTiles(overlay, z: TileZ.overlay),
			fog: addTiles(fog, z: TileZ.fog),
			grid: grid,
			size: size,
			cursor: addCursor(root: root),
			selection: addCursor(root: root, z: 0.05, color: .selectedCursor)
		)
	}

	func update<let size: Int>(map: borrowing Map<size, Terrain>, cursor: XY, selected: XY?) {
		let cursorCG = map.point(at: cursor)
		if self.cursor.position != cursorCG {
			self.cursor.position = cursorCG
			self.cursor.zPosition = zPosition(at: cursor)
		}
		selection.isHidden = selected == .none
		let selected = selected ?? .zero
		let selectedCG = map.point(at: selected)
		if selection.position != selectedCG {
			selection.position = selectedCG
			selection.zPosition = zPosition(at: selected)
		}
	}

	static func addCursor(root: SKNode, z: CGFloat = 0.0, color: SKColor? = nil) -> SKNode {
		let node = SKNode()
		node.position = .init(x: -1.0, y: -1.0)

		let cursor = SKSpriteNode(texture: .cursor)
		if let color {
			cursor.color = color
			cursor.colorBlendFactor = 0.68
			cursor.blendMode = .alpha
		}
		cursor.zPosition = 0.1 + z

		node.addChild(cursor)
		root.addChild(node)

		return node
	}
}

extension Map where Element == Terrain {

	func point(at xy: XY) -> CGPoint {
		xy.point
	}
}
