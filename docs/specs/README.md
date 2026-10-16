# 仕様

| ファイル | 内容 |
|---|---|
| [clipboard-history.md](clipboard-history.md) | クリップボードの監視と、履歴の持ち方 |
| [filtering.md](filtering.md) | 記録しない内容の判定 |
| [storage-and-encryption.md](storage-and-encryption.md) | 保存ファイル、暗号化、鍵の扱い |
| [snippets.md](snippets.md) | スニペットのファイル形式と読み込み |
| [ui-and-paste.md](ui-and-paste.md) | ホットキー、パネル、貼り付け、メニューバー |
| [build-and-signing.md](build-and-signing.md) | ビルド、`.app` への詰め方、署名、インストール |

## 決まった値

| 項目 | 値 |
|---|---|
| 履歴の上限件数 | 30件 |
| 履歴の保存期間 | 7日 |
| 履歴のホットキー | `⌘⇧V` |
| スニペットのホットキー | `⌘⇧B` |
| 選んだ後の動作 | Clipy と同じく、クリップボードに入れてすぐ貼り付ける |
| 扱う種類 | テキストのみ |
| 対応 OS | macOS 13 以降 |
| Bundle ID | `local.safeclipy.SafeClipy` |

これらの値は、将来の設定画面で変えられるようにする余地を残しつつ、最初は定数として持つ。
