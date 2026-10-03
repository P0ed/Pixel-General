// swift-tools-version: 6.4

import PackageDescription

let package = Package(
	name: "COR",
	platforms: [
		.iOS(.v27),
		.macOS(.v27),
	],
	products: [
		.library(name: "COR", type: .dynamic, targets: ["COR"]),
	],
	targets: [
		.target(
			name: "COR",
			path: ".",
			exclude: ["Tests"],
			swiftSettings: [
				.unsafeFlags(["-O"], .when(configuration: .debug)),
			]
		),
		.testTarget(
			name: "CORTests",
			dependencies: ["COR"],
			path: "Tests"
		),
	]
)
