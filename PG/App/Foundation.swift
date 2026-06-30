extension String {

	init(safeCString array: [CChar]) {
		let nullIndex = array.firstIndex(of: 0) ?? array.endIndex
		let truncated = array[..<nullIndex].map { UInt8(bitPattern: $0) }
		self.init(decoding: truncated, as: UTF8.self)
	}
}
