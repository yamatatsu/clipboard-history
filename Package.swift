// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ClipboardHistory",
    platforms: [.macOS(.v13)],
    targets: [
        // UI に依存しない純粋なロジック（テスト対象）
        .target(name: "ClipboardHistoryCore"),
        // アプリ本体（AppKit）
        .executableTarget(name: "ClipboardHistory", dependencies: ["ClipboardHistoryCore"]),
        .testTarget(name: "ClipboardHistoryCoreTests", dependencies: ["ClipboardHistoryCore"]),
    ]
)
