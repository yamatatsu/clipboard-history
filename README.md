# safe-clipy

[Clipy](https://github.com/Clipy/Clipy) と同じように使えて、セキュリティを優先した macOS 用のクリップボード履歴・スニペットアプリです。
自分専用で配布はしません。Swift で書き、Xcode を使わずにビルドします。

## 特徴

- **クリップボード履歴**: テキストのみ、最新30件、7日経つと自動で削除
- **スニペット**: フォルダ分けした定型文を呼び出して貼り付け
- **Clipy と同じ操作**: `⌘⇧V` で履歴、`⌘⇧B` でスニペットを開き、選ぶとすぐ貼り付け
- **暗号化して保存**: 履歴は AES-256-GCM で暗号化し、鍵は Keychain に置く
- **機密情報を記録しない**: パスワードマネージャーが付ける ConcealedType などの印、除外アプリ、トークンらしい文字列を検知して記録しない
- **外部ライブラリなし**: Apple の標準フレームワークだけを使う

## セキュリティモデル（概要）

| 守れる | 守れない |
|---|---|
| Time Machine やクラウド同期、ディスクのコピーから平文の履歴が漏れること | 同じユーザー権限で動くマルウェア（[ADR-0001](docs/ADR/0001-native-swift-instead-of-hammerspoon.md) を参照） |
| 他のユーザーアカウントからの読み取り | 画面の盗み見や、貼り付けた先のアプリでの漏えい |
| パスワードマネージャーからのコピーが履歴に残ること | 検知パターンに当てはまらない機密文字列 |

詳しくは [docs/specs/storage-and-encryption.md](docs/specs/storage-and-encryption.md) と [docs/specs/filtering.md](docs/specs/filtering.md) を参照してください。

## 動作環境

- macOS 13 以降
- Command Line Tools for Xcode（`xcode-select --install`）。Xcode 本体は不要です

## セットアップ

```sh
# 1. 署名用の自己署名証明書を作る（最初の1回だけ）
./scripts/make-cert.sh

# 2. ビルドして ~/Applications/SafeClipy.app にインストールする
./scripts/build.sh install

# 3. 起動する
open ~/Applications/SafeClipy.app
```

初めて起動したら、**システム設定 → プライバシーとセキュリティ → アクセシビリティ** で SafeClipy を許可してください（`⌘V` を送るのに必要です）。
許可しない場合は、選んだ項目がクリップボードに入るだけで、貼り付けは自動で行われません。

再ビルドしても同じ証明書で署名するので、アクセシビリティと Keychain の許可はそのまま引き継がれます（[ADR-0003](docs/ADR/0003-fixed-self-signed-code-signing.md) を参照）。

## 使い方

| 操作 | 内容 |
|---|---|
| `⌘⇧V` | 履歴のパネルを開く |
| `⌘⇧B` | スニペットのパネルを開く |
| 文字を入力 | 絞り込み |
| `↑` `↓` / `1`〜`9` | 選択 / 番号で即決定 |
| `⏎` | 貼り付け |
| `esc` | 閉じる |

メニューバーのアイコンからは、次の操作ができます。

- 履歴を消去
- 記録の一時停止と再開
- スニペットの編集と再読み込み
- ログイン時に起動するかどうかの切り替え
- 終了

## データの保存場所

| パス | 内容 |
|---|---|
| `~/Library/Application Support/SafeClipy/history.enc` | 暗号化した履歴 |
| `~/Library/Application Support/SafeClipy/snippets.json` | スニペット（**平文**。機密情報は入れないでください） |
| ログインキーチェーンの `SafeClipy history key` | 履歴を暗号化する鍵 |

## アンインストール

```sh
rm -rf ~/Applications/SafeClipy.app ~/Library/"Application Support"/SafeClipy
security delete-generic-password -s "SafeClipy history key"
```

最後に、アクセシビリティの許可一覧から SafeClipy を削除してください。

## ドキュメント

- [docs/ADR/](docs/ADR/): 設計判断の記録
- [docs/specs/](docs/specs/): 機能の仕様
