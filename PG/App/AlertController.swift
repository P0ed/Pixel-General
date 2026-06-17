import UIKit

struct AlertAction {
	var title: String
	var style: UIAlertAction.Style
	var handler: (UIAlertController) -> Void

	static func cancel(
		handler: @escaping (UIAlertController) -> Void = { _ in }
	) -> AlertAction {
		AlertAction(title: "Cancel", style: .cancel, handler: handler)
	}

	static func action(
		title: String,
		handler: @escaping (UIAlertController) -> Void = { _ in }
	) -> AlertAction {
		AlertAction(title: title, style: .default, handler: handler)
	}
}

extension UIViewController {

	func alert(
		title: String,
		message: String,
		fields: [(UITextField) -> Void] = [],
		actions: [AlertAction]
	) {
		let alert = UIAlertController(
			title: title,
			message: message,
			preferredStyle: .alert
		)
		fields.forEach { cfg in
			alert.addTextField(configurationHandler: cfg)
		}
		actions.forEach { action in
			alert.addAction(UIAlertAction(
				title: action.title,
				style: action.style,
				handler: { [weak alert, handler = action.handler] _ in
					if let alert { handler(alert) }
				}
			))
		}
		present(alert, animated: true)
	}
}
