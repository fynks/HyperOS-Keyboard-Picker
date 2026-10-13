# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Adaptive launcher icon (API 26+) with a themed monochrome layer, plus legacy
  bitmap mipmaps and round variants for API 21-25.
- `scripts/smoke-test.sh`, which launches the app and asserts which window holds
  focus.

### Compatibility
- `minSdk 21`, `targetSdk 35`, `compileSdk 35`.
- Verified on Android 15 / HyperOS 2.0: chooser opened on 18/18 launches at
  `targetSdk 35`, and 8/8 at `targetSdk 34`. The concern that Android 15's
  background-activity-launch rules would suppress the dialog did not
  materialise, so `targetSdk` matches `compileSdk`.

### Security / privacy
- Zero permissions declared. `showInputMethodPicker()` is public API.
- `android:allowBackup="false"`; the app stores no data.
- Release builds are signed with a local debug key held outside the repository.