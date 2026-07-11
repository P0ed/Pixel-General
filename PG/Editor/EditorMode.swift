typealias EditorMode = SceneMode<EditorState, EditorAction, EditorEvent, EditorEvent, EditorNodes>
typealias EditorScene = Scene<EditorState, EditorAction, EditorEvent, EditorEvent, EditorNodes>

extension EditorMode {

	static var editor: Self {
		.init(
			make: EditorNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			present: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			cameraPosition: { state in state.camera.point },
			mouse: { nodes, point in nodes.map.tile(at: point) }
		)
	}
}
