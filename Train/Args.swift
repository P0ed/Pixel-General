import Foundation
import COR

/// Shared `--flag value` CLI parsing for the `Train` subcommands: each
/// command supplies only its option table via `handle`, keeping the
/// `next()`/error-reporting mechanism in one place.
struct Args {
	private let values: [String]

	init(_ values: [String]) {
		self.values = values
	}

	func parse(_ handle: (_ flag: String, _ next: () throws -> String) throws -> Void) throws {
		var i = 0
		while i < values.count {
			let flag = values[i]
			try handle(flag) {
				i += 1
				guard i < values.count else { throw TrainError.usage("missing value for \(flag)") }
				return values[i]
			}
			i += 1
		}
	}
}

struct DefaultArgs: Codable {
	var bc: [String]?
	var rl: [String]?
	var ppo: [String]?
}

extension DefaultArgs {

	static var `default`: DefaultArgs? {
		(
			try? Data(contentsOf: URL(filePath: "tmp/run.json"))
		)
		.flatMap { data in
			try? JSONDecoder().decode(DefaultArgs.self, from: data)
		}
	}
}

extension LSTMWeights {
	static func load(_ path: String) throws -> LSTMWeights {
		guard let w = LSTMWeights(data: try Data(contentsOf: URL(fileURLWithPath: path))) else {
			throw TrainError.badFile(path)
		}
		return w
	}
}

func f(_ v: Float) -> String { unsafe String(format: "%.3f", v) }
