import SpriteKit
import COR

defer { NSApplication.shared.run() }

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
window.minSize = .scene
window.titlebarAppearsTransparent = true
window.center()
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)

var core: Core = .load(auto: true)
present(.auto)
