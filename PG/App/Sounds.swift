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

	private static let voices = 3

	private var pool: [Sound: [AVAudioPlayer]] = [:]
	private var next: [Sound: Int] = [:]

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
		guard volume > 0.0, let voices = pool[sound], !voices.isEmpty else { return }
		let index = (next[sound] ?? 0) % voices.count
		next[sound] = index + 1

		let player = voices[index]
		player.volume = volume
		player.currentTime = 0.0
		player.play()
	}
}
