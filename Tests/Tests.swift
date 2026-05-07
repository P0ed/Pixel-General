import Testing
@testable import PG

struct Tests {

    @Test func randomDistribution() async throws {
		var d20 = D20()
		var bins = [20 of UInt16](repeating: 0)

		(0 ..< Int(UInt16.max)).forEach { i in
			bins[d20()] += 1
		}

		let str = bins.map { "\($0)" }.joined(separator: ", ")
		print("bins: \(str)")
		#expect(bins.indices.reduce(true) { r, i in
			r && bins[i] > 3000
		})
    }
}
