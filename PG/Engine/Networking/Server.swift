import Network
import Foundation

final class Server<Message: MessageProtocol> {
	private var listener: NWListener?
	private var connections: [Connection<Message>] = []
	private let handleMessage: (Connection<Message>, Message) -> Void

	init(handleMessage: @escaping (Connection<Message>, Message) -> Void) {
		self.handleMessage = handleMessage
	}

	func start(port: UInt16) {
		listener = try? NWListener(using: .tcp, on: .init(integerLiteral: port))

		guard let listener else { return print("Unable to start server") }

		listener.newConnectionHandler = { [weak self] connection in
			self?.connections.append(Connection(
				connection: connection,
				message: { con, message in
					print("Server received message: \(message)")
					self?.handleMessage(con, message)
				},
				disconnect: { con in
					self?.connections.removeAll { $0 === con }
				}
			))
		}
		listener.start(queue: .main)
		print("Server started on port \(port)")
	}

	private func broadcast(_ message: Message) {
		for conn in connections {
			conn.send(message)
		}
	}
}
