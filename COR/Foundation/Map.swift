public struct Map<let maxSize: Int, Element>: ~Copyable {
	private var tiles: InlineArray<maxSize, InlineArray<maxSize, Element>>
	private var zero: Element
	public private(set) var size: Int

	public var count: Int { size * size }

	public init(size: Int, zero: Element) {
		precondition(size > 0 && size <= maxSize)
		self.size = size
		self.zero = zero
		tiles = .init(repeating: .init(repeating: zero))
	}

	public subscript(xy: XY) -> Element {
		_read {
			if contains(xy) {
				yield tiles[xy.y][xy.x]
			} else {
				yield zero
			}
		}
		_modify {
			if contains(xy) {
				yield &tiles[xy.y][xy.x]
			} else {
				var z = zero
				yield &z
			}
		}
	}

	public func contains(_ xy: XY) -> Bool {
		xy.x >= 0 && xy.x < size && xy.y >= 0 && xy.y < size
	}

	public func forEachEdge(_ body: (XY, Edge) -> Void) {
		Edge.allCases.forEach { edge in
			forEachEdge(edge) { xy in
				body(xy, edge)
			}
		}
	}

	public func forEachEdge(_ edge: Edge, _ body: (XY) -> Void) {
		switch edge {
		case .bottom: (0 ..< size).forEach { x in body(XY(x, 0)) }
		case .left: (0 ..< size).forEach { y in body(XY(0, y)) }
		case .top: (0 ..< size).forEach { x in body(XY(x, size - 1)) }
		case .right: (0 ..< size).forEach { y in body(XY(size - 1, y)) }
		}
	}
}

public enum Edge: Hashable, CaseIterable {
	case bottom, left, top, right
}

public extension Map {

	struct Indices: Sequence {
		var size: Int

		public func makeIterator() -> Iterator { Iterator(size: size) }

		public struct Iterator: IteratorProtocol {
			var size: Int
			var index: Int = 0

			public mutating func next() -> XY? {
				if index < size * size {
					defer { index += 1 }
					return XY(index % size, index / size)
				} else {
					return nil
				}
			}
		}
	}

	var indices: Indices { Indices(size: size) }
}
