// swift-tools-version:5.5
import PackageDescription


let package = Package(
	name: "RemoteImageView",
	platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
	products: [.library(name: "RemoteImageView", targets: ["RemoteImageView"])],
	dependencies: [
		.package(url: "https://github.com/Frizlab/OperationAwaiting.git", from: "0.7.0"),
		.package(url: "https://github.com/happn-tech/URLRequestOperation.git", from: "2.0.0-alpha.10")
	],
	targets: [
		.target(name: "RemoteImageView", dependencies: [
			.product(name: "OperationAwaiting",   package: "OperationAwaiting"),
			.product(name: "URLRequestOperation", package: "URLRequestOperation")
		])
	]
)
