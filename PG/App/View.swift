import SpriteKit

@MainActor
func View() -> SKView {
	let view = SKView()
	view.ignoresSiblingOrder = true
	return view
}

@MainActor
extension SKView {

	func present(_ scene: SKScene) {
		presentScene(scene, transition: .moveIn(with: .up, duration: 0.47))
	}
}
