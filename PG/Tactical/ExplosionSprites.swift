import SpriteKit
import UIKit
import COR

/// Procedural 32×32 pixel-art explosion, 8 frames per size level. Size 0 is
/// a small poof, 1 a hit fireball, 2 a kill blast — the same split as the
/// boom-s/m/l sounds.
@MainActor
enum ExplosionSprites {

	private static var cache: [Int: [SKTexture]] = [:]

	static func frames(size: Int) -> [SKTexture] {
		let size = min(max(size, 0), 2)
		if let frames = cache[size] { return frames }
		let frames = (0 ..< 8).map { frame in
			let texture = SKTexture(cgImage: .explosion(frame: frame, size: size))
			texture.filteringMode = .nearest
			return texture
		}
		cache[size] = frames
		return frames
	}
}

extension SKNode {

	/// One-shot explosion sprite that animates and removes itself.
	func showExplosion(_ size: Int, at position: CGPoint, zPosition: CGFloat, scale: Double) {
		let frames = ExplosionSprites.frames(size: size)
		let sprite = SKSpriteNode(texture: frames[0])
		sprite.position = position
		sprite.zPosition = zPosition
		addChild(sprite)
		sprite.run(.sequence([
			.animate(with: frames, timePerFrame: 0.06 * scale),
			.removeFromParent()
		]))
	}
}

private extension CGImage {

	/// One frame: a noise-ragged fireball that flashes hot, expands with an
	/// ease-out envelope, then hollows into a dissipating smoke ring. Hard
	/// pixels only — late frames thin out stochastically instead of fading.
	/// Isometric: the blast is a squashed ellipse hugging the ground plane,
	/// rounding out and rising as the fireball lifts off into smoke.
	static func explosion(frame: Int, size: Int) -> CGImage {
		.draw(size: CGSize(width: 32, height: 32)) { ctx in
			let t = Float(frame) / 7
			let maxR = 5 + 3.5 * Float(size)
			let eased = 1 - (1 - min(t * 2.4, 1)) * (1 - min(t * 2.4, 1))
			let r = maxR * (0.3 + 0.7 * eased)
			let inner = t < 0.55 ? 0 : maxR * (t - 0.55) / 0.45 * 0.9
			let fade = max(0, (t - 0.55) * 1.8)
			let squash = 1.9 - 0.5 * eased
			let cy = 12 + 5 * t * t

			for y in 0 ..< 32 {
				for x in 0 ..< 32 {
					var d20 = D20(seed: UInt64(size) << 24 | UInt64(frame) << 16 | UInt64(y) << 8 | UInt64(x))
					let dx = Float(x) - 15.5
					let dy = (Float(y) - cy) * squash
					let d = (dx * dx + dy * dy).squareRoot()
					guard d < r * (0.82 + 0.36 * d20.uniform()),
						  d >= inner * (0.6 + 0.8 * d20.uniform()),
						  d20.uniform() >= fade
					else { continue }
					ctx.setFillColor(.fire(d / r * 0.9 + max(0, t - 0.3) * 0.85 + d20.uniform() * 0.08))
					ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
				}
			}

			// Sparks flung past the fireball while it is still burning.
			guard (1 ... 3).contains(frame) else { return }
			var d20 = D20(seed: UInt64(size) << 8 | UInt64(frame))
			for _ in 0 ..< (4 + 3 * size) {
				let a = d20.uniform() * 2 * .pi
				let dist = r * (1.1 + 0.45 * d20.uniform())
				let x = Int((15.5 + cos(a) * dist).rounded())
				let y = Int((cy + sin(a) * dist / squash).rounded())
				guard (0 ..< 32).contains(x), (0 ..< 32).contains(y) else { continue }
				ctx.setFillColor(.fire(0.4 + 0.3 * d20.uniform()))
				ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
			}
		}
	}
}

private extension CGColor {

	/// Fire ramp: white core → yellow → orange → red → smoke as `v` grows.
	static func fire(_ v: Float) -> CGColor {
		let rgb: (CGFloat, CGFloat, CGFloat) = switch v {
		case ..<0.3: (1.0, 1.0, 0.94)
		case ..<0.55: (1.0, 0.86, 0.31)
		case ..<0.8: (1.0, 0.55, 0.16)
		case ..<1.05: (0.78, 0.24, 0.12)
		case ..<1.35: (0.33, 0.29, 0.27)
		default: (0.48, 0.45, 0.43)
		}
		return CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
	}
}
