/// Grayscale + alpha pixels, row-major from the top-left. Tinting happens downstream.
public struct Bitmap: Sendable {
	public let width: Int
	public let height: Int
	public var gray: [UInt8]
	public var alpha: [UInt8]

	public init(width: Int, height: Int) {
		self.width = width
		self.height = height
		gray = [UInt8](repeating: 0, count: width * height)
		alpha = [UInt8](repeating: 0, count: width * height)
	}
}

public extension Bitmap {

	init(canvas: Canvas) {
		self.init(width: canvas.width, height: canvas.height)
	}

	func index(x: Int, y: Int) -> Int {
		y * width + x
	}

	func contains(x: Int, y: Int) -> Bool {
		x >= 0 && y >= 0 && x < width && y < height
	}

	subscript(x: Int, y: Int) -> (gray: UInt8, alpha: UInt8) {
		get {
			let i = index(x: x, y: y)
			return (gray[i], alpha[i])
		}
		set {
			let i = index(x: x, y: y)
			gray[i] = newValue.gray
			alpha[i] = newValue.alpha
		}
	}

	var isEmpty: Bool {
		!alpha.contains { $0 > 0 }
	}

	/// Bounds of the drawn pixels, or `nil` when nothing was drawn.
	var occupied: (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
		var minX = width, maxX = -1, minY = height, maxY = -1
		for y in 0 ..< height {
			for x in 0 ..< width where alpha[index(x: x, y: y)] > 0 {
				minX = min(minX, x)
				maxX = max(maxX, x)
				minY = min(minY, y)
				maxY = max(maxY, y)
			}
		}
		return maxX < 0 ? nil : (minX ... maxX, minY ... maxY)
	}
}
