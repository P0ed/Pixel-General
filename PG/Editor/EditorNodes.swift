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
		let layers = (0 ..< state.map.size * 2 - 1).map { _ in
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
			map.setTileGroup(.tileGroup(terrain: state.map[xy], fog: false), at: xy)
		}

		return map
	}

	func update(_ state: borrowing EditorState) {
		let cameraPosition = state.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
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
			map.setTileGroup(.tileGroup(terrain: terrain, fog: false), at: xy)
		case .redraw:
			state.map.indices.forEach { xy in
				map.setTileGroup(.tileGroup(terrain: state.map[xy], fog: false), at: xy)
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
			scene?.show(.none)
			return
		}

		scene.show(MenuState(
			items: Terrain.palette.map { terrain in
				.close(
					icon: terrain.image,
					status: .init(text: "Brush: \(terrain)"),
					action: .setBrush(terrain)
				)
			} + [
				.close(icon: .new, status: "Randomize", action: .randomize),
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
		case .water: .tile(.water)
		case .bridgeWE: .bridgeWE
		case .bridgeSN: .bridgeSN
		case .city: .city
		case .airfield: .airfield
		case .roadNW: .roadNW
		case .roadNE: .roadNE
		case .roadWE: .roadWE
		case .roadSN: .roadSN
		case .roadSW: .roadSW
		case .roadSE: .roadSE
		case .villageE: .villageE
		case .villageN: .villageN
		case .villageW: .villageW
		case .villageS: .villageS
		case .roadX: .roadX
		case .none: .clear
		}
	}
}
