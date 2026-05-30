struct D20: Hashable {
	var seed: UInt64 = 0
}

extension D20: RandomNumberGenerator {
	// SplitMix64
	mutating func next() -> UInt64 {
		seed &+= 0x9e3779b97f4a7c15
		var z: UInt64 = seed
		z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
		z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
		return z ^ (z &>> 31)
	}

	mutating func callAsFunction() -> Int {
		.random(in: 0..<20, using: &self)
	}

	mutating func callAsFunction(_ `throw`: Throw, _ cnt: Int) -> Int {
		switch `throw` {
		case .min: modifying(.max) { r in for _ in 0 ..< cnt { r = min(r, self()) } }
		case .max: modifying(0) { r in for _ in 0 ..< cnt { r = max(r, self()) } }
		case .sum: modifying(0) { r in for _ in 0 ..< cnt { r += self() } }
		}
	}
}

extension D20 {
	enum Throw { case min, max, sum }
}
