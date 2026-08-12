import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public extension Bitmap {

	/// Premultiplied RGBA, gray on all three channels so the result stays tintable.
	var rgba: [UInt8] {
		var bytes = [UInt8](repeating: 0, count: width * height * 4)
		for i in 0 ..< width * height {
			let value = alpha[i] == 0 ? 0 : gray[i]
			bytes[i * 4 + 0] = value
			bytes[i * 4 + 1] = value
			bytes[i * 4 + 2] = value
			bytes[i * 4 + 3] = alpha[i]
		}
		return bytes
	}

	var cgImage: CGImage? {
		guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
		return CGImage(
			width: width,
			height: height,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
			provider: provider,
			decode: nil,
			shouldInterpolate: false,
			intent: .defaultIntent
		)
	}

	var png: Data? {
		guard let image = cgImage else { return nil }
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			data, UTType.png.identifier as CFString, 1, nil
		) else { return nil }

		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else { return nil }

		return data as Data
	}
}

public extension Renderer {

	func image(_ model: Model) -> CGImage? {
		render(model).cgImage
	}
}
