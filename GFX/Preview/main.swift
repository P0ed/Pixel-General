import Foundation
import GFX

let arguments = Array(CommandLine.arguments.dropFirst())
let directory = arguments.first.map { URL(fileURLWithPath: $0) }
let filter = arguments.dropFirst().first
let entries = switch filter {
case "units": Catalog.units
case "tiles": Catalog.tiles
case "settlements": Catalog.settlements
case let filter?: Catalog.all.filter { $0.name.localizedCaseInsensitiveContains(filter) }
case nil: Catalog.all
}

if let directory {
	try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

for entry in entries {
	let bitmap = entry.renderer.render(entry.model)

	print("\n\(entry.name)  \(bitmap.width)x\(bitmap.height)")
	print(ascii(bitmap))

	if let directory, let png = bitmap.png {
		try? png.write(to: directory.appending(path: "\(entry.name).png"))
	}
}

if let directory, let png = sheet(entries, scale: Int(ProcessInfo.processInfo.environment["GFX_SCALE"] ?? "5") ?? 5).png {
	let url = directory.appending(path: "Sheet.png")
	try? png.write(to: url)
	print("\n\(url.path)")
}

/// One character per pixel, darkest first, so a model can be eyeballed in a terminal.
func ascii(_ bitmap: Bitmap) -> String {
	let ramp = Array(" .:-=+*#%@")
	return (0 ..< bitmap.height).map { y in
		String((0 ..< bitmap.width).map { x -> Character in
			let pixel = bitmap[x, y]
			guard pixel.alpha > 0 else { return " " }
			return ramp[max(1, Int(pixel.gray) * (ramp.count - 1) / 255)]
		})
	}
	.joined(separator: "\n")
}

/// All models on one checkered sheet, magnified, for looking at in an image viewer.
func sheet(_ entries: [CatalogEntry], scale: Int, columns: Int = 5) -> Bitmap {
	let cell = (width: 64, height: 48)
	let rows = (entries.count + columns - 1) / columns
	var sheet = Bitmap(width: cell.width * columns * scale, height: cell.height * rows * scale)

	for (index, entry) in entries.enumerated() {
		let bitmap = entry.renderer.render(entry.model)
		let originX = (index % columns) * cell.width * scale
		let originY = (index / columns) * cell.height * scale
		let inset = (cell.height - bitmap.height) * scale

		for y in 0 ..< bitmap.height * scale {
			for x in 0 ..< bitmap.width * scale {
				let pixel = bitmap[x / scale, y / scale]
				let checker = ((x / scale / 8) + (y / scale / 8)).isMultiple(of: 2) ? 60 : 80 as UInt8
				sheet[originX + x, originY + y + inset] = pixel.alpha > 0 ? pixel : (checker, .max)
			}
		}
	}

	return sheet
}
