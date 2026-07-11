import Foundation
import COR

/// Protocol version for the `hello` handshake. Bump whenever the message set
/// or the wire layout of `TacticalSim`/`TacticalAction` changes — payloads
/// are raw native bytes (see `Connection.swift`).
let netVersion: UInt16 = 2

enum Message {
	case hello(UInt16)
	case joinRequest
	case joinAccept(UInt8)
	case lobby(Data)
	case start(Data)
	case action(Data)
	case resync(Data)
	case leave
}

extension Message: MessageProtocol {

	enum MessageType: UInt8 {
		case hello, joinRequest, joinAccept, lobby, start, action, resync, leave
	}

	var type: MessageType {
		switch self {
		case .hello: .hello
		case .joinRequest: .joinRequest
		case .joinAccept: .joinAccept
		case .lobby: .lobby
		case .start: .start
		case .action: .action
		case .resync: .resync
		case .leave: .leave
		}
	}

	var payload: Data {
		switch self {
		case .hello(let version): encode(version)
		case .joinRequest, .leave: Data()
		case .joinAccept(let seat): Data([seat])
		case .lobby(let d), .start(let d), .action(let d), .resync(let d): d
		}
	}

	init?(type: MessageType, payload: Data.SubSequence) {
		switch type {
		case .hello:
			guard let version: UInt16 = decode(Data(payload)) else { return nil }
			self = .hello(version)
		case .joinRequest where payload.isEmpty: self = .joinRequest
		case .joinAccept where payload.count == 1: self = .joinAccept(payload.first!)
		case .lobby: self = .lobby(Data(payload))
		case .start: self = .start(Data(payload))
		case .action: self = .action(Data(payload))
		case .resync: self = .resync(Data(payload))
		case .leave where payload.isEmpty: self = .leave
		default: return nil
		}
	}
}
