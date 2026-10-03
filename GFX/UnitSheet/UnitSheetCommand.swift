import Darwin
import Foundation
import GFX

@main
enum UnitSheetCommand {

	static let usage = """
	Usage: GFXUnitSheet [output.png] [--scale N] [--columns N]

	Render every unit shape in both facings to a labeled PNG sheet.

	  output.png     Output file (default: units.png); parent directories are created.
	  --scale N      Integer pixel scale, 1–8 (default: 4).
	  --columns N    Unit pairs per row, 1–8 (default: 4).
	  -h, --help     Show this help.
	"""

	static func main() {
		do {
			var arguments = CommandLine.arguments.dropFirst().makeIterator()
			var output: String?
			var scale = 4
			var columns = 4
			while let argument = arguments.next() {
				switch argument {
				case "-h", "--help":
					print(usage)
					return
				case "--scale", "--columns":
					guard let value = arguments.next(), let number = Int(value), (1 ... 8).contains(number) else {
						throw UnitSheetError.arguments("\(argument) requires an integer from 1 to 8.")
					}
					if argument == "--scale" { scale = number } else { columns = number }
				default:
					guard !argument.hasPrefix("-"), output == nil else {
						throw UnitSheetError.arguments("Unexpected argument: \(argument).")
					}
					output = argument
				}
			}

			let url = URL(fileURLWithPath: output ?? "/tmp/units.png").standardizedFileURL
			guard url.pathExtension.lowercased() == "png" else {
				throw UnitSheetError.arguments("The output filename must end in .png.")
			}
			let png = try UnitSheet.png(scale: scale, columns: columns)
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try png.write(to: url, options: .atomic)
			print("Rendered \(Units.Shape.allCases.count) unit shapes to \(url.path)")
		} catch {
			let message = "GFXUnitSheet: \(error.localizedDescription)\n"
			FileHandle.standardError.write(Data(message.utf8))
			exit(EXIT_FAILURE)
		}
	}
}

enum UnitSheetError: LocalizedError {
	case arguments(String)
	case rendering
	case encoding

	var errorDescription: String? {
		switch self {
		case .arguments(let message): "\(message) Run with --help for usage."
		case .rendering: "Could not create the sprite sheet image."
		case .encoding: "Could not encode the sprite sheet as PNG."
		}
	}
}
