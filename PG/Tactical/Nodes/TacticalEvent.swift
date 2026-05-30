import SpriteKit
import AVFoundation

enum TacticalEvent {
	case spawn(UID)
	case move(UID, CArray<16, XY>)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case shop
	case menu
	case end
}

extension TacticalNodes {

	func process(_ event: TacticalEvent, _ state: borrowing TacticalState) async {
		switch event {
		case let .spawn(uid): processSpawn(uid, state)
		case let .move(uid, path): await processMove(uid, path, state)
		case let .fire(src, dst, dmg, hp): await processFire(src: src, dst: dst, dmg: dmg, hp: hp, state: state)
		case let .update(id): update(id, state)
		case .shop: processShop(state)
		case .menu: processMenu(state)
		case .end: restartGame(state)
		}
	}
}

private extension TacticalNodes {

	func processSpawn(_ uid: UID, _ state: borrowing TacticalState) {
		let sprite = state.units[uid].sprite
		let xy = state.position[uid]
		sprite.position = state.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		sprite.isHidden = !state.isVisibleToHuman(uid)
		addUnit(uid, node: sprite)
	}

	func processMove(_ uid: UID, _ path: CArray<16, XY>, _ state: borrowing TacticalState) async {
		guard let node = units[uid], !path.isEmpty else { return }

		let dst = path[path.count - 1]
		node.zPosition = path.reduce(into: node.zPosition) { z, _, xy in
			z = max(z, map.zPosition(at: xy))
		}

		let onMap = state.unitsMap[state.position[uid]] == uid || !node.isHidden
		let anyVisible = onMap && path.contains { xy in state.isVisibleToHuman(xy) }
		guard anyVisible else {
			node.position = state.map.point(at: dst)
			node.zPosition = map.zPosition(at: dst)
			node.isHidden = true
			return
		}

		sounds.mov.play()
		node.isHidden = !state.isVisibleToHuman(path[0])

		var actions: [SKAction] = []
		for i in 1 ..< path.count {
			let xy = path[i]
			let point = state.map.point(at: xy)
			let prev = state.map.point(at: path[i - 1])
			let duration = (prev - point).length / 480.0
			let hidden = i == path.count - 1
				? !state.isVisibleToHuman(uid)
				: !state.isVisibleToHuman(xy)
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

		guard state.isVisibleToHuman(src) || state.isVisibleToHuman(dst) else { return }

		units[src]?.showSight(for: 0.47)
		await scene?.run(.wait(forDuration: 0.22))
		units[dst]?.showSight(for: 0.47 - 0.22)
		await scene?.run(.wait(forDuration: 0.22))

		if dmg > 0, hp == 0 {
			sounds.boomL.play()
		} else if dmg > 0 {
			sounds.boomM.play()
		} else {
			sounds.boomS.play()
		}
	}

	func update(_ id: UID, _ state: borrowing TacticalState) {
		if state.units[id].alive {
			units[id]?.update(hp: state.units[id].hp)
		} else {
			removeUnit(id)
		}
	}

	func processShop(_ state: borrowing TacticalState) {
		guard state.map[state.cursor].isSettlement,
			  state.control[state.cursor] == state.country,
			  state.unitAt(state.cursor) == nil
		else { return }

		let xy = state.cursor
		let items = state.shopUnits(at: xy).enumerated().map { i, template in
			MenuItem<TacticalAction>.close(
				icon: template.imageName,
				status: .init(
					text: template.status(),
					action: .init("\(template.cost) / \(state.player.prestige)")
				),
				action: .purchase(i, xy)
			)
		}

		if !items.isEmpty { scene?.show(MenuState(items: items)) }
	}

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.show(.none)
		}

		var vol: Int {
			let v = scene.audioEngine.mainMixerNode.outputVolume
			return v < 0.1 ? 0 : v < 0.5 ? 1 : 2
		}
		let toggleVol = { [audioEngine = scene.audioEngine] in
			core.settings.toggleSound()
			audioEngine.mainMixerNode.outputVolume = core.settings.outputVolume
		}

		scene.show(MenuState(
			items: [
				.close(icon: "Start", status: "End turn", action: .end),
				.close(icon: "Save", status: "Save") { [weak scene] _ in
					if let scene { core.store(scene.state, auto: false) }
				},
				.close(icon: "Load", status: "Load") { _ in
					core.load(auto: false)
					present(.make(core.state))
				},
				.close(icon: "HQ", status: "HQ") { [weak scene] _ in
					if let scene { restartGame(scene.state) }
				},
				MenuItem(
					icon: "Prestige1",
					status: .init(text: "Prestige: \(state.player.prestige)"),
					update: id
				),
				MenuItem(icon: "Sound\(vol)", status: .init(text: "Volume"), update: { menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[5].icon = "Sound\(vol)"
					}
				})
			]
		))
	}

	private func restartGame(_ state: borrowing TacticalState) {
		core.complete(state)
		present(.make(core.state))
	}
}
