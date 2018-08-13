// swift-tools-version:4.0
import PackageDescription


let package = Package(
    name: "XMLCoding",
    products: [
        .library(
            name: "XMLCoding",
            targets: [
                "XMLCoding"
            ]
        ),
        ],
    targets: [
        .target(
            name: "XMLCoding",
            dependencies: []
        ),
        .testTarget(
            name: "XMLCodingTests",
            dependencies: [
                "XMLCoding"
            ]
        ),
        ]
)
