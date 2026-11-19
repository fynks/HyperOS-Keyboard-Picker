# QS tile as a two-keyboard flip switch — design

Date: 2026-11-19
Status: proposed, awaiting approval

## Intent and why

On this device the user has three IMEs enabled but only ever picks two by hand:
SwiftKey Beta (default) and Gboard. The third, Google TTS voice IME, is enabled
but never chosen manually, yet the system chooser still lists it on every
launch. Opening the chooser to get from one real keyboard to the other is
therefore two-plus taps and a dialog for what is really a binary toggle.

The Quick Settings tile becomes that toggle: one tap flips between the two
keyboards actually used on this device. The launcher icon stays as it is.

## Goals

- One tap in the shade switches SwiftKey ↔ Gboard, with no system dialog.
- The tile shows which keyboard is currently active.
- The native chooser remains reachable as an escape hatch (launcher icon, and
  long-press on the tile).
- The existing chooser path is not regressed.

## Non-goals

- No per-app or contextual auto-switching.
- No settings screen, onboarding, analytics, network access or logging.
- No custom keyboard-picker UI; the system chooser stays the escape hatch.
- No support for devices other than this one (see Constraints).

## Anti-goals (what would make this a failure)

- The flip silently does nothing and leaves the user unsure which keyboard is
  active.
- Losing access to the chooser if root is denied or revoked.
- The app gaining Android permissions it does not need.

## Constraints and device facts

- Device: Xiaomi 14T Pro `23129RAA4G` (`sapphire_global`, `bengal`), Android 15
  / HyperOS `OS2.0.213.0.VNGMIXM`, locale en-GB, MIUI launcher, 1080x2400 @440dpi.
- Enabled IMEs: `com.touchtype.swiftkey.beta/com.touchtype.KeyboardService`
  (SwiftKey, default), `com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME`
  (Gboard), and the Google TTS voice IME. `input_methods_subtype_history`
  contains only SwiftKey and Gboard.
- `adb shell ime set <id>` switches instantly and was verified on-device; the
  original IME (SwiftKey) was restored afterwards.
- AOSP: `InputMethodManager.setInputMethod(null, id)` returns without doing
  anything unless the caller holds `WRITE_SECURE_SETTINGS`, which is
  signature-level. The `ime` shell command works only because the shell is
  privileged. Therefore a normal app cannot flip via public API alone.
- Root is available through KernelSU: `/system/bin/su`, context `u:r:ksu:s0`.
- The app currently declares no permissions. This change adds no manifest
  permission; it asks KernelSU for root once, at runtime, and only for the flip.

## Approaches considered

1. **Root at runtime (chosen).** The app runs `su -c "ime set <id>"` through
   KernelSU, then re-reads the setting to confirm. One-time root grant; no
   system-partition changes; reversible. Cost: the app is no longer strictly
   "zero permission" and is tied to a rooted device.
2. **System/priv-app install with `WRITE_SECURE_SETTINGS`.** No runtime root
   prompt; the app writes `Settings.Secure.DEFAULT_INPUT_METHOD` directly.
   Rejected: needs a KernelSU module that modifies HyperOS's read-only system
   partition, is tied to this ROM build, and is harder to undo.
3. **Keep the chooser and make it smarter.** Add IME preflight checks and a
   better failure message. Rejected by the user as the primary approach: it
   does not remove the dialog from the common path. It remains the fallback
   behaviour when root is unavailable.

## Decided design

### Behaviour

- **Launcher icon — unchanged.** `MainActivity` still opens the native
  chooser. This is a deliberate call: it preserves the documented home-screen
  promise and guarantees a root-free escape hatch.
- **Tile tap — flip.**
  1. Read the active IME from `Settings.Secure.DEFAULT_INPUT_METHOD` (readable
     with no permission).
  2. Pick the configured IME that is not currently active. If the current IME
     is neither of the two, or either configured IME is not enabled, treat the
     flip as unavailable and fall back to the chooser.
  3. Run `su -c "ime set <target>"` with `ProcessBuilder`, on a background
     thread, with a short timeout. Re-read `DEFAULT_INPUT_METHOD` to confirm.
  4. On confirmed success, update the tile. On failure (no `su`, denied,
     non-zero exit, or setting unchanged), show a short toast and open the
     native chooser instead. No crash, no silent no-op.
- **Tile long-press — chooser.** Add an intent-filter for
  `android.service.quicksettings.action.QS_TILE_PREFERENCES` to `MainActivity`.
  Android sends long-press there instead of App Info; the existing activity
  opens the chooser. (Tiles have no long-click callback of their own.)
- **Tile presentation.** `Tile.setLabel()` is available on API 35: show
  `SwiftKey` / `Gboard`. Use `STATE_ACTIVE` for SwiftKey (the device default)
  and `STATE_INACTIVE` for Gboard so the two states are visually distinct, and
  `setStateDescription("Switch to <other>")` for accessibility. Use a plain
  non-active tile (no `ACTIVE_TILE` metadata); `onStartListening()` is called
  whenever the shade opens, which refreshes the label naturally.

### Structure

- New `KeyboardFlip.java` in `com.fynks.keyboardpicker`: holds the two IME ids,
  reads the current IME, decides the target, runs `su`, and reports success or
  the reason for failure. No Android UI in this class.
- `PickerTileService.java`: calls the helper, updates the tile, and falls back
  to `startActivityAndCollapse` launching `MainActivity` when the flip is not
  available.
- `AndroidManifest.xml`: add the `QS_TILE_PREFERENCES` intent-filter to
  `MainActivity`. No new `<uses-permission>`.
- `res/values/strings.xml`: tile state descriptions and the fallback toast.
- `README.md` / `CHANGELOG.md`: document the tile behaviour, the one-time
  KernelSU grant, and the honest privacy wording (no Android permissions;
  root used only for the flip).
- `scripts/smoke-test.sh`: unchanged for the chooser path; add a documented
  manual check for the flip until it can be driven reliably from adb.

### Choices left to the implementer

- Exact timeout for the `su` process (suggest 3 s) and the toast wording.
- Whether to keep the existing keyboard glyph or add a tiny per-IME badge;
  default is to keep the existing icon and rely on the label.

## Verification

- `./gradlew assembleDebug` and install over the current build.
- Chooser path: `scripts/smoke-test.sh 6` must still pass 6/6.
- Flip path on device: with the shade open, read the tile label, tap it, then
  assert `settings get secure default_input_method` changed to the other IME;
  repeat in both directions and restore SwiftKey at the end.
- Fallback path: deny/revoke root for the app in KernelSU, tap the tile, and
  confirm the native chooser opens instead of a silent failure.
- Long-press: confirm it launches the chooser, not App Info.
