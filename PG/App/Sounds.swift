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

	private struct Bank: ~Copyable {
		let buffer: AVAudioPCMBuffer
		let player = AVAudioPlayerNode()
		let varispeed = AVAudioUnitVarispeed()

		func play(rate: Float) {
			varispeed.rate = rate
			player.stop()
			player.scheduleBuffer(buffer, completionHandler: nil)
			player.play()
		}
	}

	private let engine: AVAudioEngine
	private let banks: InlineArray<6, Bank?>

	init() {
		try? AVAudioSession.sharedInstance().setCategory(.ambient)

		let engine = AVAudioEngine()
		banks = InlineArray { index in
			guard let url = Bundle.main.url(forResource: Sound.allCases[index].file, withExtension: "wav"),
				let file = try? AVAudioFile(forReading: url),
				let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
				(try? file.read(into: buffer)) != nil
			else { return nil }

			let bank = Bank(buffer: buffer)
			engine.attach(bank.player)
			engine.attach(bank.varispeed)
			engine.connect(bank.player, to: bank.varispeed, format: buffer.format)
			engine.connect(bank.varispeed, to: engine.mainMixerNode, format: buffer.format)
			return bank
		}
		self.engine = engine

		engine.prepare()
	}

	func preheat() {
		guard settings.outputVolume > 0.0, !engine.isRunning else { return }
		try? AVAudioSession.sharedInstance().setActive(true)
		try? engine.start()
	}

	func play(_ sound: Sound) {
		guard settings.soundLevel != 0, banks[sound.rawValue] != nil else { return }

		if !engine.isRunning {
			try? AVAudioSession.sharedInstance().setActive(true)
			guard (try? engine.start()) != nil else { return }
		}
		engine.mainMixerNode.outputVolume = settings.outputVolume

		banks[sound.rawValue]?.play(rate: sound.variesPitch ? .random(in: 0.94 ... 1.06) : 1.0)
	}
}
