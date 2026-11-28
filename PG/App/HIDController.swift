import GameController
import COR

@MainActor
extension InputModifiers {

	private static let altKeys: [GCKeyCode] = [.leftAlt, .rightAlt]
	private static let shiftKeys: [GCKeyCode] = [.leftShift, .rightShift]

	var isKeyDown: Bool {
		guard let keyboard = GCKeyboard.coalesced?.keyboardInput else { return false }
		return (contains(.left) ? Self.altKeys : Self.shiftKeys)
			.contains { code in keyboard.button(forKeyCode: code)?.isPressed == true }
	}
}

@MainActor
final class HIDController {
	private var lifetime: Any?
	var send: (Input) -> Void = ø
	var up: (Input) -> Void = ø
	private var modifiers: InputModifiers = []
	private var usedModifiers: InputModifiers = []

	init() {
		lifetime = NotificationCenter.default.addMainActorObserver(
			forName: .GCControllerDidBecomeCurrent,
			using: { [weak self] notification in
				guard let self else { return }
				modifiers = []
				usedModifiers = []
				guard let gamepad = (notification.object as? GCController)?.extendedGamepad
				else { return }

				let sendInput: (Input) -> Void = { [weak self] input in
					if !controller.gamepadHandler(input) { self?.send(input) }
				}
				let sendDirection: (Direction?) -> Void = { [weak self] direction in
					guard let self else { return }
					let current = modifiers
					usedModifiers.formUnion(current)
					sendInput(.direction(direction, modifiers: current))
				}
				let sendAction: (InputAction) -> Void = { [weak self] action in
					guard let self else { return }
					let current = modifiers
					usedModifiers.formUnion(current)
					sendInput(.action(action, modifiers: current))
				}
				let releaseAction = { [weak self] action in
					guard let self else { return }
					up(.action(action, modifiers: modifiers))
				}
				let shoulder = { [weak self] modifier, target, pressed in
					guard let self else { return }
					if pressed {
						modifiers.insert(modifier)
						usedModifiers.remove(modifier)
					} else {
						let used = usedModifiers.contains(modifier)
						modifiers.remove(modifier)
						usedModifiers.remove(modifier)
						up(.action(nil, modifiers: modifier))
						if !used { sendInput(.target(target)) }
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
					pressed ? sendAction(.a) : releaseAction(.a)
				}
				gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
					pressed ? sendAction(.b) : releaseAction(.b)
				}
				gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
					pressed ? sendAction(.c) : releaseAction(.c)
				}
				gamepad.buttonY.pressedChangedHandler = { _, _, pressed in
					pressed ? sendAction(.d) : releaseAction(.d)
				}
				gamepad.buttonMenu.pressedChangedHandler = { _, _, pressed in
					guard pressed else { return }
					sendInput(.menu)
				}
			}
		)
	}
}
