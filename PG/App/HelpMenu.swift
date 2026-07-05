import UIKit

// macOS (Mac Catalyst) Help menu: game description, controls, and a short
// rules summary. Inserted into the system Help menu by `AppDelegate.buildMenu`.
extension AppDelegate {

	func buildHelpMenu(with builder: UIMenuBuilder) {
		guard builder.system == .main else { return }

		let help = UIMenu(
			options: .displayInline,
			children: [
				UICommand(title: "About Panzer General", action: #selector(showGameDescription)),
				UICommand(title: "Controls", action: #selector(showControls)),
				UICommand(title: "Game Rules", action: #selector(showGameRules)),
			]
		)
		builder.insertChild(help, atStartOfMenu: .help)
	}

	@objc func showGameDescription() { presentHelp(title: "About Panzer General", body: Help.description) }
	@objc func showControls() { presentHelp(title: "Controls", body: Help.controls) }
	@objc func showGameRules() { presentHelp(title: "Game Rules", body: Help.rules) }

	private func presentHelp(title: String, body: String) {
		let nav = UINavigationController(rootViewController: HelpViewController(title: title, body: body))
		nav.modalPresentationStyle = .formSheet

		var presenter: UIViewController = controller
		while let presented = presenter.presentedViewController { presenter = presented }
		presenter.present(nav, animated: true)
	}
}

private final class HelpViewController: UIViewController {

	private let body: String

	init(title: String, body: String) {
		self.body = body
		super.init(nibName: nil, bundle: nil)
		self.title = title
		preferredContentSize = CGSize(width: 520, height: 560)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground

		let text = UITextView()
		text.isEditable = false
		text.text = body
		text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
		text.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
		text.alwaysBounceVertical = true
		text.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(text)
		NSLayoutConstraint.activate([
			text.topAnchor.constraint(equalTo: view.topAnchor),
			text.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			text.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			text.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])

		navigationItem.rightBarButtonItem = UIBarButtonItem(
			systemItem: .done,
			primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
		)
	}
}

private enum Help {

	static let description = """
	Panzer General — a turn-based wargame

	A Panzer-General-inspired game of operational combat. Purchase units \
	with prestige, maneuver them across a 32×32 tactical grid, capture cities \
	and villages for income, and destroy the enemy force.

	Units are real modern platforms — infantry, artillery, anti-air, recon, \
	IFVs, tanks, helicopters and jets — each with its own stats, terrain \
	behavior and counters. In battle they gain experience, earn skills on \
	kills, and can be resupplied, repaired and re-equipped.

	Battles feed a strategic campaign across Europe: a persistent roster of \
	veterans carries forward from fight to fight, growing in strength — and \
	that you can later stake against other commanders in multiplayer.
	"""

	static let controls = """
	KEYBOARD

	  Arrow keys       Move the cursor
	  Space / A        Confirm — select, move, attack (A)
	  Delete / S       Cancel — deselect, go back (B)
	  Q                Action — shop, upgrade menu (C)
	  W                Action — sell, secondary (D)
	  Tab   /  ]       Select next unit
	  Shift-Tab  /  [  Select previous unit
	  Esc              Open the menu
	  Z / X / C        Zoom  1× / 2× / 4×
	  §                Cycle map mode (terrain · political · supply)

	Note: the letter keys A and S also map to Confirm and Cancel.

	GAMEPAD

	  D-pad            Move the cursor
	  A  /  B          Confirm  /  Cancel
	  X  /  Y          Shop / upgrade  /  Sell
	  L / R shoulder   Previous / next unit
	  Menu             Open the menu
	  Options          Cycle map mode

	POINTER

	  Click            Select / act on a tile or menu item
	  Drag / scroll    Pan the map
	"""

	static let rules = """
	THE GOAL

	Eliminate the enemy team. A player is knocked out once they hold no \
	settlements; the last team standing wins — or, in a scenario, whoever \
	meets its objective first.

	TURNS & ECONOMY

	  • Players act in turn. A day passes once everyone has moved.
	  • Each day you earn prestige from the settlements you control
	    (city 24, village 8, airfield 4).
	  • Spend prestige at an owned, enemy-free settlement to buy units:
	    cities and villages sell ground units, airfields sell aircraft.

	MOVEMENT & TERRAIN

	  • Each unit has a limited move each turn. Roads and open ground are
	    fast; forests and hills are slow; mountains and rivers cost almost
	    everything — and mountains block wheeled units.
	  • Terrain also shields defenders. Sitting still lets ground units
	    entrench for an ever-growing defensive bonus.

	COMBAT

	  • Attack an enemy within range. Nearby friendly artillery and anti-air
	    add supporting fire, and a well-entrenched, experienced defender can
	    fire first (rugged defence) or even force the attacker to retreat.
	  • Damaging and killing enemies earns experience; on a kill a unit may
	    roll a new skill. Higher-level units hit harder and defend better.

	SUPPLY & REPAIR

	  • Keep units near supply trucks and your own settlements to rearm,
	    repair, and recover. Rough or enemy-held ground throttles resupply.
	  • Fast repairs cost prestige and experience (green replacements dilute
	    veterans); resting near supply heals slowly for free.

	CAPTURING

	  • Move a ground unit onto an enemy settlement to flag it for your side.
	    Take all of a player's settlements to eliminate them.
	"""
}
