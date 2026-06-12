import Network
import Foundation
import COR

@MainActor
final class Server<Message: MessageProtocol> {
	private var listener: NWListener?
	private(set) var connections: [Connection<Message>] = []
	private let handleMessage: (Connection<Message>, Message) -> Void
	var onDisconnect: (Connection<Message>) -> Void = ø

	init(handleMessage: @escaping (Connection<Message>, Message) -> Void) {
		self.handleMessage = handleMessage
	}

	func start(port: UInt16) {
		listener = try? NWListener(using: .tcp, on: .init(integerLiteral: port))

		guard let listener else { return print("Unable to start server") }

		listener.newConnectionHandler = { [weak self] connection in
			MainActor.assumeIsolated {
				self?.connections.append(Connection(
					connection: connection,
					message: { con, message in
						print("Server received message: \(message)")
						self?.handleMessage(con, message)
					},
					disconnect: { con in
						guard let self, self.connections.contains(where: { $0 === con })
						else { return }
						self.connections.removeAll { $0 === con }
						self.onDisconnect(con)
					}
				))
			}
		}
		listener.start(queue: .main)
		print("Server started on port \(port)")
	}

	func stop() {
		listener?.cancel()
		listener = nil
		connections = []
	}

	func drop(_ con: Connection<Message>) {
		connections.removeAll { $0 === con }
	}

	func broadcast(_ message: Message) {
		for conn in connections {
			conn.send(message)
		}
	}
}
