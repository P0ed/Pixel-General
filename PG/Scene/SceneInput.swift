import SpriteKit
import UIKit
import COR

extension Scene where State: ~Copyable {

	@discardableResult
	func handle(key: UIKey) -> Bool {
		if alertState?.field != nil { return editAlertField(key) }
		guard let nodes, let input = mode.keyboard(nodes, key) else { return false }
		pressInput(input)
		return true
	}

	/// Only a held side button cares about key-up: the chord fires here, and
	/// letting go of `L`/`R` first — or losing the press altogether — takes it
	/// back.
	@discardableResult
	func handle(keyUp key: UIKey, cancelled: Bool) -> Bool {
		guard pressedSlot != nil, alertState?.field == nil else { return false }
		if cancelled {
			cancelPress()
			return true
		}
		if let modifiers = InputModifiers(modifierKey: key) {
			releaseInput(.action(nil, modifiers: modifiers))
			return true
		}
		guard let nodes, let input = mode.keyboard(nodes, key) else { return false }
		releaseInput(input)
		return true
	}

	/// Keyboard and gamepad presses land here: an `L`/`R` chord over an open
	/// menu latches the side button, everything else applies immediately.
	func pressInput(_ input: Input) {
		guard menuState != nil, alertState == nil, let slot = input.menuSlot
		else { return apply(input) }
		// Auto-repeat re-delivers the chord while it is still held down.
		guard slot != pressedSlot else { return }
		press(slot)
	}

	func releaseInput(_ input: Input) {
		guard let slot = pressedSlot, case .action(let button, let modifiers) = input
		else { return }
		guard let modifier = slot.modifier else { return }
		if let button {
			// Firing needs the chord still intact — `L`/`R` let go first takes
			// the press back, whether its own key-up arrived or not.
			guard button.index == slot.index else { return }
			release(fire: modifiers.contains(modifier))
		} else if modifiers.contains(modifier) {
			release(fire: false)
		}
	}

	func processTouch(at scenePoint: CGPoint) {
		guard let nodes, let baseNodes else { return }
		if alertState != nil {
			let buttons: [Input] = [.action(.a), .action(.b), .action(.c), .action(.d)]
			baseNodes.alertActionIndex(at: scenePoint, in: self).map { apply(buttons[$0]) }
			return
		}
		if menuState == nil {
			if let input = mode.mouse(nodes, scenePoint) {
				apply(input)
			}
		} else {
			guard self.nodes(at: scenePoint)
				.contains(where: { n in n == baseNodes.menu })
			else { return apply(.action(.b)) }

			switch baseNodes.menuSlot(at: scenePoint, in: self) {
			// Side buttons latch on touch down and fire on release the way a
			// physical button does; grid cells stay instant.
			case .left(let index): press(.left(index))
			case .right(let index): press(.right(index))
			case .item(let index): Input(slot: .item(index)).map(apply)
			case .none: break
			}
		}
	}

	/// Fires the held button if the touch lifts off while still on it, the way
	/// a physical button ignores a finger that slid away before release.
	func releaseTouch(at scenePoint: CGPoint) {
		guard let slot = pressedSlot else { return }
		release(fire: baseNodes?.menuSlot(at: scenePoint, in: self) == slot)
	}

	func cancelPress() {
		release(fire: false)
	}

	private func press(_ slot: MenuSlot) {
		release(fire: false)
		pressedSlot = slot
		// Only a chord actually held by a modifier key is worth watching: the
		// `1`…`4` bindings carry `R` without one, as does a pointer press.
		chordModifier = slot.modifier.flatMap { $0.isKeyDown ? $0 : nil }
		baseNodes?.setMenuButton(slot, pressed: true)
		baseNodes?.click.play()
	}

	/// Lets the button back up — it clicks either way, but only a press that
	/// stayed on target fires.
	private func release(fire: Bool) {
		guard let slot = pressedSlot else { return }
		pressedSlot = nil
		chordModifier = nil
		baseNodes?.setMenuButton(slot, pressed: false)
		baseNodes?.click.play()
		if fire, menuState != nil { Input(slot: slot).map(apply) }
	}
}

extension InputModifiers {

	/// The side a bare modifier key stands for: option is `L`, shift is `R`,
	/// matching `Input.init(key:)`.
	@MainActor
	init?(modifierKey key: UIKey) {
		switch key.keyCode {
		case .keyboardLeftAlt, .keyboardRightAlt: self = .left
		case .keyboardLeftShift, .keyboardRightShift: self = .right
		default: return nil
		}
	}
}

extension Input {

	@MainActor
	init?(key: UIKey) {
		let shift = key.modifierFlags.contains(.shift)
		let option = key.modifierFlags.contains(.alternate)
		let mods: InputModifiers = [
			shift ? .right : [],
			option ? .left : [],
		]

		switch key.keyCode {
		case .keyboardReturnOrEnter, .keyboardSpacebar: self = .action(.a)
		case .keyboardDeleteOrBackspace: self = .action(.b)
		case .keyboardEscape: self = .menu
		case .keyboardTab: self = .target(shift ? .prev : .next)
		case .keyboardLeftArrow: self = .direction(.left, modifiers: mods)
		case .keyboardRightArrow: self = .direction(.right, modifiers: mods)
		case .keyboardDownArrow: self = .direction(.down, modifiers: mods)
		case .keyboardUpArrow: self = .direction(.up, modifiers: mods)

		// `charactersIgnoringModifiers` still applies shift, so `R+A` arrives
		// as "A" — fold the case to keep the letter bindings modifier agnostic.
		default: switch key.charactersIgnoringModifiers.lowercased() {
		case "1": self = .action(.a, modifiers: .right)
		case "2": self = .action(.b, modifiers: .right)
		case "3": self = .action(.c, modifiers: .right)
		case "4": self = .action(.d, modifiers: .right)
		case "[": self = .target(.prev)
		case "]": self = .target(.next)
		case "a": self = .action(.a, modifiers: mods)
		case "s": self = .action(.b, modifiers: mods)
		case "q": self = .action(.c, modifiers: mods)
		case "w": self = .action(.d, modifiers: mods)
		case "z": self = .scale(1)
		case "x": self = .scale(2)
		case "c": self = .scale(4)
		default: return nil
		}
		}
	}
}
