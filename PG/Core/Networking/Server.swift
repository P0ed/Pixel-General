import Network
import Foundation

final class Server {
	private var listener: NWListener?
	private var connections: [Connection] = []

	func start(port: UInt16) {
		listener = try? NWListener(using: .tcp, on: .init(integerLiteral: port))

		guard let listener else { return print("Unable to start server") }

		listener.newConnectionHandler = { [weak self] connection in
			self?.connections.append(Connection(
				connection: connection,
				message: { con, message in
					self?.handleMessage(from: con, message: message)
				},
				disconnect: { con in
					self?.connections.removeAll { $0 === con }
				}
			))
		}
		listener.start(queue: .main)
		print("Server started on port \(port)")
	}

	private func handleMessage(from sender: Connection, message: Message) {
		print("Server received message: \(message)")

		switch message {
		case .joinRequest: sender.send(.joinAccept(Data([0xFF])))
		case .endTurn: broadcast(.endTurn)
		default: break
		}
	}

	private func broadcast(_ message: Message) {
		for conn in connections {
			conn.send(message)
		}
	}
}
