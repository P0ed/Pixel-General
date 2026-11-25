import SpriteKit
import COR

extension HQNodes {

	func scenarioMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		let primary = state.sim.player
		let opponents: [Country] = [.isr, .usa, .irn, .rus]
		var setup = Scenario(
			players: [primary] + opponents.filter { $0 != primary.country }.prefix(3).map {
				Player(country: $0, type: .ai, prestige: .rich)
			},
			units: []
		)
		var forts: UInt8 = 0
		var density: UInt8 = 0
		var defenseSeat: Int?

		var seats: [Int] { setup.players.indices.filter { setup.players[$0].alive } }
		var defendingTeam: Team? { defenseSeat.map { setup.players[$0].country.team } }
		var canStart: Bool {
			guard let defendingTeam else { return true }
			return seats.contains { setup.players[$0].country.team != defendingTeam }
		}

		let corners = Array(Scenario.spawnOptions)
		let cornerNames = ["Northwest", "Northeast", "Southwest", "Southeast"]

		func spawnStatus(_ seat: Int) -> String {
			guard setup.players[seat].alive else { return "Spawn · Open seat" }
			let corner = setup.spawns[seat].flatMap { corners.firstIndex(of: $0) }
			return "Spawn · " + (corner.map { cornerNames[$0] } ?? "Random")
		}

		func spawnIcon(_ seat: Int) -> SKTexture {
			guard setup.players[seat].alive else { return .clear }
			let corner = setup.spawns[seat].flatMap { corners.firstIndex(of: $0) }
			return corner.flatMap { .number(UInt8($0)) } ?? .rnd
		}

		var symmetryIcon: SKTexture {
			setup.symmetryAvailable ? (setup.symmetry ? .plus : .minus) : .clear
		}
		var symmetryStatus: String {
			setup.symmetryAvailable
				? "Symmetry · \(setup.symmetry ? "On" : "Off")"
				: "Symmetry unavailable with three players"
		}
		var defenseIcon: SKTexture {
			defenseSeat.map { setup.players[$0].country.flag } ?? .minus
		}
		var defenseStatus: String {
			defenseSeat.map { "Defense · Player \($0 + 1) · \(setup.players[$0].country)" } ?? "Defense · Off"
		}

		func updateControls(_ menu: inout MenuState<HQAction>) {
			for seat in setup.players.indices {
				menu.items[20 + seat].icon = spawnIcon(seat)
				menu.items[20 + seat].status.text = spawnStatus(seat)
			}
			menu.rightButtons[2].icon = symmetryIcon
			menu.rightButtons[2].status.text = symmetryStatus
			menu.leftButtons[2].icon = defenseIcon
			menu.leftButtons[2].status.text = defenseStatus
			menu.rightButtons[3].icon = canStart ? .arrowRight : .clear
			menu.rightButtons[3].status.text = canStart ? "Start" : "Defense requires an opposing team"
		}

