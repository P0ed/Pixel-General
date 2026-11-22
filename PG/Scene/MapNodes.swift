import SpriteKit
import COR

@MainActor
struct MapNodes {
	var terrain: SKTileMapNode
	var grid: SKTileMapNode
	var decorations: SKTileMapNode
	var overlay: SKTileMapNode
	var fog: SKTileMapNode
	var size: Int
	var cursor: SKSpriteNode
	var selection: SKSpriteNode
}

/// Units are ordered by diagonal above the map layers.
private enum TileZ {
	static let decoration: CGFloat = 0.2
	static let grid: CGFloat = 0.3
	static let overlay: CGFloat = 0.4
	static let fog: CGFloat = 0.5
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
		let last = size - 1
		for i in 0 ..< last {
			grid.setTileGroup(.gridTopLeft, at: XY(0, i))
			grid.setTileGroup(.gridTopRight, at: XY(i + 1, last))
		}
		grid.setTileGroup(.gridTopCorner, at: XY(0, last))
		grid.isHidden = !settings.gridLines
		return MapNodes(
			terrain: addTiles(terrain, z: 0.0),
			grid: grid,
			decorations: addTiles(decorations, z: TileZ.decoration),
			overlay: addTiles(overlay, z: TileZ.overlay),
			fog: addTiles(fog, z: TileZ.fog),
			size: size,
			cursor: addCursor(root: root),
			selection: addCursor(root: root)
		)
	}

	func update(cursor: XY, selected: XY?) {
		update(self.cursor, at: cursor, selected: false)
		selection.isHidden = selected == nil
		if let selected { update(selection, at: selected, selected: true) }
	}

	private func update(_ sprite: SKSpriteNode, at xy: XY, selected: Bool) {
		let position = xy.point
		guard sprite.texture == nil || sprite.position != position else { return }
		let texture = SKTexture.gridHighlight(topLeft: xy.x == 0, topRight: xy.y == size - 1, selected: selected)
		sprite.texture = texture
		sprite.size = texture.size()
		sprite.position = position
		sprite.zPosition = zPosition(at: xy) + (selected ? 0.15 : 0.1)
	}

	private static func addCursor(root: SKNode) -> SKSpriteNode {
		let sprite = SKSpriteNode()
		sprite.anchorPoint.y = CGSize.tile.height / (2 * CGSize.tile3D.height)
		root.addChild(sprite)
		return sprite
	}
}

extension Map where Element == Terrain {

	func point(at xy: XY) -> CGPoint {
		xy.point
	}
}
