import SpriteKit

@MainActor
struct MapNodes {
	var layers: [SKTileMapNode]
	var size: Int
	var cursor: SKNode
	var selection: SKNode
}

extension MapNodes {

	func tile(at event: NSEvent) -> Input? {
		guard !layers.isEmpty else { return .none }

		let map = layers[0]
		let location = event.location(in: map)
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

	func setTileGroup(_ tileGroup: SKTileGroup?, at xy: XY) {
		layers[layer(at: xy)].setTileGroup(tileGroup, at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(layer(at: xy))
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

	var elevationLevel: Int {
		switch self {
		case .hill, .forestHill: 1
		case .mountain: 2
		default: 0
		}
	}

	var elevation: CGFloat {
		CGFloat(elevationLevel * 4)
	}
}
