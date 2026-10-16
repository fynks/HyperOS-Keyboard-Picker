# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-10-17

### Fixed
- `versionName` corrected from `1.0.0` to `1.1.0`. The published `v1.1.0` APK
  disagreed with its own tag, because `versionName` was left behind when the tile
  bumped `versionCode` to 5. `versionCode` was correct, so upgrades were never
  affected; only the reported version string was wrong. Not repackaged or
  re-tagged, since rewriting a published tag would break the checksums people have
  already downloaded.
- `MainActivity`: a focus loss arriving *before* the chooser was ever requested
  (notification shade, a system dialog, the screen turning off) was treated as
  proof the chooser had opened, which could finish the activity before it ever
  appeared. `IDLE` and `PENDING` are now distinct states, and only focus loss
  after an actual request counts as evidence.
- `MainActivity`: the retry and give-up callbacks are now held as fields. A method
  reference creates a new instance on each evaluation, so
  `removeCallbacks(this::retryChooser)` could never match the posted runnable and
  was silently a no-op.
- Layout colours moved from hardcoded literals to `res/values/colors.xml`.
- The Quick Settings tile reused the launcher's adaptive-icon foreground as its
  icon. That is a 108dp canvas whose glyph sits in the safe zone, and the shade
  draws tile icons as-is, so the keyboard rendered at roughly a third of the
  size of the tiles around it. The tile now has a dedicated 24dp full-bleed
  icon (`ic_tile_keyboard`).
- The keyboard glyph's key dots sat at x = 7, 11, 15, 19 instead of the
  Tabler source's 6, 10, 14, 18, so the key rows were shifted 1dp right and
  the spacebar (correctly at 10–14) appeared off-centre — most visibly in the
  tile, where the glyph fills its canvas. Fixed in the tile icon and the
  launcher foreground.

### Added
- `scripts/check-release-version.sh`, wired into CI. It fails a tagged build when
  the tag and Gradle `versionName` disagree, and cross-checks the built APK's own
  version metadata. Branch and pull-request builds skip the tag comparison.
- CI restores the SDK component cache *before* installing components, so the
  cache is actually used rather than only written.
- Release notes generated from the verified APK: "What's changed", install and
  upgrade instructions, `sha256sum -c` verification for Linux and macOS, and the
  signing certificate's SHA-256 fingerprint, read from the artifact rather than
  hardcoded.
- Material-style adaptive launcher icon: the palette is driven from
  `values/colors.xml` and `values-night/colors.xml` — a soft white shade with
  the navy glyph in light mode, the opposite dark shade with the white glyph
  at night. The existing `monochrome` layer keeps live Material You themed
  icons working.

### Changed
- `scripts/smoke-test.sh` now implements its documented input fallback correctly
  (plain `adb shell input` first, `su` only if that is denied) and detects the
  chooser without depending on its English title: it asserts that our activity is
  still the focused app while a window other than ours holds focus. Exit status
  is non-zero on failure, and missing adb, no device, and invalid repeat counts
  are reported distinctly.

### Documentation
- README: project tree corrected to include `PickerTileService`, an
  Android 14 / 15 / 16+ compatibility table marking unverified configurations,
  a troubleshooting section, and smoke-test prerequisites and limitations.
- README: repaired the broken "Install and use" section (a duplicated heading
  with an unclosed code fence), and updated the icon notes for the night
  palette, themed icons, and the dedicated tile icon.

### Verified
- On Android 15 / HyperOS 2.0 (23129RAA4G) over wireless ADB: the tile icon
  renders at the same visual size as the neighbouring system tiles, the spacebar
  is centred, and the launcher icon renders the light palette in light mode and
  the dark palette at night (after a launcher restart — the HyperOS launcher
  re-renders icons on process restart or reinstall, not live on a dark-mode
  toggle).
- Previous session's fixes (focus handling, version metadata) verified on the
  same device with the debug build.

## [1.1.0] - 2026-10-13

### Added
- Optional Quick Settings tile (`PickerTileService`) that opens the chooser from
  the shade. It launches `MainActivity` rather than calling the input method API
  from a service, so the picker lifecycle logic exists in exactly one place.
  Uses `startActivityAndCollapse(PendingIntent)`, since the `Intent` overload is
  deprecated as of API 34.
- `versionCode` 4 -> 5 for the new feature.

### Verified
- On Android 15 / HyperOS 2.0: SystemUI binds the tile, tapping it opens the
  native chooser 6/6, and dismissing leaves 0 activity records behind.

### Docs
- Store listing copy and privacy wording updated for the tile. The previous
  "zero permissions" phrasing was imprecise: the app declares no
  `<uses-permission>` entries, but the tile is gated by a system permission on
  the service.

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