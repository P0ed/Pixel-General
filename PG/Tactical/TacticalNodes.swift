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
	@IO var baseKey: BaseKey = .terrain

	/// Everything the map-mode base layer depends on, as one equatable
	/// repaint key: the layer repaints exactly when the key changes. A new
	/// mode adds a case here and a render case in `baseGroup` — the change
	/// detection itself never grows.
	enum BaseKey: Equatable {
		case terrain
		case team
		case country
		case supply(SupplySources, air: Bool)
		case defense(UnitType)
	}
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
		map.update(
			map: state.sim.map,
			cursor: state.ui.cursor,
			selected: state.ui.selectedUnit == .none ? nil : state.sim.position[state.ui.selectedUnit]
		)
	}

	private func updateFogIfNeeded(state: borrowing TacticalState) {
		let lit = state.ui.selectable ?? state.sim.visibleToHuman
		let key: BaseKey = switch state.ui.mapMode {
		case .terrain: .terrain
		case .team: .team
		case .country: .country
		case .supply: .supply(state.sim.humanSupply, air: Self.selectedType(state).isAir)
		case .defense: .defense(Self.selectedType(state))
		}

		let baseChanged = key != baseKey
		let litChanged = lit != self.lit
		guard baseChanged || litChanged else { return }
		defer { self.lit = lit; baseKey = key }

		if baseChanged {
			state.sim.map.indices.forEach { xy in
				map.setBase(baseGroup(for: state, at: xy, key: key), at: xy)
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

	/// The unit type the supply and defense map modes shade for: the human
	/// selection, falling back to infantry.
	private static func selectedType(_ state: borrowing TacticalState) -> UnitType {
		guard state.ui.selectedUnit != .none else { return .inf }
		let unit = state.sim.units[state.ui.selectedUnit]
		return unit.alive ? unit.type : .inf
	}

	private func baseGroup(
		for state: borrowing TacticalState,
		at xy: XY,
		key: BaseKey
	) -> SKTileGroup {
		switch key {
		case .terrain:
			return .base(terrain: state.sim.map[xy], at: xy)
		case .team:
			return .team(
				state.sim.control[xy].team,
				elevation: state.sim.map[xy].elevationLevel
			)
		case .supply(let supply, let air):
			// Air service is airfield-gated: `resupply` feeds an air unit only
			// inside the airfields mask, so unserviced tiles show the worst
			// grade rather than `airLevel`'s literal 0.
			let value: Int8 = air
				? (supply.airfields[xy] ? supply.airLevel(at: xy) : .min)
				: supply.level(at: xy, terrain: state.sim.map[xy])
			let level: UInt8 = switch value {
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
		case .defense(let defense):
			// def(type) + entrenchment floor: the defenderMod a just-arrived
			// unit has after one end of turn. −5 (heavy armor in a river) …
			// +6 (infantry in a city) onto the 8-step gradient; air ignores
			// terrain and never entrenches, so it shades uniformly.
			let terrain = state.sim.map[xy]
			let value = defense.isAir
				? 0 : Int(terrain.def(defense)) + Int(terrain.baseEntrenchment)
			return .base(
				surface: .supply(UInt8(clamping: (value + 5) * 7 / 11)),
				elevation: terrain.elevationLevel
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
