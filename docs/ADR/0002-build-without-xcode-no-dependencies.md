# ADR-0002: Xcode を使わず SwiftPM でビルドし、外部ライブラリを使わない

- Status: Accepted
- Date: 2026-10-16

## Context

- 自分専用で配布しない。App Store も公証も必要ない。
- Xcode 本体は大きく、更新の手間もかかる。Command Line Tools の `swiftc` は入っている（`/Library/Developer/CommandLineTools/usr/bin/swiftc`）。
- 外部ライブラリ（ホットキー用の KeyboardShortcuts など）は便利だが、その分サプライチェーン上の信頼先が増える。
- 必要な機能は、どれも標準フレームワークで実現できる。

| 必要な機能 | 標準フレームワーク |
|---|---|
| メニューバー常駐、パネル表示 | AppKit |
| クリップボードの監視 | AppKit（`NSPasteboard.changeCount`） |
| グローバルホットキー | Carbon（`RegisterEventHotKey`。アクセシビリティ権限は不要） |
| `⌘V` を送る | CoreGraphics（`CGEvent`） |
| 暗号化 | CryptoKit |
| 鍵の保管 | Security（Keychain） |
| ログイン時に起動 | ServiceManagement（`SMAppService`） |

## Decision

- **SwiftPM の executable target** としてビルドする。`.xcodeproj` は作らない。
- `scripts/build.sh` で、ビルド結果を `.app` バンドル（`Contents/MacOS`、`Info.plist`）に詰めて署名する。
- **外部ライブラリは使わない。** `Package.swift` に dependencies を書かない。
- 対応 OS は macOS 13 以降にする。

## Consequences

- Xcode のない環境でも `./scripts/build.sh` だけでビルドできる。
- アセットカタログ、Storyboard、Xcode のプレビューは使えない。UI はコード（AppKit）で組む。メニューバーのアイコンは SF Symbols を使う。
- **確認結果（2026-10-16、Swift 6.3.3 の Command Line Tools）**:
  - AppKit / CryptoKit / Carbon を使うコードは、Command Line Tools だけでビルドできる。
  - XCTest は使えない（`no such module 'XCTest'`）。
  - swift-testing は、フレームワークの検索パスと rpath を指定すれば使える。手順は `scripts/test.sh` にまとめた。
- テストの対象にするため、UI に依存しないロジックは `SafeClipyCore` ライブラリのターゲットに分ける。
