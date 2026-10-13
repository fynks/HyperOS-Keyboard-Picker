#!/bin/bash
# Smoke test: launch the app N times and check the system chooser actually opens.
#
# The app's whole behaviour is a side effect on another process, so this is the
# only meaningful test. Requires adb plus the ability to inject input events
# (either Developer options -> USB debugging (Security settings), or root).
#
# Usage: scripts/smoke-test.sh [runs]   (default 6)

set -u
PACKAGE=com.fynks.keyboardpicker
ACTIVITY=.MainActivity
RUNS=${1:-6}

need() { command -v "$1" >/dev/null || { echo "missing: $1"; exit 1; }; }
need adb

adb shell su -c "input keyevent KEYCODE_HOME" >/dev/null 2>&1 \
  || echo "note: no root, relying on plain 'adb shell input'"

pass=0
fail=0
for i in $(seq 1 "$RUNS"); do
  adb shell am force-stop "$PACKAGE"
  adb shell cmd statusbar collapse >/dev/null 2>&1
  adb shell su -c "input keyevent KEYCODE_HOME" >/dev/null 2>&1
  sleep 1
  adb shell am start -n "$PACKAGE/$ACTIVITY" >/dev/null 2>&1
  sleep 3
  focus=$(adb shell dumpsys window 2>/dev/null | grep mCurrentFocus | head -1)
  case "$focus" in
    *"Select input method"*) pass=$((pass + 1)); echo "run $i: ok" ;;
    *) fail=$((fail + 1)); echo "run $i: FAILED (focus: ${focus:-unknown})" ;;
  esac
done

echo
echo "chooser opened $pass/$RUNS"
[ "$fail" -eq 0 ]