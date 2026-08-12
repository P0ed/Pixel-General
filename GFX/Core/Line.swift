/// A stroked segment in world space: flat pixel art for the parts no box can carry —
/// rotor discs, aerials, rigging, road markings. Unlit, so `tone` is the gray it draws.
public struct Line: Sendable {
	public var from: V3
	public var to: V3
	public var tone: UInt8
	public var width: Int
	public var dash: Float?

	public init(from: V3, to: V3, tone: UInt8 = 0, width: Int = 1, dash: Float? = nil) {
		self.from = from
		self.to = to
		self.tone = tone
		self.width = width
		self.dash = dash
	}
}

public extension Line {

	/// Both blades of a rotor: `radius` along each horizontal axis, so they cross on screen.
	static func rotor(at centre: V3, radius: Float, tone: UInt8, width: Int = 1) -> [Line] {
		[
			Line(from: centre - V3(radius, 0, 0), to: centre + V3(radius, 0, 0), tone: tone, width: width),
			Line(from: centre - V3(0, radius, 0), to: centre + V3(0, radius, 0), tone: tone, width: width),
		]
	}

	/// Segment running the full footprint from the centre out towards `direction`.
	static func spoke(_ direction: Direction, z: Float, tone: UInt8, width: Int, dash: Float? = nil) -> Line {
		let half = Volume.footprint / 2
		let centre = V3(half, half, z)
		let reach: V3 = switch direction {
		case .xPlus: V3(half, 0, 0)
		case .xMinus: V3(-half, 0, 0)
		case .yPlus: V3(0, half, 0)
		case .yMinus: V3(0, -half, 0)
		}
		return Line(from: centre, to: centre + reach, tone: tone, width: width, dash: dash)
	}

	func translated(by v: V3) -> Line {
		moved { $0 + v }
	}

	func rotated(_ turn: Turn, about centre: V3) -> Line {
		moved { turn.apply($0 - centre) + centre }
	}

	func mirrored(about centre: V3) -> Line {
		moved { V3($0.y - centre.y + centre.x, $0.x - centre.x + centre.y, $0.z) }
	}

	private func moved(_ transform: (V3) -> V3) -> Line {
		var line = self
		line.from = transform(from)
		line.to = transform(to)
		return line
	}
}

extension Line {

	/// Pixel centres the stroke covers, each with the view-ray depth of the point that put it there.
	func trace(on canvas: Canvas) -> [(x: Int, y: Int, t: Float)] {
		let a = canvas.project(from)
		let b = canvas.project(to)
		let span = max(abs(b.x - a.x), abs(b.y - a.y))
		let steps = max(1, Int((span * 2).rounded(.up)))
		let length = (to - from).length

		let low = -(width - 1) / 2
		var covered: [(x: Int, y: Int, t: Float)] = []

		for step in 0 ... steps {
			let f = Float(step) / Float(steps)
			if let dash, dash > 0, ((f * length) / dash).truncatingRemainder(dividingBy: 2) >= 1 { continue }

			let point = from + (to - from) * f
			let screen = canvas.project(point)
			let px = Int(screen.x.rounded(.down))
			let py = Int(screen.y.rounded(.down))

			for dy in low ..< low + width {
				for dx in low ..< low + width {
					let x = px + dx
					let y = py + dy
					guard x >= 0, y >= 0, x < canvas.width, y < canvas.height else { continue }
					covered.append((x, y, canvas.depth(of: point, x: x, y: y)))
				}
			}
		}

		return covered
	}
}

extension Canvas {

	/// How far along the view ray through pixel `(x, y)` the point sits; larger is nearer.
	func depth(of point: V3, x: Int, y: Int) -> Float {
		let delta = point - origin(x: x, y: y)
		return (delta.x + delta.y + delta.z) / 3
	}
}
