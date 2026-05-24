import SpriteKit
import GameplayKit

@MainActor
extension SKTileGroup {

	private static func make(_ image: NSImage) -> SKTileGroup {
		let texture = SKTexture(image: image)
		texture.filteringMode = .nearest

		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: image.size
			)
		)
	}

	static func make(
		color: SKColor,
		elevation: Int,
		fog: Bool,
		decoration: NSImage? = nil
	) -> SKTileGroup {
		let frame = NSImage.frame(elevation)
		let surface = NSImage.surface(elevation)
		let image = composite(
			size: frame.size,
			frame: frame,
			surface: surface,
			tint: color,
			decoration: decoration,
			fog: fog
		)
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: frame.size
			)
		)
	}

	static let white = make(.white)
	static let gray = make(.gray)
	static let blue = make(.blue)
	static let yellow = make(.yellow)
	static let green = make(.green)
	static let red = make(.red)
}

@MainActor
extension Terrain {

	private struct CacheKey: Hashable {
		let terrain: Terrain
		let lit: Bool
	}

	private static var cache: [CacheKey: SKTileGroup] = [:]

	func tileGroup(lit: Bool) -> SKTileGroup? {
		guard self != .none else { return nil }
		let key = CacheKey(terrain: self, lit: lit)
		if let group = Self.cache[key] { return group }
		let group = SKTileGroup.make(
			color: surfaceColor,
			elevation: elevationLevel,
			fog: !lit,
			decoration: decoration
		)
		Self.cache[key] = group
		return group
	}

	var surfaceColor: SKColor {
		switch self {
		case .forest, .forestHill: .forestSurface
		case .water, .river00, .river01, .river10, .river11: .waterSurface
		default: .fieldSurface
		}
	}

	var decoration: NSImage? {
		switch self {
		case .none, .field, .forest, .hill, .forestHill, .mountain: nil
		case .city: .city
		case .airfield: .airfield
		case .water: .water
		case .river00: .river00
		case .river01: .river01
		case .river10: .river10
		case .river11: .river11
		case .bridge01: .bridge01
		case .bridge10: .bridge10
		case .roadNW: .roadNw
		case .roadNE: .roadNe
		case .roadWE: .roadWe
		case .roadSN: .roadSn
		case .roadSW: .roadSw
		case .roadSE: .roadSe
		case .roadNWE: .roadNwe
		case .roadSWE: .roadSwe
		case .roadSEN: .roadSen
		case .roadSWN: .roadSwn
		case .roadNWSE: .roadNwse
		}
	}
}

@MainActor
extension SKTileSet {

	private static let tiles: [Terrain] = [
		.city, .airfield, .field, .forest, .hill, .forestHill, .mountain,
		.water, .river00, .river01, .river10, .river11, .bridge01, .bridge10,
		.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE,
		.roadNWE, .roadSWE, .roadSEN, .roadSWN, .roadNWSE,
	]

	static let terrain = SKTileSet(
		tileGroups: tiles.flatMap { t in
			[t.tileGroup(lit: true), t.tileGroup(lit: false)]
		}.compactMap { $0 },
		tileSetType: .isometric
	)

	static let colors = SKTileSet(
		tileGroups: [.gray, .white, .blue, .yellow, .green, .red],
		tileSetType: .isometric
	)
}

extension SKTileMapNode {

	convenience init(tiles: SKTileSet, size: Int) {
		self.init(
			tileSet: tiles,
			columns: size,
			rows: size,
			tileSize: .tile
		)
	}

	func setTileGroup(_ tileGroup: SKTileGroup?, at xy: XY) {
		setTileGroup(tileGroup, forColumn: xy.x, row: xy.y)
	}
}

extension NSImage {

	static func frame(_ elevation: Int) -> NSImage {
		switch elevation {
		case 0: .frame0
		case 1: .frame1
		default: .frame2
		}
	}

	static func surface(_ elevation: Int) -> NSImage {
		switch elevation {
		case 0: .surface0
		case 1: .surface1
		default: .surface2
		}
	}
}

@MainActor
private func composite(
	size: NSSize,
	frame: NSImage,
	surface: NSImage,
	tint: SKColor,
	decoration: NSImage?,
	fog: Bool
) -> CGImage {
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
	let rect = CGRect(origin: .zero, size: size)

	if let cg = unsafe frame.cgImage(forProposedRect: nil, context: nil, hints: nil) {
		context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
	}
	if let cg = tintedSurface(surface, tint: tint) {
		context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
	}
	if let decoration, let cg = unsafe decoration.cgImage(forProposedRect: nil, context: nil, hints: nil) {
		context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
	}

	if fog {
		for i in stride(from: 0, to: byteCount, by: 4) {
			unsafe pixels[i]     >>= 1
			unsafe pixels[i + 1] >>= 1
			unsafe pixels[i + 2] >>= 1
		}
	}

	return context.makeImage()!
}

@MainActor
private func tintedSurface(_ surface: NSImage, tint: SKColor) -> CGImage? {
	guard let src = unsafe surface.cgImage(forProposedRect: nil, context: nil, hints: nil)
	else { return nil }

	let width = src.width
	let height = src.height
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
	context.draw(src, in: CGRect(x: 0, y: 0, width: width, height: height))

	var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
	unsafe tint.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
	let tr = UInt16((r * 255).rounded())
	let tg = UInt16((g * 255).rounded())
	let tb = UInt16((b * 255).rounded())

	for i in stride(from: 0, to: byteCount, by: 4) {
		unsafe pixels[i]     = UInt8((UInt16(pixels[i])     * tr) / 255)
		unsafe pixels[i + 1] = UInt8((UInt16(pixels[i + 1]) * tg) / 255)
		unsafe pixels[i + 2] = UInt8((UInt16(pixels[i + 2]) * tb) / 255)
	}

	return context.makeImage()
}
