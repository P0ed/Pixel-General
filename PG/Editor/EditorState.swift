struct EditorState: ~Copyable {
	var map: Map<Terrain>
}

enum EditorAction {}
enum EditorEvent { case set(XY, Terrain) }

extension EditorState {

	init() {
		map = Map(size: 32, zero: .field)
	}

	func apply(_ input: Input) -> EditorAction? {
		// TODO: Implement
		nil
	}

	func reduce(_ action: EditorAction?) -> [EditorEvent] {
		// TODO: Implement
		[]
	}

	var status: Status {
		Status()
	}
}
