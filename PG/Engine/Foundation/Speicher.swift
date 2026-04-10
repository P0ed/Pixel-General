protocol DeadOrAlive: ~Copyable {
	var alive: Bool { get }
}

struct Speicher<let capacity: Int, Element: DeadOrAlive>: ~Copyable {
	private var array: CArray<capacity, Element>
}

extension Speicher {

	var count: Int { array.count }

	var indices: CountableRange<Int> { 0 ..< count }

	var hasAlive: Bool { !array.isEmpty && firstMap(ø) != nil }

	init(head: [Element], tail: Element) {
		array = .init(head: head, tail: tail)
	}

	subscript(_ index: Int) -> Element {
		get { array[index] }
		set { array[index] = newValue }
	}

	@discardableResult
	mutating func add(_ element: Element) -> Int {
		for i in indices where !array[i].alive {
			array[i] = element
			return i
		}
		defer { array.add(element) }
		return count
	}

	mutating func erase() {
		array.erase()
	}

	func forEach(_ body: (Int, Element) -> Void) {
		for i in indices where array[i].alive { body(i, array[i]) }
	}

	mutating func modifyEach(_ transform: (Int, inout Element) -> Void) {
		for i in indices where array[i].alive {
			transform(i, &array[i])
		}
	}

	func map<A>(_ transform: (Int, Element) -> A) -> [A] {
		var result = [] as [A]
		for i in indices where array[i].alive {
			result.append(transform(i, array[i]))
		}
		return result
	}

	func flatMap<A>(_ transform: (Int, Element) -> [A]) -> [A] {
		var arr = [] as [A]
		for i in indices where array[i].alive {
			arr.append(contentsOf: transform(i, self[i]))
		}
		return arr
	}

	func compactMap<A>(_ transform: (Int, Element) -> A?) -> [A] {
		var result = [] as [A]
		for i in indices where array[i].alive {
			if let value = transform(i, array[i]) {
				result.append(value)
			}
		}
		return result
	}

	func reduce<R>(into result: R, _ fold: (inout R, Int, Element) -> Void) -> R {
		var result = result
		for i in indices where array[i].alive {
			fold(&result, i, array[i])
		}
		return result
	}

	func firstMap<A>(_ transform: (Int, Element) -> A?) -> A? {
		for i in indices where array[i].alive {
			if let some = transform(i, array[i]) { return some }
		}
		return nil
	}
}
