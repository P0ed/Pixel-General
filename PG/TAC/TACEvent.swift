import SpriteKit
import COR

extension TacticalNodes {

	func process(_ event: Event, _ state: borrowing TACSceneState) async {
		switch event {
		case let .spawn(uid): processSpawn(uid, state)
		case let .move(uid, path): await processMove(uid, path, state)
		case let .fire(src, dst, dmg, hp): await processFire(src: src, dst: dst, dmg: dmg, hp: hp, state: state)
		case let .update(id): update(id, state)
		case .ruggedDefence: sounds.play(.ruggedDefence)
		case .end: endGame(state)
		}
	}

	func present(_ intent: PresentationIntent, _ state: borrowing TACSceneState) async {
		switch intent {
		case .shop: processShop(state)
		case .menu: processMenu(state)
		}
	}

	func endGame(_ state: borrowing TACSceneState) {
		core.complete(state.tac)
		core.save()
		view.present(TACScene())
	}
}

private extension TacticalNodes {

	func processSpawn(_ uid: UID, _ state: borrowing TACSceneState) {
		let sprite = state.tac.units[uid].sprite
		let xy = state.tac.position[uid]
		sprite.position = state.tac.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		sprite.isHidden = !state.tac.isVisibleToHuman(uid)
		addUnit(uid, node: sprite)
	}

	func processMove(_ uid: UID, _ path: Path, _ state: borrowing TACSceneState) async {
		guard let node = units[uid], path.count > 0 else { return }

		let dst = path[path.count - 1]
		node.zPosition = path.reduce(into: node.zPosition) { z, xy in
			z = max(z, map.zPosition(at: xy))
		}

		let onMap = state.tac.unitsMap[state.tac.position[uid]] == uid || !node.isHidden
		let anyVisible = onMap && path.contains { xy in state.tac.isVisibleToHuman(xy) }
		guard anyVisible else {
			node.position = state.tac.map.point(at: dst)
			node.zPosition = map.zPosition(at: dst)
			node.isHidden = true
			return
		}

		sounds.play(.mov)
		node.isHidden = !state.tac.isVisibleToHuman(path[0])

		let scale = settings.animationScale
		var actions: [SKAction] = []
		for i in 1 ..< path.count {
			let xy = path[i]
			let point = state.tac.map.point(at: xy)
			let prev = state.tac.map.point(at: path[i - 1])
			let duration = (prev - point).length / 400.0 * scale
			let hidden = i == path.count - 1
				? !state.tac.isVisibleToHuman(uid)
				: !state.tac.isVisibleToHuman(xy)
			actions.append(.move(to: point, duration: duration))
			actions.append(.run { node.isHidden = hidden })
		}
		await node.run(.sequence(actions))
		node.zPosition = map.zPosition(at: dst)
	}

	func processFire(src: UID, dst: UID, dmg: UInt8, hp: UInt8, state: borrowing TACSceneState) async {
		defer {
			if hp > 0 {
				units[dst]?.update(hp: hp)
			} else {
				removeUnit(dst)
			}
		}

		guard state.tac.isVisibleToHuman(src) || state.tac.isVisibleToHuman(dst) else { return }

		let scale = settings.animationScale
		units[src]?.showSight(for: 0.47 * scale)
		await scene?.run(.wait(forDuration: 0.22 * scale))
		units[dst]?.showSight(for: (0.47 - 0.22) * scale)
		await scene?.run(.wait(forDuration: 0.22 * scale))

		if dmg > 0, hp == 0 {
			sounds.play(.boomL)
			showExplosion(2, at: dst)
		} else if dmg > 0 {
			sounds.play(.boomM)
			showExplosion(1, at: dst)
		} else {
			sounds.play(.boomS)
			showExplosion(0, at: dst)
		}
	}

	func showExplosion(_ size: Int, at dst: UID) {
		guard let node = units[dst] else { return }
		scene?.showExplosion(
			size,
			at: node.position,
			zPosition: node.zPosition + 3,
			scale: settings.animationScale
		)
	}

	func update(_ id: UID, _ state: borrowing TACSceneState) {
		if state.tac.units[id].alive {
			units[id]?.update(hp: state.tac.units[id].hp)
		} else {
			removeUnit(id)
		}
	}

	func processShop(_ state: borrowing TACSceneState) {
		guard state.tac.map[state.ui.cursor].isSettlement,
			  state.tac.control[state.ui.cursor] == state.tac.country,
			  state.tac.unitAt(state.ui.cursor) == nil
		else { return }

		let xy = state.ui.cursor
		scene?.showMenu(.shop(
			units: state.tac.shopUnits(at: xy),
			auxiliary: state.tac.shopUnits(at: xy, aux: true),
			auxiliaryOnly: state.tac.map[xy] == .port,
			offer: { unit, index, aux in
				.close(
					icon: unit.image, status: unit.purchaseStatus(prestige: state.tac.player.prestige),
					action: .purchase(index, xy, aux: aux)
				)
			}
		))
	}
}
