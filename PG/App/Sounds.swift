import AVFAudio

enum Sound: Int, CaseIterable {
	case click
	case boomS
	case boomM
	case boomL
	case mov
	case ruggedDefence

	var file: String {
		switch self {
		case .click, .boomS: "boom-s"
		case .boomM: "boom-m"
		case .boomL: "boom-l"
		case .mov: "mov"
		case .ruggedDefence: "getcrew"
		}
	}

	var variesPitch: Bool {
		switch self {
		case .boomS, .boomM, .boomL: true
		default: false
		}
	}
}

@MainActor
final class Sounds {

	private struct Voice: ~Copyable {
		let player = AVAudioPlayerNode()
		let varispeed = AVAudioUnitVarispeed()
	}

	private struct Bank: ~Copyable {
		let buffer: AVAudioPCMBuffer
		let voices: InlineArray<2, Voice>
		var next: Int = 0
	}

	private let engine: AVAudioEngine
	private var banks: InlineArray<5, Bank?>

	init() {
		try? AVAudioSession.sharedInstance().setCategory(.ambient)

		let engine = AVAudioEngine()
		banks = InlineArray { index in
			guard let url = Bundle.main.url(forResource: Sound.allCases[index].file, withExtension: "wav"),
				let file = try? AVAudioFile(forReading: url),
				let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
				(try? file.read(into: buffer)) != nil
			else { return nil }

			return Bank(
				buffer: buffer,
				voices: InlineArray { _ in
					let voice = Voice()
					engine.attach(voice.player)
					engine.attach(voice.varispeed)
					engine.connect(voice.player, to: voice.varispeed, format: buffer.format)
					engine.connect(voice.varispeed, to: engine.mainMixerNode, format: buffer.format)
					return voice
				}
			)
		}
		self.engine = engine

		engine.isAutoShutdownEnabled = true
		engine.prepare()
	}

	func play(_ sound: Sound) {
		let volume = settings.outputVolume
		guard volume > 0.0, banks[sound.rawValue] != nil else { return }

		if !engine.isRunning {
			try? AVAudioSession.sharedInstance().setActive(true)
			guard (try? engine.start()) != nil else { return }
		}
		engine.mainMixerNode.outputVolume = volume

		let next = banks[sound.rawValue]?.next ?? 0
		let voiceCount = banks[sound.rawValue]?.voices.count ?? 1
		banks[sound.rawValue]?.next = (next + 1) % voiceCount

		if let buffer = banks[sound.rawValue]?.buffer {
			banks[sound.rawValue]?.voices[next].varispeed.rate = sound.variesPitch ? .random(in: 0.94 ... 1.06) : 1.0
			banks[sound.rawValue]?.voices[next].player.stop()
			banks[sound.rawValue]?.voices[next].player.scheduleBuffer(buffer, completionHandler: nil)
			banks[sound.rawValue]?.voices[next].player.play()
		}
	}
}
