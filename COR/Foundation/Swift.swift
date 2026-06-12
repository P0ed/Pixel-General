import Foundation

public func id<A>(_ x: A) -> A { x }
public func ø<each A>(_ x: repeat each A) {}

public func modifying<A>(_ value: A, _ transform: (inout A) -> Void) -> A {
	var value = value
	transform(&value)
	return value
}

/// The only sanctioned way to duplicate game state. Like `encode`/`decode`
/// below it is a raw bitwise copy: every field of `A` must stay effectively
/// `BitwiseCopyable` (no `String`, class, or heap-backed storage), or the
/// copy silently corrupts. Wire/persisted types that can conform declare
/// `BitwiseCopyable` as a compile-time guard (see `TacticalAction`);
/// `~Copyable` state structs cannot, so the constraint is on their fields.
public func clone<A: ~Copyable>(_ value: borrowing A) -> A {
	unsafe withUnsafeTemporaryAllocation(
		byteCount: MemoryLayout<A>.size,
		alignment: MemoryLayout<A>.alignment
	) { raw in
		unsafe withUnsafePointer(to: value) { src in
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

public func encode<A: ~Copyable>(_ value: borrowing A) -> Data {
	unsafe withUnsafePointer(to: value) { ptr in
		unsafe Data(bytes: ptr, count: MemoryLayout<A>.size)
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
