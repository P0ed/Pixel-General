import SpriteKit

struct TacticalNodes {
	var camera: SKCameraNode
	var map: MapNodes
	var flag: SKSpriteNode
	var sounds: SoundNodes
	var units: [UID: SKNode] = [:]
	@IO var fog: SetXY = .empty
}

struct SoundNodes {
	var boomS: SKAudioNode
	var boomM: SKAudioNode
	var boomL: SKAudioNode
	var mov: SKAudioNode
}

extension TacticalNodes {

	init(parent: SKNode, state: borrowing TacticalState) {
		self = TacticalNodes(
			camera: Self.addCamera(parent: parent),
			map: Self.addMap(parent: parent, state: state),
			flag: Self.addFlag(parent: parent),
			sounds: Self.addSounds(parent: parent)
		)
		units = Dictionary(uniqueKeysWithValues: state.units.map { i, u in
			let sprite = state.units[i].sprite
			let xy = state.units[i].position
			sprite.position = state.map.point(at: xy)
			sprite.zPosition = map.zPosition(at: xy)
			sprite.isHidden = !state.player.visible[xy]
			parent.addChild(sprite)
			return (i, sprite)
		})
	}

	func layout(size: CGSize) {
		flag.position = CGPoint(
			x: size.width / 2.0 - 18.0,
			y: 12.0 - size.height / 2.0
		)
	}

	private static func addSounds(parent: SKNode) -> SoundNodes {
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

		[boomS, boomM, boomL, mov].forEach(parent.addChild)

		return SoundNodes(boomS: boomS, boomM: boomM, boomL: boomL, mov: mov)
	}

	private static func addFlag(parent: SKNode) -> SKSpriteNode {
		let node = SKSpriteNode()
		node.zPosition = 66.0
		node.size = CGSize(width: 24.0, height: 12.0)
		(parent as? SKScene)?.camera?.addChild(node)
		return node
	}

	private static func addMap(parent: SKNode, state: borrowing TacticalState) -> MapNodes {
		let layers = (0 ..< state.map.size * 2 - 1).map { idx in
			SKTileMapNode(tiles: .terrain, size: state.map.size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			parent.addChild(layer)
		}

		let map = MapNodes(
			layers: layers,
			size: state.map.size,
			cursor: MapNodes.addCursor(parent: parent),
			selection: MapNodes.addCursor(parent: parent, z: -0.05, color: .selectedCursor)
		)

		state.map.indices.forEach { xy in
			map.setTileGroup(state.map[xy].tileGroup(fog: false), at: xy)
		}

		return map
	}

	private static func addCamera(parent: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		parent.addChild(camera)
		(parent as? SKScene)?.camera = camera
		return camera
	}

	func updateUnits(_ state: borrowing TacticalState) {
		state.units.forEach { i, u in
			units[i]?.update(hp: u.hp)
		}
	}

	func update(state: borrowing TacticalState) {
		let cameraPosition = state.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}
		map.update(
			map: state.map,
			cursor: state.cursor,
			selected: state.selectedUnit.map { i in state.units[i].position }
		)
		let cameraScale = CGFloat(state.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}

		updateFogIfNeeded(state: state)

		if let uid = state.selectedUnit {
			flag.texture = .init(image: state.units[uid].country.flag)
			flag.texture?.filteringMode = .nearest
			flag.isHidden = false
		} else {
			flag.isHidden = true
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
			units[i]?.isHidden = !visible[u.position]
		}
		self.fog = fog
	}

	func mouse(event: NSEvent) -> Input? {
		let location = event.location(in: map.layers[0])
		return .tile(
			XY(
				map.layers[0].tileColumnIndex(fromPosition: location),
				map.layers[0].tileRowIndex(fromPosition: location)
			)
		)
	}
}

extension TacticalScene {

	func addUnit(_ uid: UID, node: SKNode) {
		addChild(node)
		nodes?.units[uid] = node
	}

	func removeUnit(_ uid: UID) {
		nodes?.units[uid]?.removeFromParent()
		nodes?.units[uid] = .none
	}
}
