import SpriteKit

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
			map.setTileGroup(state.map[xy].tileGroup(lit: true), at: xy)
		}

		return map
	}

	func update(_ state: borrowing EditorState, _ ui: borrowing EditorUI) {
		let cameraPosition = ui.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}
		map.update(map: state.map, cursor: ui.cursor, selected: nil)

		let cameraScale = CGFloat(ui.scale)
		if camera.xScale != cameraScale {
			camera.run(.scale(to: cameraScale, duration: 0.15))
		}
	}

	func process(_ event: EditorEvent, _ state: borrowing EditorState) async {
		switch event {
		case let .set(xy, terrain):
			map.setTileGroup(terrain.tileGroup(lit: true), at: xy)
		case .redraw:
			state.map.indices.forEach { xy in
				map.setTileGroup(state.map[xy].tileGroup(lit: true), at: xy)
			}
		case .menu:
			processMenu(state)
		case .hq:
			present(.make(core.state))
		}
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

private extension EditorNodes {

	func processMenu(_ state: borrowing EditorState) {
		guard let scene, case .none = scene.menuState else {
			scene?.show(.none)
			return
		}

		scene.show(MenuState(
			items: Terrain.palette.map { terrain in
				.close(
					icon: terrain.imageName,
					status: .init(text: "Brush: \(terrain)"),
					action: .setBrush(terrain)
				)
			} + [
				.close(icon: "New", status: "Randomize", action: .randomize),
				.close(icon: "Empty", status: "Clear map", action: .clear),
				.close(icon: "Save", status: "Save map", action: .save),
				.close(icon: "Load", status: "Load map", action: .load),
				.close(icon: "HQ", status: "HQ", action: .hq),
			]
		))
	}
}
