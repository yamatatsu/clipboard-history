#!/bin/bash
# リリースビルドして build/SafeClipy.app を作り、固定の証明書で署名する（docs/specs/build-and-signing.md）。
#   ./scripts/build.sh           build/SafeClipy.app を作る
#   ./scripts/build.sh install   上に加えて ~/Applications/SafeClipy.app に置き換える
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="SafeClipy Local Signing"
APP="build/SafeClipy.app"
INSTALL_DIR="$HOME/Applications"

swift build -c release --product SafeClipy
BIN="$(swift build -c release --show-bin-path)/SafeClipy"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SafeClipy"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "ビルドしました: $APP"

if [[ "${1:-}" == "install" ]]; then
    if pgrep -x SafeClipy >/dev/null; then
        osascript -e 'tell application id "local.safeclipy.SafeClipy" to quit' || pkill -x SafeClipy || true
        sleep 1
    fi
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/SafeClipy.app"
    cp -R "$APP" "$INSTALL_DIR/SafeClipy.app"
    echo "インストールしました: $INSTALL_DIR/SafeClipy.app"
fi
