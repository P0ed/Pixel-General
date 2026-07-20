import Network
import Foundation
import Darwin
import SpriteKit
import COR

/// Coordinator for a LAN battle: a deterministic action relay over the
/// length-prefixed TCP `Connection`. The host generates the battle once and
/// ships the whole encoded `TacticalSim`; afterwards only `TacticalAction`s
/// travel, applied by every peer through the deterministic `reduce`.
///
/// The host is the single authority: clients send their actions as intents
/// and apply them only when the host echoes them back, so peers can never
/// diverge optimistically.
@MainActor
final class NetSession {

	enum Role { case host, client }

	let role: Role

	// Lobby: four seats, edited by the host, mirrored to clients via `lobby`
	// snapshots. `Player.alive == false` means the seat is off; `.remote`
	// means open for (or claimed by) a networked player.
	private(set) var seats: [4 of Player]
	private(set) var mySeat = 0
	var onLobby: () -> Void = ø
	var onEnd: () -> Void = ø

	private var server: Server<Message>?
	private var client: Client<Message>?
	private var owners: [Connection<Message>?] = [nil, nil, nil, nil]
	private var helloed: Set<ObjectIdentifier> = []

	// In-game: actions waiting for the scene to drain them through the
	// `ai` hook. On the host entries carry the sender's player index for
	// re-validation at drain time (-1 = host-issued, always valid).
	private var queue: [(seat: Int, action: TacticalAction)] = []
	private var draining = false
	private var hostless = false
	private(set) var started = false
	private var playerOf: [ObjectIdentifier: Int] = [:]
	private var countries: [Country] = []

	private init(role: Role, seats: [4 of Player]) {
		self.role = role
		self.seats = seats
	}

	private var scene: TacticalScene? {
		view.scene as? TacticalScene
	}

	// MARK: - Lifecycle

	static func host(player: Player) -> NetSession {
		let session = NetSession(role: .host, seats: [
			player,
			Player(country: .isr, type: .ai, prestige: 0x1400),
			Player(country: .usa, type: .ai, prestige: 0x1400),
			Player(country: .irn, type: .ai, prestige: 0x1400),
		])
		session.server = Server { [weak session] con, message in
			session?.handle(con, message)
		}
		session.server?.onDisconnect = { [weak session] con in
			session?.connectionLost(con)
		}
		session.server?.start(port: Address.defaultPort)
		return session
	}

	static func join(_ address: Address) -> NetSession {
		let session = NetSession(role: .client, seats: .init(repeating: Player(alive: false)))
		session.client = Client<Message> { [weak session] message in
			session?.handle(message)
		}
		session.client?.onReady = { [weak session] in
			session?.client?.send(.hello(netVersion))
			session?.client?.send(.joinRequest)
		}
		session.client?.onDisconnect = { [weak session] in
			session?.hostLost()
		}
		session.client?.connect(address)
		return session
	}

	/// Notify the other peers and tear the session down.
	func leave() {
		switch role {
		case .host: server?.broadcast(.leave)
		case .client: client?.send(.leave)
		}
		shutdown()
	}

	func shutdown() {
		server?.stop()
		client?.disconnect()
		server = nil
		client = nil
		if net === self { net = nil }
	}

	// MARK: - Host lobby

	func claimed(_ seat: Int) -> Bool {
		owners[seat] != nil
	}

	func set(seat: Int, country: Country) {
		update(seat: seat) { p in
			p.alive = true
			p.country = country
		}
	}

	/// Turn the seat off, kicking any joined client.
	func close(seat: Int) {
		kick(seat: seat)
		update(seat: seat) { p in p.alive = false }
	}

	/// Cycle a non-host seat: AI → open for a networked player → local
	/// human (hot seat) → AI. Kicks the joined client when its seat leaves
	/// `.remote`.
	func toggle(seat: Int) {
		if seats[seat].type == .remote { kick(seat: seat) }
		update(seat: seat) { p in
			p.type = switch p.type {
			case .ai: .remote
			case .remote: .human
			case .human: .ai
			}
		}
	}

	func togglePrestige(seat: Int) {
		update(seat: seat) { p in
			p.prestige = p.prestige < .rich ? .rich : .poor
		}
	}

	private func update(seat: Int, _ change: (inout Player) -> Void) {
		change(&seats[seat])
		broadcastLobby()
		onLobby()
	}

	private func kick(seat: Int) {
		guard let con = owners[seat] else { return }
		owners[seat] = nil
		helloed.remove(ObjectIdentifier(con))
		con.send(.leave)
		server?.drop(con)
	}

	/// Build the battle from the lobby and ship it to every peer. Open seats
	/// nobody claimed are dropped.
	func start(units: [Unit]) {
		var players: [Player] = []
		for i in 0 ..< 4 {
			guard seats[i].alive else { continue }
			if seats[i].type == .remote {
				guard let con = owners[i] else { continue }
				playerOf[ObjectIdentifier(con)] = players.count
				con.send(.joinAccept(UInt8(players.count)))
			}
			players.append(seats[i])
		}
		guard players.count > 1 else { return }
		countries = players.map { $0.country }

		let sim = TacticalSim(new: Scenario(
			players: players,
			units: units,
			seed: .random(in: 0 ..< 128)
		))
		started = true
		server?.broadcast(.start(encode(sim)))
		core.startScenario(sim)
		core.save()
		view.present(.auto)
	}

