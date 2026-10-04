import SpriteKit
import COR

@MainActor
struct MapNodes {
	var tiles: SKTileMapNode
	var decorationLayers: [SKTileMapNode]
	var size: Int
	var cursor: SKNode
	var selection: SKNode
}

/// Z offsets within one anti-diagonal above the flat terrain map:
/// decorations carry their own fogged variant, with units on top.
enum TileZ {
	static let decoration: CGFloat = 0.4
	static let unit: CGFloat = 0.6
}

extension MapNodes {

	func tile(at point: CGPoint) -> Input? {
		guard let scene = tiles.scene else { return .none }

		let location = tiles.convert(point, from: scene)
		return .tile(
			XY(
				tiles.tileColumnIndex(fromPosition: location),
				tiles.tileRowIndex(fromPosition: location)
			)
		)
	}

	func layer(at xy: XY) -> Int {
		xy.x + size - 1 - xy.y
	}

	func setBase(_ tileGroup: SKTileGroup?, at xy: XY) {
		tiles.setTileGroup(tileGroup, at: xy)
	}

	func setTile(_ terrain: Terrain, fog: Bool = false, at xy: XY) {
		setBase(.base(terrain: terrain, fog: fog), at: xy)
		setDecoration(terrain, fog: fog, at: xy)
	}

	func setDecoration(_ terrain: Terrain, fog: Bool, at xy: XY) {
		guard !decorationLayers.isEmpty else { return }
		decorationLayers[layer(at: xy)].setTileGroup(.decoration(terrain, fog: fog), at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(layer(at: xy)) + TileZ.unit
	}

	static func make(
		root: SKNode,
		size: Int,
		tiles: SKTileSet,
		decorations: Bool = false
	) -> MapNodes {
		func addTiles(_ tiles: SKTileSet, z: CGFloat) -> SKTileMapNode {
			let map = SKTileMapNode(tiles: tiles, size: size)
			map.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			map.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			map.zPosition = z
			root.addChild(map)
			return map
		}
		return MapNodes(
			tiles: addTiles(tiles, z: 0.0),
			decorationLayers: decorations ? (0 ..< size * 2 - 1).map {
				addTiles(.decorations, z: CGFloat($0) + TileZ.decoration)
			} : [],
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
