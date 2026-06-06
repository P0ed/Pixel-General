import Foundation

public func id<A>(_ x: A) -> A { x }
public func ø<each A>(_ x: repeat each A) {}

public func modifying<A>(_ value: A, _ tfm: (inout A) -> Void) -> A {
	var value = value
	tfm(&value)
	return value
}

public func clone<A: ~Copyable>(_ x: borrowing A) -> A {
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

public func encode<A: ~Copyable>(_ x: borrowing A) -> Data {
	unsafe withUnsafePointer(to: x) { p in
		unsafe Data(bytes: p, count: MemoryLayout<A>.size)
	}
}

public func decode<A: ~Copyable>(_ data: Data) -> A? {
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
public struct IO<A> {
	private var get: () -> A
	private var set: (A) -> Void

	public var wrappedValue: A {
		get { get() }
		nonmutating set { set(newValue) }
	}

	public init(wrappedValue: A) {
		var closure = wrappedValue
		get = { closure }
		set = { newValue in closure = newValue }
	}
}

@propertyWrapper
public struct NC<Value>: ~Copyable {
	private var value: Value

	public var wrappedValue: Value {
		_read { yield value }
		_modify { yield &value }
	}

	public init(wrappedValue: Value) {
		value = wrappedValue
	}
}
