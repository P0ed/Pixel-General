public struct UnitSet: BitwiseCopyable {
	private var mask: [3 of UInt64] = .init(repeating: 0)

	public init() {}

	public subscript(_ uid: UID) -> Bool {
		get {
			let word = uid.index / UInt64.bitWidth
			guard mask.indices.contains(word) else { return false }
			let bit = UInt64(1) << (uid.index % UInt64.bitWidth)
			return mask[word] & bit != 0
		}
		set {
			let word = uid.index / UInt64.bitWidth
			guard mask.indices.contains(word) else { return }
			let bit = UInt64(1) << (uid.index % UInt64.bitWidth)
			if newValue {
				mask[word] |= bit
			} else {
				mask[word] &= ~bit
			}
		}
	}
}
