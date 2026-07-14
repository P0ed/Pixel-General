import SpriteKit
import COR

@MainActor
struct StrategicNodes {
	weak var scene: StrategicScene?
	var camera: SKCameraNode
	var map: MapNodes
	var armies: [SKSpriteNode?]
	@IO var lit: SetXY = .empty
}

extension StrategicNodes {

	init(scene: StrategicScene) {
		self = StrategicNodes(
			scene: scene,
			camera: Self.addCamera(root: scene, at: scene.state.ui.camera.point),
			map: Self.addMap(root: scene, state: scene.state),
			armies: Self.addArmies(root: scene)
		)
		map.selection.isHidden = true
		update(scene.state)
	}

	private static func addArmies(root: SKNode) -> [SKSpriteNode?] {
		var nodes = [SKSpriteNode?](repeating: nil, count: 64 * 4)
		for country in Country.playable {
			for slot in 0 ..< 4 {
				let image = country.flag
				let flag = SKSpriteNode(texture: .init(image: image))
				flag.texture?.filteringMode = .nearest
				flag.size = image.size
				flag.isHidden = true
				root.addChild(flag)
				nodes[armyNodeIndex(country: country, slot: slot)] = flag
			}
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

	private static func addMap(root: SKNode, state: borrowing StrategicState) -> MapNodes {
		MapNodes.make(
			root: root,
			size: state.sim.owner.size,
			tiles: .terrain,
			fog: true
		)
	}

	private static func armyNodeIndex(country: Country, slot: Int) -> Int {
		Int(country.rawValue) * 4 + slot
	}
}

extension StrategicNodes {

	func update(_ state: borrowing StrategicState) {
		let cameraPosition = state.ui.camera.point
		if scene?.cameraTracking != true, camera.position != cameraPosition {
			camera.run(
				.move(to: cameraPosition, duration: 0.15),
				withKey: SKAction.cameraPositionKey
			)
		}
		let cameraScale = CGFloat(state.ui.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}

		map.cursor.position = state.sim.terrain.point(at: state.ui.cursor)
		map.cursor.zPosition = map.zPosition(at: state.ui.cursor)

		for country in Country.playable {
			for slot in 0 ..< 4 {
				let army = state.sim.army(ArmyID(country: country, slot: slot))
				let node = armies[Self.armyNodeIndex(country: country, slot: slot)]
				node?.isHidden = !army.active
				guard army.active else { continue }
				node?.position = state.sim.terrain.point(at: army.position)
				node?.zPosition = map.zPosition(at: army.position) + TileZ.unit
			}
		}

		let selected = state.ui.selected.map { state.sim.army($0).position }
		map.selection.isHidden = selected == nil
		if let selected {
			map.selection.position = state.sim.terrain.point(at: selected)
			map.selection.zPosition = map.zPosition(at: selected)
		}

		state.sim.owner.indices.forEach { xy in
			map.setBase(Self.baseGroup(for: state, at: xy), at: xy)
		}
		updateFog(state)
	}

	private func updateFog(_ state: borrowing StrategicState) {
		var next = SetXY.empty
		if let selectable = state.ui.selectable {
			next = selectable
		} else {
			state.sim.owner.indices.forEach { next[$0] = true }
		}
		guard next != lit else { return }
		defer { lit = next }
		state.sim.owner.indices.forEach { xy in
			map.setFog(!next[xy], terrain: state.sim.terrain[xy], at: xy)
		}
	}

	private static func baseGroup(for state: borrowing StrategicState, at xy: XY) -> SKTileGroup {
		let terrain = state.sim.terrain[xy]
		// Sea remains sea in political, industry, and fortification modes too;
		// older saves may still identify it only through `.none` ownership.
		if terrain.isSea || state.sim.owner[xy] == .none {
			return .base(terrain: .sea, at: xy)
		}
		let elevation = terrain.elevationLevel
		switch state.ui.mapMode {
		case .terrain:
			return .base(terrain: terrain, at: xy)
		case .team:
			return .team(state.sim.owner[xy].team, elevation: elevation)
		case .country:
			return .base(surface: .country(state.sim.owner[xy]), elevation: elevation)
		case .industry:
			let level = UInt8(min(7, state.sim.provinces[xy].industry))
			return .base(surface: .supply(level), elevation: elevation)
		case .forts:
			let level = state.sim.provinces[xy][.fort] * 7 / 3
			return .base(surface: .supply(level), elevation: elevation)
		}
	}
}
