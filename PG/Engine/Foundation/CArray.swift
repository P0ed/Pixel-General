struct CArray<let capacity: Int, Element>: ~Copyable {
	private(set) var count: Int
	private var mem: InlineArray<capacity, Element>
}

extension CArray {

	var indices: CountableRange<Int> { 0 ..< count }

	var isEmpty: Bool { count == 0 }

	init(tail: Element) {
		mem = .init(repeating: tail)
		count = 0
	}

	init(head: Element, tail: Element) {
		mem = .init { i in i == 0 ? head : tail }
		count = 1
	}

	init(head: [Element], tail: Element) {
		mem = .init(head: head, tail: tail)
		count = head.count
	}

	subscript(_ index: Int) -> Element {
		get { mem[index] }
		set { mem[index] = newValue }
	}

	mutating func add(_ element: Element) {
		mem[count] = element
		count += 1
	}

	mutating func add<let n: Int>(_ elements: borrowing CArray<n, Element>) {
		for i in elements.indices {
			mem[count] = elements[i]
			count += 1
		}
	}

	mutating func remove(at index: Int) {
		precondition(index < count)
		count -= 1
		for i in index ..< count {
			mem[i] = mem[i + 1]
		}
	}

	mutating func erase() {
		count = 0
	}

	func forEach(_ body: (Int, Element) -> Void) {
		for i in indices { body(i, mem[i]) }
	}

	mutating func modifyEach(_ transform: (Int, inout Element) -> Void) {
		for i in indices { transform(i, &mem[i]) }
	}

	func map<A>(_ transform: (Int, Element) -> A) -> [A] {
		var result = [] as [A]
		for i in indices {
			result.append(transform(i, mem[i]))
		}
		return result
	}

	func flatMap<A>(_ transform: (Int, Element) -> [A]) -> [A] {
		var arr = [] as [A]
		for i in indices {
			arr.append(contentsOf: transform(i, mem[i]))
		}
		return arr
	}

	func compactMap<A>(_ transform: (Int, Element) -> A?) -> [A] {
		var result = [] as [A]
		for i in indices {
			if let value = transform(i, mem[i]) {
				result.append(value)
			}
		}
		return result
	}

	func reduce<R>(into result: R, _ fold: (inout R, Int, Element) -> Void) -> R {
		var result = result
		for i in indices {
			fold(&result, i, mem[i])
		}
		return result
	}

	func firstMap<A>(_ transform: (Int, Element) -> A?) -> A? {
		for i in indices {
			if let some = transform(i, mem[i]) { return some }
		}
		return nil
	}
}
