import SpriteKit

struct TacticalNodes {
	weak var scene: TacticalScene?
	var camera: SKCameraNode
	var map: MapNodes
	var sounds: SoundNodes
	@IO var units: [128 of SKNode?] = .init(repeating: nil)
	@IO var fog: SetXY = .empty
}

struct SoundNodes {
	var boomS: SKAudioNode
	var boomM: SKAudioNode
	var boomL: SKAudioNode
	var mov: SKAudioNode
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
			head: scene.state.units.map { i, u in
				let sprite = scene.state.units[i].sprite
				let xy = scene.state.position[i]
				sprite.position = scene.state.map.point(at: xy)
				sprite.zPosition = map.zPosition(at: xy)
				sprite.isHidden = !scene.state.player.visible[xy]
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

		[boomS, boomM, boomL, mov].forEach(root.addChild)

		return SoundNodes(boomS: boomS, boomM: boomM, boomL: boomL, mov: mov)
	}

	private static func addMap(root: SKNode, state: borrowing TacticalState) -> MapNodes {
		let layers = (0 ..< state.map.size * 2 - 1).map { idx in
			SKTileMapNode(tiles: .terrain, size: state.map.size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			root.addChild(layer)
		}

		let map = MapNodes(
			layers: layers,
			size: state.map.size,
			cursor: MapNodes.addCursor(root: root),
			selection: MapNodes.addCursor(root: root, z: 0.05, color: .selectedCursor)
		)

		state.map.indices.forEach { xy in
			map.setTileGroup(state.map[xy].tileGroup(fog: false), at: xy)
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
		state.units.forEach { i, u in
			units[i]?.update(hp: u.hp)
		}
	}

	func update(_ state: borrowing TacticalState) {
		let cameraPosition = state.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}
		map.update(
			map: state.map,
			cursor: state.cursor,
			selected: state.selectedUnit.map { i in state.position[i.index] }
		)
		let cameraScale = CGFloat(state.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}

		updateFogIfNeeded(state: state)

		if state.player.type == .ai {
			scene?.send(state.runAI())
		}
	}

	func updateFogIfNeeded(state: borrowing TacticalState) {
		let visible = state.player.visible
		let fog = state.selectable ?? visible

		guard self.fog != fog else { return }

		state.map.indices.forEach { xy in
			map.setTileGroup(state.map[xy].tileGroup(fog: fog[xy]), at: xy)
		}
		state.units.forEach { i, u in
			units[i]?.isHidden = !state.isVisible(i.uid)
		}
		self.fog = fog
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
}

extension TacticalNodes {

	func addUnit(_ uid: UID, node: SKNode) {
		scene?.addChild(node)
		units[uid.index] = node
	}

	func removeUnit(_ uid: UID) {
		units[uid.index]?.removeFromParent()
		units[uid.index] = .none
	}
}
