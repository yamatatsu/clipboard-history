#!/bin/bash
# Command Line Tools だけで swift-testing を動かす。
# CLT の Testing.framework は既定の検索パスにないため、明示的に指定する。
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)/Library/Developer"
exec swift test \
    -Xswiftc -F"$DEV/Frameworks" \
    -Xlinker -F"$DEV/Frameworks" \
    -Xlinker -rpath -Xlinker "$DEV/Frameworks" \
    -Xlinker -rpath -Xlinker "$DEV/usr/lib" \
    "$@"
