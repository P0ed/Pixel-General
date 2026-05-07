import SpriteKit

@MainActor
struct EditorNodes {
	weak var scene: EditorScene?

	init(scene: EditorScene) {
		self.scene = scene
	}
}

extension EditorNodes {

	func update(_ state: borrowing EditorState) {
		// TODO: Implement
	}

	func process(_ event: EditorEvent, _ state: borrowing EditorState) async {
		// TODO: Implement
	}
}
