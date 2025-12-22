// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SVGEditor",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "SVGEditor",
            targets: ["SVGEditor"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/AashirMubeeb/SVGKit.git",
            branch: "3.x"
        )
    ],
    targets: [
        .target(
            name: "SVGEditor",
            dependencies: [
                .product(name: "SVGKit", package: "SVGKit")
            ]
        ),
        .testTarget(
            name: "SVGEditorTests",
            dependencies: ["SVGEditor"]
        ),
    ]
)

