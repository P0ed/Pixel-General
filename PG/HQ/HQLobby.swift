import SpriteKit
import UIKit
import COR

// LAN lobby flows. The host edits four seats (country / human–AI–open type /
// prestige) and starts the battle; clients join via `ip:port`, watch the seat
// table and wait for the host's `start`. The seat model lives in `NetSession`
// so joins and kicks can re-render the menu live.
extension HQNodes {

	func hostMenu(_ root: MenuState<HQAction>, _ state: borrowing HQState) -> MenuState<HQAction>? {
		let session = NetSession.host(player: state.sim.player)
		net = session
		session.onLobby = { [weak scene] in
			guard let scene, scene.menuState != nil else { return }
			scene.show(modifying(lobby(root)) { m in
				m.cursor = scene.menuState?.cursor ?? 0
			})
		}
		return lobby(root)
	}

	func joinMenu(_ root: MenuState<HQAction>) -> MenuState<HQAction>? {
		Self.askForAddress { address in
			let session = NetSession.join(address)
			net = session
			session.onLobby = { [weak scene] in
				guard let scene, scene.menuState != nil else { return }
				scene.show(modifying(lobby(root)) { m in
					m.cursor = scene.menuState?.cursor ?? 0
				})
			}
			session.onEnd = { [weak scene] in
				guard let scene, scene.menuState != nil else { return }
				scene.show(root)
			}
			scene?.show(lobby(root))
		}
		return root
	}

	private func lobby(_ root: MenuState<HQAction>) -> MenuState<HQAction> {
		guard let session = net else { return root }

		let isHost = session.role == .host
		var countriesLeft: [Country] {
			Country.playable.filter { c in
				!(0 ..< 4).contains { i in
					session.seats[i].alive && session.seats[i].country == c
				}
			}
		}
		func rebuilt(cursor: Int) -> MenuState<HQAction> {
			modifying(lobby(root)) { m in m.cursor = cursor }
		}

		let countries = (0 ..< 4).map { idx in
			MenuItem<HQAction>(
				icon: session.seats[idx].alive ? session.seats[idx].country.flag : .neutral,
				status: .init(text: seatText(idx, session)),
				update: { menu in
					guard isHost, idx > 0 else { return menu }
					return MenuState<HQAction>(
						items: countriesLeft.map { c in
							MenuItem<HQAction>(
								icon: c.flag,
								status: .init(text: "\(c)"),
								update: { _ in
									session.set(seat: idx, country: c)
									return rebuilt(cursor: idx)
								}
							)
						} + [
							.init(icon: .neutral, status: .init(text: "Off"), update: { _ in
								session.close(seat: idx)
								return rebuilt(cursor: idx)
							})
						],
						close: { _ in rebuilt(cursor: idx) }
					)
				}
			)
		}
		let types = (0 ..< 4).map { idx in
			MenuItem<HQAction>(
				icon: session.seats[idx].alive ? session.seats[idx].type.icon : .clear,
				status: .init(text: seatText(idx, session)),
				update: { menu in
					guard isHost, idx > 0, session.seats[idx].alive else { return menu }
					session.toggle(seat: idx)
					return rebuilt(cursor: 4 + idx)
				}
			)
		}
		let prestige = (0 ..< 4).map { idx in
			MenuItem<HQAction>(
				icon: session.seats[idx].prestige < 0x1400 ? .prestige1 : .prestige2,
				status: .init(text: seatText(idx, session)),
				update: { menu in
					guard isHost, session.seats[idx].alive else { return menu }
					session.togglePrestige(seat: idx)
					return rebuilt(cursor: 8 + idx)
				}
			)
		}
		let sizes: [UIImage] = [.sizeS, .sizeM, .sizeL]
		let bottom: [MenuItem<HQAction>] = isHost ? [
			.init(icon: .empty, status: .init(text: Address.me.string), update: id),
			.space,
			.init(
				icon: sizes[(session.size - 16) / 8],
				status: .init(text: "Size: \(session.size)"),
				update: { menu in
					session.size = 16 + (session.size - 8) % 24
					return rebuilt(cursor: 14)
				}
			),
			.init(icon: .start, status: .init(text: "Start", action: .init(Address.me.string)), update: { menu in
				guard let scene else { return nil }
				session.start(units: scene.state.sim.units.compactMap { u in u.alive ? u : nil })
				return session.started ? nil : menu
			}),
		] : [
			.space, .space, .space,
			.init(icon: .empty, status: .init(text: "waiting for host"), update: id),
		]

		return MenuState(
			items: countries + types + prestige + bottom,
			close: { _ in
				net?.leave()
				return root
			}
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
	private static func askForAddress(_ completion: @escaping @MainActor (Address) -> Void) {
		controller.alert(
			title: "Join LAN battle",
			message: "Host address as ip:port",
			fields: [
				{ field in field.text = UserDefaults.standard.lanHost.string }
			],
			actions: [
				.cancel(),
				.action(title: "Join") { alert in
					let address = Address(alert.textFields?.first?.text ?? "") ?? .default
					UserDefaults.standard.lanHost = address
					completion(address)
				},
			]
		)
	}
}
