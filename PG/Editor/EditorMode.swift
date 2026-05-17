typealias EditorMode = SceneMode<EditorState, EditorUI, EditorAction, EditorEvent, EditorNodes>
typealias EditorScene = Scene<EditorState, EditorUI, EditorAction, EditorEvent, EditorNodes>

extension EditorMode {

	static var editor: Self {
		.init(
			make: EditorNodes.init,
			input: { state, ui, input in ui.apply(input, state) },
			update: { nodes, state, ui in nodes.update(state, ui) },
			reduce: { state, ui, action in state.reduce(action) },
			process: { event, nodes, state, ui in await nodes.process(event, state) },
			status: { state, ui in state.status(ui) },
			mouse: { nodes, event in nodes.mouse(event) }
		)
	}
}
