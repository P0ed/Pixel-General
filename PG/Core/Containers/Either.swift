enum Either<A, B> {
	case a(A)
	case b(B)
}

extension Either {

	init(_ a: A) { self = .a(a) }
	init(_ b: B) { self = .b(b) }

	func mapA<C>(_ tfmA: (A) -> C) -> C? {
		switch self {
		case .a(let a): tfmA(a)
		case .b: nil
		}
	}

	func mapB<C>(_ tfmB: (B) -> C) -> C? {
		switch self {
		case .a: nil
		case .b(let b): tfmB(b)
		}
	}

	func map<C>(_ tfmA: (A) -> C, tfmB: (B) -> C) -> C {
		switch self {
		case .a(let a): tfmA(a)
		case .b(let b): tfmB(b)
		}
	}
}
