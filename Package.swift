// swift-tools-version:5.6
import PackageDescription
import Foundation

// Automatically detect local FFI development mode.
// When LocalPackages/Package.swift exists (created by Scripts/init-local-ffi.sh),
// the SDK builds against the locally-built FFI instead of the pre-built binary
// from GitHub Releases. Run `rm -rf LocalPackages` to switch back.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let useLocalFFI = FileManager.default.fileExists(atPath: packageDir + "/LocalPackages/Package.swift")

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.24.2"),
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
]

var sdkDependencies: [Target.Dependency] = [
    .product(name: "SQLite", package: "SQLite.swift"),
    .product(name: "GRPC", package: "grpc-swift"),
]

var targets: [Target] = []

if useLocalFFI {
    dependencies.append(.package(name: "libzcashlc", path: "LocalPackages"))
    sdkDependencies.append(.product(name: "libzcashlc", package: "libzcashlc"))
} else {
    // Zecky (audit C-51): the Zecky engine release, not the upstream 4.0.0
    // binary (which knows no NU7). This asset has every slice, macOS
    // included; the iPhone app uses libzcashlc.xcframework.zip of the same
    // release, which has the iOS slices as plain static libraries.
    targets.append(
        .binaryTarget(
            name: "libzcashlc",
            url: "https://github.com/zecky-app/zecky-engine/releases/download/v4.0.0-zecky.3/libzcashlc-swiftpm.xcframework.zip",
            checksum: "35a3e6829555d4a3f5a5b0aafea5577318e8f81d8b27ec6a2de98ce76ba15a7c"
        )
    )
    sdkDependencies.append("libzcashlc")
}

targets.append(contentsOf: [
    .target(
        name: "ZcashLightClientKit",
        dependencies: sdkDependencies,
        exclude: [
            "Modules/Service/GRPC/ProtoBuf/proto/proposal.proto",
            "Error/Sourcery/",
            // Zecky: community voting is not built into libzcashlc (Rust
            // feature `voting` is off), so its Swift wrapper is left out.
            "Rust/Voting/"
        ],
        resources: [
            .copy("Resources/checkpoints")
        ]
    ),
    .target(
        name: "TestUtils",
        dependencies: ["ZcashLightClientKit"],
        path: "Tests/TestUtils",
        exclude: [
            "proto/darkside.proto",
            "Sourcery/AutoMockable.stencil",
            "Sourcery/generateMocks.sh"
        ],
        resources: [
            .copy("Resources/test_data.db"),
            .copy("Resources/cache.db"),
            .copy("Resources/darkside_caches.db"),
            .copy("Resources/darkside_data.db"),
            .copy("Resources/sandblasted_mainnet_block.json"),
            .copy("Resources/txBase64String.txt"),
            .copy("Resources/txFromAndroidSDK.txt"),
            .copy("Resources/integerOverflowJSON.json"),
            .copy("Resources/sapling-spend.params"),
            .copy("Resources/sapling-output.params")
        ]
    ),
    .testTarget(
        name: "OfflineTests",
        dependencies: ["ZcashLightClientKit", "TestUtils"],
        exclude: [
            "PirSnapshotResolverTests.swift",
            "VotingConfirmVoteSubmissionTests.swift",
            "VotingKeyTypesTests.swift",
            "VotingRecoverWireJsonTests.swift",
            "VotingRustBackendTests.swift",
            "VotingSignDelegationRequestTests.swift"
        ]
    ),
    .testTarget(
        name: "NetworkTests",
        dependencies: ["ZcashLightClientKit", "TestUtils"]
    ),
    .testTarget(
        name: "DarksideTests",
        dependencies: ["ZcashLightClientKit", "TestUtils"]
    ),
    .testTarget(
        name: "AliasDarksideTests",
        dependencies: ["ZcashLightClientKit", "TestUtils"],
        exclude: [
            "scripts/"
        ]
    ),
    .testTarget(
        name: "PerformanceTests",
        dependencies: ["ZcashLightClientKit", "TestUtils"]
    )
])

let package = Package(
    name: "ZcashLightClientKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ZcashLightClientKit",
            targets: ["ZcashLightClientKit"]
        )
    ],
    dependencies: dependencies,
    targets: targets
)
