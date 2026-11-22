import GFX
import SpriteKit

/// Procedural art: tile slabs, settlements and ground vehicles are rendered from
/// boxes and prisms by the GFX package instead of shipping a PNG for each.
@MainActor
extension CGImage {

	private static let slab: (surface: CGImage, frame: CGImage) = {
		return (
			surface: Renderer.tile.fill(Tiles.footprint).cgImage!,
			frame: Renderer.tile.edges(Tiles.base(elevation: 0)).cgImage!
		)
	}()

	/// The tinted part of a base tile: top face and walls, no outline.
	static var surface: CGImage {
		slab.surface
	}

	/// The neutral grid lines drawn over the tinted surface.
	static var frame: CGImage {
		slab.frame
	}

	private static var decorations: [Decoration: CGImage] = [:]

	/// Everything a tile carries on top of its surface, all of it modelled in GFX.
	enum Decoration: Hashable {
		case city(Tiles.Variant, framed: Bool = true), fort(Tiles.Variant)
		case airfield
		case road([GFX.Direction], framed: Bool = true)
		case bridge(GFX.Axis)

		var withOpenRoads: Self? {
			switch self {
			case .city(let variant, _): .city(variant, framed: false)
			case .road(let directions, _): .road(directions, framed: false)
			default: nil
			}
		}

		var image: CGImage? {
			switch self {
			case .city(let variant, let framed): Renderer.building.image(Settlements.city(variant: variant, framed: framed))
			case .fort(let variant): Renderer.decal.image(Settlements.fort(variant: variant))?
				.tinted(SKColor.hex(0x5A564F).cgColor, blendMode: .screen)
			case .airfield: Renderer.building.image(Settlements.airfield)
			case .road(let directions, let framed): Renderer.decal.image(Roads.road(directions, framed: framed))
			case .bridge(let axis): Renderer.decal.image(Roads.bridge(along: axis))
			}
		}
	}

	static func decoration(_ decoration: Decoration) -> CGImage {
		if let image = decorations[decoration] { return image }
		let image = decoration.image!
		decorations[decoration] = image
		return image
	}
}

@MainActor
extension CGPoint {

	/// Drops a GFX sprite's footprint centre onto the tile origin instead of its canvas centre.
	static var vehicle: CGPoint {
		let anchor = Canvas.unit.anchor
		return CGPoint(x: CGFloat(anchor.x), y: CGFloat(anchor.y))
	}
}

@MainActor
extension SKTexture {

	static let cursor: SKTexture = {
		let image = Renderer.cursor.image(Tiles.cursor)!.tinted(SKColor.hex(0xF7EF73).cgColor)!
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return texture
	}()

	private struct VehicleKey: Hashable {
		let shape: Units.Shape
		let mirrored: Bool
	}
	private static var vehicles: [VehicleKey: SKTexture] = [:]

	/// Mirrored sprites are re-rendered rather than flipped, so the light stays top-left.
	static func vehicle(_ shape: Units.Shape, mirrored: Bool) -> SKTexture {
		let key = VehicleKey(shape: shape, mirrored: mirrored)
		if let texture = vehicles[key] { return texture }

		let model = mirrored ? shape.model.mirrored() : shape.model
		let texture = SKTexture(cgImage: Renderer.unit.image(model)!)
		texture.filteringMode = .nearest
		vehicles[key] = texture
		return texture
	}
}
