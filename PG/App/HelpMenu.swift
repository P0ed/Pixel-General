import UIKit
import COR

extension AppDelegate {

	func buildHelpMenu(with builder: UIMenuBuilder) {
		guard builder.system == .main else { return }

		let title = "Pixel General Help"
		let help = UICommand(
			title: title,
			image: UIImage(systemName: "lightbulb"),
			action: #selector(showHelp)
		)
		builder.replaceChildren(ofMenu: .help) { children in
			var replaced = false
			let children = children.map { child in
				guard let command = child as? UICommand, command.title == title else {
					return child
				}
				replaced = true
				return help
			}
			return replaced ? children : children + [help]
		}
	}

	@objc func showHelp() {
		let nav = UINavigationController(rootViewController: HelpViewController())
		nav.modalPresentationStyle = .formSheet

		var presenter: UIViewController = controller
		while let presented = presenter.presentedViewController { presenter = presented }
		presenter.present(nav, animated: true)
	}
}

private final class HelpViewController: UIViewController {

	private let text = UITextView()
	private lazy var sections = UISegmentedControl(
		items: Help.Section.allCases.map(\.title)
	)

	init() {
		super.init(nibName: nil, bundle: nil)
		title = "Pixel General Help"
		preferredContentSize = CGSize(width: 640, height: 560)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground

		sections.selectedSegmentIndex = 0
		sections.addTarget(self, action: #selector(selectSection), for: .valueChanged)
		sections.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(sections)

		text.isEditable = false
		text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
		text.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
		text.alwaysBounceVertical = true
		text.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(text)
		NSLayoutConstraint.activate([
			sections.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
			sections.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
			sections.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
			text.topAnchor.constraint(equalTo: sections.bottomAnchor, constant: 8),
			text.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			text.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			text.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])
		selectSection()

		navigationItem.rightBarButtonItem = UIBarButtonItem(
			systemItem: .done,
			primaryAction: UIAction { [weak self] _ in self?.close() }
		)
	}

	override var canBecomeFirstResponder: Bool { true }
	override var keyCommands: [UIKeyCommand]? {
		[UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(close))]
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		controller.gamepadHandler = { [weak self] input in
			guard let self else { return false }
			if case .action(.b, modifiers: _) = input { self.close() }
			return true
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		controller.gamepadHandler = { _ in false }
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.contains(where: { $0.key?.keyCode == .keyboardEscape }) {
			close()
		} else {
			super.pressesBegan(presses, with: event)
		}
	}

	@objc private func selectSection() {
		guard let section = Help.Section(rawValue: sections.selectedSegmentIndex) else { return }
		text.text = section.body
		text.setContentOffset(.zero, animated: false)
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}

private enum Help {
	enum Section: Int, CaseIterable {
		case about, controls, rules

		var title: String {
			switch self {
			case .about: "About"
			case .controls: "Controls"
			case .rules: "Game Rules"
			}
		}

		var body: String {
			switch self {
			case .about: Help.description
			case .controls: Help.controls
			case .rules: Help.rules
			}
		}
	}

	static let description = """
	Pixel General — a turn-based wargame

	A Panzer-General-inspired game of operational combat. Purchase units \
	with prestige, maneuver them across a 64×64 tactical grid, and capture \
	city districts to control territory and earn income.

	Units are real modern platforms — infantry, artillery, anti-air, recon, \
	IFVs, tanks, helicopters and jets — each with its own stats, terrain \
	behavior and counters. In battle they gain experience, earn skills on \
	kills, and can be resupplied, repaired and re-equipped.

	Build a roster of veterans in HQ and take them into custom scenarios. \
	Play against the AI or share a device with other players. Auto-battle \
	uses the AI's tactics.

	Made by Konstantin Sukharev
	poed@me.com
	"""

	static let controls = """
	KEYBOARD

	  Arrow keys          Move the cursor
	  A / Space / Return  Confirm — select, move, attack
	  S / Delete          Cancel — deselect, go back
	  Q                   Action — shop, upgrade menu
	  W                   Action — sell, secondary
	  ] / Tab             Select next unit
	  [ / Shift-Tab       Select previous unit
	  Esc                 Open the menu
	  Z / X / C           Zoom  1× / 2× / 4×
	  1 / 2               Terrain / Country-Team map
	  3 / 4               Supply / Defense map

	GAMEPAD

	  D-pad               Move the cursor
	  A / B               Confirm / Cancel (B closes Help)
	  X / Y               Shop / Sell
	  Tap L / R shoulder  Previous / Next unit
	  Hold L + D-pad      Pan the map
	  Hold R + D-pad ↑/↓  Zoom in / out
	  Hold R + A / B      Terrain / Country-Team map
	  Hold R + X / Y      Supply / Defense map
	  Menu                Open the menu

	POINTER

	  Click               Select / act on a tile or menu item
	  Scroll              Pan the map
	"""

	static let rules = """
	THE GOAL

	A team is eliminated when it loses its last city tile. The last team \
	standing wins. Scenarios can also end when their objective is met.

	TURNS & ECONOMY

	  • Players act in turn. A day passes once everyone has moved.
	  • Each day you earn 24 prestige per city tile and 4 per airfield
	    you control.
	  • Spend prestige at an owned, enemy-free settlement to buy units.
	    Cities sell ground units and airfields sell aircraft.

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
	  • Aircraft flying into enemy anti-air range are interrupted and
	    fired upon — one shot per anti-air per turn, none after it moves.
	  • Damaging and killing enemies earns experience; on a kill a unit may
	    roll a new skill. Higher-level units hit harder and defend better.

	SUPPLY & REPAIR

	  • Keep units near supply trucks and your own settlements to rearm,
		repair, and recover. Rough or enemy-held ground throttles resupply.
	  • Repairs cost prestige and experience (green replacements dilute veterans).

	CAPTURING

	  • Hold an enemy city tile with a ground unit at the end of a turn
	    to capture it. A city can have up to three districts, and each
	    district is captured independently.
	  • Airfields and surrounding tiles follow the nearest city tile.
	    Ties go to the first city tile in row-major map order.
	"""
}
