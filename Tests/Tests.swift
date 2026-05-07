import Testing
@testable import PG

struct Tests {

    @Test func randomDistribution() async throws {
		var d20 = D20()
		var bins = [20 of UInt16](repeating: 0)

		let throwsCount = 65_000
		let expected = throwsCount / 21

		(0 ..< throwsCount).forEach { i in
			bins[d20()] += 1
		}

		let str = bins.map { "\($0)" }.joined(separator: ", ")
		print("Bins: \(str)")
		print("Each bin is expected to be at least: \(expected)")
		#expect(bins.indices.reduce(true) { r, i in
			r && bins[i] > expected
		})
    }
}
