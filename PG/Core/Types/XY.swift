import CoreGraphics

struct XY: Hashable, Codable {
	private var _x: Int8
	private var _y: Int8

	var x: Int { Int(_x) }
	var y: Int { Int(_y) }

	init(_ x: Int, _ y: Int) {
		_x = Int8(x)
		_y = Int8(y)
	}
}

extension XY: CustomStringConvertible {
	var description: String { "(\(x), \(y))" }
}

extension XY {

	static var zero: XY {
		XY(0, 0)
	}

	var dr: Int {
		2 * max(abs(x), abs(y)) + min(abs(x), abs(y))
	}

	var manhattan: Int {
		abs(x) + abs(y)
	}

	func distance(to xy: XY) -> Int {
		(self - xy).dr
	}

	private static var d4: [4 of XY] {
		[XY(1, 0), XY(0, 1), XY(-1, 0), XY(0, -1)]
	}

	private static var x4: [4 of XY] {
		[XY(1, 1), XY(-1, 1), XY(-1, -1), XY(1, -1)]
	}

	private static var d8: [8 of XY] {
		[XY(1, 0), XY(1, 1), XY(0, 1), XY(-1, 1), XY(-1, 0), XY(-1, -1), XY(0, -1), XY(1, -1)]
	}

	var n4: [4 of XY] {
		Self.d4.map { xy in xy + self }
	}

	var x4: [4 of XY] {
		Self.x4.map { xy in xy + self }
	}

	var n8: [8 of XY] {
		Self.d8.map { xy in xy + self }
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

	func circle(_ dr: Int) -> [XY] {
		guard dr > 1 else { return [self] }

		var arr = [] as [XY]
		let rng = dr >> 1
		arr.reserveCapacity(rng * (rng - 1) * 4 + 1)
		arr.append(self)
		for x in 0...rng {
			for y in 1...rng {
				let xy = XY(x, y)
				if xy.dr <= dr {
					let mirrored = xy.mirror
					for i in mirrored.indices {
						arr.append(self + mirrored[i])
					}
				}
			}
		}
		return arr
	}

	var pt: CGPoint {
		CGPoint(x: Double(x + y) * 1.0, y: Double(y - x) * 0.5)
	}
}

extension CGPoint {

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
