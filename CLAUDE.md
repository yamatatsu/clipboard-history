# CLAUDE.md

## プロジェクト概要

clipboard-history は、セキュリティを優先した macOS 用のクリップボード履歴・スニペットアプリです（Clipy 互換の操作感）。
自分専用で配布はしない。全体像は README.md、設計判断は docs/ADR/、仕様は docs/specs/ を参照する。

## 必ず守る制約

- **Xcode は使わない。** Command Line Tools（`swiftc` / SwiftPM）だけでビルドする。`.xcodeproj` は作らない。
- **外部ライブラリを入れない。** 使ってよいのは Apple の標準フレームワーク（AppKit, CryptoKit, Security, Carbon, ServiceManagement など）だけ。
- **Hammerspoon など、他のアプリやランタイムに依存しない**（[ADR-0001](docs/ADR/0001-native-swift-instead-of-hammerspoon.md)）。
- **署名は必ず固定の自己署名証明書で行う。** ad-hoc 署名（`-s -`）にすると、ビルドのたびにアクセシビリティと Keychain の許可が外れる（[ADR-0003](docs/ADR/0003-fixed-self-signed-code-signing.md)）。

## セキュリティ上のルール

- クリップボードの内容とスニペットの本文を **ログ・標準出力・クラッシュ時の出力に一切出さない**。デバッグ時も文字数やハッシュの先頭など、内容が分からない情報にとどめる。
- 履歴を **平文でディスクに書かない**。一時ファイルも含む。書き込みは暗号化したデータだけを、アトミックに行う。
- 鍵を Keychain 以外（ファイル、UserDefaults、環境変数、プロセス引数）に置かない。
- 復号に失敗しても、既存の暗号化ファイルを黙って上書きしない（[storage-and-encryption.md](docs/specs/storage-and-encryption.md)）。
- フィルタの判定は「迷ったら記録しない」に倒す（[filtering.md](docs/specs/filtering.md)）。

## コマンド

```sh
./scripts/make-cert.sh        # 自己署名証明書を作成（最初の1回）
./scripts/build.sh            # リリースビルド → build/ClipboardHistory.app を作って署名
./scripts/build.sh install    # 上に加えて ~/Applications へコピー
./scripts/test.sh             # ClipboardHistoryCore の単体テスト
swift build                   # 開発中のコンパイル確認
```

- 証明書を作った直後の初回の署名では、キーチェーンのダイアログが出る。利用者が「常に許可」を押す必要があるので、初回のビルドは利用者に `! ./scripts/build.sh` で実行してもらう。

## 構成

```
Package.swift
Sources/ClipboardHistoryCore/    # UI に依存しないロジック（テスト対象）
Sources/ClipboardHistory/        # アプリ本体（AppKit、Keychain、ホットキーなど）
Tests/ClipboardHistoryCoreTests/ # swift-testing
Resources/Info.plist             # LSUIElement=true（Dock に出さない）
scripts/                         # make-cert.sh, build.sh
docs/ADR/                        # 設計判断（番号つき、追記していく）
docs/specs/                      # 機能仕様
```

## テスト

- テストの対象は、`ClipboardHistoryCore` にある UI に依存しないロジック（ContentFilter、HistoryStore、HistoryCodec、SnippetLibrary、DisplayText）に絞る。
- **XCTest は Command Line Tools では使えない。** swift-testing（`import Testing`）を使う。
- `swift test` を直接実行すると `no such module 'Testing'` になる。必ず `./scripts/test.sh` を使う（フレームワークのパスを補っている）。
- UI、Keychain、クリップボード、ホットキーは、実際にアプリを起動して手で確かめる。

## ドキュメントの運用

- 設計判断を変えたり追加したりしたら、docs/ADR/ に新しい番号で ADR を足す。既存の ADR は書き換えず、`Status: Superseded by ADR-XXXX` にする。
- 仕様を変えたら、コードと同じ変更で docs/specs/ も更新する。
- ドキュメントもコメントも日本語で書く。識別子は英語。
