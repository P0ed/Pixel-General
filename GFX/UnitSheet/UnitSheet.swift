import CoreGraphics
import CoreText
import Foundation
import GFX
import ImageIO
import UniformTypeIdentifiers

enum UnitSheet {

	static func png(scale: Int, columns: Int, shapes: [Units.Shape] = Units.Shape.allCases, title: String = "Unit sprites") throws -> Data {
		let rows = (shapes.count + columns - 1) / columns
		let faceWidth = max(128, Canvas.unit.width * scale)
		let cardWidth = faceWidth * 2
		let cardHeight = Canvas.unit.height * scale + 32
		let width = columns * cardWidth
		let height = rows * cardHeight + 64
		guard let context = CGContext(
			data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { throw UnitSheetError.rendering }

		context.setFillColor(CGColor(gray: 0.86, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		context.interpolationQuality = .none
		text(title, at: CGPoint(x: 16, y: height - 30), size: 22, in: context)
		text("\(shapes.count) shapes · both facings · \(scale)×", at: CGPoint(x: 16, y: height - 50), size: 12, in: context)

		for (index, shape) in shapes.enumerated() {
			let column = index % columns
			let row = index / columns
			let x = column * cardWidth
			let y = height - 64 - (row + 1) * cardHeight
			context.setFillColor(CGColor(gray: (column + row).isMultiple(of: 2) ? 0.77 : 0.82, alpha: 1))
			context.fill(CGRect(x: x + 2, y: y + 2, width: cardWidth - 4, height: cardHeight - 4))

			let model = shape.model
			for facing in 0 ..< 2 {
				let faceX = x + facing * faceWidth
				let label = "\(shape.name) \(facing == 0 ? "→" : "←")"
				text(label, at: CGPoint(x: faceX + 12, y: y + cardHeight - 23), size: 14, in: context)
				guard let image = Renderer.unit.image(facing == 0 ? model : model.mirrored()) else {
					throw UnitSheetError.rendering
				}
				context.draw(image, in: CGRect(
					x: faceX + (faceWidth - image.width * scale) / 2, y: y,
					width: image.width * scale, height: image.height * scale
				))
			}
		}

		guard let image = context.makeImage() else { throw UnitSheetError.rendering }
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
			throw UnitSheetError.encoding
		}
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else { throw UnitSheetError.encoding }
		return data as Data
	}

	private static func text(_ string: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
		let attributes: [NSAttributedString.Key: Any] = [
			NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, size, nil),
			NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.2, alpha: 1),
		]
		let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
		context.textPosition = point
		CTLineDraw(line, context)
	}

}
