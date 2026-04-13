import SpriteKit
import AVFoundation

extension TacticalScene {

	func process(events: [TacticalEvent]) async {
		for e in events { await process(e) }
	}

	func respawn() {
		state.units.forEach { i, u in processSpawn(uid: i.uid) }
	}
}

private extension TacticalScene {

	func process(_ event: TacticalEvent) async {
		switch event {
		case let .spawn(uid): processSpawn(uid: uid)
		case let .move(uid, a, b): await processMove(uid: uid, from: a, to: b)
		case let .attack(src, dst, dmg, hp): await processAttack(src: src, dst: dst, dmg: dmg, hp: hp)
		case .nextDay: nodes?.updateUnits(state)
		case .shop: processShop()
		case .menu: processMenu()
		case .gameOver: restartGame(state: state)
		case .none: break
		}
	}

	func processSpawn(uid: UID) {
		guard let nodes else { return }

		let sprite = state.units[uid.index].sprite
		let xy = state.units[uid.index].position
		sprite.position = state.map.point(at: xy)
		sprite.zPosition = nodes.map.zPosition(at: xy)
		sprite.isHidden = !state.player.visible[xy]
		addUnit(uid, node: sprite)
	}

	func processMove(uid: UID, from a: XY, to b: XY) async {
		guard let nodes, let unit = nodes.units[uid] else { return }

		let z = nodes.map.zPosition(at: b)
		unit.zPosition = max(unit.zPosition, z)
		nodes.sounds.mov.play()
		await unit.run(.move(
			to: state.map.point(at: b),
			duration: CGFloat(a.distance(to: b)) * 0.047
		))
		unit.zPosition = z
		unit.isHidden = !state.player.visible[b]
		if !state.units[uid.index].alive { removeUnit(uid) }
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

		let xy = state.cursor
		let items = state.shopUnits(at: xy).map { template in
			MenuItem<TacticalState>.close(
				icon: template.imageName,
				status: template.status,
				action: "\(template.cost) / \(state.player.prestige) ><",
				update: { state in state.buy(template, at: xy) }
			)
		}

		if !items.isEmpty { show(MenuState(items: items)) }
	}

	func processMenu() {
		guard case .none = menuState else { return show(.none) }

		var vol: Int {
			let v = audioEngine.mainMixerNode.outputVolume
			return v < 0.1 ? 0 : v < 0.7 ? 1 : 2
		}
		let toggleVol = { [audioEngine] in
			switch vol {
			case 0: audioEngine.mainMixerNode.outputVolume = 0.5
			case 1: audioEngine.mainMixerNode.outputVolume = 1.0
			default: audioEngine.mainMixerNode.outputVolume = 0.0
			}
		}

		show(MenuState(
			items: [
				.close(icon: "Start", status: "End turn") { state in
					state.endTurn()
				},
				.close(icon: "Save", status: "Save") { state in
					core.store(tactical: state, auto: false)
				},
				.close(icon: "Load", status: "Load") { [weak self] state in
					core.load(auto: false)
					_ = self?.view?.present(core.state)
				},
				.close(icon: "HQ", status: "HQ") { [weak self] state in
					self?.restartGame(state: state)
				},
				MenuItem(icon: "s", status: "Prestige: \(state.player.prestige)", update: { _, m in
					m
				}),
				MenuItem(icon: "Sound\(vol)", status: "Volume", update: { _, menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[5].icon = "Sound\(vol)"
					}
				})
			]
		))
	}

	private func restartGame(state: borrowing TacticalState) {
		core.complete(tactical: state)
		view?.present(core.state)
	}
}
