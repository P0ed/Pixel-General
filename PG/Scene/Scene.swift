import SpriteKit
import AVFAudio
import UIKit
import COR

final class Scene<State: ~Copyable, Action, Event, Nodes>: SKScene {
	let mode: SceneMode<State, Action, Event, Nodes>
	private let hid = HIDController()

	private var processing = false
	private var pending: Input?
	private(set) var pan: CGPoint = .zero
	private var lastPan: CGPoint = .zero
	private(set) var menuState: MenuState<Action>? { didSet { didSetMenu() } }
	private(set) var state: State { didSet { didSetState() } }
	private(set) var baseNodes: BaseNodes?
	private(set) var nodes: Nodes?
	private var enterBackground: Any?
	private var panRecognizer: UIPanGestureRecognizer?

	init(mode: SceneMode<State, Action, Event, Nodes>, state: consuming State, size: CGSize = .scene) {
		self.state = state
		self.mode = mode
		super.init(size: size)
	}

	required init?(coder aDecoder: NSCoder) { fatalError() }

	override func sceneDidLoad() {
		backgroundColor = .black
		scaleMode = .aspectFit
		audioEngine.mainMixerNode.outputVolume = settings.outputVolume

		enterBackground = NotificationCenter.default.addMainActorObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			using: { [weak self] _ in
				self?.saveState()
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
	}

	isolated deinit {
		if let enterBackground { NotificationCenter.default.removeObserver(enterBackground) }
	}

	override func didMove(to view: SKView) {
		controller.keyHandler = { [weak self] key in self?.handle(key: key) ?? false }

		let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		pan.minimumNumberOfTouches = 2
		pan.maximumNumberOfTouches = 2
		pan.allowedScrollTypesMask = .all
		view.addGestureRecognizer(pan)
		panRecognizer = pan
	}

	override func willMove(from view: SKView) {
		if let panRecognizer { view.removeGestureRecognizer(panRecognizer) }
		panRecognizer = nil
	}

	override func didChangeSize(_ oldSize: CGSize) {
		if let nodes { mode.layout(size, nodes) }
		baseNodes?.layout(size: size)
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		processTouch(at: touch.location(in: self))
	}

	func apply(_ input: Input) {
		if case .some = menuState {
			menuState?.apply(input)
		} else if processing {
			pending = input
		} else {
			react(mode.input(&state, input))
		}
	}

	func send(_ action: Action) {
		react(.action(action))
	}

	private func react(_ reaction: Reaction<Action, Event>) {
		guard let nodes, !processing else { return }
		processing = true
		let events: [Event] = switch reaction {
		case .action(let action): mode.relay(state, action) ? [] : mode.reduce(&state, action)
		case .events(let events): events
		}
		Task {
			for event in events {
				await mode.process(event, nodes, state)
			}
			processing = false
			didSetState()
			advance()
		}
	}

	/// Also poked by `NetSession` when actions arrive over the wire.
	func advance() {
		guard !processing, menuState == nil else { return }
		if let input = pending {
			pending = nil
			apply(input)
		} else if let action = mode.ai(state) {
			send(action)
		}
	}

	func show(_ menu: MenuState<Action>?) {
		menuState = modifying(menu) { m in
			m = m.flatMap { m in m.items.isEmpty ? nil : m }
			m?.padItems()
		}
	}

	func saveState() {
		mode.save(state)
	}

	private func didSetState() {
		guard let nodes, !processing else { return }
		updateStatus()
		mode.update(nodes, state)
	}

	private func didSetMenu() {
		if let menuState, let action = menuState.action {
			if case let .action(idx) = action {
				if let action = menuState.items[idx].action {
					react(.action(action))
				}
				show(menuState.items[idx].update(
					modifying(menuState) { m in
						m.action = nil
						m.padItems()
					}
				))
			} else {
				show(menuState.close(modifying(menuState) { m in m.action = nil }))
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
			menuState.map { $0.status } ?? mode.status(state)
		)
	}

	@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
		guard let view = gesture.view else { return }
		switch gesture.state {
		case .began:
			lastPan = .zero
		case .changed:
			let translation = gesture.translation(in: view)
			let x = translation.x - lastPan.x
			let y = translation.y - lastPan.y
			lastPan = translation
			pan.x += x
			pan.y += y

			if pan.x > 64 {
				pan.x -= 64
				apply(.pan(.zero.neighbor(.left).neighbor(.down)))
			} else if pan.x < -64 {
				pan.x += 64
				apply(.pan(.zero.neighbor(.right).neighbor(.up)))
			} else if pan.y > 32 {
				pan.y -= 32
				apply(.pan(.zero.neighbor(.up).neighbor(.left)))
			} else if pan.y < -32 {
				pan.y += 32
				apply(.pan(.zero.neighbor(.down).neighbor(.right)))
			}
		case .ended, .cancelled, .failed:
			pan = .zero
			lastPan = .zero
		default:
			break
		}
	}
}

extension MenuState {

	var status: Status {
		cursor < items.count ? items[cursor].status : Status()
	}

	mutating func padItems() {
		let cnt = items.count
		if cnt % 16 != 0 {
			items.append(contentsOf: [MenuItem<Action>](
				repeatElement(.space, count: 16 - cnt % 16)
			))
		}
	}
}
