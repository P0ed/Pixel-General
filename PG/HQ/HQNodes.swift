import SpriteKit
import COR

@MainActor
struct HQNodes {
	weak var scene: HQScene?
	var camera: SKCameraNode
	var map: MapNodes
	@IO var units: [16 of SKNode?]
}

extension HQNodes {

	init(scene: HQScene) {
		self = HQNodes(
			scene: scene,
			camera: Self.addCamera(
				root: scene,
				at: XY(scene.state.sim.map.size - 1, scene.state.sim.map.size - 1).point * 0.5
			),
			map: Self.addMap(root: scene, state: scene.state),
			units: .init(repeating: nil)
		)
		units = .init { i in
			let u = scene.state.sim.units[i]
			let node = unitSprite(uid: i.uid, unit: u)
			node.isHidden = !u.alive
			scene.addChild(node)
			return node
		}
	}

	private static func addMap(root: SKNode, state: borrowing HQState) -> MapNodes {

		let layers = (0 ..< state.sim.map.size * 2 - 1).map { idx in
			SKTileMapNode(tiles: .colors, size: state.sim.map.size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			root.addChild(layer)
		}

		let nodes = MapNodes(
			layers: layers,
			size: state.sim.map.size,
			cursor: MapNodes.addCursor(root: root),
			selection: MapNodes.addCursor(root: root, z: 0.05, color: .selectedCursor)
		)

		state.sim.map.indices.forEach { xy in
			nodes.setTileGroup(.gray, at: xy)
		}

		return nodes
	}

	private static func addCamera(root: SKNode, at center: CGPoint) -> SKCameraNode {
		let camera = SKCameraNode()
		camera.position = center
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
			map: state.sim.map,
			cursor: state.ui.cursor,
			selected: state.ui.selected != .none
				? XY(state.ui.selected.index % 4, state.ui.selected.index / 4)
				: nil
		)
	}

	func unitSprite(uid: UID, unit: Unit) -> SKNode {
		let sprite = unit.hqSprite
		let xy = XY(uid.index % 4, uid.index / 4)
		sprite.position = xy.point
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
