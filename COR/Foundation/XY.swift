public struct XY: Hashable, Codable, BitwiseCopyable {
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
		clamped(0 ... size - 1)
	}

	func clamped(_ range: ClosedRange<Int>) -> XY {
		XY(
			max(range.lowerBound, min(range.upperBound, x)),
			max(range.lowerBound, min(range.upperBound, y))
		)
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

	func line(to xy: XY) -> [XY] {
		let dx = xy.x - x
		let dy = xy.y - y
		let steps = max(abs(dx), abs(dy))
		guard steps > 0 else { return [self] }
		return (0 ... steps).map { i in
			XY((x * steps + dx * i) / steps, (y * steps + dy * i) / steps)
		}
	}
}
