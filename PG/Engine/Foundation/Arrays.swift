extension InlineArray {

	init(head: [Element], tail: Element) {
		precondition(head.count <= count)
		self = .init { [count = head.count] i in
			i < count ? head[i] : tail
		}
	}

	mutating func modifyEach(_ transform: (inout Element) -> Void) {
		for i in indices { transform(&self[i]) }
	}

	func mapInPlace(_ transform: (inout Element) -> Void) -> Self {
		var arr = self
		for i in indices { transform(&arr[i]) }
		return arr
	}

	func map(_ transform: (Element) -> Element) -> Self {
		var arr = self
		for i in indices { arr[i] = transform(arr[i]) }
		return arr
	}

	func map<A>(_ transform: (Element) -> A) -> [A] {
		var arr = [] as [A]
		arr.reserveCapacity(count)
		for i in indices { arr.append(transform(self[i])) }
		return arr
	}

	func flatMap<A>(_ transform: (Element) -> [A]) -> [A] {
		var arr = [] as [A]
		for i in indices { arr.append(contentsOf: transform(self[i])) }
		return arr
	}

	func compactMap<A>(_ transform: (Element) -> A?) -> [A] {
		var arr = [] as [A]
		for i in indices {
			if let value = transform(self[i]) { arr.append(value) }
		}
		return arr
	}

	func reduce<R>(into result: R, _ fold: (inout R, Element) -> Void) -> R {
		var result = result
		for i in indices {
			fold(&result, self[i])
		}
		return result
	}

	func firstMap<A>(_ transform: (Element) -> A?) -> A? {
		for i in indices {
			if let some = transform(self[i]) { return some }
		}
		return nil
	}
}

extension Array {

	init<let count: Int>(_ inlineArray: InlineArray<count, Element>) {
		var arr = [] as Self
		arr.reserveCapacity(count)
		for idx in inlineArray.indices { arr.append(inlineArray[idx]) }
		self = arr
	}

	mutating func modifyEach(_ transform: (inout Element) -> Void) {
		for i in indices { transform(&self[i]) }
	}

	func mapInPlace(_ transform: (inout Element) -> Void) -> Self {
		map { e in modifying(e, transform) }
	}

	func firstMap<A>(_ transform: (Element) -> A?) -> A? {
		for e in self {
			if let some = transform(e) { return some }
		}
		return nil
	}
}
