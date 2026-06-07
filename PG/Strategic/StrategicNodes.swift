import SpriteKit
import COR

@MainActor
struct StrategicNodes {
	weak var scene: StrategicScene?
	var camera: SKCameraNode
	var map: MapNodes
}

extension StrategicNodes {

	init(scene: StrategicScene) {
		self = StrategicNodes(
			scene: scene,
			camera: Self.addCamera(root: scene, at: scene.state.camera.point),
			map: Self.addMap(root: scene, state: scene.state)
		)
		map.selection.isHidden = true
		update(scene.state)
	}

	private static func addCamera(root: SKNode, at center: CGPoint) -> SKCameraNode {
		let camera = SKCameraNode()
		camera.position = center
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}

	private static func addMap(root: SKNode, state: borrowing StrategicState) -> MapNodes {
		let size = state.owner.size
		let layers = (0 ..< size * 2 - 1).map { _ in
			SKTileMapNode(tiles: .terrain, size: size)
		}
		layers.enumerated().forEach { idx, layer in
			layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
			layer.position = CGPoint(x: -CGSize.tile.width * 0.5, y: 0.0)
			layer.zPosition = CGFloat(idx)
			root.addChild(layer)
		}
		return MapNodes(
			layers: layers,
			size: size,
			cursor: MapNodes.addCursor(root: root),
			selection: MapNodes.addCursor(root: root, z: 0.05, color: .selectedCursor)
		)
	}
}

extension StrategicNodes {

	func update(_ state: borrowing StrategicState) {
		let cameraPosition = state.camera.point
		if camera.position != cameraPosition {
			camera.run(.move(to: cameraPosition, duration: 0.15))
		}

		map.cursor.position = state.cursor.point
		map.cursor.zPosition = map.zPosition(at: state.cursor)

		state.owner.indices.forEach { xy in
			map.setTileGroup(Self.political(state.owner[xy]), at: xy)
		}
	}

	/// Colour a province by its owner's team (axis/allies/soviet); sea is gray.
	private static func political(_ country: Country) -> SKTileGroup {
		let index: Int = switch country {
		case .sea: -1
		default: switch country.team {
			case .axis: 0
			case .allies: 1
			case .soviet: 2
			}
		}
		return .political(playerIndex: index, elevation: 0, fog: false)
	}
}
