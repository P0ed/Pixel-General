import Foundation

extension NotificationCenter {

	func addMainActorObserver(
		forName name: NSNotification.Name,
		object: Any? = nil,
		using body: @MainActor @escaping (Notification) -> Void
	) -> any NSObjectProtocol {
		addObserver(
			forName: name,
			object: object,
			queue: .main,
			using: { n in
				nonisolated(unsafe) let n = n
				MainActor.assumeIsolated {
					unsafe body(n)
				}
			}
		)
	}
}
