import Foundation

func id<A>(_ x: A) -> A { x }
func ø<each A>(_ x: repeat each A) {}

precedencegroup ApplicationPrecedence {
	associativity: right
	higherThan: AssignmentPrecedence
}

infix operator §: ApplicationPrecedence
func § <A, B> (_ f: (A) -> B, x: A) -> B { f(x) }

func modifying<A>(_ value: A, _ tfm: (inout A) -> Void) -> A {
	var value = value
	tfm(&value)
	return value
}

func clone<A: ~Copyable>(_ x: borrowing A) -> A {
	withUnsafeTemporaryAllocation(
		byteCount: MemoryLayout<A>.size,
		alignment: MemoryLayout<A>.alignment
	) { raw in
		withUnsafePointer(to: x) { src in
			raw.baseAddress!.copyMemory(
				from: src,
				byteCount: MemoryLayout<A>.size
			)
		}
		return raw.baseAddress!
			.assumingMemoryBound(to: A.self)
			.move()
	}
}

func encode<A: ~Copyable>(_ x: borrowing A) -> Data {
	withUnsafePointer(to: x) { p in Data(bytes: p, count: MemoryLayout<A>.size) }
}

func decode<A: ~Copyable>(_ data: Data) -> A? {
	guard data.count == MemoryLayout<A>.size else { return nil }
	return withUnsafeTemporaryAllocation(
		byteCount: MemoryLayout<A>.size,
		alignment: MemoryLayout<A>.alignment
	) { ap in
		data.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
			ap.baseAddress!.copyMemory(from: p.baseAddress!, byteCount: MemoryLayout<A>.size)
		}
		return ap.baseAddress!
			.assumingMemoryBound(to: A.self)
			.move()
	}
}

@propertyWrapper
struct IO<A> {
	private var get: () -> A
	private var set: (A) -> Void

	var wrappedValue: A {
		get { get() }
		nonmutating set { set(newValue) }
	}

	init(wrappedValue: A) {
		var closure = wrappedValue
		get = { closure }
		set = { newValue in closure = newValue }
	}
}
