import Network
import Foundation

final class Client<Message: MessageProtocol> {
	private var connection: Connection<Message>?
	private let handleMessage: (Message) -> Void

	init(handleMessage: @escaping (Message) -> Void) {
		self.handleMessage = handleMessage
	}

	func connect(host: String, port: UInt16) {
		guard connection == nil else { return print("Already connected") }

		let con = Connection<Message>(
			connection: NWConnection(
				host: .init(host),
				port: .init(integerLiteral: port),
				using: .tcp
			),
			message: { [weak self] c, m in
				print("Client received message: \(m)")
				self?.handleMessage(m)
			},
			disconnect: { c in }
		)
		connection = con
	}

	func disconnect() {
		connection = nil
	}

	func send(_ message: Message) {
		connection?.send(message)
	}
}
