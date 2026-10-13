#!/usr/bin/env bash
#
# Validate that release version metadata is internally consistent.
#
#   scripts/check-release-version.sh [tag]
#
# With no argument the tag is taken from $GITHUB_REF_NAME when running in CI.
# Checks performed:
#   1. the Gradle versionName matches the tag (tags only)
#   2. versionName matches semver-ish MAJOR.MINOR.PATCH
#   3. versionCode is a positive integer
#   4. if an APK is supplied, its package/versionName/versionCode match Gradle
#
# Exits non-zero with an actionable message on any failure. On a branch or pull
# request only checks 2 and 3 run, so ordinary development builds are unaffected.

set -euo pipefail

cd "$(dirname "$0")/.."

GRADLE_FILE="app/build.gradle"
APK="${APK:-}"

# Note: ${1-} not ${1:-}. A caller that deliberately passes an empty string (CI
# does, for branch builds) must not fall back to GITHUB_REF_NAME, which on a
# branch push is the branch name and is not a version tag.
if [ "$#" -ge 1 ]; then
    TAG="$1"
elif [ -n "${GITHUB_REF:-}" ]; then
    case "$GITHUB_REF" in
        refs/tags/v*) TAG="${GITHUB_REF#refs/tags/}" ;;
        *) TAG="" ;;
    esac
else
    TAG=""
fi

fail() {
    echo "::error::Version validation failed: $1"
    exit 1
}

command -v grep >/dev/null || fail "grep is required but was not found"

[ -f "$GRADLE_FILE" ] || fail "$GRADLE_FILE not found"

VERSION_NAME=$(grep -oE 'versionName[[:space:]]*=[[:space:]]*"[^"]+"' "$GRADLE_FILE" \
    | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
VERSION_CODE=$(grep -oE 'versionCode[[:space:]]*=[[:space:]]*[0-9]+' "$GRADLE_FILE" \
    | head -1 | grep -oE '[0-9]+')

[ -n "$VERSION_NAME" ] || fail "could not read versionName from $GRADLE_FILE"
[ -n "$VERSION_CODE" ] || fail "could not read versionCode from $GRADLE_FILE"

echo "Gradle versionName : $VERSION_NAME"
echo "Gradle versionCode : $VERSION_CODE"

if [[ ! "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    fail "versionName '$VERSION_NAME' is not MAJOR.MINOR.PATCH"
fi

if (( VERSION_CODE < 1 )); then
    fail "versionCode must be 1 or greater, found $VERSION_CODE"
fi

# Tag comparison only makes sense for a release build.
if [[ -n "$TAG" ]]; then
    case "$TAG" in
        v*) ;;
        *) fail "tag '$TAG' must start with 'v' (expected e.g. v1.1.0)" ;;
    esac
    TAG_VERSION="${TAG#v}"
    TAG_VERSION="${TAG_VERSION%%-*}"

    if [ "$TAG_VERSION" != "$VERSION_NAME" ]; then
        fail "tag '$TAG' does not match versionName '$VERSION_NAME' in $GRADLE_FILE.
    Either the Gradle version is wrong, or the tag is. Fix the source, then re-run:
      versionName = \"$TAG_VERSION\"   # in $GRADLE_FILE
    Note: existing published tags must not be rewritten - bump the version instead."
    fi
    echo "Tag $TAG matches versionName"
else
    echo "No tag supplied - skipping tag comparison (development build)"
fi

# APK cross-check, when aapt2 is available and an APK was supplied.
if [ -n "$APK" ] && [ -f "$APK" ]; then
    AAPT2="${AAPT2:-}"
    if [ -z "$AAPT2" ]; then
        for candidate in "${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}/build-tools/"*/aapt2; do
            [ -x "$candidate" ] && AAPT2="$candidate" && break
        done
    fi
    if [ -z "$AAPT2" ]; then
        echo "::warning::aapt2 not found; skipping APK metadata check"
    else
        BADGING=$("$AAPT2" dump badging "$APK" 2>/dev/null | head -5)
        echo "$BADGING" | grep -q "versionName='$VERSION_NAME'" \
            || fail "APK versionName does not match Gradle '$VERSION_NAME' (see: $BADGING)"
        echo "$BADGING" | grep -q "versionCode='$VERSION_CODE'" \
            || fail "APK versionCode does not match Gradle '$VERSION_CODE' (see: $BADGING)"
        echo "$BADGING" | grep -q "name='com.fynks.keyboardpicker'" \
            || fail "APK applicationId is not com.fynks.keyboardpicker"
        echo "APK metadata matches Gradle"
    fi
fi

echo "Version validation passed"