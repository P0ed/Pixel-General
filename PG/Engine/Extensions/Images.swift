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
		let width = width
		let height = height
		let rect = CGRect(x: 0, y: 0, width: width, height: height)

		guard let ctx = unsafe CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		ctx.interpolationQuality = .none

		ctx.setBlendMode(.normal)
		ctx.draw(self, in: rect)

		ctx.setBlendMode(.multiply)
		ctx.setFillColor(color)
		ctx.fill(rect)

		ctx.setBlendMode(.destinationIn)
		ctx.draw(self, in: rect)

		return ctx.makeImage()
	}
}
