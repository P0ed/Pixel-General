import SpriteKit

let window = NSWindow(
	contentRect: NSRect(origin: .zero, size: .window),
	styleMask: [.titled, .fullSizeContentView, .closable, .resizable, .miniaturizable],
	backing: .buffered,
	defer: false
)

let view = SKView(frame: window.contentLayoutRect)
view.autoresizingMask = [.width, .height]
view.ignoresSiblingOrder = true

window.contentView = view
window.titlebarAppearsTransparent = true
window.center()
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)

let core = Core()
present(.editor)

NSApplication.shared.run()
