import SpriteKit

let core = Core()
core.load()

private let window: NSWindow = .make { window in
	let view = SKView(frame: window.contentLayoutRect)
	view.autoresizingMask = [.width, .height]
	view.ignoresSiblingOrder = true
	view.present(core.state)
	return view
}

app.run()
