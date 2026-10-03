import Testing
@testable import GFX

struct RoadTests {

	@Test(arguments: Axis.allCases)
	func bridgeContinuesThePavementAndMarkingsOfAdjoiningRoads(axis: Axis) {
		let directions: [Direction] = axis == .x ? [.xMinus, .xPlus] : [.yMinus, .yPlus]
		let road = Renderer.decal.render(Roads.road(directions))
		let bridge = Renderer.decal.render(Roads.bridge(along: axis))
		let expected = joined([road, road, road], along: axis)
		let actual = joined([road, bridge, road], along: axis)

		for i in expected.alpha.indices where expected.alpha[i] > 0 {
			#expect(actual.alpha[i] == 255, "the road–bridge joins must not expose holes")
			if expected.gray[i] == Roads.Tone.bed || expected.gray[i] == Roads.Tone.mark {
				#expect(actual.gray[i] == expected.gray[i], "asphalt and center stripes continue across the span")
			}
		}
	}

	/// Three neighbouring isometric tiles, composited in map drawing order.
	private func joined(_ tiles: [Bitmap], along axis: Axis) -> Bitmap {
		var result = Bitmap(width: 128, height: 72)
		for (index, tile) in tiles.enumerated() {
			let originX = (axis == .x ? index : 2 - index) * 32
			let originY = index * 16
			for y in 0 ..< tile.height {
				for x in 0 ..< tile.width where tile[x, y].alpha > 0 {
					result[originX + x, originY + y] = tile[x, y]
				}
			}
		}
		return result
	}
}
