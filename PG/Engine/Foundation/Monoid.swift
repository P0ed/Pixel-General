protocol Monoid {
	static var empty: Self { get }
	mutating func combine(_ other: Self)
}

extension Monoid {

	static func make(_ tfm: (inout Self) -> Void) -> Self {
		modifying(.empty, tfm)
	}

	func combined(_ other: Self) -> Self {
		modifying(self, { m in m.combine(other) })
	}
}

extension Set: Monoid {
	static var empty: Set { [] }
	mutating func combine(_ other: Set) { formUnion(other) }
}

extension Array: Monoid {
	static var empty: Array { [] }
	mutating func combine(_ other: Array) { self += other }
}

extension String: Monoid {
	static var empty: String { "" }
	mutating func combine(_ other: String) { self += other }
}
