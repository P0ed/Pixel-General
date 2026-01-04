struct Map<Element>: ~Copyable {
	private var tiles: InlineArray<1024, Element>
	private var zero: Element
	var size: Int

	var count: Int { size * size }

	init(size: Int, zero: Element) {
		precondition(size > 0 && size <= 32)
		self.size = size
		self.zero = zero
		tiles = .init(repeating: zero)
	}

	var indices: AnySequence<XY> {
		AnySequence { [size, count] in
			var i = 0
			return AnyIterator {
				defer { i += 1 }
				return i < count
				? XY(i % size, i / size)
				: nil
			}
		}
	}

	subscript(xy: XY) -> Element {
		get { contains(xy) ? tiles[xy.x + xy.y * size] : zero }
		set { contains(xy) ? tiles[xy.x + xy.y * size] = newValue : () }
	}

	func contains(_ xy: XY) -> Bool {
		xy.x >= 0 && xy.x < size && xy.y >= 0 && xy.y < size
	}

	func forEachEdge(_ body: (XY, Edge) -> Void) {
		Edge.allCases.forEach { edge in
			forEachEdge(edge) { xy in
				body(xy, edge)
			}
		}
	}

	func forEachEdge(_ edge: Edge, _ body: (XY) -> Void) {
		switch edge {
		case .bottom: (0 ..< size).forEach { x in body(XY(x, 0)) }
		case .left: (0 ..< size).forEach { y in body(XY(0, y)) }
		case .top: (0 ..< size).forEach { x in body(XY(x, size - 1)) }
		case .right: (0 ..< size).forEach { y in body(XY(size - 1, y)) }
		}
	}
}

enum Edge: Hashable, CaseIterable {
	case bottom, left, top, right
}
