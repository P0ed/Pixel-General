import SpriteKit
import UIKit
import COR

// LAN lobby flows. The host edits four seats (country / human–AI–open type /
// prestige) and starts the battle; clients join via `ip:port`, watch the seat
// table and wait for the host's `start`. The seat model lives in `NetSession`
// so joins and kicks can re-render the menu live.
extension HQNodes {

	func hostMenu(_ state: borrowing HQState) -> MenuState<HQAction>? {
		let session = NetSession.host(player: state.sim.player)
		net = session
		watchLobby(session)
		return lobby()
	}

	/// Seat edits land at any time, from either side of the wire: the open
	/// lobby is rebuilt in place so the cursor stays where its owner left it.
	private func watchLobby(_ session: NetSession) {
		session.onLobby = { [weak scene] in
			guard let scene, let open = scene.menuState else { return }
			scene.replaceMenu(modifying(lobby()) { m in m.cursor = open.cursor })
		}
	}

	/// Joining runs through an alert, so the lobby is pushed from the
	/// completion rather than returned — nothing to open yet at call time.
	func joinMenu() -> MenuState<HQAction>? {
		askForAddress { address in
			let session = NetSession.join(address)
			net = session
			watchLobby(session)
			session.onEnd = { [weak scene] in
				guard let scene, scene.menuState != nil else { return }
				scene.popMenu()
			}
			scene?.pushMenu(lobby())
		}
		return nil
	}

	private func lobby() -> MenuState<HQAction> {
		guard let session = net else { return MenuState(items: []) }

		let isHost = session.role == .host
		var countriesLeft: [Country] {
			Country.playable.filter { c in
				!(0 ..< 4).contains { i in
					session.seats[i].alive && session.seats[i].country == c
				}
			}
		}
		/// The seat table is rebuilt wholesale after every edit: one toggle can
		/// move several icons at once.
		func rebuilt(cursor: Int) -> MenuState<HQAction> {
			modifying(lobby()) { m in m.cursor = cursor }
		}

		let countries = (0 ..< 4).map { idx in
			MenuItem<HQAction>(
				icon: session.seats[idx].alive ? session.seats[idx].country.flag : .neutral,
				status: .init(text: seatText(idx, session)),
				update: { stk, _ in
					guard isHost, idx > 0 else { return }
					stk.append(MenuState<HQAction>(
						items: countriesLeft.map { c in
							.pop(icon: c.flag, status: "\(c)") { menu in
								session.set(seat: idx, country: c)
								menu = rebuilt(cursor: idx)
							}
						} + [
							.pop(icon: .neutral, status: "Off") { menu in
								session.close(seat: idx)
								menu = rebuilt(cursor: idx)
							}
						]
					))
				}
			)
		}
		let types = (0 ..< 4).map { idx in
			MenuItem<HQAction>.update(
				icon: session.seats[idx].alive ? session.seats[idx].type.icon : .clear,
				status: seatText(idx, session),
				menu: { menu in
					guard isHost, idx > 0, session.seats[idx].alive else { return }
					session.toggle(seat: idx)
					menu = rebuilt(cursor: 4 + idx)
				}
			)
		}
		let prestige = (0 ..< 4).map { idx in
			MenuItem<HQAction>.update(
				icon: session.seats[idx].prestige < 0x1400 ? .prestige1 : .prestige2,
				status: seatText(idx, session),
				menu: { menu in
					guard isHost, session.seats[idx].alive else { return }
					session.togglePrestige(seat: idx)
					menu = rebuilt(cursor: 8 + idx)
				}
			)
		}
		let bottom: [MenuItem<HQAction>] = isHost ? [
			.apply(icon: .empty, status: Address.me.string),
			.space, .space,
			MenuItem(
				icon: .start,
				status: .init(text: "Start", action: .init(Address.me.string)),
				update: { [weak scene] stk, _ in
					guard let scene else { return }
					session.start(units: scene.state.sim.units.compactMap { u in u.alive ? u : nil })
					if session.started { stk = [] }
				}
			),
		] : [
			.space, .space, .space,
			.apply(icon: .empty, status: "waiting for host"),
		]

		return MenuState(
			items: countries + types + prestige + bottom,
			leftButtons: [
				.pop(icon: .minus, status: "Leave") { _ in net?.leave() },
				.space,
				.space,
				.space,
			]
		)
	}

	private func seatText(_ idx: Int, _ session: NetSession) -> String {
		guard session.seats[idx].alive else { return "Off" }
		let role = switch session.seats[idx].type {
		case .human: idx == 0 && session.role == .host ? "host" : "human"
		case .ai: "AI"
		case .remote: session.role == .host
			? (session.claimed(idx) ? "joined" : "open")
			: (idx == session.mySeat ? "you" : "remote")
		}
		return "Player \(idx): \(role)"
	}

	@MainActor
	private func askForAddress(_ completion: @escaping @MainActor (Address) -> Void) {
		scene?.showAlert(Alert(
			title: "Join LAN battle",
			message: "Host address as ip:port",
			field: .init(
				placeholder: "0.0.0.0:1234",
				text: UserDefaults.standard.lanHost.string
			),
			actions: [
				.init("Join") { text in
					let address = Address(text) ?? .default
					UserDefaults.standard.lanHost = address
					completion(address)
				},
				.init("Cancel"),
			]
		))
	}
}
