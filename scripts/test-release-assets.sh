#!/usr/bin/env bash
# Check that the release screenshots exist and are cropped to the QS panel.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
check() {
    local file="$1" expected="$2" size
    if [ ! -f "$file" ]; then
        echo "error: $file is missing" >&2
        status=1
        return
    fi
    size=$(identify -format '%wx%h' "$file" 2>/dev/null)
    if [ "$size" != "$expected" ]; then
        echo "error: $file is $size, expected $expected" >&2
        status=1
    fi
}

check docs/release/tile-swiftkey.png 1080x850
check docs/release/chooser.png 1080x930

[ "$status" -eq 0 ] && echo "release assets OK"
exit "$status"
