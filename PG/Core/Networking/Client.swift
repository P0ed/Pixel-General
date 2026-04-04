import Network
import Foundation

final class Client {
	private var connection: Connection?

	func connect(host: String, port: UInt16) {
		guard connection == nil else { return print("Already connected") }

		let con = Connection(
			connection: NWConnection(
				host: .init(host),
				port: .init(integerLiteral: port),
				using: .tcp
			),
			message: { [weak self] c, m in self?.handle(m) },
			disconnect: { c in }
		)
		connection = con

		con.send(.joinRequest)
	}

	func disconnect() {
		connection = nil
	}

	func send(_ message: Message) {
		connection?.send(message)
	}

	private func handle(_ message: Message) {
		print("Client received message: \(message)")

		switch message {
		case .joinAccept: break
		case .endTurn: break
		default: break
		}
	}
}
