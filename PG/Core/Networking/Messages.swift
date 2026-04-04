import Foundation

enum MessageType: UInt8 {
	case joinRequest
	case joinAccept
	case endTurn
}

enum Message {
	case joinRequest
	case joinAccept(Data)
	case endTurn
}

extension Message {

	var type: MessageType {
		switch self {
		case .joinRequest: .joinRequest
		case .joinAccept: .joinAccept
		case .endTurn: .endTurn
		}
	}

	var payload: Data {
		switch self {
		case .joinRequest: Data()
		case .joinAccept(let d): d
		case .endTurn: Data()
		}
	}

	var payloadSize: Int {
		switch self {
		case .joinRequest: 0
		case .joinAccept(let d): d.count
		case .endTurn: 0
		}
	}

	init?(type: MessageType, payload: Data.SubSequence) {
		switch type {
		case .joinRequest where payload.isEmpty: self = .joinRequest
		case .joinAccept where payload.count == 1: self = .joinAccept(payload)
		case .endTurn where payload.isEmpty: self = .endTurn
		default: return nil
		}
	}
}
