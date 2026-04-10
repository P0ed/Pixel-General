import SpriteKit

extension SKColor {
	static var baseSelection: SKColor { .init(white: 0.33, alpha: 0.47) }
	static var baseCursor: SKColor { .init(white: 0.22, alpha: 0.33) }

	static var lineSelection: SKColor { .init(white: 0.22, alpha: 0.47) }
	static var lineCursor: SKColor { .init(white: 0.22, alpha: 0.82) }

	static var selectedCursor: SKColor { .init(red: 0.82, green: 0.33, blue: 0.2, alpha: 1) }

	static var textDefault: SKColor { .init(white: 0.01, alpha: 1.0) }
}

extension SKLabelNode {

	enum Size: UInt8 {
		case s = 14
		case m = 16
		case l = 22
	}

	convenience init(size: Size, color: SKColor = .white) {
		self.init()
		fontName = "Monaco"
		fontSize = CGFloat(size.rawValue)
		fontColor = color
		setScale(0.5)
		numberOfLines = 0
	}
}

extension SKAudioNode {

	func play() {
		run(.stop())
		run(.play())
	}
}

extension CGPath {

	static func make(_ transform: (CGMutablePath) -> Void) -> CGPath {
		let path = CGMutablePath()
		transform(path)
		return path
	}
}

extension XY {
	var point: CGPoint { pt * CGSize.tile.height }
}

extension CGSize {
	static var tile: CGSize { .init(width: 64.0, height: 32.0) }
	static var scene: CGSize { .init(width: 640.0, height: 400.0) }
	static var window: CGSize { .init(width: 1280.0, height: 800.0) }
}
