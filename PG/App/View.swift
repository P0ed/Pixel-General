import SpriteKit

@MainActor
func View() -> SKView {
	let view = PixelView()
	view.ignoresSiblingOrder = true
	return view
}

/// Keeps the presented scene at a fixed 2× zoom: the scene is resized to
/// half the view's point size, so one scene unit maps to exactly two points
/// and pixel art stays sharp at any window size.
final class PixelView: SKView {

	override func layoutSubviews() {
		super.layoutSubviews()
		scene.map(fit)
	}

	override func presentScene(_ scene: SKScene, transition: SKTransition) {
		fit(scene)
		super.presentScene(scene, transition: transition)
	}

	private func fit(_ scene: SKScene) {
		guard !bounds.isEmpty else { return }
		scene.size = CGSize(width: bounds.width / 2.0, height: bounds.height / 2.0)
	}
}

@MainActor
extension SKView {

	func present(_ scene: SKScene) {
		presentScene(scene, transition: .moveIn(with: .up, duration: 0.47))
	}
}
