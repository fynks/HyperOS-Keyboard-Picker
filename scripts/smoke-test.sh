#!/usr/bin/env bash
#
# Smoke test: launch the app N times and check that Android's native keyboard
# chooser actually opened.
#
# The app's entire behaviour is a side effect on another process (a system
# dialog), so this is the only meaningful functional test. It requires a real
# device or emulator and CANNOT run on GitHub-hosted CI without one; the CI
# workflow only builds, lints and verifies release metadata.
#
# Usage: scripts/smoke-test.sh [runs]      (default 6)
#
# Prerequisites:
#   * adb on PATH, exactly one device connected and authorised
#   * the app installed
#   * the ability to inject input events to return to the home screen:
#       - plain `adb shell input` works on most builds, but MIUI/HyperOS denies
#         INJECT_EVENTS to the shell user, so this script falls back to `su -c`
#         when that is available (e.g. KernelSU/Magisk root).
#   * at least two IMEs enabled, otherwise the chooser lists a single entry
#
# Detection is locale independent: it does not match the chooser's title text.
# While the chooser is up, our activity is still the focused *app* but the
# focused *window* belongs to a system dialog rather than to our activity. That
# combination is what this script asserts.

set -uo pipefail

PACKAGE=com.fynks.keyboardpicker
ACTIVITY=".MainActivity"
WAIT_SECONDS="${WAIT_SECONDS:-4}"

die() { echo "error: $*" >&2; exit 2; }

command -v adb >/dev/null 2>&1 || die "adb not found on PATH"

RUNS="${1:-6}"
case "$RUNS" in
    ''|*[!0-9]*) die "repeat count must be a positive integer, got '$RUNS'" ;;
esac
[ "$RUNS" -ge 1 ] || die "repeat count must be at least 1, got '$RUNS'"

DEVICES=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
[ -n "$DEVICES" ] || die "no authorised device found. Connect one and accept the USB debugging prompt."
if [ "$(printf '%s\n' "$DEVICES" | wc -l)" -gt 1 ]; then
    echo "warning: multiple devices connected; using the first ($DEVICES)" >&2
fi
DEVICE=$(printf '%s\n' "$DEVICES" | head -1)

adb -s "$DEVICE" shell pm list packages 2>/dev/null | grep -qx "package:$PACKAGE" \
    || die "$PACKAGE is not installed on $DEVICE"

# HOME via plain adb first; fall back to su where the shell lacks INJECT_EVENTS.
inject_home() {
    if adb -s "$DEVICE" shell input keyevent KEYCODE_HOME >/dev/null 2>&1; then
        return 0
    fi
    if adb -s "$DEVICE" shell su -c "input keyevent KEYCODE_HOME" >/dev/null 2>&1; then
        INPUT_MODE="su"
        return 0
    fi
    return 1
}

INPUT_MODE="adb shell"
inject_home || die "cannot inject KEYCODE_HOME. Enable USB debugging (Security settings) or provide root."

echo "device : $DEVICE"
echo "input  : $INPUT_MODE"
echo "runs   : $RUNS"
echo

# True when our app is the focused app but a window other than our activity
# holds focus: i.e. a system dialog (the chooser) is on top.
chooser_is_open() {
    local windows focused focused_app
    windows=$(adb -s "$DEVICE" shell dumpsys window 2>/dev/null)
    focused=$(printf '%s\n' "$windows" | grep -m1 'mCurrentFocus=')
    focused_app=$(printf '%s\n' "$windows" | grep -m1 'mFocusedApp=')

    # Our activity is still in front...
    printf '%s\n' "$focused_app" | grep -q "$PACKAGE" || return 1
    # ...but the focused window is not one of ours.
    printf '%s\n' "$focused" | grep -q "$PACKAGE" && return 1
    [ -n "$focused" ] || return 1
    return 0
}

pass=0
fail=0
for i in $(seq 1 "$RUNS"); do
    adb -s "$DEVICE" shell am force-stop "$PACKAGE" >/dev/null 2>&1
    adb -s "$DEVICE" shell cmd statusbar collapse >/dev/null 2>&1
    inject_home >/dev/null 2>&1
    sleep 1

    adb -s "$DEVICE" shell am start -n "$PACKAGE/$ACTIVITY" >/dev/null 2>&1

    opened=1
    for _ in $(seq 1 "$WAIT_SECONDS"); do
        sleep 1
        if chooser_is_open; then opened=0; break; fi
    done

    if [ "$opened" -eq 0 ]; then
        pass=$((pass + 1))
        echo "run $i: ok (chooser opened)"
    else
        fail=$((fail + 1))
        focus=$(adb -s "$DEVICE" shell dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus=')
        echo "run $i: FAILED - no system dialog on top of $PACKAGE"
        echo "         focus: ${focus:-unknown}"
    fi

    # Dismiss so runs do not stack up.
    adb -s "$DEVICE" shell su -c "input keyevent KEYCODE_BACK" >/dev/null 2>&1 \
        || adb -s "$DEVICE" shell input keyevent KEYCODE_BACK >/dev/null 2>&1
    sleep 1
done

echo
echo "chooser opened $pass/$RUNS"
if [ "$fail" -ne 0 ]; then
    echo "smoke test FAILED"
    exit 1
fi
echo "smoke test passed"