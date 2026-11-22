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
	static let top: CGFloat = 0.6
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

	func setShading(_ tint: TileOverlay?, fogged: Bool, at xy: XY) {
		overlay.setTileGroup(tint.map { .overlay($0) }, at: xy)
		fog.setTileGroup(fogged ? .fog : nil, at: xy)
//		grid.setTileGroup(.grid(overlay: tint, fogged: fogged), at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(xy.x + size - 1 - xy.y) + TileZ.top
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
		let selection = addCursor(.selection, to: root)
		selection.isHidden = true

		return MapNodes(
			terrain: addTiles(terrain, z: 0.0),
			grid: grid,
			decorations: addTiles(decorations, z: TileZ.decoration),
			overlay: addTiles(overlay, z: TileZ.overlay),
			fog: addTiles(fog, z: TileZ.fog),
			size: size,
			cursor: addCursor(.cursor, to: root),
			selection: selection
		)
	}

	func update(cursor: XY, selected: XY?) {
		update(self.cursor, at: cursor, zOffset: 0.1)
		selection.isHidden = selected == nil
		if let selected { update(selection, at: selected, zOffset: 0.15) }
	}

	private func update(_ sprite: SKSpriteNode, at xy: XY, zOffset: CGFloat) {
		sprite.position = xy.point
		sprite.zPosition = zPosition(at: xy) + zOffset
	}

	private static func addCursor(_ texture: SKTexture, to root: SKNode) -> SKSpriteNode {
		let sprite = SKSpriteNode(texture: texture)
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
