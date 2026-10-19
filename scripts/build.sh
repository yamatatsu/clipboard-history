#!/bin/bash
# リリースビルドして build/ClipboardHistory.app を作り、固定の証明書で署名する（docs/specs/build-and-signing.md）。
#   ./scripts/build.sh           build/ClipboardHistory.app を作る
#   ./scripts/build.sh install   上に加えて ~/Applications/ClipboardHistory.app に置き換える
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="ClipboardHistory Local Signing"
APP="build/ClipboardHistory.app"
INSTALL_DIR="$HOME/Applications"

swift build -c release --product ClipboardHistory
BIN="$(swift build -c release --show-bin-path)/ClipboardHistory"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ClipboardHistory"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "ビルドしました: $APP"

if [[ "${1:-}" == "install" ]]; then
    if pgrep -x ClipboardHistory >/dev/null; then
        osascript -e 'tell application id "local.clipboardhistory.ClipboardHistory" to quit' || pkill -x ClipboardHistory || true
        sleep 1
    fi
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/ClipboardHistory.app"
    cp -R "$APP" "$INSTALL_DIR/ClipboardHistory.app"
    echo "インストールしました: $INSTALL_DIR/ClipboardHistory.app"
fi
