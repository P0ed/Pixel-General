public protocol Monoid {
	static var empty: Self { get }
	mutating func combine(_ other: Self)
}

public extension Monoid {

	static func make(_ tfm: (inout Self) -> Void) -> Self {
		modifying(.empty, tfm)
	}

	func combined(_ other: Self) -> Self {
		modifying(self, { m in m.combine(other) })
	}
}

extension Set: Monoid {
	public static var empty: Set { [] }
	public mutating func combine(_ other: Set) { formUnion(other) }
}

extension Array: Monoid {
	public static var empty: Array { [] }
	public mutating func combine(_ other: Array) { self += other }
}

extension String: Monoid {
	public static var empty: String { "" }
	public mutating func combine(_ other: String) { self += other }
}
