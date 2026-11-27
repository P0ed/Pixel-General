import SpriteKit
import UIKit
import COR

final class TACScene: SKScene {
	private let hid = HIDController()

	private var isPresented = false
	private var processing = false
	private var pending: Input?
	private(set) var pan: CGPoint = .zero
	private(set) var cameraTracking = false
	private var panOrigin: CGPoint?
	private var panTranslation: CGPoint?
	private var menuStack: [MenuState<Action>] = [] { didSet { didSetMenu() } }
	var menuState: MenuState<Action>? { menuStack.last }
	var pressedSlot: MenuSlot? { didSet { didSetPressedSlot(oldValue) } }
	var chordModifier: InputModifiers?
	private var hoveredSlot: MenuSlot? { didSet { if hoveredSlot != oldValue { updateStatus() } } }
	var state: TacticalState { didSet { didSetState() } }
	private let ai = AI.heuristic
	private(set) var baseNodes: BaseNodes?
	private(set) var nodes: TacticalNodes?
	private var enterBackground: Any?
	private var panRecognizer: UIPanGestureRecognizer?
	private var hoverRecognizer: UIHoverGestureRecognizer?

	init(state: consuming TacticalState, size: CGSize = .scene) {
		self.state = state
		super.init(size: size)
	}

	required init?(coder aDecoder: NSCoder) { fatalError() }

	override func sceneDidLoad() {
		backgroundColor = .black
		scaleMode = .aspectFit

		enterBackground = NotificationCenter.default.addMainActorObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			using: { [weak self] _ in
				if let self, isPresented { saveState() }
			}
		)
		nodes = TacticalNodes(scene: self)

		baseNodes = makeBaseNodes()
		baseNodes?.layout(size: size)

		hid.send = { [weak self] input in self?.pressInput(input) }
		hid.up = { [weak self] input in self?.releaseInput(input) }

		didSetState()
		showMenu(state.sim.isFinished ? HQMenu().menu() : nil)
	}

	isolated deinit {
		if let enterBackground { NotificationCenter.default.removeObserver(enterBackground) }
	}

	override func didMove(to view: SKView) {
		isPresented = true
		controller.keyHandler = { [weak self] key in self?.handle(key: key) ?? false }
		controller.keyUpHandler = { [weak self] key, cancelled in
			self?.handle(keyUp: key, cancelled: cancelled) ?? false
		}

		let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		pan.minimumNumberOfTouches = 2
		pan.maximumNumberOfTouches = 2
		pan.allowedScrollTypesMask = .all
		view.addGestureRecognizer(pan)
		panRecognizer = pan

		let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
		view.addGestureRecognizer(hover)
		hoverRecognizer = hover
		advance()
	}

	override func willMove(from view: SKView) {
		isPresented = false
		if let panRecognizer { view.removeGestureRecognizer(panRecognizer) }
		if let hoverRecognizer { view.removeGestureRecognizer(hoverRecognizer) }
		panRecognizer = nil
		hoverRecognizer = nil
	}

	override func didChangeSize(_ oldSize: CGSize) {
		baseNodes?.layout(size: size)
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		processTouch(at: touch.location(in: self))
	}

	/// Letting go of `L`/`R` before `A`…`D` takes the press back, and the only
	/// way to see that on Mac Catalyst is to watch the key.
	override func update(_ currentTime: TimeInterval) {
		if let chordModifier, !chordModifier.isKeyDown { cancelPress() }
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		releaseTouch(at: touch.location(in: self))
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		cancelPress()
	}

	func apply(_ input: Input) {
		if !menuStack.isEmpty {
			menuStack[menuStack.count - 1].apply(input)
		} else if processing, case .pan = input {
			_ = state.apply(input)
		} else if processing {
			pending = input
		} else {
			react(state.apply(input))
		}
	}

	private func react(_ reaction: InputReaction) {
		guard let nodes, !processing else { return }

		switch reaction {
		case .none:
			didSetState()
			advance()
		case .action(let action):
			processing = true
			let events = state.reduce(action)
			Task {
				for event in events {
					await nodes.process(event, state)
				}
				finishReaction()
			}
		case .presentation(let intent):
			processing = true
			Task {
				await nodes.present(intent, state)
				finishReaction()
			}
		}
	}

	private func finishReaction() {
		processing = false
		didSetState()
		advance()
	}

	private func advance() {
		guard isPresented, !processing, menuState == nil else { return }
		if let input = pending {
			pending = nil
			apply(input)
		} else if let action = state.auto ? ai(state.sim) : nil {
			react(.action(action))
		}
	}

	func showMenu(_ menu: MenuState<Action>?) {
		setMenu(menu.map { m in [m] } ?? [])
	}

	private func setMenu(_ stack: [MenuState<Action>]) {
		menuStack = stack.compactMap { m in
			modifying(m) { m in m.padItems() }
		}
	}

	func saveState() {
		core.store(state.sim)
		core.save()
	}

	private func didSetState() {
		guard let nodes, !processing else { return }
		updateStatus()
		nodes.update(state)
	}

	private func didSetPressedSlot(_ oldValue: MenuSlot?) {
		guard pressedSlot != oldValue else { return }
		oldValue.map { slot in baseNodes?.menu.setMenuButton(slot, pressed: false) }
		pressedSlot.map { slot in baseNodes?.menu.setMenuButton(slot, pressed: true) }
	}

	private func didSetMenu() {
		if menuState == nil {
			pressedSlot = nil
			chordModifier = nil
			hoveredSlot = nil
		}
		if let menuState, let slot = menuState.action {
			let item = menuState[slot]
			if let action = item.action {
				react(.action(action))
			}
			setMenu(modifying(menuStack) { stk in
				stk[stk.count - 1].action = nil
				item.update(&stk, slot)
			})
			if let next = self.menuState {
				baseNodes?.menu.redrawMenu(next)
			}
		} else if let menuState {
			if baseNodes?.menu.root.isHidden == true || baseNodes?.menu.isHiding == true {
				baseNodes?.menu.showMenu(menuState)
			} else {
				baseNodes?.menu.updateMenu(menuState)
			}
		} else if baseNodes?.menu.root.isHidden == false {
			baseNodes?.menu.hideMenu()
		}
		updateStatus()
		advance()
	}

	private func updateStatus() {
		baseNodes?.updateStatus(
			menuState.map { $0.status(hovering: hoveredSlot) } ?? state.status
		)
	}

	@objc func handleHover(_ gesture: UIHoverGestureRecognizer) {
		guard let view = gesture.view, menuState != nil, let baseNodes else {
			hoveredSlot = nil
			return
		}
		switch gesture.state {
		case .began, .changed:
			let point = convertPoint(fromView: gesture.location(in: view))
			let slot = baseNodes.menu.menuSlot(at: point, in: self)
			hoveredSlot = slot?.modifier == nil ? nil : slot
		default:
			hoveredSlot = nil
		}
	}

	@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
		guard let view = gesture.view, let camera else { return }
		switch gesture.state {
		case .began:
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

			let target = state.ui.camera.point
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
		func component(_ value: CGFloat) -> Int {
			Int(min(CGFloat(Int8.max), max(CGFloat(Int8.min), value.rounded())))
		}
		let x = point.x / CGSize.tile.width
		let y = point.y / CGSize.tile.height
		return XY(component(x - y), component(x + y))
	}

	private func finishCameraPan() {
		pan = .zero
		panOrigin = nil
		panTranslation = nil
		cameraTracking = false
	}
}
