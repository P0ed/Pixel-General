import SpriteKit
import COR

@MainActor
struct StrategicNodes {
	weak var scene: StrategicScene?
	var camera: SKCameraNode
	var map: MapNodes
	var armies: [SKSpriteNode]
}

extension StrategicNodes {

	init(scene: StrategicScene) {
		self = StrategicNodes(
			scene: scene,
			camera: Self.addCamera(root: scene, at: scene.state.ui.camera.point),
			map: Self.addMap(root: scene, state: scene.state),
			armies: Self.addArmies(root: scene, country: scene.state.sim.player.country)
		)
		map.selection.isHidden = true
		update(scene.state)
	}

	private static func addArmies(root: SKNode, country: Country) -> [SKSpriteNode] {
		(0 ..< 4).map { _ in
			let image = country.flag
			let flag = SKSpriteNode(texture: .init(image: image))
			flag.texture?.filteringMode = .nearest
			flag.size = image.size
			flag.isHidden = true
			root.addChild(flag)
			return flag
		}
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

		for slot in 0 ..< 4 {
			let army = state.sim.armies[slot]
			armies[slot].isHidden = !army.active
			guard army.active else { continue }
			armies[slot].position = state.sim.terrain.point(at: army.position)
			armies[slot].zPosition = map.zPosition(at: army.position) + TileZ.unit
		}

		let selected = state.ui.selected.map { slot in state.sim.armies[slot].position }
		map.selection.isHidden = selected == nil
		if let selected {
			map.selection.position = state.sim.terrain.point(at: selected)
			map.selection.zPosition = map.zPosition(at: selected)
		}

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
