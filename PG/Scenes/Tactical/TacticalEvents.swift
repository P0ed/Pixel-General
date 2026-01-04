import SpriteKit

extension TacticalScene {

	func process(events: [TacticalEvent]) async {
		for e in events { await process(e) }
	}

	func respawn() {
		state.units.forEach { i, u in
			processSpawn(uid: i)
		}
	}
}

private extension TacticalScene {

	func process(_ event: TacticalEvent) async {
		switch event {
		case let .spawn(uid): processSpawn(uid: uid)
		case let .move(uid, distance): await processMove(uid: uid, distance: distance)
		case let .attack(src, dst, dmg, hp): await processAttack(src: src, dst: dst, dmg: dmg, hp: hp)
		case .nextDay: nodes?.updateUnits(state)
		case .shop: processShop()
		case .menu: processMenu()
		case .gameOver: processGameOver()
		case .none: break
		}
	}

	func processSpawn(uid: UID) {
		guard let nodes else { return }

		let sprite = state.units[uid].sprite
		let xy = state.units[uid].position
		sprite.position = state.map.point(at: xy)
		sprite.zPosition = nodes.map.zPosition(at: xy)
		sprite.isHidden = !state.player.visible[xy]
		addUnit(uid, node: sprite)
	}

	func processMove(uid: UID, distance: Int) async {
		guard let nodes, let unit = nodes.units[uid] else { return }

		let xy = state.units[uid].position
		let z = nodes.map.zPosition(at: xy)
		unit.zPosition = max(unit.zPosition, z)
		nodes.sounds.mov.play()
		await unit.run(.move(
			to: state.map.point(at: xy),
			duration: CGFloat(distance) * 0.047
		))
		unit.zPosition = z
	}

	func processAttack(src: UID, dst: UID, dmg: UInt8, hp: UInt8) async {
		nodes?.units[src]?.showSight(for: 0.47)
		await run(.wait(forDuration: 0.22))
		nodes?.units[dst]?.showSight(for: 0.47 - 0.22)
		await run(.wait(forDuration: 0.22))

		if hp > 0 {
			if dmg > 0 {
				nodes?.sounds.boomM.play()
			} else {
				nodes?.sounds.boomS.play()
			}
			nodes?.units[dst]?.update(hp: hp)
		} else {
			nodes?.sounds.boomL.play()
			removeUnit(dst)
		}
	}

	func processShop() {
		guard let building = state.buildings[state.cursor],
			  building.country == state.country,
			  state.units[state.cursor] == nil
		else { return }

		show(MenuState(
			layout: .inspector,
			items: state.unitTemplates.map { template in
				MenuItem(
					icon: template.imageName,
					text: template.stats.shortDescription,
					description: template.description + " / \(state.player.prestige)",
					action: { [xy = state.cursor] state in
						state.buy(template, at: xy)
					}
				)
			}
		))
	}

	func processMenu() {
		guard case .none = menuState else { return show(.none) }

		show(MenuState(
			layout: .compact,
			items: [
				.init(icon: "End", text: "End turn", action: { state in
					state.endTurn()
				}),
				.init(
					icon: "Restart", text: "Restart",
					action: { [weak self] state in self?.restartGame(state: state) }
				)
			]
		))
	}

	func processGameOver() {
		restartGame(state: state)
	}

	private func restartGame(state: borrowing TacticalState) {
		core.complete(tactical: state)
		view?.present(core.state)
	}
}
