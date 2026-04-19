import SpriteKit

struct HQNodes {
	weak var scene: HQScene?
	var camera: SKCameraNode
	var map: MapNodes
	@IO var units: [16 of SKNode?]
}

extension HQNodes {

	static let map = Map<Terrain>(size: 4, zero: .field)

	init(scene: HQScene) {
		self = HQNodes(
			scene: scene,
			camera: Self.addCamera(root: scene),
			map: Self.addMap(root: scene, state: scene.state),
			units: .init(repeating: nil)
		)
		units = .init { i in
			let u = scene.state.units[i]
			let node = unitSprite(uid: i.uid, unit: u)
			node.isHidden = !u.alive
			scene.addChild(node)
			return node
		}
	}

	private static func addMap(root: SKNode, state: borrowing HQState) -> MapNodes {

		let layers = (0 ..< map.size * 2 - 1).map { idx in
			SKTileMapNode(tiles: .terrain, size: map.size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			root.addChild(layer)
		}

		let nodes = MapNodes(
			layers: layers,
			size: map.size,
			cursor: MapNodes.addCursor(root: root),
			selection: MapNodes.addCursor(root: root, z: -0.05, color: .selectedCursor)
		)

		map.indices.forEach { xy in
			nodes.setTileGroup(map[xy].tileGroup(fog: false), at: xy)
		}

		return nodes
	}

	private static func addCamera(root: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		camera.position = XY(map.size - 1, map.size - 1).point * 0.5
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
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

	func update(_ state: borrowing HQState) {
		map.update(
			map: Self.map,
			cursor: state.cursor,
			selected: state.selected.map { i in XY(i.index % 4, i.index / 4) }
		)
	}

	func mouse(_ event: NSEvent) -> Input? {
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
		let xy = XY(uid.index % 4, uid.index / 4)
		sprite.position = HQNodes.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		return sprite
	}

	func addUnit(_ uid: UID, node: SKNode) {
		scene?.addChild(node)
		units[uid.index]?.removeFromParent()
		units[uid.index] = node
	}

	func removeUnit(_ uid: UID) {
		units[uid.index]?.removeFromParent()
		units[uid.index] = nil
	}
}
