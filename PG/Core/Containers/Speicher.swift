protocol DeadOrAlive: ~Copyable {
	var alive: Bool { get }
}

extension DeadOrAlive {
	var alive: Bool { true }
}

struct Speicher<let capacity: Int, Element: DeadOrAlive>: ~Copyable {
	private var elements: InlineArray<capacity, Element>
	private(set) var count: Int
}

extension Speicher {

	init(head: [Element], tail: Element) {
		elements = .init(head: head, tail: tail)
		count = head.count
	}

	var indices: CountableRange<Int> {
		0..<count
	}

	var isEmpty: Bool {
		count == 0 || firstMap(ø) == nil
	}

	subscript(_ index: Int) -> Element {
		get { elements[index] }
		set { elements[index] = newValue }
	}

	@discardableResult
	mutating func add(_ element: Element) -> Int {
		for i in indices where !elements[i].alive {
			elements[i] = element
			return i
		}
		defer { count += 1 }
		elements[count] = element
		return count
	}

	mutating func erase() {
		count = 0
	}

	func forEach(_ body: (Int, Element) -> Void) {
		for i in indices where elements[i].alive { body(i, elements[i]) }
	}

	mutating func modifyEach(_ transform: (Int, inout Element) -> Void) {
		for i in indices where elements[i].alive {
			transform(i, &elements[i])
		}
	}

	func map<A>(_ transform: (Int, Element) -> A) -> [A] {
		var array = [] as [A]
		for i in indices where elements[i].alive {
			array.append(transform(i, elements[i]))
		}
		return array
	}

	func flatMap<A>(_ transform: (Int, Element) -> [A]) -> [A] {
		var arr = [] as [A]
		for i in indices where elements[i].alive {
			arr.append(contentsOf: transform(i, self[i]))
		}
		return arr
	}

	func compactMap<A>(_ transform: (Int, Element) -> A?) -> [A] {
		var array = [] as [A]
		for i in indices where elements[i].alive {
			if let value = transform(i, elements[i]) {
				array.append(value)
			}
		}
		return array
	}

	func reduce<R>(into result: R, _ fold: (inout R, Int, Element) -> Void) -> R {
		var result = result
		for i in indices where elements[i].alive {
			fold(&result, i, elements[i])
		}
		return result
	}

	func firstMap<A>(_ transform: (Int, Element) -> A?) -> A? {
		for i in indices where elements[i].alive {
			if let some = transform(i, elements[i]) { return some }
		}
		return nil
	}
}
