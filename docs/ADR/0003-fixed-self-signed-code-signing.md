# ADR-0003: 固定の自己署名証明書でコード署名する

- Status: Accepted
- Date: 2026-10-16

## Context

- `⌘V` を送るには **アクセシビリティの許可（TCC）** が要る。TCC は、許可したアプリをコード署名の designated requirement で見分けている。
- Keychain の項目にアクセスできるアプリの一覧（ACL）も、同じく署名で見分けている。
- ad-hoc 署名（`codesign -s -`）は cdhash がそのまま designated requirement になる。そのため **ビルドするたびに別のアプリと見なされ**、アクセシビリティの許可を付け直し、Keychain の確認ダイアログが出る。
- 配布しないので、Apple Developer Program の証明書や公証は要らない。
- ローカルでビルドしたファイルには quarantine 属性が付かないので、Gatekeeper にも止められない。

## Decision

- `scripts/make-cert.sh` で、**コード署名用の自己署名証明書**（Common Name: `SafeClipy Local Signing`、拡張キー用途: codeSigning）を1回だけ作り、ログインキーチェーンに入れる。
- `scripts/build.sh` は、毎回この証明書で `codesign --force --options runtime --sign "SafeClipy Local Signing"` を実行する。
- Bundle ID は `local.safeclipy.SafeClipy` で固定する。
- 署名した後に `codesign --verify --strict` を実行し、失敗したらビルドを失敗扱いにする。

## Consequences

- 再ビルドしても designated requirement（Bundle ID と証明書）が変わらないので、アクセシビリティと Keychain の許可が引き継がれる。
- 証明書の秘密鍵はログインキーチェーンにある。これを盗めるのは、同じユーザー権限で動くマルウェア（守る範囲の外。[ADR-0001](0001-native-swift-instead-of-hammerspoon.md)）だけ。
- 証明書を作り直すと、別のアプリと見なされる。その場合は許可の付け直しと、Keychain の鍵の ACL の更新が必要になる。
- **未確認事項**: 自己署名証明書を `codesign` に使うには、コード署名用としての信頼設定（`security add-trusted-cert -p codeSign` 相当）が要るかもしれない。`make-cert.sh` を実装するときに確かめる。
