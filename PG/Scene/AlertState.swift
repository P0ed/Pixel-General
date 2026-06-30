import SpriteKit

@MainActor
struct Alert {
	var title: String
	var message: String
	var field: Field?
	var actions: [Action]

	init(title: String, message: String = "", field: Field? = nil, actions: [Action]) {
		self.title = title
		self.message = message
		self.field = field
		self.actions = Array(actions.prefix(4))
	}

	@MainActor
	struct Field {
		var placeholder: String = ""
		var text: String = ""
		var maxLength: Int = 64
	}

	@MainActor
	struct Action {
		var title: String
		var handler: (String) -> Void

		init(_ title: String, handler: @escaping (String) -> Void = { _ in }) {
			self.title = title
			self.handler = handler
		}
	}
}
