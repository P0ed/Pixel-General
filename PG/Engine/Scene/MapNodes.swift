import SpriteKit

@MainActor
struct MapNodes {
	var layers: [SKTileMapNode]
	var size: Int
	var cursor: SKNode
	var selection: SKNode
}

extension MapNodes {

	func layer(at xy: XY) -> Int {
		xy.x + size - 1 - xy.y
	}

	func setTileGroup(_ tileGroup: SKTileGroup?, at xy: XY) {
		layers[layer(at: xy)].setTileGroup(tileGroup, at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(layer(at: xy))
	}

	func update(map: borrowing Map<Terrain>, cursor: XY, selected: XY?) {
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
		cursor.color = color ?? .white
		cursor.colorBlendFactor = color == nil ? 0.0 : 0.68
		cursor.blendMode = .alpha
		cursor.zPosition = 0.1 + z

		node.addChild(cursor)
		root.addChild(node)

		return node
	}
}

extension Map<Terrain> {

	func point(at xy: XY) -> CGPoint {
		xy.point + CGPoint(x: 0, y: self[xy].elevation)
	}
}

extension Terrain {

	var elevation: CGFloat {
		switch self {
		case .hill, .forestHill: 4.0
		case .mountain: 8.0
		default: 0.0
		}
	}
}
