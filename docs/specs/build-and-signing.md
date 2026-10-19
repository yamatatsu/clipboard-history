# ビルド、`.app` への詰め方、署名、インストール

方針は [ADR-0002](../ADR/0002-build-without-xcode-no-dependencies.md) と [ADR-0003](../ADR/0003-fixed-self-signed-code-signing.md) を参照。

## Package.swift

- `swift-tools-version:5.10`（Swift 6 の言語モードの厳しい並行性チェックを避けるため）。
- `platforms: [.macOS(.v13)]`
- ターゲットは、ライブラリの `ClipboardHistoryCore`（UI に依存しないロジック）、実行ファイルの `ClipboardHistory`、テストの `ClipboardHistoryCoreTests` の3つ。
- `dependencies` は空にする。

## scripts/make-cert.sh

最初の1回だけ実行する。

1. ログインキーチェーンに `ClipboardHistory Local Signing` の証明書がすでにあれば、何もせずに終わる
2. `openssl` で、自己署名の証明書と秘密鍵を作る
   - CN: `ClipboardHistory Local Signing`
   - keyUsage: digitalSignature（critical）、extendedKeyUsage: codeSigning（critical）
   - 有効期限: 10年
3. p12 にまとめて、`security import` でログインキーチェーンに入れる（`-T /usr/bin/codesign` を付ける）
4. 信頼の設定はしない（不要なことを確認済み。ADR-0003）
5. 作業用のファイル（秘密鍵、p12）は `mktemp -d` で作った場所に置き、終わったら消す
6. `security find-identity -p codesigning` で、使える状態になったか確かめる

## scripts/build.sh

```
./scripts/build.sh           # build/ClipboardHistory.app を作る
./scripts/build.sh install   # 上に加えて ~/Applications/ClipboardHistory.app に置き換える
```

1. `swift build -c release`
2. `build/ClipboardHistory.app/Contents/` を作る
   - `MacOS/ClipboardHistory`: ビルドしたバイナリ
   - `Info.plist`: `Resources/Info.plist` をコピーする
3. `codesign --force --options runtime --timestamp=none --sign "ClipboardHistory Local Signing" build/ClipboardHistory.app`
4. `codesign --verify --strict --verbose=2 build/ClipboardHistory.app`。失敗したら終了コード 1 で終わる
5. `install` のとき
   - ClipboardHistory が起動していれば終了させる
   - `~/Applications/ClipboardHistory.app` と置き換える
   - 起動はしない（起動するかどうかは利用者が決める）

## Info.plist の主なキー

| キー | 値 |
|---|---|
| `CFBundleIdentifier` | `local.clipboardhistory.ClipboardHistory` |
| `CFBundleName` | `ClipboardHistory` |
| `CFBundleExecutable` | `ClipboardHistory` |
| `CFBundlePackageType` | `APPL` |
| `CFBundleShortVersionString` | `0.1.0` |
| `LSMinimumSystemVersion` | `13.0` |
| `LSUIElement` | `true` |

## entitlements

- サンドボックスにはしない（他のアプリへの `⌘V` の送信や、ログインキーチェーンの利用に影響するため）。
- Hardened Runtime は有効にする（`--options runtime`）。追加で必要な entitlement はない見込み。
