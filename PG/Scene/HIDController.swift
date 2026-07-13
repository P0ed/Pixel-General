import GameController
import COR

@MainActor
struct HIDController {
	@IO private var lifetime: Any?
	@IO var send: (Input) -> Void = ø
	@IO private var modifiers: InputModifiers = []
	@IO private var usedModifiers: InputModifiers = []

	init() {
		lifetime = NotificationCenter.default.addMainActorObserver(
			forName: .GCControllerDidBecomeCurrent,
			using: { [_send, _modifiers, _usedModifiers] notification in
				_modifiers.wrappedValue = []
				_usedModifiers.wrappedValue = []
				guard let gamepad = (notification.object as? GCController)?.extendedGamepad
				else { return }

				let send = { input in
					if !controller.gamepadHandler(input) { _send.wrappedValue(input) }
				}
				let sendDirection = { direction in
					let current = _modifiers.wrappedValue
					_usedModifiers.wrappedValue.formUnion(current)
					send(.direction(direction, modifiers: current))
				}
				let sendAction = { action in
					let current = _modifiers.wrappedValue
					_usedModifiers.wrappedValue.formUnion(current)
					send(.action(action, modifiers: current))
				}
				let shoulder = { modifier, target, pressed in
					if pressed {
						_modifiers.wrappedValue.insert(modifier)
						_usedModifiers.wrappedValue.remove(modifier)
					} else {
						let used = _usedModifiers.wrappedValue.contains(modifier)
						_modifiers.wrappedValue.remove(modifier)
						_usedModifiers.wrappedValue.remove(modifier)
						if !used { send(.target(target)) }
					}
				}

				gamepad.dpad.left.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendDirection(.left)
				}
				gamepad.dpad.right.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendDirection(.right)
				}
				gamepad.dpad.down.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendDirection(.down)
				}
				gamepad.dpad.up.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendDirection(.up)
				}
				gamepad.leftShoulder.pressedChangedHandler = { _, _, pressed in
					shoulder(.left, .prev, pressed)
				}
				gamepad.rightShoulder.pressedChangedHandler = { _, _, pressed in
					shoulder(.right, .next, pressed)
				}
				gamepad.buttonA.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendAction(.a)
				}
				gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendAction(.b)
				}
				gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendAction(.c)
				}
				gamepad.buttonY.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendAction(.d)
				}
				gamepad.buttonMenu.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.menu)
				}
			}
		)
	}
}
