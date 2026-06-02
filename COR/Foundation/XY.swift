import CoreGraphics

public struct XY: Hashable, Codable {
	private var _x: Int8
	private var _y: Int8

	public var x: Int {
		get { Int(_x) }
		set { _x = Int8(newValue) }
	}
	public var y: Int {
		get { Int(_y) }
		set { _y = Int8(newValue) }
	}

	public init(_ x: Int, _ y: Int) {
		_x = Int8(x)
		_y = Int8(y)
	}
}

public extension XY {

	static var zero: XY {
		XY(0, 0)
	}

	static var one: XY {
		XY(1, 1)
	}

	private var doubleRadius: Int {
		2 * max(abs(x), abs(y)) + min(abs(x), abs(y))
	}

	var manhattanComparator: (XY, XY) -> Bool {
		{ a, b in (a - self).manhattan < (b - self).manhattan }
	}

	var manhattan: Int {
		abs(x) + abs(y)
	}

	func manhattanDistance(to xy: XY) -> Int {
		(self - xy).manhattan
	}

	func stepDistance(to xy: XY) -> Int {
		(self - xy).doubleRadius
	}

	func clamped(_ size: Int) -> XY {
		XY(max(0, min(size - 1, x)), max(0, min(size - 1, y)))
	}

	func neighbor(_ direction: Direction) -> XY {
		switch direction {
		case .right: XY(1, 0) + self
		case .up: XY(0, 1) + self
		case .left: XY(-1, 0) + self
		case .down: XY(0, -1) + self
		}
	}

	var mirror: [4 of XY] {
		[XY(x, y), XY(y, -x), XY(-x, -y), XY(-y, x)]
	}

	static func + (lhs: XY, rhs: XY) -> XY {
		XY(lhs.x + rhs.x, lhs.y + rhs.y)
	}

	static func - (lhs: XY, rhs: XY) -> XY {
		XY(lhs.x - rhs.x, lhs.y - rhs.y)
	}

	static func / (lhs: XY, rhs: XY) -> XY {
		XY(lhs.x / rhs.x, lhs.y / rhs.y)
	}

	var pt: CGPoint {
		CGPoint(x: Double(x + y) * 1.0, y: Double(y - x) * 0.5)
	}

	func line(to xy: XY) -> [XY] {
		.make { xs in
			let dx = xy.x - x
			let dy = xy.y - y
			let n = max(abs(dx), abs(dy))
			xs.reserveCapacity(n + 1)
			let divN = n == 0 ? 0.0 : 1.0 / Double(n)
			let xStep = Double(dx) * divN
			let yStep = Double(dy) * divN
			var (x, y) = (Double(x), Double(y))
			for _ in 0...n {
				xs.append(XY(Int(x), Int(y)))
				x += xStep
				y += yStep
			}
		}
	}
}

public extension CGPoint {

	var length: Double { sqrt(x * x + y * y) }

	static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}

	static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
		CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}

	static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
		CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
	}
}
