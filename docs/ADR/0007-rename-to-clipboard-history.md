# ADR-0007: 名前を clipboard-history に変える

- Status: Accepted
- Date: 2026-10-19

## Context

- これまでの名前「safe-clipy」は、Clipy の名前を借りたうえで「こちらは safe」と言っている。裏返すと、Clipy が安全でないように読める。
- Clipy に脆弱性があるかどうかは知らないし、Clipy を貶める意図もない。リポジトリを public にするので、誤解を与える名前は避けたい。
- 自分で使うだけなので、かっこいい名前は要らない。機能をそのまま説明する名前でよい。

## Decision

- 名前を **clipboard-history** に変える。Clipy を含む名前や、Safe・Secure・Vault のように他と比べて安全だと匂わせる名前は使わない。
- 名前が入っている値は、次のとおり置き換える。ADR-0003 と ADR-0004 で決めた名前は、この表で置き換わる。

| 項目 | 旧 | 新 |
|---|---|---|
| リポジトリ名 | `safe-clipy` | `clipboard-history` |
| アプリ名・実行ファイル名 | `SafeClipy` | `ClipboardHistory` |
| ライブラリのターゲット | `SafeClipyCore` | `ClipboardHistoryCore` |
| Bundle ID | `local.safeclipy.SafeClipy` | `local.clipboardhistory.ClipboardHistory` |
| 自分が書き込んだ印 | `local.safeclipy.marker` | `local.clipboardhistory.marker` |
| 署名用の証明書の CN | `SafeClipy Local Signing` | `ClipboardHistory Local Signing` |
| Keychain の service | `SafeClipy history key` | `ClipboardHistory history key` |
| データの置き場所 | `~/Library/Application Support/SafeClipy/` | `~/Library/Application Support/ClipboardHistory/` |

- 旧版からの移行処理は作らない。旧版はアンインストールし、新しい名前で一から始める。

## Consequences

- Bundle ID と証明書が変わるので、別のアプリとして扱われる。アクセシビリティの許可と Keychain の許可は付け直しになる。
- 旧版の履歴は読めなくなる。使い始めたばかりで失うものが少ないので、移行処理のコードを持たないほうを選んだ。
- 既存の ADR の本文は書き換えないので、ADR-0001〜0006 には旧名が残る。
