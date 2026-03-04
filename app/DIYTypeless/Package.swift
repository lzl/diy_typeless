// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DIYTypelessCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DIYTypelessCore",
            targets: ["DIYTypelessCore"]
        )
    ],
    targets: [
        .target(
            name: "DIYTypelessCore",
            path: "Sources/DIYTypelessCore",
            exclude: [
                "Domain/DOMAIN_README.md",
                "Domain/Repositories/REPOS_INDEX.md",
                "Domain/UseCases/USECASES_INDEX.md"
            ]
        ),
        .testTarget(
            name: "DIYTypelessCoreTests",
            dependencies: ["DIYTypelessCore"],
            path: "Tests/DIYTypelessCoreTests"
        )
    ]
)
