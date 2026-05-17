import SpriteKit
import AVFAudio

final class Scene<State: ~Copyable, UI, Action, Event, Nodes>: SKScene {
	let mode: SceneMode<State, UI, Action, Event, Nodes>
	private let hid = HIDController()

	private var processing = false
	private var pending: Input?
	private var panAccumulator: CGPoint = .zero
	private(set) var menuState: MenuState<Action>? { didSet { didSetMenu() } }
	private(set) var state: State { didSet { didSetState() } }
	/// Session/UI state, owned by the scene (never persisted, never read by
	/// the simulation or AI). Mutated at the input stage; the simulation is
	/// only borrowed there.
	var ui: UI

	private(set) var baseNodes: BaseNodes?
	private(set) var nodes: Nodes?
	private var willCloseWindow: Any?
	private var eventsMonitor: Any?

	init(mode: SceneMode<State, UI, Action, Event, Nodes>, state: consuming State, ui: UI, size: CGSize = .scene) {
		self.state = state
		self.ui = ui
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
		audioEngine.mainMixerNode.outputVolume = 0.5

		willCloseWindow = NotificationCenter.default.addMainActorObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			using: { [weak self] _ in
				self?.saveAndExit()
			}
		)

		let nodes = mode.make(self)
		mode.layout(size, nodes)
		self.nodes = nodes

		baseNodes = makeBaseNodes()
		baseNodes?.layout(size: size)

		hid.send = { [weak self] input in self?.apply(input) }

		didSetState()
		advance()

		eventsMonitor = panHandler
	}

	isolated deinit {
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
		} else if processing {
			if mode.live(input) {
				_ = mode.input(state, &ui, input)
				if let nodes { mode.liveUpdate(nodes, state, ui) }
			} else {
				pending = input
			}
		} else {
			send(mode.input(state, &ui, input))
		}
	}

	/// Idle step of the scene loop. Runs when no `Task` is in flight and no
	/// menu overlay is up: drains a scheduled input first, otherwise lets the
	/// mode's auto-driver (e.g. AI) take a turn. A menu being open pauses both.
	private func advance() {
		guard !processing, menuState == nil else { return }
		if let input = pending {
			pending = nil
			apply(input)
		} else if let action = mode.auto(state) {
			send(action)
		}
	}

	func send(_ action: Action?) {
		guard let nodes, !processing else { return }
		processing = true
		Task {
			let events = mode.reduce(&state, &ui, action)
			for event in events {
				await mode.process(event, nodes, state, ui)
			}
			processing = false
			didSetState()
			advance()
		}
	}

	func show(_ menu: MenuState<Action>?) {
		menuState = menu.flatMap { m in m.items.isEmpty ? .none : m }
	}

	func saveAndExit() {
		mode.save(state)
		exit(0)
	}

	private func didSetState() {
		guard let nodes, !processing else { return }
		updateStatus()
		mode.update(nodes, state, ui)
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
		advance()
	}

	private func updateStatus() {
		baseNodes?.updateStatus(
			menuState.map { $0.status } ?? mode.status(state, ui)
		)
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

@MainActor
func present(_ scene: SKScene) {
	view.presentScene(scene, transition: .moveIn(with: .up, duration: 0.47))
}
