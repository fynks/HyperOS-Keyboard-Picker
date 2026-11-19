#!/usr/bin/env bash
# On-device test for the Quick Settings keyboard flip tile.
set -uo pipefail

PACKAGE=com.fynks.keyboardpicker
TILE=com.fynks.keyboardpicker/.PickerTileService
SWIFTKEY=com.touchtype.swiftkey.beta/com.touchtype.KeyboardService
GBOARD=com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME

die() { echo "error: $*" >&2; exit 2; }

command -v adb >/dev/null 2>&1 || die "adb not found on PATH"
DEVICE=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}' | head -1)
[ -n "$DEVICE" ] || die "no authorised device found"
A=(adb -s "$DEVICE")

"${A[@]}" shell pm list packages 2>/dev/null | grep -qx "package:$PACKAGE" || die "$PACKAGE is not installed"
"${A[@]}" shell su -c id 2>/dev/null | grep -q 'uid=0' || die "root unavailable on $DEVICE"

current_ime() { "${A[@]}" shell settings get secure default_input_method 2>/dev/null | tr -d '\r'; }

# The shade animation can swallow the first tap; retry until the state changes.
tap_until() {
    local want="$1"
    local attempt _
    for attempt in 1 2 3; do
        "${A[@]}" shell input tap 174 462 >/dev/null 2>&1
        for _ in 1 2 3 4; do
            sleep 1
            [ "$(current_ime)" = "$want" ] && return 0
        done
    done
    return 1
}

start=$(current_ime)
case "$start" in
    "$SWIFTKEY") expected="$GBOARD" ;;
    "$GBOARD") expected="$SWIFTKEY" ;;
    *) die "current IME is neither configured keyboard: $start" ;;
esac

cleanup() {
    "${A[@]}" shell cmd statusbar collapse >/dev/null 2>&1
    "${A[@]}" shell input keyevent KEYCODE_BACK >/dev/null 2>&1
    "${A[@]}" shell su -c "ime set $start" >/dev/null 2>&1
}
trap cleanup EXIT

"${A[@]}" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
"${A[@]}" shell am force-stop "$PACKAGE" >/dev/null 2>&1
"${A[@]}" shell input keyevent KEYCODE_BACK >/dev/null 2>&1
"${A[@]}" shell input keyevent KEYCODE_BACK >/dev/null 2>&1
"${A[@]}" shell cmd statusbar collapse >/dev/null 2>&1
"${A[@]}" shell cmd statusbar add-tile "$TILE" >/dev/null 2>&1 || die "could not add the tile"
"${A[@]}" shell cmd statusbar expand-settings >/dev/null 2>&1
sleep 3
for _ in 1 2 3 4 5; do
    sleep 1
    "${A[@]}" shell dumpsys activity services "$PACKAGE" 2>/dev/null | grep -q PickerTileService && break
done
"${A[@]}" shell dumpsys activity services "$PACKAGE" 2>/dev/null | grep -q PickerTileService \
    || die "SystemUI never bound the tile"

# On this ROM `cmd statusbar click-tile` dispatches onClick twice, so use real taps.
# The Keyboard Picker tile is the first tile in the expanded shade at 1080x2400.
tap_until "$expected" || die "tile tap did not switch to $expected (got $(current_ime))"
tap_until "$start" || die "second tile tap did not restore $start (got $(current_ime))"

"${A[@]}" shell input swipe 174 462 174 462 1200 >/dev/null 2>&1
sleep 2
windows=$("${A[@]}" shell dumpsys window 2>/dev/null)
focused_app=$(printf '%s\n' "$windows" | grep -m1 'mFocusedApp=')
focused=$(printf '%s\n' "$windows" | grep -m1 'mCurrentFocus=')
printf '%s' "$focused_app" | grep -q "$PACKAGE" \
    || die "long-press did not launch MainActivity (app: ${focused_app:-none})"
printf '%s' "$focused" | grep -q "$PACKAGE" \
    && die "long-press opened our window instead of the chooser"
[ -n "$focused" ] || die "long-press left no focused window"

echo "flip test passed"