	private func broadcastLobby() {
		server?.broadcast(.lobby(encode(seats)))
	}

	private func handle(_ con: Connection<Message>, _ message: Message) {
		switch message {
		case .hello(let version):
			if version == netVersion {
				helloed.insert(ObjectIdentifier(con))
			} else {
				con.send(.leave)
				server?.drop(con)
			}
		case .joinRequest:
			guard !started, helloed.contains(ObjectIdentifier(con)),
				  let seat = (0 ..< 4).first(where: { i in
					  seats[i].alive && seats[i].type == .remote && owners[i] == nil
				  })
			else { return con.send(.leave) }
			owners[seat] = con
			con.send(.joinAccept(UInt8(seat)))
			broadcastLobby()
			onLobby()
		case .action(let data):
			guard started,
				  let action: TacticalAction = decode(data),
				  let seat = playerOf[ObjectIdentifier(con)],
				  let scene, seat == scene.state.sim.playerIndex
			else { return }
			queue.append((seat, action))
			scene.advance()
		case .leave:
			server?.drop(con)
			connectionLost(con)
		default:
			break
		}
	}

	/// A client vanished. In the lobby its seat reopens; mid-battle its seat
	/// is handed to the host AI via a relayed `.takeover`.
	private func connectionLost(_ con: Connection<Message>) {
		let id = ObjectIdentifier(con)
		helloed.remove(id)
		if let seat = owners.firstIndex(where: { $0 === con }) {
			owners[seat] = nil
			if !started {
				broadcastLobby()
				onLobby()
			}
		}
		if started, let player = playerOf.removeValue(forKey: id) {
			queue.append((-1, .takeover(countries[player])))
			scene?.advance()
		}
	}

	// MARK: - Client

	private func handle(_ message: Message) {
		switch message {
		case .joinAccept(let seat):
			mySeat = Int(seat)
			onLobby()
		case .lobby(let data):
			guard let seats: [4 of Player] = decode(data) else { return }
			self.seats = seats
			onLobby()
		case .start(let data), .resync(let data):
			guard var sim: TacticalSim = decode(data) else { return hostLost() }
			localize(&sim)
			started = true
			core.startScenario(sim)
			core.save()
			view.present(.auto)
		case .action(let data):
			guard started, let action: TacticalAction = decode(data) else { return }
			queue.append((0, action))
			scene?.advance()
		case .leave:
			hostLost()
		default:
			break
		}
	}

	/// Make the decoded host state peer-relative: our seat is `.human`,
	/// everything else `.remote`.
	private func localize(_ sim: inout TacticalSim) {
		let mySeat = mySeat
		sim.players.modifyEach { i, p in
			p.type = i == mySeat ? .human : .remote
		}
	}

	/// The host is gone. Mid-battle the game degrades to local play: every
	/// seat this peer doesn't own is handed to the local AI through queued
	/// `.takeover`s, and the session frees itself once they drain.
	private func hostLost() {
		guard started, let scene else {
			shutdown()
			return onEnd()
		}
		hostless = true
		for i in 0 ..< scene.state.sim.players.count where i != mySeat {
			let player = scene.state.sim.players[i]
			if player.alive { queue.append((-1, .takeover(player.country))) }
		}
		scene.advance()
	}

	// MARK: - Relay

	/// Scene hook: inspect a locally produced action before Reduce. Returns
	/// true when the action must not be applied locally.
	func relay(_ sim: borrowing TacticalSim, _ action: TacticalAction) -> Bool {
		defer { draining = false }
		guard started else { return true }
		switch role {
		case .host:
			// Drop local actions for seats the host doesn't drive; everything
			// applied here (own input, AI, drained client intents) is the
			// authoritative stream and is echoed to every client.
			guard draining || sim.player.type != .remote else { return true }
			server?.broadcast(.action(encode(action)))
			return false
		case .client:
			// Confirmed actions drained from the queue apply as-is; our own
			// actions travel to the host and apply on the echo.
			if draining { return false }
			guard sim.player.type == .human else { return true }
			client?.send(.action(encode(action)))
			return true
		}
	}

	/// Scene hook replacing the local AI driver: feeds queued network
	/// actions into the scene, runs the real AI only on the host, and waits
	/// for the wire otherwise.
	func nextAction(
		_ sim: borrowing TacticalSim,
		_ ai: (borrowing TacticalSim) -> TacticalAction?
	) -> TacticalAction? {
		guard started else { return nil }
		switch role {
		case .host:
			while let first = queue.first {
				queue.removeFirst()
				// Client intents were validated on arrival; drop the ones the
				// turn rolled past (e.g. a duplicate `.end`).
				guard first.seat == -1 || first.seat == sim.playerIndex else { continue }
				draining = true
				return first.action
			}
			return sim.player.type == .ai ? ai(sim) : nil
		case .client:
			if !queue.isEmpty {
				draining = true
				return queue.removeFirst().action
			}
			if hostless {
				// All takeovers drained — degrade to plain local play.
				shutdown()
				return ai(sim)
			}
			return nil
		}
	}
}
