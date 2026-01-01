import SpriteKit

struct TacticalNodes {
	var cursor: SKNode
	var camera: SKCameraNode
	var map: MapNodes
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

struct MapNodes {
	var layers: [SKTileMapNode]
	var size: Int
}

extension TacticalNodes {

	init(parent: SKNode, state: borrowing TacticalState) {
		self = TacticalNodes(
			cursor: Self.addCursor(parent: parent),
			camera: Self.addCamera(parent: parent),
			map: Self.addMap(parent: parent, state: state),
			sounds: Self.addSounds(parent: parent)
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
			size: state.map.size
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

	private static func addCursor(parent: SKNode) -> SKNode {
		let node = SKNode()
		node.position = .init(x: -1.0, y: -1.0)

		let cursor = SKSpriteNode(texture: .init(image: .cursor))
		cursor.texture?.filteringMode = .nearest
		cursor.zPosition = 0.1

		node.addChild(cursor)
		parent.addChild(node)

		return node
	}

	func updateUnits(_ state: borrowing TacticalState) {
		state.units.forEach { i, u in
			units[i]?.update(hp: u.stats.hp)
		}
	}

	func update(state: borrowing TacticalState) {
		let cursorPosition = state.map.point(at: state.cursor)
		if cursor.position != cursorPosition {
			cursor.position = cursorPosition
			cursor.zPosition = map.zPosition(at: state.cursor)
		}
		let cameraPosition = state.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}
		let cameraScale = CGFloat(state.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}

		updateFogIfNeeded(state: state)
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

extension MapNodes {

	func layer(at xy: XY) -> Int {
		xy.x + size - 1 - xy.y
	}

	func setTileGroup(_ tileGroup: SKTileGroup?, at xy: XY) {
		layers[layer(at: xy)].setTileGroup(tileGroup, at: xy)
	}

	func zPosition(at xy: XY) -> CGFloat {
		CGFloat(layer(at: xy))
	}
}
