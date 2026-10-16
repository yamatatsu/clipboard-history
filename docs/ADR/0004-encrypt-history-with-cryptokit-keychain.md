# ADR-0004: 履歴を CryptoKit（AES-GCM）で暗号化し、鍵を Keychain に置く

- Status: Accepted
- Date: 2026-10-16

## Context

- 履歴は再起動後も残したい。ディスクに保存する以上、暗号化したい。
- ディスク上の平文が漏れる主な経路は、Time Machine のバックアップ、クラウド同期、ディスクのコピー、他のユーザーアカウントからの読み取り。
- 方式の候補は2つあった。
  - macOS 付属の `openssl`（LibreSSL）: GCM が使えないので、CBC と HMAC の組み合わせを自前で組む必要があり、間違えやすい。
  - CryptoKit: 認証つきの暗号（AES-GCM）を標準 API で使える。
- Keychain には2種類ある。
  - Data Protection Keychain: entitlement（keychain-access-groups）が必要で、それにはプロビジョニングプロファイルが要る。自己署名では使えない。
  - ログインキーチェーン（ファイル型）: entitlement なしで使える。ACL は、項目を作ったアプリの署名に紐づく。

## Decision

- 履歴全体を JSON にして、**CryptoKit の `AES.GCM`（256bit の鍵）** で暗号化し、1つのファイル（`history.enc`）に保存する。
- 鍵は初回の起動時に `SymmetricKey(size: .bits256)` で作り、**ログインキーチェーン** に generic password として保存する。
  - service: `SafeClipy history key`、account: `default`
  - 対象の macOS で使えれば、accessible を `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` にする。
- ファイルの形式や、復号に失敗したときの扱いは [storage-and-encryption.md](../specs/storage-and-encryption.md) で決める。

## Consequences

- バックアップ、同期、ディスクのコピー、他のユーザーアカウントには、暗号文しか見えない。
- 鍵の ACL は SafeClipy の署名に紐づくので、別のアプリが鍵を読もうとすると確認ダイアログが出る。
- 同じユーザー権限で動くマルウェアは、ダイアログを通したり、SafeClipy に処理を差し込んだりして鍵や内容を手に入れる余地がある（守る範囲の外）。
- 鍵をなくすと（Keychain の項目を消す、別の Mac に移るなど）、履歴は戻せない。履歴は消えても困らないデータなので、これは受け入れる。
- スニペットは暗号化しない（[ADR-0006](0006-snippets-plaintext-json.md)）。
