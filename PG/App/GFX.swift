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

	private static var buildings: [Settlement: CGImage] = [:]

	enum Settlement: Hashable {
		case city, fort
		case village(GFX.Direction)

		var model: Model {
			switch self {
			case .city: Settlements.city
			case .fort: Settlements.fort
			case .village(let facing): Settlements.village(facing: facing)
			}
		}
	}

	static func settlement(_ settlement: Settlement) -> CGImage {
		if let image = buildings[settlement] { return image }
		let image = Renderer.building.image(settlement.model)!
		buildings[settlement] = image
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
