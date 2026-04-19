import AppKit

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
