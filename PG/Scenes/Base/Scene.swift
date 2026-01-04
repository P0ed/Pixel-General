import SpriteKit

final class Scene<State: ~Copyable, Event, Nodes>: SKScene {
	let mode: SceneMode<State, Event, Nodes>
	private let hid = HIDController()

	private var processing = false
	private(set) var menuState: MenuState<State>? { didSet { didSetMenu() } }
	private(set) var state: State { didSet { didSetState() } }
	private(set) var baseNodes: BaseNodes?
	private(set) var nodes: Nodes?
	private var willCloseWindow: Any?

	init(mode: SceneMode<State, Event, Nodes>, state: consuming State, size: CGSize = .scene) {
		self.state = state
		self.mode = mode
		super.init(size: size)
	}

	required init?(coder aDecoder: NSCoder) { fatalError() }

	override func becomeFirstResponder() -> Bool {
		super.becomeFirstResponder()
		return true
	}

	override func sceneDidLoad() {
		backgroundColor = .black
		scaleMode = .aspectFit

		willCloseWindow = NotificationCenter.default.willCloseWindow { [weak self] window in
			guard self?.view?.window == window else { return }
			self?.saveAndExit()
		}

		let nodes = mode.make(self, state)
		mode.layout(size, nodes)
		self.nodes = nodes

		baseNodes = makeBaseNodes()
		baseNodes?.layout(size: size)

		mode.respawn(self)

		hid.send = { [weak self] input in self?.apply(input) }

		didSetState()
	}

	override func didChangeSize(_ oldSize: CGSize) {
		if let nodes { mode.layout(size, nodes) }
		baseNodes?.layout(size: size)
	}

	override func keyDown(with event: NSEvent) {
		processKeyEvent(event)
	}

	override func mouseDown(with event: NSEvent) {
		processMouseEvent(event)
	}

	func apply(_ input: Input) {
		if case .some = menuState {
			menuState?.apply(input)
		} else if mode.inputable(state), !processing {
			mode.input(&state, input)
		}
	}

	func show(_ menu: MenuState<State>?) {
		menuState = menu.flatMap { m in m.items.isEmpty ? .none : m }
	}

	private func didSetState() {
		guard let nodes else { return }

		updateStatus()
		mode.update(state, nodes)

		guard !processing, mode.reducible(state) else { return }

		processing = true
		let events = mode.reduce(&state)
		if !events.isEmpty {
			Task {
				await mode.process(self, events)
				processing = false
				if mode.reducible(state) { didSetState() }
			}
		} else {
			processing = false
			if mode.reducible(state) { didSetState() }
		}
	}

	private func didSetMenu() {
		if let action = menuState?.action {
			if let menuState, case let .apply(idx) = action {
				menuState.items[idx].action(&state)
			}
			return menuState = .none
		} else if (menuState == nil) != (baseNodes?.menu.isHidden == true) {
			if let menuState { baseNodes?.showMenu(menuState) }
			else { baseNodes?.hideMenu() }
		} else if let menuState {
			baseNodes?.updateMenu(menuState)
		}
		updateStatus()
	}

	private func updateStatus() {
		baseNodes?.status.text = menuState?.statusText ?? mode.status(state)
	}

	func saveAndExit() {
		mode.save(state)
		exit(0)
	}
}

extension TacticalScene {

	func addUnit(_ uid: UID, node: SKNode) {
		addChild(node)
		nodes?.units[uid] = node
	}

	func removeUnit(_ uid: UID) {
		nodes?.units[uid]?.removeFromParent()
		nodes?.units[uid] = .none
	}
}

extension HQScene {

	func addUnit(_ uid: UID, node: SKNode) {
		addChild(node)
		nodes?.units[uid] = node
	}
}

private extension SKScene {

	static func make(_ state: borrowing State) -> SKScene {
		if state.tactical != nil {
			Scene(mode: .tactical, state: clone(state.tactical!))
		} else if state.strategic != nil {
			fatalError()
		} else {
			Scene(mode: .hq, state: clone(state.hq!))
		}
	}
}

extension SKView {

	func present(_ state: borrowing State) {
		presentScene(
			.make(state),
			transition: .moveIn(with: .up, duration: 0.47)
		)
	}
}
