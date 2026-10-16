# ADR-0001: Hammerspoon を使わず Swift のネイティブアプリにする

- Status: Accepted
- Date: 2026-10-16

## Context

最初は Hammerspoon の上で、次の2つを作る予定だった。

1. brew で入る Hammerspoon が GitHub で公開されているものと一致するかを検証する仕組み
2. Clipy と同じようなクリップボード履歴

検討の中で、次のことが分かった（2026-10-16 に確認）。

- Hammerspoon 1.1.1 は Developer ID `Chris Jones (VQCYSNZB89)` で署名・公証されている。brew cask の sha256 と GitHub Releases の asset digest は一致していた。
- **正式リリースの zip は GitHub Actions でビルドされていない。** メンテナーが手元で `scripts/release.sh` を実行してビルド・公証し、個人アカウント（`cmsj`）で Releases にアップロードしている。GitHub Actions でビルドしているのはナイトリー版だけで、出力先は Actions の artifact。1.1.1 の zip に artifact attestation もない。
  - このため、リポジトリのコードを信頼しても、配布されている zip がそのコードからビルドされたことは外から確かめられない。確かめられるのは署名した Team ID までになる。
- Hammerspoon はアクセシビリティ権限を持ったまま、**署名のない `~/.hammerspoon/init.lua` をそのまま読み込む。** 同じユーザー権限で動くプロセスがこのファイルを書き換えれば、その権限とクリップボードの内容を丸ごと使える。
- 履歴の暗号化（AES）は Hammerspoon の API ではできない。結局 Swift のヘルパーが必要になる。
- Hammerspoon から Keychain を使うと `/usr/bin/security` 経由になる。Keychain が信頼するのは `security` コマンドなので、鍵を守る範囲が広がりすぎる。
- Hammerspoon は、この2つ以外の用途で使う予定がない。

## Decision

- クリップボード履歴は **Swift で書くネイティブアプリ** として作る。
- Hammerspoon は使わない（アンインストールする）。そのため **Hammerspoon の検証機能も作らない。**

## Consequences

- 信頼しなければならないものが「他人が手元でビルドしたバイナリ＋署名のない Lua の設定」から「自分のコード＋Apple のフレームワーク」に減る。
- Keychain のアクセス権限が、自分のアプリの署名に紐づくようになる（[ADR-0004](0004-encrypt-history-with-cryptokit-keychain.md)）。
- コード量は増える（Lua なら300行程度、Swift だと1000行前後の見込み）。開発のたびにビルドが必要になる。
- ビルドと署名の手順を自分で持つ必要がある（[ADR-0002](0002-build-without-xcode-no-dependencies.md)、[ADR-0003](0003-fixed-self-signed-code-signing.md)）。
- 同じユーザー権限で動くマルウェアは、どの方式でも守りきれない。このアプリでは守る範囲の外とする。
