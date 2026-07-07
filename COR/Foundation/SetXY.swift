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

	func forEach(_ body: (XY) -> Void) {
		for y in storage.indices {
			var row = storage[y]
			while row != 0 {
				body(XY(row.trailingZeroBitCount, y))
				row &= row - 1
			}
		}
	}

	func contains(_ predicate: (XY) -> Bool) -> Bool {
		for y in storage.indices {
			var row = storage[y]
			while row != 0 {
				if predicate(XY(row.trailingZeroBitCount, y)) { return true }
				row &= row - 1
			}
		}
		return false
	}

	func firstMap<A>(_ transform: (XY) -> A?) -> A? {
		for y in storage.indices {
			var row = storage[y]
			while row != 0 {
				if let some = transform(XY(row.trailingZeroBitCount, y)) { return some }
				row &= row - 1
			}
		}
		return nil
	}

	func reduce<R>(into result: R, _ fold: (inout R, XY) -> Void) -> R {
		var result = result
		forEach { xy in fold(&result, xy) }
		return result
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
