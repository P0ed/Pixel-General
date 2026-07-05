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
		let nodes = MapNodes.make(
			root: root,
			size: state.sim.map.size,
			tiles: .colors
		)
		state.sim.map.indices.forEach { xy in
			nodes.setBase(.gray, at: xy)
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
