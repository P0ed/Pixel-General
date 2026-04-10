extension UInt8 {

	@discardableResult
	mutating func increment(by amount: UInt8, cap: UInt8 = .max) -> UInt8 {
		let old = self
		self = UInt8(Swift.min(UInt16(cap), UInt16(self) + UInt16(amount)))
		return self - old
	}

	@discardableResult
	mutating func decrement(by amount: UInt8 = 1) -> UInt8 {
		let old = self
		self -= self < amount ? self : amount
		return old - self
	}
}

extension UInt16 {

	@discardableResult
	mutating func increment(by amount: UInt16, cap: UInt16 = .max) -> UInt16 {
		let old = self
		self = UInt16(Swift.min(UInt32(cap), UInt32(self + amount)))
		return self - old
	}

	@discardableResult
	mutating func decrement(by amount: UInt16 = 1) -> UInt16 {
		let old = self
		self -= self < amount ? self : amount
		return old - self
	}
}
