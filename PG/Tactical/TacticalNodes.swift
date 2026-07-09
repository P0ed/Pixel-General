import SpriteKit
import COR

@MainActor
struct TacticalNodes {
	weak var scene: TacticalScene?
	var camera: SKCameraNode
	var map: MapNodes
	var sounds: SoundNodes
	@IO var units: [128 of SKNode?] = .init(repeating: nil)
	@IO var lit: SetXY = .empty
	@IO var mapMode: MapMode = .terrain
	@IO var supply: SupplySources = .empty
}

@MainActor
struct SoundNodes {
	var boomS: SKAudioNode
	var boomM: SKAudioNode
	var boomL: SKAudioNode
	var mov: SKAudioNode
	var ruggedDefence: SKAudioNode
}

extension TacticalNodes {

	init(scene: TacticalScene) {
		self = TacticalNodes(
			scene: scene,
			camera: Self.addCamera(root: scene),
			map: Self.addMap(root: scene, state: scene.state),
			sounds: Self.addSounds(root: scene)
		)
		units = .init(
			head: scene.state.sim.units.map { i, u in
				guard u.alive else { return nil }
				let sprite = u.sprite
				let xy = scene.state.sim.position[i]
				sprite.position = scene.state.sim.map.point(at: xy)
				sprite.zPosition = map.zPosition(at: xy)
				sprite.isHidden = !scene.state.sim.isVisibleToHuman(i.uid)
					|| scene.state.sim.unitsMap[xy] != i.uid
				scene.addChild(sprite)
				return sprite
			},
			tail: nil
		)
	}

	private static func addSounds(root: SKNode) -> SoundNodes {
		let mk = { name in
			let node = SKAudioNode(fileNamed: name)
			node.autoplayLooped = false
			node.isPositional = false
			return node
		}
		let boomS = mk("boom-s")
		let boomM = mk("boom-m")
		let boomL = mk("boom-l")
		let mov = mk("mov")
		let rd = mk("getcrew")

		[boomS, boomM, boomL, mov, rd].forEach(root.addChild)

		return SoundNodes(
			boomS: boomS,
			boomM: boomM,
			boomL: boomL,
			mov: mov,
			ruggedDefence: rd
		)
	}

	private static func addMap(root: SKNode, state: borrowing TacticalState) -> MapNodes {
		let map = MapNodes.make(
			root: root,
			size: state.sim.map.size,
			tiles: .terrain,
			decorations: true,
			fog: true
		)
		state.sim.map.indices.forEach { xy in
			map.setTile(state.sim.map[xy], at: xy)
		}
		return map
	}

	private static func addCamera(root: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}

	func updateUnits(_ state: borrowing TacticalState) {
		state.sim.units.forEachAlive { i, u in
			units[i]?.update(hp: u.hp)
		}
	}

	func update(_ state: borrowing TacticalState) {
		updateView(state)
		updateFogIfNeeded(state: state)
	}

	private func updateView(_ state: borrowing TacticalState) {
		let cameraPosition = state.ui.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}
		let cameraScale = CGFloat(state.ui.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}
		map.update(
			map: state.sim.map,
			cursor: state.ui.cursor,
			selected: state.ui.selectedUnit == .none ? nil : state.sim.position[state.ui.selectedUnit]
		)
	}

	private func updateFogIfNeeded(state: borrowing TacticalState) {
		let lit = state.ui.selectable ?? state.sim.visibleToHuman
		let mode = state.ui.mapMode
		let supply = mode == .supply ? state.sim.humanSupply : self.supply

		let baseChanged = mode != mapMode || supply != self.supply
		let litChanged = lit != self.lit
		guard baseChanged || litChanged else { return }
		defer { self.lit = lit; self.mapMode = mode; self.supply = supply }

		if baseChanged {
			state.sim.map.indices.forEach { xy in
				map.setBase(baseGroup(for: state, at: xy, supply: supply), at: xy)
			}
		}
		if litChanged {
			state.sim.map.indices.forEach { xy in
				map.setFog(!lit[xy], terrain: state.sim.map[xy], at: xy)
			}
			state.sim.units.forEachAlive { i, u in
				units[i]?.isHidden = !state.sim.isVisibleToHuman(i.uid)
			}
		}
	}

	private func baseGroup(
		for state: borrowing TacticalState,
		at xy: XY,
		supply: SupplySources
	) -> SKTileGroup {
		switch state.ui.mapMode {
		case .terrain:
			return .base(terrain: state.sim.map[xy])
		case .political:
			let country = state.sim.control[xy]
			let idx = state.sim.players.firstMap { i, p in p.country == country ? i : nil } ?? -1
			return .political(
				playerIndex: idx,
				elevation: state.sim.map[xy].elevationLevel
			)
		case .supply:
			let level: UInt8 = switch supply.level(at: xy, terrain: state.sim.map[xy]) {
			case ..<(-2): 0
			case -2: 1
			case -1: 2
			case 0: 3
			case 1: 4
			case 2: 5
			case 3: 6
			default: 7
			}
			return .base(
				surface: .supply(level),
				elevation: state.sim.map[xy].elevationLevel
			)
		case .country:
			return .base(
				surface: .country(state.sim.control[xy]),
				elevation: state.sim.map[xy].elevationLevel
			)
		}
	}
}

extension TacticalNodes {

	func addUnit(_ uid: UID, node: SKNode) {
		scene?.addChild(node)
		units[uid] = node
	}

	func removeUnit(_ uid: UID) {
		units[uid]?.removeFromParent()
		units[uid] = .none
	}
}
