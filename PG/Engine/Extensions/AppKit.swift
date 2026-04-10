import AppKit

let app = NSApplication.shared

extension NSWindow {

	static func make(_ content: (NSWindow) -> NSView) -> NSWindow {
		let window = NSWindow(
			contentRect: NSRect(origin: .zero, size: .window),
			styleMask: [.titled, .fullSizeContentView, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: false
		)
		window.contentView = content(window)
		window.titlebarAppearsTransparent = true
		window.center()
		window.makeKeyAndOrderFront(nil)
		window.makeFirstResponder(window.contentView)

		return window
	}
}

extension NotificationCenter {

	func willCloseWindow(_ body: @escaping (NSWindow) -> Void) -> any NSObjectProtocol {
		addObserver(
			forName: NSWindow.willCloseNotification,
			object: nil,
			queue: .main,
			using: { n in
				if let w = n.object as? NSWindow { body(w) }
			}
		)
	}
}
