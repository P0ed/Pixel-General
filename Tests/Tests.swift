import Testing
@testable import PG

struct RNGTests {

	@Test func randomDistribution() async throws {
		var d20 = D20()
		var bins = [20 of UInt16](repeating: 0)

		let throwsCount = 65_000
		let expected = throwsCount / 21

		(0 ..< throwsCount).forEach { i in
			bins[d20()] += 1
		}

		let str = bins.indices
			.map { i in "\(bins[i])" }
			.joined(separator: ", ")

		let result = bins.indices
			.reduce(true) { r, i in r && bins[i] > expected }

		print("Bins: \(str)")
		print("Each bin is expected to be greater than: \(expected)")
		#expect(result)
	}
}