		let countries = setup.players.indices.map { idx in
			MenuItem<HQAction>.push(icon: setup.players[idx].country.flag, status: "Player \(idx + 1)") {
				guard idx > 0 else { return nil }
				let countriesLeft = Country.playable.filter { country in
					!seats.contains { setup.players[$0].country == country }
				}
				return MenuState(
					items: countriesLeft.map { country in
						.pop(icon: country.flag, status: "\(country)") { menu in
							setup.players[idx].country = country
							setup.players[idx].alive = true
							menu.items[idx].icon = country.flag
							menu.cursor = idx
							updateControls(&menu)
						}
					} + [
						.pop(icon: .neutral, status: "Open") { menu in
							setup.players[idx].alive = false
							if defenseSeat == idx { defenseSeat = nil }
							menu.items[idx].icon = .neutral
							menu.cursor = idx
							updateControls(&menu)
						}
					],
					leftButtons: [.back, .space, .space, .space]
				)
			}
		}
		let types = setup.players.indices.map { idx in
			MenuItem<HQAction>.toggle(icon: setup.players[idx].type.icon, status: "Player \(idx + 1)") {
				guard idx > 0 else { return }
				setup.players[idx].type.toggle()
			}
		}
		let prestige = setup.players.indices.map { idx in
			MenuItem<HQAction>.toggle(
				icon: setup.players[idx].prestige < .rich ? .prestige1 : .prestige2,
				status: "Prestige"
			) {
				setup.players[idx].prestige = setup.players[idx].prestige < .rich ? .rich : .poor
			}
		}
		let exp = setup.players.indices.map { idx in
			MenuItem<HQAction>.toggle(icon: .toggle4(setup.players[idx].baseLevel), status: "Experience") {
				guard idx > 0 else { return }
				setup.players[idx].baseLevel.toggle4()
			}
		}
		let tier = setup.players.indices.map { idx in
			MenuItem<HQAction>.toggle(icon: .toggle4(setup.players[idx].tier), status: "Tier") {
				guard idx > 0 else { return }
				setup.players[idx].tier.toggle4()
			}
		}
		let spawn = setup.players.indices.map { seat in
			MenuItem<HQAction>.push(icon: spawnIcon(seat), status: spawnStatus(seat)) {
				guard setup.players[seat].alive else { return nil }
				let available = setup.availableSpawns(for: seat)
				let choices = corners.enumerated().compactMap { index, corner -> MenuItem<HQAction>? in
					guard available.contains(corner), let icon = SKTexture.number(UInt8(index)) else { return nil }
					return .pop(icon: icon, status: cornerNames[index]) { menu in
						setup.spawns[seat] = corner
						updateControls(&menu)
					}
				}
				return MenuState(
					items: choices + [
						.pop(icon: .rnd, status: "Random") { menu in
							setup.spawns[seat] = nil
							updateControls(&menu)
						}
					],
					leftButtons: [.back, .space, .space, .space]
				)
			}
		}
		let defense = MenuItem<HQAction>.push(icon: defenseIcon, status: defenseStatus) {
			MenuState(
				items: [.pop(icon: .minus, status: "Off") { menu in
					defenseSeat = nil
					updateControls(&menu)
				}] + seats.map { seat in
					let country = setup.players[seat].country
					return .pop(icon: country.flag, status: "Player \(seat + 1) · \(country)") { menu in
						defenseSeat = seat
						updateControls(&menu)
					}
				},
				leftButtons: [.back, .space, .space, .space]
			)
		}
		let start = MenuItem<HQAction>(icon: .arrowRight, status: .init(text: "Start"), update: { [weak scene] stack, _ in
			guard canStart, let scene else { return }
			let active = seats.map { setup.players[$0] }
			setup.units = scene.state.sim.units.compactMap { $0.alive ? $0 : nil }
				+ active.dropFirst().flatMap { [Unit].base($0.country, lvl: $0.baseLevel) }
				+ active.flatMap { [Unit].aux($0.country, lvl: $0.baseLevel) }
			setup.cityLevel = Int(density)
			setup.fortLevel = Int(forts)
			setup.seed = Int.random(in: 0 ..< 1024)
			setup.objective = defendingTeam.map { .survive($0, day: 30) } ?? .none
			core.startScenario(setup.makeSim())
			core.save()
			stack = []
			view.present(.auto)
		})

		return MenuState(
			items: countries + types + prestige + exp + tier + spawn,
			leftButtons: [
				.back,
				.toggle(
					icon: setup.continents ? .plus : .minus,
					status: "Continents · \(setup.continents ? "On" : "Off")"
				) {
					setup.continents.toggle()
				},
				defense,
				.space,
			],
			rightButtons: [
				.toggle(icon: .toggle4(density), status: "Density: \(density)") { density.toggle4() },
				.toggle(icon: .toggle4(forts), status: "Forts: \(forts)") { forts.toggle4() },
				.toggle(icon: symmetryIcon, status: symmetryStatus) {
					if setup.symmetryAvailable { setup.symmetry.toggle() }
				},
				start,
			]
		)
	}
}

extension PlayerType {

	mutating func toggle() {
		self = switch self {
		case .human: .ai
		case .ai: .human
		}
	}

	@MainActor
	var icon: SKTexture {
		switch self {
		case .human: .human
		case .ai: .AI
		}
	}
}
