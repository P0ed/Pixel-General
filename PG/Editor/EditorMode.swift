typealias EditorMode = SceneMode<EditorState, EditorAction, EditorEvent, EditorNodes>
typealias EditorScene = Scene<EditorState, EditorAction, EditorEvent, EditorNodes>

extension EditorMode {

	static var editor: Self {
		.init(
			make: EditorNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.map.tile(at: event) }
		)
	}
}
