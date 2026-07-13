import SpriteKit
import COR

extension TacticalNodes {

	func process(_ event: TacticalEvent, _ state: borrowing TacticalState) async {
		switch event {
		case let .spawn(uid): processSpawn(uid, state)
		case let .move(uid, path): await processMove(uid, path, state)
		case let .fire(src, dst, dmg, hp): await processFire(src: src, dst: dst, dmg: dmg, hp: hp, state: state)
		case let .update(id): update(id, state)
		case .ruggedDefence: sounds.ruggedDefence.play()
		case .end: endGame(state)
		}
	}

	func present(_ intent: TacticalPresentationIntent, _ state: borrowing TacticalState) async {
		switch intent {
		case .shop: processShop(state)
		case .menu: processMenu(state)
		}
	}

	func endGame(_ state: borrowing TacticalState) {
		net?.leave()
		core.complete(state.sim)
		core.save()
		view.present(.auto)
	}
}

private extension TacticalNodes {

	func processSpawn(_ uid: UID, _ state: borrowing TacticalState) {
		let sprite = state.sim.units[uid].sprite
		let xy = state.sim.position[uid]
		sprite.position = state.sim.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		sprite.isHidden = !state.sim.isVisibleToHuman(uid)
		addUnit(uid, node: sprite)
	}

	func processMove(_ uid: UID, _ path: Path, _ state: borrowing TacticalState) async {
		guard let node = units[uid], path.count > 0 else { return }

		let dst = path[path.count - 1]
		node.zPosition = path.reduce(into: node.zPosition) { z, xy in
			z = max(z, map.zPosition(at: xy))
		}

		let onMap = state.sim.unitsMap[state.sim.position[uid]] == uid || !node.isHidden
		let anyVisible = onMap && path.contains { xy in state.sim.isVisibleToHuman(xy) }
		guard anyVisible else {
			node.position = state.sim.map.point(at: dst)
			node.zPosition = map.zPosition(at: dst)
			node.isHidden = true
			return
		}

		sounds.mov.play()
		node.isHidden = !state.sim.isVisibleToHuman(path[0])

		let scale = settings.animationScale
		var actions: [SKAction] = []
		for i in 1 ..< path.count {
			let xy = path[i]
			let point = state.sim.map.point(at: xy)
			let prev = state.sim.map.point(at: path[i - 1])
			let duration = (prev - point).length / 330.0 * scale
			let hidden = i == path.count - 1
				? !state.sim.isVisibleToHuman(uid)
				: !state.sim.isVisibleToHuman(xy)
			actions.append(.move(to: point, duration: duration))
			actions.append(.run { node.isHidden = hidden })
		}
		await node.run(.sequence(actions))
		node.zPosition = map.zPosition(at: dst)
	}

	func processFire(src: UID, dst: UID, dmg: UInt8, hp: UInt8, state: borrowing TacticalState) async {
		defer {
			if hp > 0 {
				units[dst]?.update(hp: hp)
			} else {
				removeUnit(dst)
			}
		}

		guard state.sim.isVisibleToHuman(src) || state.sim.isVisibleToHuman(dst) else { return }

		let scale = settings.animationScale
		units[src]?.showSight(for: 0.47 * scale)
		await scene?.run(.wait(forDuration: 0.22 * scale))
		units[dst]?.showSight(for: (0.47 - 0.22) * scale)
		await scene?.run(.wait(forDuration: 0.22 * scale))

		if dmg > 0, hp == 0 {
			sounds.boomL.play()
		} else if dmg > 0 {
			sounds.boomM.play()
		} else {
			sounds.boomS.play()
		}
	}

	func update(_ id: UID, _ state: borrowing TacticalState) {
		if state.sim.units[id].alive {
			units[id]?.update(hp: state.sim.units[id].hp)
		} else {
			removeUnit(id)
		}
	}

	func processShop(_ state: borrowing TacticalState) {
		guard state.sim.map[state.ui.cursor].isSettlement,
			  state.sim.control[state.ui.cursor] == state.sim.country,
			  state.sim.unitAt(state.ui.cursor) == nil
		else { return }

		let xy = state.ui.cursor
		let items = state.sim.shopUnits(at: xy).enumerated().map { i, template in
			MenuItem<TacticalAction>.close(
				icon: template.image,
				status: .init(
					text: template.status(),
					action: .init("\(template.cost) / \(state.sim.player.prestige)")
				),
				action: .purchase(i, xy)
			)
		}

		if !items.isEmpty { scene?.showMenu(MenuState(items: items)) }
	}
}
