public struct SetXY: BitwiseCopyable {
	private var storage: InlineArray<32, UInt32>
}

extension SetXY: Monoid {

	public static var empty: Self {
		.init(storage: .init(repeating: .zero))
	}

	public static var full: Self {
		.init(storage: .init(repeating: .max))
	}

	public mutating func combine(_ other: Self) {
		formUnion(other)
	}
}

extension SetXY: Equatable {

	public static func == (lhs: Self, rhs: Self) -> Bool {
		for i in lhs.storage.indices where lhs.storage[i] != rhs.storage[i] {
			return false
		}
		return true
	}
}

public extension SetXY {

	init(_ xys: [XY]) {
		self = .empty
		for xy in xys { self[xy] = true }
	}

	subscript(_ xy: XY) -> Bool {
		get {
			guard bounds(xy) else { return false }
			return storage[xy.y] & 1 << xy.x != 0
		}
		set {
			guard bounds(xy) else { return }
			if newValue {
				storage[xy.y] |= 1 << xy.x
			} else {
				storage[xy.y] &= ~(1 << xy.x)
			}
		}
	}

	private func bounds(_ xy: XY) -> Bool {
		xy.x >= 0 && xy.x < 32 && xy.y >= 0 && xy.y < 32
	}

	mutating func formUnion(_ set: Self) {
		for i in storage.indices {
			storage[i] |= set.storage[i]
		}
	}

	mutating func formIntersection(_ set: Self) {
		for i in storage.indices {
			storage[i] &= set.storage[i]
		}
	}

	func union(_ xys: [XY]) -> Self {
		var result = self
		for xy in xys { result[xy] = true }
		return result
	}

	func subtracting(_ xys: [XY]) -> Self {
		var result = self
		for xy in xys { result[xy] = false }
		return result
	}
}
