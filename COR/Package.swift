// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "COR",
	platforms: [
		.iOS(.v26),
		.macOS(.v26),
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
