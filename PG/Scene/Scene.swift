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
	private(set) var cameraTracking = false
	private var panOrigin: CGPoint?
	private var panTranslation: CGPoint?
	private(set) var menuState: MenuState<Action>? { didSet { didSetMenu() } }
	private(set) var alertState: Alert? { didSet { didSetAlert(oldValue) } }
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
		if alertState != nil {
			switch input {
			case .action(.a, modifiers: _): fireAlert(0)
			case .action(.b, modifiers: _): fireAlert(1)
			case .action(.c, modifiers: _): fireAlert(2)
			case .action(.d, modifiers: _): fireAlert(3)
			case .menu: alertState = nil
			default: break
			}
		} else if menuState != nil {
			menuState?.apply(input)
		} else if processing, case .pan = input {
			_ = mode.input(&state, input)
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
		guard !processing, menuState == nil, alertState == nil else { return }
		if let input = pending {
			pending = nil
			apply(input)
		} else if let action = mode.ai(state) {
			send(action)
		}
	}

	func showMenu(_ menu: MenuState<Action>?) {
		menuState = modifying(menu) { m in
			m = m.flatMap { m in m.items.isEmpty ? nil : m }
			m?.padItems()
		}
	}

	func showAlert(_ alert: Alert?) {
		alertState = alert
	}

	private func fireAlert(_ index: Int) {
		guard let alert = alertState, index < alert.actions.count else { return }
		let text = alert.field?.text ?? ""
		let handler = alert.actions[index].handler
		alertState = nil
		handler(text)
	}

	func editAlertField(_ key: UIKey) -> Bool {
		guard let field = alertState?.field else { return false }
		switch key.keyCode {
		case .keyboardReturnOrEnter: apply(.action(.a))
		case .keyboardEscape: apply(.menu)
		case .keyboardDeleteOrBackspace:
			if !field.text.isEmpty { alertState?.field?.text.removeLast() }
		default:
			let chars = key.characters
			if !chars.isEmpty,
				chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }),
				field.text.count + chars.count <= field.maxLength {
				alertState?.field?.text.append(contentsOf: chars)
			}
		}
		return true
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
				showMenu(menuState.items[idx].update(
					modifying(menuState) { m in
						m.action = nil
						m.padItems()
					}
				))
			} else {
				showMenu(menuState.close(modifying(menuState) { m in m.action = nil }))
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

	private func didSetAlert(_ oldValue: Alert?) {
		switch (oldValue, alertState) {
		case (.none, .some(let alert)): baseNodes?.showAlert(alert)
		case (.some, .none): baseNodes?.hideAlert()
		case (.some, .some(let alert)): baseNodes?.updateAlert(alert)
		case (.none, .none): break
		}
		advance()
	}

	private func updateStatus() {
		baseNodes?.updateStatus(
			menuState.map { $0.status } ?? mode.status(state)
		)
	}

	@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
		guard let view = gesture.view, let camera else { return }
		switch gesture.state {
		case .began:
			guard mode.cameraPosition(state) != nil else { return }
			camera.removeAction(forKey: SKAction.cameraPositionKey)
			panOrigin = camera.position
			pan = .zero
			panTranslation = .zero
			cameraTracking = true
		case .changed:
			guard let panOrigin, let panTranslation else { return }
			let translation = gesture.translation(in: view)
			pan = pan + cameraOffset(for: translation - panTranslation, camera: camera)
			self.panTranslation = translation
			camera.position = panOrigin + pan
		case .ended, .cancelled, .failed:
			guard panOrigin != nil, let panTranslation else { return }
			let velocity = gesture.state == .ended ? gesture.velocity(in: view) : .zero
			let remaining = gesture.translation(in: view) - panTranslation
			let projectedOffset = pan + cameraOffset(
				for: remaining + velocity * 0.18,
				camera: camera
			)
			let dxy = gridOffset(for: projectedOffset)
			let speed = cameraOffset(for: velocity, camera: camera).length
			apply(.pan(dxy))

			guard let target = mode.cameraPosition(state) else {
				finishCameraPan()
				return
			}
			camera.removeAction(forKey: SKAction.cameraPositionKey)
			let distance = (target - camera.position).length
			let duration = min(0.45, max(0.12, distance / max(speed, 200) * 2))
			let move = SKAction.move(to: target, duration: duration)
			move.timingMode = .easeOut
			camera.run(
				.sequence([move, .run { [weak self] in self?.finishCameraPan() }]),
				withKey: SKAction.cameraPositionKey
			)
		default:
			break
		}
	}

	private func cameraOffset(for translation: CGPoint, camera: SKCameraNode) -> CGPoint {
		CGPoint(
			x: -translation.x * camera.xScale,
			y: translation.y * camera.yScale
		)
	}

	private func gridOffset(for point: CGPoint) -> XY {
		XY(
			Int((point.x / 64.0 - point.y / 32.0).rounded()),
			Int((point.x / 64.0 + point.y / 32.0).rounded())
		)
	}

	private func finishCameraPan() {
		pan = .zero
		panOrigin = nil
		panTranslation = nil
		cameraTracking = false
	}
}

extension SKAction {
	static let cameraPositionKey = "camera.position"
}

extension MenuState {

	var status: Status {
		cursor < items.count ? items[cursor].status : Status()
	}

	mutating func padItems() {
		let cnt = items.count
		if cnt % 4 != 0 {
			items.append(contentsOf: [MenuItem<Action>](
				repeatElement(.space, count: 4 - cnt % 4)
			))
		}
	}
}
