import SpriteKit
import COR

extension SKLabelNode {

	enum Size: UInt8 {
		case s = 14
		case m = 16
		case l = 22
	}

	convenience init(size: Size, color: SKColor = .white) {
		self.init()
		fontName = "Menlo"
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
	static var tile3D: CGSize { .init(width: 64.0, height: 40.0) }

	/// Initial size only — `PixelView` resizes the scene to track its bounds.
	static var scene: CGSize { .init(width: 640.0, height: 400.0) }
}
