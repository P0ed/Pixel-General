import SpriteKit
import COR

@MainActor
final class TacticalNodes {
	weak var scene: TACScene?
	var camera: SKCameraNode
	var map: MapNodes
	var units: [192 of SKNode?]
	var lit: SetXY
	var overlayKey: OverlayKey

	enum OverlayKey: Equatable {
		case terrain
		case team(UInt32)
		case country(UInt32)
		case supply(SupplySources, MoveType)
		case defense(UnitType)
	}

	init(scene: TACScene) {
		let lit = scene.state.litTiles
		let map = Self.addMap(root: scene, state: scene.state, lit: lit)
		self.scene = scene
		self.camera = Self.addCamera(root: scene)
		self.map = map
		self.lit = lit
		self.overlayKey = .terrain
		self.units = .init(
			head: scene.state.tac.units.map { i, u in
				guard u.alive else { return nil }
				let sprite = u.sprite
				let xy = scene.state.tac.position[i]
				sprite.position = scene.state.tac.map.point(at: xy)
				sprite.zPosition = map.zPosition(at: xy)
				sprite.isHidden = !scene.state.showsUnit(i.uid)
				scene.addChild(sprite)
				return sprite
			},
			tail: nil
		)
	}

	private static func addMap(root: SKNode, state: borrowing TACSceneState, lit: SetXY) -> MapNodes {
		let map = MapNodes.make(
			root: root,
			size: state.tac.map.size,
			decorations: .decorations,
			overlay: .overlay,
			fog: .fog
		)
		state.tac.map.indices.forEach { xy in
			map.setTile(from: state.tac.map, at: xy)
			if !lit[xy] { map.setShading(nil, fogged: true, at: xy) }
		}
		return map
	}

	private static func addCamera(root: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}

	func updateUnits(_ state: borrowing TACSceneState) {
		state.tac.units.forEachAlive { i, u in
			units[i]?.update(hp: u.hp)
		}
	}

	func update(_ state: borrowing TACSceneState) {
		updateView(state)
		updateShadingIfNeeded(state: state)
	}

	private func updateView(_ state: borrowing TACSceneState) {
		let cameraPosition = state.ui.camera.point
		if scene?.cameraTracking != true, camera.position != cameraPosition {
			camera.run(
				.move(to: cameraPosition, duration: 0.15),
				withKey: SKAction.cameraPositionKey
			)
		}
		let cameraScale = CGFloat(1 << state.ui.scale) / 2.0
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}
		map.update(
			cursor: state.ui.cursor,
			selected: state.ui.selectedUnit == .none ? nil : state.tac.position[state.ui.selectedUnit]
		)
	}

	private func updateShadingIfNeeded(state: borrowing TACSceneState) {
		let type = Self.selectedType(state)
		let key: OverlayKey = switch state.ui.mapMode {
		case .terrain: .terrain
		case .team: .team(state.tac.turn)
		case .country: .country(state.tac.turn)
		case .supply:
			.supply(
				type.isNaval && state.tac.player.type == .human
					? state.tac.supplySources(for: state.tac.country) : state.tac.humanSupply,
				type.isNaval ? .naval : type.isAir ? .air : .leg
			)
		case .defense: .defense(type)
		}

		let lit = state.litTiles
		let previousLit = self.lit
		let overlayChanged = key != overlayKey
		let fogChanged = lit != previousLit
		guard overlayChanged || fogChanged else { return }
		self.lit = lit
		overlayKey = key

		for xy in state.tac.map.indices where overlayChanged || lit[xy] != previousLit[xy] {
			map.setShading(overlay(for: state, at: xy, key: key), fogged: !lit[xy], at: xy)
		}
		if fogChanged {
			state.tac.units.forEachAlive { i, u in
				units[i]?.isHidden = !state.showsUnit(i.uid)
			}
		}
	}

	private static func selectedType(_ state: borrowing TACSceneState) -> UnitType {
		guard state.ui.selectedUnit != .none else { return .inf }
		let unit = state.tac.units[state.ui.selectedUnit]
		return unit.alive ? unit.type : .inf
	}

	private func overlay(
		for state: borrowing TACSceneState,
		at xy: XY,
		key: OverlayKey
	) -> TileOverlay? {
		switch key {
		case .terrain:
			return nil
		case .team:
			return .team(state.tac.control[xy].team)
		case .country:
			return .country(state.tac.control[xy])
		case .supply(let supply, let moveType):
			let value: Int8 = switch moveType {
			case .air: supply.airfields[xy] ? supply.airLevel(at: xy) : .min
			case .naval: supply.ports[xy] ? supply.navalLevel(at: xy) : .min
			default: supply.level(at: xy, terrain: state.tac.map[xy])
			}
			let level = UInt8(min(7, max(0, value + 3)))
			return .level(level)
		case .defense(let defense):
			let terrain = state.tac.map[xy]
			let value = defense.isAir
				? 0 : Int(terrain.def(defense)) + Int(terrain.baseEntrenchment)
			return .level(UInt8(clamping: (value + 5) * 7 / 11))
		}
	}

	func addUnit(_ uid: UID, node: SKNode) {
		scene?.addChild(node)
		units[uid] = node
	}

	func removeUnit(_ uid: UID) {
		units[uid]?.removeFromParent()
		units[uid] = .none
	}
}

extension TACSceneState {

	var auto: Bool {
		!tac.isFinished && (tac.player.type == .ai || ui.autoBattle)
	}

	var litTiles: SetXY {
		tac.isFinished ? .full : ui.selectable ?? tac.visibleToHuman
	}

	func showsUnit(_ uid: UID) -> Bool {
		tac.isFinished ? !tac.offMap(unit: uid) : tac.isVisibleToHuman(uid)
	}
}
