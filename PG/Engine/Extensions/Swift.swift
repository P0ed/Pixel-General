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
	unsafe withUnsafeTemporaryAllocation(
		byteCount: MemoryLayout<A>.size,
		alignment: MemoryLayout<A>.alignment
	) { raw in
		unsafe withUnsafePointer(to: x) { src in
			unsafe raw.baseAddress!.copyMemory(
				from: src,
				byteCount: MemoryLayout<A>.size
			)
		}
		return unsafe raw.baseAddress!
			.assumingMemoryBound(to: A.self)
			.move()
	}
}

func encode<A: ~Copyable>(_ x: borrowing A) -> Data {
	unsafe withUnsafePointer(to: x) { p in
		unsafe Data(bytes: p, count: MemoryLayout<A>.size)
	}
}

func decode<A: ~Copyable>(_ data: Data) -> A? {
	guard data.count == MemoryLayout<A>.size else { return nil }
	return unsafe withUnsafeTemporaryAllocation(
		byteCount: MemoryLayout<A>.size,
		alignment: MemoryLayout<A>.alignment
	) { ap in
		unsafe data.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
			unsafe ap.baseAddress!.copyMemory(from: p.baseAddress!, byteCount: MemoryLayout<A>.size)
		}
		return unsafe ap.baseAddress!
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
