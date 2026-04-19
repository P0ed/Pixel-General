import SpriteKit

final class Scene<State: ~Copyable, Action, Event, Nodes>: SKScene {
	let mode: SceneMode<State, Action, Event, Nodes>
	private let hid = HIDController()

	private var processing = false
	private var panAccumulator: CGPoint = .zero
	private(set) var menuState: MenuState<Action>? { didSet { didSetMenu() } }
	private(set) var state: State { didSet { didSetState() } }
	private(set) var baseNodes: BaseNodes?
	private(set) var nodes: Nodes?
	private var willCloseWindow: Any?
	private var eventsMonitor: Any?

	init(mode: SceneMode<State, Action, Event, Nodes>, state: consuming State, size: CGSize = .scene) {
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

		hid.send = { [weak self] input in self?.apply(input) }

		didSetState()

		eventsMonitor = panHandler
	}

	deinit {
		if let eventsMonitor { NSEvent.removeMonitor(eventsMonitor) }
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
		} else if !processing {
			if let action = mode.input(&state, input) {
				send(action)
			}
		}
	}

	func send(_ action: Action) {
		guard !processing else { return }
		processing = true

		Task {
			if let action = await mode.send(action) {
				let events = mode.reduce(&state, action)
				if !events.isEmpty, let nodes {
					for event in events {
						await mode.process(event, nodes, state)
					}
				}
			}
			processing = false
		}
	}

	func show(_ menu: MenuState<Action>?) {
		menuState = menu.flatMap { m in m.items.isEmpty ? .none : m }
	}

	private func didSetState() {
		guard let nodes else { return }
		updateStatus()
		mode.update(nodes, state)
	}

	private func didSetMenu() {
		if let menuState, let action = menuState.action {
			if case let .action(idx) = action {
				if let action = menuState.items[idx].action {
					send(action)
				}
				self.menuState = menuState.items[idx].update(
					modifying(menuState) { m in m.action = nil }
				)
			} else {
				self.menuState = menuState.close(modifying(menuState) { m in m.action = nil })
			}
			if let next = self.menuState {
				baseNodes?.redrawMenu(next)
			}
		} else if (menuState == nil) != (baseNodes?.menu.isHidden == true) {
			if let menuState { baseNodes?.showMenu(menuState) }
			else { baseNodes?.hideMenu() }
		} else if let menuState {
			baseNodes?.updateMenu(menuState)
		}
		updateStatus()
	}

	private func updateStatus() {
		baseNodes?.updateStatus(
			menuState.map { $0.status } ?? mode.status(state)
		)
	}

	func saveAndExit() {
		mode.save(state)
		exit(0)
	}

	private var panHandler: Any? {
		NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
			guard let self, e.type == .scrollWheel else { return e }
			let x = e.scrollingDeltaX
			let y = e.scrollingDeltaY
			panAccumulator.x += x
			panAccumulator.y += y

			if panAccumulator.x > 64 {
				panAccumulator.x -= 64
				apply(.pan(.zero.neighbor(.left).neighbor(.down)))
			} else if panAccumulator.x < -64 {
				panAccumulator.x += 64
				apply(.pan(.zero.neighbor(.right).neighbor(.up)))
			} else if panAccumulator.y > 32 {
				panAccumulator.y -= 32
				apply(.pan(.zero.neighbor(.up).neighbor(.left)))
			} else if panAccumulator.y < -32 {
				panAccumulator.y += 32
				apply(.pan(.zero.neighbor(.down).neighbor(.right)))
			}
			if abs(x) < 0.1, abs(y) < 0.1 { panAccumulator = .zero }

			return e
		}
	}
}

extension MenuState {

	var status: Status {
		let item = cursor < items.count ? items[cursor] : nil
		return item?.status ?? Status()
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
