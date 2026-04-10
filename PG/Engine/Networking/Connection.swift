import Network
import Foundation

protocol MessageProtocol {
	associatedtype MessageType: RawRepresentable<UInt8>

	var type: MessageType { get }
	var payload: Data { get }

	init?(type: MessageType, payload: Data)
}

final class Connection<Message: MessageProtocol> {
	private let connection: NWConnection
	private let queue = DispatchQueue(label: "game.connection")
	private let onMessage: (Connection, Message) -> Void
	private let onDisconnect: (Connection) -> Void
	private var buffer = Data()

	init(
		connection: NWConnection,
		message: @escaping (Connection, Message) -> Void,
		disconnect: @escaping (Connection) -> Void
	) {
		self.connection = connection
		self.onMessage = message
		self.onDisconnect = disconnect
		connection.stateUpdateHandler = { [weak self] state in
			guard let self else { return }
			switch state {
			case .ready: receiveLoop()
			case .failed, .cancelled: onDisconnect(self)
			default: break
			}
		}
		connection.start(queue: queue)
	}

	deinit {
		connection.cancel()
	}

	func send(_ message: Message) {
		var data = Data()

		let type = message.type
		let payload = message.payload

		var length = UInt32(1 + payload.count).bigEndian
		data.append(Data(bytes: &length, count: 4))

		data.append(type.rawValue)
		data.append(payload)

		connection.send(content: data, completion: .contentProcessed { _ in })
	}

	private func receiveLoop() {
		connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) {
			[weak self] data, _, isComplete, error in

			guard let self else { return }

			if let data {
				self.buffer.append(data)
				self.processBuffer()
			}

			if isComplete || error != nil {
				onDisconnect(self)
				return
			}

			self.receiveLoop()
		}
	}

	private func processBuffer() {
		while true {
			guard buffer.count >= 4 else { return }

			let length = buffer.prefix(4).withUnsafeBytes {
				$0.load(as: UInt32.self).bigEndian
			}

			guard buffer.count >= 4 + Int(length) else { return }

			let messageData = buffer.subdata(in: 4 ..< 4 + Int(length))
			buffer.removeSubrange(0 ..< 4 + Int(length))

			guard let type = Message.MessageType(rawValue: messageData.first!) else {
				continue
			}

			if let message = Message(type: type, payload: messageData.dropFirst()) {
				onMessage(self, message)
			} else {
				print("Can't form message \(type)")
			}
		}
	}
}
