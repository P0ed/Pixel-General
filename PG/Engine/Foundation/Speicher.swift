protocol DeadOrAlive {
	var alive: Bool { get }
}

typealias Speicher<let capacity: Int, Element: DeadOrAlive> = CArray<capacity, Element>

extension Speicher {

	@discardableResult
	mutating func insert(_ element: Element) -> Int {
		for i in indices where !self[i].alive {
			self[i] = element
			return i
		}
		defer { add(element) }
		return count
	}

	func forEachAlive(_ body: (Int, Element) -> Void) {
		for i in indices where self[i].alive { body(i, self[i]) }
	}

	func mapAlive<A>(_ transform: (Int, Element) -> A) -> [A] {
		var result = [] as [A]
		for i in indices where self[i].alive {
			result.append(transform(i, self[i]))
		}
		return result
	}

	func flatMapAlive<A>(_ transform: (Int, Element) -> [A]) -> [A] {
		var arr = [] as [A]
		for i in indices where self[i].alive {
			arr.append(contentsOf: transform(i, self[i]))
		}
		return arr
	}

	func compactMapAlive<A>(_ transform: (Int, Element) -> A?) -> [A] {
		var result = [] as [A]
		for i in indices where self[i].alive {
			if let value = transform(i, self[i]) {
				result.append(value)
			}
		}
		return result
	}

	func reduceAlive<R>(into result: R, _ fold: (inout R, Int, Element) -> Void) -> R {
		var result = result
		for i in indices where self[i].alive {
			fold(&result, i, self[i])
		}
		return result
	}

	func firstMapAlive<A>(_ transform: (Int, Element) -> A?) -> A? {
		for i in indices where self[i].alive {
			if let some = transform(i, self[i]) { return some }
		}
		return nil
	}
}
