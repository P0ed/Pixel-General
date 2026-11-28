public struct UID: Equatable, BitwiseCopyable, Sendable {
	public var rawValue: UInt8

	public init(_ value: UInt8) { rawValue = value }
}

public extension UID {
	static let none = UID(255)
	var index: Int { Int(rawValue) }
}

public extension Int {
	var uid: UID { UID(UInt8(self)) }
}

public extension InlineArray where Element == Unit, count == 16 {
	subscript(_ xy: XY) -> (UID, Unit)? {
		let i = xy.x + xy.y * 4
		let u = self[i]
		return u.alive ? (i.uid, u) : nil
	}
}

public extension CArray where capacity == 192 {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}

public extension InlineArray where count == 192 {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}

public extension Array {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}
