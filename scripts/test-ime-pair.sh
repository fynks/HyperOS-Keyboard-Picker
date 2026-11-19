#!/usr/bin/env bash
# Host-side test for ImeIds: no Android SDK, no dependencies.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

SRC="$TMP/src/com/fynks/keyboardpicker"
mkdir -p "$SRC" "$TMP/classes"
cp "$ROOT/app/src/main/java/com/fynks/keyboardpicker/ImeIds.java" "$SRC/ImeIds.java" 2>/dev/null || true

cat > "$SRC/ImeIdsTest.java" <<'EOF'
package com.fynks.keyboardpicker;

public class ImeIdsTest {
    private static void check(boolean ok, String msg) {
        if (!ok) throw new AssertionError(msg);
    }

    public static void main(String[] args) {
        String swiftkey = "com.touchtype.swiftkey.beta/com.touchtype.KeyboardService";
        String gboard = "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME";

        check(gboard.equals(ImeIds.flip(swiftkey)), "swiftkey flips to gboard");
        check(swiftkey.equals(ImeIds.flip(gboard)), "gboard flips to swiftkey");
        check(ImeIds.flip("com.google.android.tts/voice") == null, "unknown ime has no flip");
        check(ImeIds.flip(null) == null, "null has no flip");
        check("SwiftKey".equals(ImeIds.labelFor(swiftkey)), "swiftkey label");
        check("Gboard".equals(ImeIds.labelFor(gboard)), "gboard label");
        check(ImeIds.labelFor("other") == null, "unknown label");
        check("Gboard".equals(ImeIds.otherLabel(swiftkey)), "other label from swiftkey");
        check(ImeIds.otherLabel("other") == null, "no other label for unknown");
    }
}
EOF

javac -d "$TMP/classes" "$SRC/ImeIds.java" "$SRC/ImeIdsTest.java" || exit 1
java -cp "$TMP/classes" com.fynks.keyboardpicker.ImeIdsTest
