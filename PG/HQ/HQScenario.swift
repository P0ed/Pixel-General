import SpriteKit
import COR

extension HQMenu {

	func scenarioMenu() -> Menu {
		let primary = hq.player
		let opponents: [Country] = [.isr, .usa, .irn, .rus]
		var setup = Scenario(
			players: [primary] + opponents.filter { $0 != primary.country }.prefix(3).map {
				Player(country: $0, type: .ai, prestige: .rich)
			},
			units: []
		)
		var forts: UInt8 = 0
		var density: UInt8 = 0

		var seats: [Int] { setup.players.indices.filter { setup.players[$0].alive } }

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

		func updateControls(_ menu: inout Menu) {
			for seat in setup.players.indices {
				menu.items[20 + seat].icon = spawnIcon(seat)
				menu.items[20 + seat].status.text = spawnStatus(seat)
			}
			menu.leftButtons[3].icon = symmetryIcon
			menu.leftButtons[3].status.text = symmetryStatus
		}

		let countries = setup.players.indices.map { idx in
			MenuItem.push(icon: setup.players[idx].country.flag, status: "Player \(idx + 1)") {
				guard idx > 0 else { return nil }
				let countriesLeft = Country.playable.filter { country in
					!seats.contains { setup.players[$0].country == country }
				}
				return Menu(
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
			MenuItem.toggle(icon: setup.players[idx].type.icon, status: "Player \(idx + 1)") {
				guard idx > 0 else { return }
				setup.players[idx].type.toggle()
			}
		}
		let prestige = setup.players.indices.map { idx in
			MenuItem.toggle(
				icon: setup.players[idx].prestige < .rich ? .prestige1 : .prestige2,
				status: "Prestige"
			) {
				setup.players[idx].prestige = setup.players[idx].prestige < .rich ? .rich : .poor
			}
		}
		let exp = setup.players.indices.map { idx in
			MenuItem.toggle(icon: .toggle4(setup.players[idx].baseLevel), status: "Experience") {
				guard idx > 0 else { return }
				setup.players[idx].baseLevel.toggle4()
			}
		}
		let tier = setup.players.indices.map { idx in
			MenuItem.toggle(icon: .toggle4(setup.players[idx].tier), status: "Tier") {
				guard idx > 0 else { return }
				setup.players[idx].tier.toggle4()
			}
		}
		let spawn = setup.players.indices.map { seat in
			MenuItem.push(icon: spawnIcon(seat), status: spawnStatus(seat)) {
				guard setup.players[seat].alive else { return nil }
				let available = setup.availableSpawns(for: seat)
				let choices = corners.enumerated().compactMap { index, corner -> MenuItem? in
					guard available.contains(corner), let icon = SKTexture.number(UInt8(index)) else { return nil }
					return .pop(icon: icon, status: cornerNames[index]) { menu in
						setup.spawns[seat] = corner
						updateControls(&menu)
					}
				}
				return Menu(
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
		let start = MenuItem.close(icon: .arrowRight, status: "Start", update: { [self] in
			let active = seats.map { setup.players[$0] }
			setup.units = hq.units.compactMap { $0.alive ? $0 : nil }
				+ active.dropFirst().flatMap { [Unit].base($0.country, lvl: $0.baseLevel) }
				+ active.flatMap { [Unit].aux($0.country, lvl: $0.baseLevel) }
			setup.cityLevel = Int(density)
			setup.fortLevel = Int(forts)
			setup.seed = Int.random(in: 0 ..< 1024)
			core.store(setup.makeSim())
			core.save()
			view.present(TACScene())
		})

		return Menu(
			items: countries + types + prestige + exp + tier + spawn,
			leftButtons: [
				.back,
				.space,
				.toggle(
					icon: .toggle4(setup.mapType.rawValue),
					status: "Map · \(setup.mapType.name)"
				) {
					setup.mapType = MapType.allCases[(Int(setup.mapType.rawValue) + 1) % MapType.allCases.count]
				},
				.toggle(icon: symmetryIcon, status: symmetryStatus) {
					if setup.symmetryAvailable { setup.symmetry.toggle() }
				},
			],
			rightButtons: [
				start,
				.space,
				.toggle(icon: .toggle4(density), status: "Density: \(density)") { density.toggle4() },
				.toggle(icon: .toggle4(forts), status: "Forts: \(forts)") { forts.toggle4() },
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

private extension MapType {

	var name: String {
		switch self {
		case .land: "Land"
		case .island: "Island"
		case .twoIslands: "Two islands"
		case .fourIslands: "Four islands"
		}
	}
}
