import SpriteKit

struct HQNodes {
	var camera: SKCameraNode
	var map: MapNodes
	var units: [UID: SKNode] = [:]
}

extension HQNodes {

	static let map = Map<Terrain>(size: 4, zero: .field)

	init(parent: SKNode, state: borrowing HQState) {
		self = HQNodes(
			camera: Self.addCamera(parent: parent),
			map: Self.addMap(parent: parent, state: state)
		)
		units = Dictionary(uniqueKeysWithValues: state.units.map { i, u in
			let node = unitSprite(uid: i, unit: u)
			parent.addChild(node)
			return (i, node)
		})
	}

	private static func addMap(parent: SKNode, state: borrowing HQState) -> MapNodes {

		let layers = (0 ..< map.size * 2 - 1).map { idx in
			SKTileMapNode(tiles: .terrain, size: map.size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			parent.addChild(layer)
		}

		let nodes = MapNodes(
			layers: layers,
			size: map.size,
			cursor: MapNodes.addCursor(parent: parent),
			selection: MapNodes.addCursor(parent: parent, z: -0.05, color: .selectedCursor)
		)

		map.indices.forEach { xy in
			nodes.setTileGroup(map[xy].tileGroup(fog: false), at: xy)
		}

		return nodes
	}

	private static func addCamera(parent: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		camera.position = XY(map.size - 1, map.size - 1).point * 0.5
		parent.addChild(camera)
		(parent as? SKScene)?.camera = camera
		return camera
	}

	private static func addCursor(parent: SKNode, xz: CGFloat = 0.0, color: SKColor? = nil) -> SKNode {
		let node = SKNode()
		node.position = .init(x: -1.0, y: -1.0)

		let cursor = SKSpriteNode(texture: .init(image: .cursor))
		cursor.texture?.filteringMode = .nearest
		cursor.color = color ?? .white
		cursor.colorBlendFactor = color == nil ? 0.0 : 0.68
		cursor.blendMode = .alpha
		cursor.zPosition = 0.1 + xz

		node.addChild(cursor)
		parent.addChild(node)

		return node
	}

	func update(state: borrowing HQState) {
		map.update(
			map: Self.map,
			cursor: state.cursor,
			selected: state.selected.map { i in state.units[i].position }
		)
	}

	func mouse(event: NSEvent) -> Input? {
		let location = event.location(in: map.layers[0])
		return .tile(
			XY(
				map.layers[0].tileColumnIndex(fromPosition: location),
				map.layers[0].tileRowIndex(fromPosition: location)
			)
		)
	}

	func unitSprite(uid: UID, unit: Unit) -> SKNode {
		let sprite = unit.hqSprite
		let xy = unit.position
		sprite.position = HQNodes.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		return sprite
	}
}
