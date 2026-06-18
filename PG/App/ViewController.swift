import UIKit

final class ViewController: UIViewController {

	var keyHandler: @MainActor (UIKey) -> Bool = { _ in false }

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
}
