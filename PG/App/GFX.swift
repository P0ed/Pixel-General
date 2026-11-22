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
		case city(Tiles.Variant), fort(Tiles.Variant)
		case airfield
		case road([GFX.Direction])
		case bridge(GFX.Axis)

		var image: CGImage? {
			switch self {
			case .city(let variant): Renderer.building.image(Settlements.city(variant: variant))
			case .fort(let variant): Renderer.decal.image(Settlements.fort(variant: variant))?
				.tinted(SKColor.hex(0x5A564F).cgColor, blendMode: .screen)
			case .airfield: Renderer.building.image(Settlements.airfield)
			case .road(let directions): Renderer.decal.image(Roads.road(directions))
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

	private struct GridHighlightKey: Hashable {
		let topLeft: Bool
		let topRight: Bool
		let selected: Bool
	}

	private static var gridHighlights: [GridHighlightKey: SKTexture] = [:]

	static func gridHighlight(topLeft: Bool, topRight: Bool, selected: Bool) -> SKTexture {
		let key = GridHighlightKey(topLeft: topLeft, topRight: topRight, selected: selected)
		if let texture = gridHighlights[key] { return texture }
		let color: SKColor = selected ? .selectedCursor : .hex(0xF7EF73)
		let outline = Tiles.gridHighlight(topLeft: topLeft, topRight: topRight)
		let image = outline.cgImage!.tinted(color.cgColor)!
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		gridHighlights[key] = texture
		return texture
	}

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
