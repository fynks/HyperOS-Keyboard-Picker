# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-13

First public release.

### Added
- Single-activity launcher that opens the real system keyboard chooser via the
  public `InputMethodManager.showInputMethodPicker()` API. No custom dialog, no
  Settings detour, no predetermined keyboard.
- `onWindowFocusChanged` state machine (`WAITING -> PICKER_SHOWN -> CLOSED`) that
  keeps the activity alive while the chooser is open and finishes it only after
  the chooser is dismissed.
- Retry once at 1.5 s if window focus never changes, and a 10 s watchdog so a
  failed launch can never leave an invisible activity hanging on screen.
- Adaptive launcher icon (API 26+) plus legacy bitmap mipmaps for API 21-25,
  including a round variant and a monochrome layer for themed icons.

### Security / privacy
- Requests **zero permissions**. `showInputMethodPicker()` is public API.
- `android:allowBackup="false"` with explicit data-extraction rules; the app
  stores no user data of any kind.

### Notes
- `minSdk 21`, `targetSdk 34`, `compileSdk 35`.
- `targetSdk` is intentionally held at 34: Android 15 tightened
  background-activity-launch rules that can suppress a system dialog launched
  from a cold-start launcher activity.
- Release builds are signed with a local debug key. See README for the
  implications before installing over an existing copy.