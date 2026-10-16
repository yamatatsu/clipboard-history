# 保存ファイル、暗号化、鍵の扱い

方針は [ADR-0004](../ADR/0004-encrypt-history-with-cryptokit-keychain.md) を参照。

## 保存場所

| パス | パーミッション |
|---|---|
| `~/Library/Application Support/SafeClipy/` | 0700 |
| `~/Library/Application Support/SafeClipy/history.enc` | 0600 |

## ファイルの形式

```
history.enc = magic(4バイト "SCH1") || AES.GCM.SealedBox.combined
               combined = nonce(12バイト) || ciphertext || tag(16バイト)
```

- 暗号化する前の内容は、`HistoryFile` を JSON にしたもの。

  ```swift
  struct HistoryFile: Codable {
      let version: Int        // 今は 1
      var items: [HistoryItem]
  }
  ```

- 追加の認証データ（AAD）として、magic の `"SCH1"` を渡す。
- nonce は保存するたびに新しく作る（CryptoKit の既定の動作）。

## 書き込み

1. 暗号化したデータを、同じディレクトリの一時ファイルに書く（平文の一時ファイルは作らない）
2. `FileManager.replaceItemAt` などで、アトミックに `history.enc` と差し替える
3. パーミッションを 0600 にする

## 鍵

- ログインキーチェーンの generic password に置く。service は `SafeClipy history key`、account は `default`。
- 起動時の流れ:
  - 鍵がある → 読み込む
  - 鍵がなく、`history.enc` もない → 鍵を作って保存する
  - **鍵がないのに `history.enc` がある** → 下の「復号に失敗したとき」と同じ扱いにする
- 鍵はメモリ上の `SymmetricKey` としてだけ持ち、ログには出さない。

## 復号に失敗したとき

鍵がない、改ざんされている、形式が違う、などで読み込めない場合は次のようにする。

1. `history.enc` を `history.enc.unreadable-<yyyyMMddHHmmss>` に名前を変えて残す（**黙って上書きしない**）
2. 空の履歴から始める（鍵がなければ新しく作る）
3. 「履歴を読み込めなかったので、新しく始めます」と1回だけ通知する

## 平文を扱う範囲

- 平文の履歴はメモリの中だけに置く。
- 暗号化する前の JSON を、ファイルやログに出さない。
