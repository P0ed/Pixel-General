import GFX
import SpriteKit

/// Procedural art: tile slabs, settlements and ground vehicles are rendered from
/// boxes and prisms by the GFX package instead of shipping a PNG for each.
@MainActor
extension CGImage {

	private static var slabs: [Int: (surface: CGImage, frame: CGImage)] = [:]

	/// The tinted part of a base tile: top face and walls, no outline.
	static func surface(_ elevation: Int) -> CGImage {
		slab(elevation).surface
	}

	/// The neutral grid lines drawn over the tinted surface.
	static func frame(_ elevation: Int) -> CGImage {
		slab(elevation).frame
	}

	private static func slab(_ elevation: Int) -> (surface: CGImage, frame: CGImage) {
		if let slab = slabs[elevation] { return slab }
		let model = Tiles.base(elevation: elevation)
		let slab = (
			surface: Renderer.tile.fill(model).cgImage!,
			frame: Renderer.tile.edges(model).cgImage!
		)
		slabs[elevation] = slab
		return slab
	}

	private static var decorations: [Decoration: CGImage] = [:]

	/// Everything a tile carries on top of its surface, all of it modelled in GFX.
	enum Decoration: Hashable {
		case city, fort, airfield
		case village(GFX.Direction)
		case road([GFX.Direction])
		case bridge(GFX.Axis)

		var model: Model {
			switch self {
			case .city: Settlements.city
			case .fort: Settlements.fort
			case .airfield: Settlements.airfield
			case .village(let facing): Settlements.village(facing: facing)
			case .road(let directions): Roads.road(directions)
			case .bridge(let axis): Roads.bridge(along: axis)
			}
		}

		/// Roads are paint on the ground, so they take a rim barely darker than the paint.
		var renderer: Renderer {
			switch self {
			case .road: .decal
			default: .building
			}
		}
	}

	static func decoration(_ decoration: Decoration) -> CGImage {
		if let image = decorations[decoration] { return image }
		let image = decoration.renderer.image(decoration.model)!
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
