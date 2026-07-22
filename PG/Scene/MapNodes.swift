import SpriteKit
import COR

@MainActor
struct MapNodes {
	var layers: [SKTileMapNode]
	var fogLayers: [SKTileMapNode]
	var decorationLayers: [SKTileMapNode]
	var size: Int
	var cursor: SKNode
	var selection: SKNode
}

/// Z offsets within one anti-diagonal: base tile at the diagonal index,
/// fog overlay above it (darkens the base only), decorations above the fog
/// (they carry their own fogged variant), units on top.
enum TileZ {
	static let fog: CGFloat = 0.2
	static let decoration: CGFloat = 0.4
	static let unit: CGFloat = 0.6
}

extension MapNodes {

	/// `point` is in scene coordinates.
	func tile(at point: CGPoint) -> Input? {
		guard let map = layers.first, let scene = map.scene else { return .none }

		let location = map.convert(point, from: scene)
		return .tile(
			XY(
				map.tileColumnIndex(fromPosition: location),
				map.tileRowIndex(fromPosition: location)
			)
		)
	}

	func layer(at xy: XY) -> Int {
		xy.x + size - 1 - xy.y
	}

	func setBase(_ tileGroup: SKTileGroup?, at xy: XY) {
		layers[layer(at: xy)].setTileGroup(tileGroup, at: xy)
	}

	func setTile(_ terrain: Terrain, at xy: XY) {
		setBase(.base(terrain: terrain), at: xy)
		guard !decorationLayers.isEmpty else { return }
		decorationLayers[layer(at: xy)].setTileGroup(.decoration(terrain, fog: false), at: xy)
	}

	func setFog(_ fog: Bool, terrain: Terrain, at xy: XY) {
		guard !fogLayers.isEmpty else { return }
		fogLayers[layer(at: xy)].setTileGroup(
			fog ? .fog(elevation: terrain.elevationLevel) : nil,
			at: xy
		)
		if !decorationLayers.isEmpty, terrain.decoration != nil {
			decorationLayers[layer(at: xy)].setTileGroup(.decoration(terrain, fog: fog), at: xy)
		}
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(layer(at: xy)) + TileZ.unit
	}

	static func make(
		root: SKNode,
		size: Int,
		tiles: SKTileSet,
		decorations: Bool = false,
		fog: Bool = false
	) -> MapNodes {
		func addLayers(_ tiles: SKTileSet, z: CGFloat) -> [SKTileMapNode] {
			(0 ..< size * 2 - 1).map { idx in
				let layer = SKTileMapNode(tiles: tiles, size: size)
				layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
				layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
				layer.zPosition = CGFloat(idx) + z
				root.addChild(layer)
				return layer
			}
		}
		return MapNodes(
			layers: addLayers(tiles, z: 0.0),
			fogLayers: fog ? addLayers(.fog, z: TileZ.fog) : [],
			decorationLayers: decorations ? addLayers(.decorations, z: TileZ.decoration) : [],
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

		let cursor = SKSpriteNode(texture: .init(image: .cursor))
		cursor.texture?.filteringMode = .nearest
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
		xy.point + CGPoint(x: 0, y: self[xy].elevation)
	}
}

extension Terrain {

	var elevation: CGFloat {
		CGFloat(elevationLevel * 4)
	}
}
