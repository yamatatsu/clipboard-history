# Architecture Decision Records

| # | タイトル | Status |
|---|---|---|
| [0001](0001-native-swift-instead-of-hammerspoon.md) | Hammerspoon を使わず Swift のネイティブアプリにする | Accepted |
| [0002](0002-build-without-xcode-no-dependencies.md) | Xcode を使わず SwiftPM でビルドし、外部ライブラリを使わない | Accepted |
| [0003](0003-fixed-self-signed-code-signing.md) | 固定の自己署名証明書でコード署名する | Accepted |
| [0004](0004-encrypt-history-with-cryptokit-keychain.md) | 履歴を CryptoKit（AES-GCM）で暗号化し、鍵を Keychain に置く | Accepted |
| [0005](0005-sensitive-content-filtering.md) | 機密らしい内容を記録しない | Accepted |
| [0006](0006-snippets-plaintext-json.md) | スニペットを平文の JSON ファイルで管理する | Accepted |

## テンプレート

```markdown
# ADR-XXXX: タイトル

- Status: Proposed | Accepted | Superseded by ADR-XXXX
- Date: YYYY-MM-DD

## Context
## Decision
## Consequences
```
