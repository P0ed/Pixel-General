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
		let cameraScale = CGFloat(state.ui.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}

		map.cursor.position = state.sim.terrain.point(at: state.ui.cursor)
		map.cursor.zPosition = map.zPosition(at: state.ui.cursor)

		state.sim.owner.indices.forEach { xy in
			map.setBase(Self.baseGroup(for: state, at: xy), at: xy)
		}
	}

	private static func baseGroup(for state: borrowing StrategicState, at xy: XY) -> SKTileGroup {
		let elevation = state.sim.terrain[xy].elevationLevel
		switch state.ui.mapMode {
		case .team:
			return .team(state.sim.owner[xy].team, elevation: elevation)
		case .country:
			return .base(surface: .country(state.sim.owner[xy]), elevation: elevation)
		}
	}
}
