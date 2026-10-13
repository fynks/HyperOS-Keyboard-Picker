# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Optional Quick Settings tile (`PickerTileService`) that opens the chooser from
  the shade. It launches `MainActivity` rather than calling the input method API
  from a service, so the picker lifecycle logic exists in exactly one place.
  Uses `startActivityAndCollapse(PendingIntent)`, since the `Intent` overload is
  deprecated as of API 34.

## [1.0.0] - 2026-10-13

First public release.

### Added
- Single-activity launcher that opens Android's native keyboard chooser via
  `InputMethodManager.showInputMethodPicker()`. No custom dialog, no Settings
  detour, no predetermined keyboard.
- `onWindowFocusChanged` state machine (`WAITING -> SHOWN -> CLOSED`) that keeps
  the activity alive while the chooser is open and finishes it once dismissed.
- Delayed first request with a single retry, plus a 10 s give-up timer so a
  refused request cannot strand an idle window. See README for the measurements
  behind this - requesting the chooser without the delay failed on every attempt.
- Adaptive launcher icon using the `keyboard` glyph from Tabler Icons (MIT), with
  a themed monochrome layer.
- `scripts/smoke-test.sh`, which launches the app and asserts which window holds
  focus.

### Toolchain
- AGP 8.5.2 -> 9.4.1, Gradle 8.7 -> 9.8.1, `compileSdk` 35 -> 36,
  `build-tools` 35.0.0 -> 37.0.0. Builds on JDK 17 through 27.
- AGP 9 adds a default `kotlin-stdlib` dependency. The app is pure Java with no
  dependencies, so this bundled ~2 MB of unused Kotlin runtime and inflated the
  APK from 14 KB to 2 MB. Disabled via `kotlin.stdlib.default.dependency=false`
  in `gradle.properties`.

### Compatibility
- `minSdk 34`, `targetSdk 35`, `compileSdk 36`. `targetSdk` is held at 35 rather
  than 36: the chooser is the entire app and 36 is not yet verified on Android 16
  hardware.
- Verified on Android 15 / HyperOS 2.0: chooser opened on 18/18
  launches, and 8/8 at `targetSdk 34`. The concern that Android 15's
  background-activity-launch rules would suppress the dialog did not
  materialise.
- `minSdk` raised from 21 to 34 (Android 14, which is what HyperOS 1 shipped on).
  This makes every supported device newer than API 26, so the five densities of
  legacy bitmap mipmaps became unreachable and were deleted; the APK dropped
  from ~69 KB to ~14 KB.

### Security / privacy
- Zero permissions declared. `showInputMethodPicker()` is public API.
- `android:allowBackup="false"`; the app stores no data.
- Release signing reads `keystore.properties` (git-ignored) when present and
  falls back to the debug key otherwise, so a fresh clone always builds. CI
  reconstructs the keystore from repository secrets, which makes successive tagged
  releases upgrade cleanly over one another instead of each carrying a distinct
  ephemeral signature.