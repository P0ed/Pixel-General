// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "GFX",
	platforms: [
		.iOS(.v26),
		.macOS(.v26),
	],
	products: [
		.library(name: "GFX", type: .dynamic, targets: ["GFX"])
	],
	targets: [
		.target(
			name: "GFX",
			path: ".",
			exclude: ["Preview", "Tests"]
		),
		.executableTarget(
			name: "GFXPreview",
			dependencies: ["GFX"],
			path: "Preview"
		),
		.testTarget(
			name: "GFXTests",
			dependencies: ["GFX"],
			path: "Tests"
		),
	]
)
