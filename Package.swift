// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SafeClipy",
    platforms: [.macOS(.v13)],
    targets: [
        // UI に依存しない純粋なロジック（テスト対象）
        .target(name: "SafeClipyCore"),
        // アプリ本体（AppKit）
        .executableTarget(name: "SafeClipy", dependencies: ["SafeClipyCore"]),
        .testTarget(name: "SafeClipyCoreTests", dependencies: ["SafeClipyCore"]),
    ]
)
