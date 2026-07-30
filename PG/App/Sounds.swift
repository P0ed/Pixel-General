import AVFAudio

enum Sound: String, CaseIterable {
	case boomS = "boom-s"
	case boomM = "boom-m"
	case boomL = "boom-l"
	case mov
	case ruggedDefence = "getcrew"

	static let click = Sound.boomS
}

@MainActor
final class Sounds {

	private static let voices = 2

	private var pool: [Sound: [AVAudioPlayer]] = [:]

	init() {
		for sound in Sound.allCases {
			guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
				let data = try? Data(contentsOf: url)
			else { continue }
			pool[sound] = (0 ..< Self.voices).compactMap { _ in
				let player = try? AVAudioPlayer(data: data)
				player?.prepareToPlay()
				return player
			}
		}
	}

	func play(_ sound: Sound) {
		let volume = settings.outputVolume
		guard volume > 0.0, let voices = pool[sound],
			let player = voices.first(where: { p in !p.isPlaying }) ?? voices.first
		else { return }
		player.volume = volume
		player.currentTime = 0.0
		player.play()
	}
}
