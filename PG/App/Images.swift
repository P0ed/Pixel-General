import UIKit

extension UIImage {

	var cg: CGImage? {
		cgImage
	}

	func tinted(_ color: UIColor) -> UIImage {
		cg?.tinted(color.cgColor).map { UIImage(cgImage: $0) } ?? self
	}

	static func toggle4(_ value: UInt8) -> UIImage {
		switch value {
		case 0: .value0
		case 1: .value1
		case 2: .value2
		default: .value3
		}
	}
}

extension CGImage {

	func tinted(_ color: CGColor) -> CGImage? {
		.draw(size: CGSize(width: width, height: height)) { ctx in
			let rect = CGRect(x: 0, y: 0, width: width, height: height)

			ctx.setBlendMode(.normal)
			ctx.draw(self, in: rect)

			ctx.setBlendMode(.multiply)
			ctx.setFillColor(color)
			ctx.fill(rect)

			ctx.setBlendMode(.destinationIn)
			ctx.draw(self, in: rect)
		}
	}
}

extension CGImage {

	static func draw(size: CGSize, body: (CGContext) -> Void) -> CGImage {
		let buf = ImageBuffer(size: size)
		return buf.draw(body)
	}
}

@safe struct ImageBuffer: ~Copyable {
	private let context: CGContext
	private let pixels: UnsafeMutablePointer<UInt8>

	init(size: CGSize) {
		let width = Int(size.width)
		let height = Int(size.height)

		unsafe pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)

		context = unsafe CGContext(
			data: pixels,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		)!
		context.interpolationQuality = .none
	}

	deinit { unsafe pixels.deallocate() }

	func draw(_ body: (CGContext) -> Void) -> CGImage {
		unsafe pixels.initialize(repeating: 0, count: context.width * context.height * 4)
		body(context)
		return context.makeImage()!
	}
}

@MainActor
extension ImageBuffer {
	static let tile = ImageBuffer(size: .tile3D)
}
