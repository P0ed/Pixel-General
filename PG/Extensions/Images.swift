import SpriteKit

extension NSImage {

	var cg: CGImage? {
		unsafe cgImage(forProposedRect: nil, context: nil, hints: nil)!
	}

	func tinted(_ color: NSColor) -> NSImage {
		cg?.tinted(color.cgColor).map {
			NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height))
		} ?? self
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
		let width = Int(size.width)
		let height = Int(size.height)
		let bytesPerRow = width * 4
		let byteCount = height * bytesPerRow

		let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
		defer { unsafe pixels.deallocate() }
		unsafe pixels.initialize(repeating: 0, count: byteCount)

		let context = unsafe CGContext(
			data: pixels,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		)!
		context.interpolationQuality = .none

		body(context)

		return context.makeImage()!
	}
}
