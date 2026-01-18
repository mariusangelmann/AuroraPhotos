// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuroraPhotos",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AuroraPhotos", targets: ["AuroraPhotos"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "AuroraPhotos",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "AuroraPhotos",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AuroraPhotosTests",
            dependencies: ["AuroraPhotos"],
            path: "Tests"
        )
    ]
)
