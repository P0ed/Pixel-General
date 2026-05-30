extension Map {

	struct Indices: Sequence {
		var size: Int

		func makeIterator() -> Iterator { Iterator(size: size) }

		struct Iterator: IteratorProtocol {
			var size: Int
			var index: Int = 0

			mutating func next() -> XY? {
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
