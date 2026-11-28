public struct Map<let size: Int, Element>: ~Copyable {
	private var tiles: InlineArray<size, InlineArray<size, Element>>
	private var zero: Element

	public var size: Int { Self.size }
	public var count: Int { size * size }

	public init(zero: Element) {
		self.zero = zero
		tiles = .init(repeating: .init(repeating: zero))
	}

	public subscript(xy: XY) -> Element {
		get {
			contains(xy) ? tiles[xy.y][xy.x] : zero
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

@frozen public enum Edge: Hashable, CaseIterable {
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
