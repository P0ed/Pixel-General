import SpriteKit
import COR

@MainActor
struct EditorNodes {
	weak var scene: EditorScene?
	var camera: SKCameraNode
	var map: MapNodes
}

extension EditorNodes {

	init(scene: EditorScene) {
		self = EditorNodes(
			scene: scene,
			camera: Self.addCamera(root: scene),
			map: Self.addMap(root: scene, state: scene.state)
		)
	}

	private static func addCamera(root: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}

	private static func addMap(root: SKNode, state: borrowing EditorState) -> MapNodes {
		let map = MapNodes.make(
			root: root,
			size: state.map.size,
			tiles: .terrain,
			decorations: true
		)
		state.map.indices.forEach { xy in
			map.setTile(state.map[xy], at: xy)
		}
		return map
	}

	func update(_ state: borrowing EditorState) {
		let cameraPosition = state.camera.point
		if scene?.cameraTracking != true, camera.position != cameraPosition {
			camera.run(
				.move(to: cameraPosition, duration: 0.15),
				withKey: SKAction.cameraPositionKey
			)
		}
		map.update(map: state.map, cursor: state.cursor, selected: nil)

		let cameraScale = CGFloat(state.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}
	}

	func process(_ event: EditorEvent, _ state: borrowing EditorState) async {
		switch event {
		case let .set(xy, terrain):
			map.setTile(terrain, at: xy)
		case .redraw:
			state.map.indices.forEach { xy in
				map.setTile(state.map[xy], at: xy)
			}
		case .menu:
			processMenu(state)
		case .hq:
			view.present(.auto)
		}
	}
}

private extension EditorNodes {

	func processMenu(_ state: borrowing EditorState) {
		guard let scene, case .none = scene.menuState else {
			scene?.showMenu(.none)
			return
		}

		scene.showMenu(MenuState(
			items: Terrain.palette.map { terrain in
				.close(
					icon: terrain.image,
					status: .init(text: "Brush: \(terrain)"),
					action: .setBrush(terrain)
				)
			} + [
				.space,
				.close(icon: .rnd, status: "Randomize", action: .randomize),

				.close(icon: .empty, status: "Clear map", action: .clear),
				.close(icon: .save, status: "Save map", action: .save),
				.close(icon: .load, status: "Load map", action: .load),
				.close(icon: .HQ, status: "HQ", action: .hq),
			]
		))
	}
}

extension Terrain {

	@MainActor
	var image: UIImage {
		switch self {
		case .field: .tile(.field)
		case .forest: .tile(.forest)
		case .hill: .tile(.hill)
		case .forestHill: .tile(.forestHill)
		case .mountain: .tile(.mountain)
		case .river: .tile(.river)
		case .sea: .tile(.sea)
		case .bridgeWE: .tile(.bridgeWE)
		case .bridgeSN: .tile(.bridgeSN)
		case .city: .tile(.city)
		case .airfield: .tile(.airfield)
		case .roadNW: .tile(.roadNW)
		case .roadNE: .tile(.roadNE)
		case .roadWE: .tile(.roadWE)
		case .roadSN: .tile(.roadSN)
		case .roadSW: .tile(.roadSW)
		case .roadSE: .tile(.roadSE)
		case .villageE: .tile(.villageE)
		case .villageN: .tile(.villageN)
		case .villageW: .tile(.villageW)
		case .villageS: .tile(.villageS)
		case .roadX: .tile(.roadX)
		case .fort: .tile(.fort)
		case .none: .clear
		}
	}
}
