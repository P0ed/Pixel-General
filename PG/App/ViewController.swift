import UIKit
import COR

final class ViewController: UIViewController {

	var keyHandler: @MainActor (UIKey) -> Bool = { _ in false }
	var keyUpHandler: @MainActor (UIKey, _ cancelled: Bool) -> Bool = { _, _ in false }
	var gamepadHandler: @MainActor (Input) -> Bool = { _ in false }

	override func loadView() {
		self.view = PG.view
	}

	override var prefersStatusBarHidden: Bool { true }
	override var prefersHomeIndicatorAutoHidden: Bool { true }
	override var canBecomeFirstResponder: Bool { true }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses {
			if let key = press.key, keyHandler(key) { handled = true }
		}
		if !handled { super.pressesBegan(presses, with: event) }
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses {
			if let key = press.key, keyUpHandler(key, false) { handled = true }
		}
		if !handled { super.pressesEnded(presses, with: event) }
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			if let key = press.key { _ = keyUpHandler(key, true) }
		}
		super.pressesCancelled(presses, with: event)
	}
}
