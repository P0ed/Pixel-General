import SpriteKit
import COR

@MainActor
struct StrategicNodes {
	weak var scene: StrategicScene?
	var camera: SKCameraNode
	var map: MapNodes
}

extension StrategicNodes {

	init(scene: StrategicScene) {
		self = StrategicNodes(
			scene: scene,
			camera: Self.addCamera(root: scene, at: scene.state.ui.camera.point),
			map: Self.addMap(root: scene, state: scene.state)
		)
		map.selection.isHidden = true
		update(scene.state)
	}

	private static func addCamera(root: SKNode, at center: CGPoint) -> SKCameraNode {
		let camera = SKCameraNode()
		camera.position = center
		camera.setScale(2)
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}

	private static func addMap(root: SKNode, state: borrowing StrategicState) -> MapNodes {
		MapNodes.make(
			root: root,
			size: state.sim.owner.size,
			tiles: .terrain
		)
	}
}

extension StrategicNodes {

	func update(_ state: borrowing StrategicState) {
		let cameraPosition = state.ui.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}

		map.cursor.position = state.ui.cursor.point
		map.cursor.zPosition = map.zPosition(at: state.ui.cursor)

		state.sim.owner.indices.forEach { xy in
			map.setBase(Self.political(state.sim.owner[xy]), at: xy)
		}
	}

	/// Colour a province by its owner's team (axis/allies/soviet); .none is gray.
	private static func political(_ country: Country) -> SKTileGroup {
		let index: Int = switch country.team {
		case .axis: 0
		case .allies: 1
		case .soviet: 2
		case .none: -1
		}
		return .political(playerIndex: index, elevation: 0)
	}
}
