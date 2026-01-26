import GameController

struct HIDController {
	@IO private var lifetime: Any?
	@IO var send: (Input) -> Void = ø

	init() {
		lifetime = NotificationCenter.default.addObserver(
			forName: .GCControllerDidBecomeCurrent,
			object: nil,
			queue: .main,
			using: { [_send] notification in
				guard let gamepad = (notification.object as? GCController)?.extendedGamepad else { return }
				let send = { input in _send.wrappedValue(input) }

				gamepad.dpad.left.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.direction(.left))
				}
				gamepad.dpad.right.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.direction(.right))
				}
				gamepad.dpad.down.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.direction(.down))
				}
				gamepad.dpad.up.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.direction(.up))
				}
				gamepad.leftShoulder.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.target(.prev))
				}
				gamepad.rightShoulder.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.target(.next))
				}
				gamepad.buttonA.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.action(.a))
				}
				gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.action(.b))
				}
				gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.action(.c))
				}
				gamepad.buttonY.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.action(.d))
				}
				gamepad.buttonMenu.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					send(.menu)
				}
			}
		)
	}
}
