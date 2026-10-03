// swift-tools-version: 6.4

import PackageDescription

let package = Package(
	name: "GFX",
	platforms: [
		.iOS(.v27),
		.macOS(.v27),
	],
	products: [
		.library(name: "GFX", type: .dynamic, targets: ["GFX"]),
		.executable(name: "GFXUnitSheet", targets: ["GFXUnitSheet"]),
	],
	targets: [
		.target(
			name: "GFX",
			path: ".",
			exclude: ["UnitSheet", "Tests"]
		),
		.executableTarget(
			name: "GFXUnitSheet",
			dependencies: ["GFX"],
			path: "UnitSheet"
		),
		.testTarget(
			name: "GFXTests",
			dependencies: ["GFX"],
			path: "Tests"
		),
	]
)
