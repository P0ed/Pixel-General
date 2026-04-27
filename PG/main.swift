import SpriteKit

private let window = NSWindow(
	contentRect: NSRect(origin: .zero, size: .window),
	styleMask: [.titled, .fullSizeContentView, .closable, .resizable, .miniaturizable],
	backing: .buffered,
	defer: false
)

private let view = SKView(frame: window.contentLayoutRect)
view.autoresizingMask = [.width, .height]
view.ignoresSiblingOrder = true

window.contentView = view
window.titlebarAppearsTransparent = true
window.center()
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)

func present(_ scene: SKScene) {
	view.presentScene(scene, transition: .moveIn(with: .up, duration: 0.47))
}

let core = Core()
core.load()
core.new()
present(.make(core.state))

NSApplication.shared.run()
