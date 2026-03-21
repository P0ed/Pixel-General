import SpriteKit

typealias MedievalMode = SceneMode<MedievalState, MedievalEvent, MedievalNodes>
typealias MedievalScene = Scene<MedievalState, MedievalEvent, MedievalNodes>

extension MedievalMode {

	static var medieval: Self {
		.init(
			make: MedievalNodes.init,
			inputable: { state in state.inputable },
			input: { state, input in state.apply(input) },
			update: { state, nodes in nodes.update(state: state) },
			reducible: { state in state.reducible },
			reduce: { state in state.reduce() },
			process: { scene, events in await scene.process(events: events) },
			status: { state in ("", "") },
			save: { state in }
		)
	}
}

struct MedievalState: ~Copyable {
	var map: Map<Terrain>
	var units: Speicher<128, MedievalUnit>
	var selected: UID?
	var events: Speicher<4, MedievalEvent>
	var combos: Combos = .empty
}

struct Combos {
	var rawValue: UInt64

	static var empty: Combos { .init(rawValue: 0) }

	enum Move: UInt8 {
		case none, rt, up, lt, dw, a, b, c, d
	}

	var moves: [Move] {
		.make { cs in
			for i in 0..<8 {
				let c = self[i]
				if c == .none { return }
				cs.append(c)
			}
		}
	}

	subscript(_ i: Int) -> Move {
		Move(rawValue: UInt8(rawValue >> (8 * i) & 0xFF)) ?? .none
	}

	mutating func add(_ c: Move) {
		rawValue = rawValue << 8 | UInt64(c.rawValue)
	}
}

extension MedievalState {

	static var initial: MedievalState {
		.init(
			map: .init(size: 16, seed: .random(in: 0...31)),
			units: .init(
				head: [
					.init(pos: XY(1, 1), hp: 20, team: false),
					.init(pos: XY(1, 0), hp: 20),
					.init(pos: XY(0, 1), hp: 20)
				],
				tail: .init()
			),
			selected: 0,
			events: .init(head: [], tail: .none)
		)
	}

	var inputable: Bool { true }
	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let d?):
			if let selected {
				units[selected].pos = units[selected].pos.neighbor(d)
				events.add(.move(selected, units[selected].pos))
			}
		default: break
		}
	}
	var reducible: Bool { !events.isEmpty }
	mutating func reduce() -> [MedievalEvent] {
		defer { events.erase() }
		return events.map { $1 }
	}
}

enum MedievalEvent: DeadOrAlive {
	case none, move(UID, XY)

	var alive: Bool { if case .none = self { false } else { true } }
}

struct MedievalUnit: Hashable {
	var pos: XY = .zero
	var hp: UInt8 = 0
	var team: Bool = true
}

extension MedievalUnit: DeadOrAlive {
	var alive: Bool { hp != 0 }

	var sprite: SKNode {
		let sprite = SKSpriteNode(texture: .init(image: .pike))
		sprite.texture?.filteringMode = .nearest
		sprite.blendMode = .alpha
		sprite.colorBlendFactor = 0.3
		sprite.color = team ? .red : .yellow
		return sprite
	}
}

struct MedievalNodes {
	var camera: SKCameraNode
	var map: MapNodes
	var units: [UID: SKNode] = [:]
}

extension MedievalNodes {

	init(parent: SKNode, state: borrowing MedievalState) {
		self = .init(
			camera: Self.addCamera(parent: parent),
			map: Self.addMap(parent: parent, state: state)
		)
		units = Dictionary(uniqueKeysWithValues: state.units.map { i, u in
			let sprite = state.units[i].sprite
			let xy = state.units[i].pos
			sprite.position = state.map.point(at: xy)
			sprite.zPosition = map.zPosition(at: xy)
//			sprite.isHidden = !state.player.visible[xy]
			parent.addChild(sprite)
			return (i, sprite)
		})
	}

	func update(state: borrowing MedievalState) {
		let pt = state.map.point(at: state.units[0].pos)
		if camera.position != pt {
			camera.run(.move(to: pt, duration: 0.47))
		}
	}

	private static func addMap(parent: SKNode, state: borrowing MedievalState) -> MapNodes {
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
		map.cursor.isHidden = true
		map.selection.isHidden = true

		state.map.indices.forEach { xy in
			map.setTileGroup(state.map[xy].tileGroup(fog: true), at: xy)
		}

		return map
	}

	private static func addCamera(parent: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		parent.addChild(camera)
		(parent as? SKScene)?.camera = camera
		return camera
	}
}

extension MedievalScene {

	func process(events: [MedievalEvent]) async {
		for event in events {
			switch event {
			case .move(let uid, let xy):
				if let nodes, let u = nodes.units[uid] {
					let dst = state.map.point(at: xy)
					let src = u.position
					u.zPosition = max(u.zPosition, nodes.map.zPosition(at: xy))

					let t = 0.47 as CGFloat
					await u.run(.customAction(withDuration: t) { n, p in
						let pos: CGPoint = dst * (p / t) + src * (1.0 - p / t)
						n.position = CGPoint(x: round(pos.x / 2.0) * 2.0, y: round(pos.y / 2.0) * 2.0)
					})
					u.position = dst
					u.zPosition = nodes.map.zPosition(at: xy)
				}
			case .none: break
			}
		}
	}

	func addUnit(_ uid: UID, node: SKNode) {
		addChild(node)
		nodes?.units[uid] = node
	}

	func removeUnit(_ uid: UID) {
		nodes?.units[uid]?.removeFromParent()
		nodes?.units[uid] = .none
	}
}
