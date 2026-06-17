import Network
import Foundation
import COR

@MainActor
final class Client<Message: MessageProtocol> {
	private var connection: Connection<Message>?
	private let handleMessage: (Message) -> Void
	var onReady: () -> Void = ø
	var onDisconnect: () -> Void = ø

	init(handleMessage: @escaping (Message) -> Void) {
		self.handleMessage = handleMessage
	}

	func connect(_ address: Address) {
		guard connection == nil else { return print("Already connected") }

		connection = Connection<Message>(
			connection: NWConnection(
				host: .init(address.host),
				port: .init(integerLiteral: address.port),
				using: .tcp
			),
			ready: { [weak self] _ in
				self?.onReady()
			},
			message: { [weak self] _, m in
				print("Client received message: \(m)")
				self?.handleMessage(m)
			},
			disconnect: { [weak self] _ in
				guard let self, self.connection != nil else { return }
				self.connection = nil
				self.onDisconnect()
			}
		)
	}

	func disconnect() {
		connection = nil
	}

	func send(_ message: Message) {
		connection?.send(message)
	}
}
