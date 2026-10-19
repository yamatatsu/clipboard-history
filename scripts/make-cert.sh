#!/bin/bash
# コード署名用の自己署名証明書をログインキーチェーンに作る（ADR-0003）。最初の1回だけ実行する。
set -euo pipefail

NAME="ClipboardHistory Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
OPENSSL=/usr/bin/openssl   # macOS 付属の LibreSSL（security import と相性がよい）

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "証明書「${NAME}」はすでにあります。"
    security find-identity -p codesigning "$KEYCHAIN" | grep "$NAME" || true
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
chmod 700 "$WORK"

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

# p12 は一時的なものなので、使い捨てのパスワードで包む。
P12_PASSWORD="$("$OPENSSL" rand -hex 16)"
export P12_PASSWORD
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$NAME" -out "$WORK/identity.p12" -passout env:P12_PASSWORD

# -T: codesign が確認ダイアログなしで秘密鍵を使えるようにする。
security import "$WORK/identity.p12" -k "$KEYCHAIN" -f pkcs12 -P "$P12_PASSWORD" -T /usr/bin/codesign

echo "証明書「${NAME}」を作成しました。"
security find-identity -p codesigning "$KEYCHAIN" | grep "$NAME" || \
    echo "注意: まだコード署名用として有効になっていません（信頼の設定が必要かもしれません）。"
