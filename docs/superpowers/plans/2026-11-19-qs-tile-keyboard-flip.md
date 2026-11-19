# QS tile keyboard flip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Quick Settings tile flip between SwiftKey and Gboard in one tap, with the native chooser as a fallback.

**Architecture:** A pure, host-testable `ImeIds` class decides which IME is the flip target from a current IME id (the ids live here rather than in `KeyboardFlip` so the decision logic can be tested with plain `javac`, without Android). `KeyboardFlip` does the Android work: read `Settings.Secure.DEFAULT_INPUT_METHOD`, check that both configured IMEs are enabled, run `su -c "ime set <target>"`, and confirm the setting changed. `PickerTileService` calls it off the main thread, updates the tile label/state, and falls back to launching `MainActivity` (the existing chooser) whenever the flip is unavailable or fails. No new Android permissions; root is requested at runtime through KernelSU.

**Tech Stack:** Java 17, Android SDK 36 (`minSdk` 34, `targetSdk` 35), Gradle/AGP as configured, plain `javac` for the host test, adb shell scripts for on-device tests. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-19-qs-tile-keyboard-flip-design.md`

## Global Constraints

- Package: `com.fynks.keyboardpicker`. No new Android dependencies or `<uses-permission>` entries.
- `minSdk = 34`, `targetSdk = 35`, `compileSdk = 36`, Java 17 (copy verbatim from `app/build.gradle`).
- The launcher icon / `MainActivity` chooser path stays unchanged and must remain root-free.
- No logging, no analytics, no network, no settings screen, no custom chooser UI.
- Root executable is KernelSU's `/system/bin/su`; flip command is `ime set <id>`; target ids are hardcoded constants, never user input.
- Exact IME ids: `com.touchtype.swiftkey.beta/com.touchtype.KeyboardService` (SwiftKey) and `com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME` (Gboard). The Google TTS voice IME is deliberately excluded.
- Device for verification: `206b08c4`, Xiaomi 14T Pro `23129RAA4G`, Android 15 / HyperOS `OS2.0.213.0.VNGMIXM`, locale en-GB.
- Restore SwiftKey as the default IME after every on-device test run.

## Review Focus

- **Root denied or revoked** → tile must open the chooser and leave the IME unchanged, never fail silently. Pinned in Task 3 by the KernelSU revoke check.
- **Current IME is neither configured one** (e.g. the voice IME) → flip is unavailable and the chooser opens. Pinned in Task 1 by `flip(VOICE_ID) == null` and in Task 3 by the voice-IME device check.
- **A configured IME is disabled** → no flip, chooser opens. Pinned in Task 3 by the `ime disable` check.
- **Tile label goes stale after a flip** → label and state must match the actual current IME on every refresh. Pinned in Task 3 by asserting the label after each tap.
- **Tile long-press** → opens the chooser, not App Info. Pinned in Task 3 by the `QS_TILE_PREFERENCES` launch check.

---

### Task 1: Pure IME-pair decision logic

**Files:**
- Create: `app/src/main/java/com/fynks/keyboardpicker/ImeIds.java`
- Create: `scripts/test-ime-pair.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `ImeIds` (package-private `final class`, no constructor, no Android imports) with constants `SWIFTKEY_ID`, `GBOARD_ID`, `SWIFTKEY_LABEL`, `GBOARD_LABEL`, and static methods `String flip(String currentId)` (returns the other id, or `null` if `currentId` is neither), `String labelFor(String id)` (returns `SwiftKey`/`Gboard`, or `null`), `String otherLabel(String currentId)` (label of the flip target, or `null`).

- [ ] **Step 1: Write the failing host test**

Create `scripts/test-ime-pair.sh`. It copies `ImeIds.java` into a temp dir, writes a no-dependency `ImeIdsTest.java` with these assertions, compiles both with `javac`, and runs `java -cp "$TMP" ImeIdsTest`:

```java
check(GBOARD_ID.equals(ImeIds.flip(SWIFTKEY_ID)), "swiftkey flips to gboard");
check(SWIFTKEY_ID.equals(ImeIds.flip(GBOARD_ID)), "gboard flips to swiftkey");
check(ImeIds.flip("com.google.android.tts/voice") == null, "unknown ime has no flip");
check(ImeIds.flip(null) == null, "null has no flip");
check("SwiftKey".equals(ImeIds.labelFor(SWIFTKEY_ID)), "swiftkey label");
check("Gboard".equals(ImeIds.labelFor(GBOARD_ID)), "gboard label");
check(ImeIds.labelFor("other") == null, "unknown label");
check("Gboard".equals(ImeIds.otherLabel(SWIFTKEY_ID)), "other label from swiftkey");
check(ImeIds.otherLabel("other") == null, "no other label for unknown");
```

Use the exact id/label constants from Global Constraints. `check` throws `AssertionError` with the message on failure; script exits non-zero.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/test-ime-pair.sh`
Expected: FAIL — `javac` reports `ImeIds.java` missing.

- [ ] **Step 3: Implement `ImeIds`**

Implement the class with the exact constants and method signatures from Interfaces. Bodies are pure string comparisons; no Android imports.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash scripts/test-ime-pair.sh`
Expected: PASS, no output.

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/com/fynks/keyboardpicker/ImeIds.java scripts/test-ime-pair.sh
git commit -m "feat: add pure IME pair decision logic and host test"
```

---

### Task 2: Flip executor, tile integration, and on-device verification

**Files:**
- Create: `app/src/main/java/com/fynks/keyboardpicker/KeyboardFlip.java`
- Modify: `app/src/main/java/com/fynks/keyboardpicker/PickerTileService.java`
- Modify: `app/src/main/AndroidManifest.xml`
- Modify: `app/src/main/res/values/strings.xml`
- Create: `scripts/flip-test.sh`

**Interfaces:**
- Consumes: `ImeIds` from Task 1.
- Produces: `KeyboardFlip` (package-private `final class`) with enum `Result { SWITCHED, UNAVAILABLE, FAILED }`, constructor `KeyboardFlip(Context context)`, methods `String currentId()`, `boolean pairAvailable()` (true only when both ids appear in `InputMethodManager.getEnabledInputMethodList()`), and `Result flip()`. `flip()` returns `UNAVAILABLE` when `ImeIds.flip(current)` is null or `pairAvailable()` is false; otherwise runs `su -c "ime set <target>"` with `ProcessBuilder`, `redirectErrorStream(true)`, a 3-second `waitFor`, then re-reads `currentId()` and returns `SWITCHED` only if it equals the target, else `FAILED`.

- [ ] **Step 1: Write the failing on-device flip test**

Create `scripts/flip-test.sh`. Preflight: one authorised device, `com.fynks.keyboardpicker` installed, and root available (`su -c id` returns uid 0). It defines `current_ime()` as `settings get secure default_input_method`, `tap_tile()` as: `cmd statusbar expand-notifications`, `uiautomator dump /sdcard/qs.xml`, extract the `bounds="[x1,y1][x2,y2]"` of the node whose `text` contains `SwiftKey` or `Gboard`, `input tap` its centre, then `cmd statusbar collapse`. Fail with a clear "add the Keyboard Picker tile to the shade first" message if no such node exists.

Test sequence:
1. Assert current IME is one of the two configured ids; save it as `start`.
2. `tap_tile`; poll up to 3 s; assert current IME equals the flipped id; assert the tile label in a fresh `uiautomator dump` equals the new IME's label.
3. `tap_tile` again; poll; assert current IME equals `start` and the label equals `start`'s label.
4. Assert long-press routing with `am start -a android.service.quicksettings.action.QS_TILE_PREFERENCES -n com.fynks.keyboardpicker/.MainActivity`, then assert a system dialog has focus while our activity is the focused app (same check as `scripts/smoke-test.sh`).
5. Restore `start` with `su -c "ime set <start>"` in an `EXIT` trap.

Run: `adb install -r app/build/outputs/apk/debug/app-debug.apk`, add the tile to the shade once manually, then `bash scripts/flip-test.sh`.
Expected: FAIL — the current tile opens the chooser, so the IME never changes.

- [ ] **Step 2: Implement `KeyboardFlip`**

Implement the class to the Interfaces contract. Read the setting with `Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD)`. The `su` argument is built only from the hardcoded id constants, never from free text.

- [ ] **Step 3: Wire the tile**

In `PickerTileService.onClick()`, call `flip()` on a single background executor, then post the result back to the main thread with `new Handler(Looper.getMainLooper())`. On `SWITCHED`, refresh the tile. On `UNAVAILABLE` or `FAILED`, show a short Toast (string `tile_fallback_toast`) and call the existing `startActivityAndCollapse` chooser fallback. In `onStartListening()`, refresh the tile: `setLabel(ImeIds.labelFor(currentId()))` falling back to `tile_label` when there is no known label), `setIcon(Icon.createWithResource(this, R.drawable.ic_tile_keyboard))`, `setState(STATE_ACTIVE)` for SwiftKey and `STATE_INACTIVE` otherwise, and `setStateDescription` from `tile_state_switch_to` with `ImeIds.otherLabel(...)`, or `tile_state_open_chooser` when there is no flip target. Call `updateTile()`. Do not add `ACTIVE_TILE` metadata; the tile is refreshed when the shade opens.

- [ ] **Step 4: Add the long-press route and strings**

Add an `<intent-filter>` with action `android.service.quicksettings.action.QS_TILE_PREFERENCES` to `MainActivity` in `AndroidManifest.xml`, leaving its launcher intent-filter intact. Add `tile_fallback_toast`, `tile_state_switch_to` (format `%1$s`), and `tile_state_open_chooser` to `res/values/strings.xml`.

- [ ] **Step 5: Rebuild and re-run the on-device test**

Run: `./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk && bash scripts/flip-test.sh`
Expected: PASS — IME flips both ways, labels match, long-press opens the chooser, and SwiftKey is restored.

- [ ] **Step 6: Verify the failure-mode cases on device**

Perform these manual checks with explicit expected results:
- In KernelSU, turn off root for Keyboard Picker, tap the tile: expected — native chooser opens, IME unchanged, short fallback toast. Re-enable root afterwards.
- With root on, run `adb shell ime set com.google.android.tts/com.google.android.apps.speech.tts.googletts.settings.asr.voiceime.VoiceInputMethodService`, tap the tile: expected — chooser opens (no flip). Restore SwiftKey.
- Run `adb shell ime disable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME`, tap the tile: expected — chooser opens. Then `ime enable` it and restore SwiftKey.

- [ ] **Step 7: Check for chooser-path regression**

Run: `bash scripts/smoke-test.sh 6`
Expected: `chooser opened 6/6` and `smoke test passed`.

- [ ] **Step 8: Commit**

```bash
git add app/src/main/java/com/fynks/keyboardpicker/KeyboardFlip.java app/src/main/java/com/fynks/keyboardpicker/PickerTileService.java app/src/main/AndroidManifest.xml app/src/main/res/values/strings.xml scripts/flip-test.sh
git commit -m "feat: flip keyboards from the Quick Settings tile"
```

---

### Task 3: Documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the behaviour implemented in Tasks 1–2.
- Produces: no code interfaces.

- [ ] **Step 1: Update the README**

Document that the tile flips SwiftKey ↔ Gboard in one tap, that long-press and the launcher icon open the native chooser, that the tile shows the active keyboard, and that root is granted once through KernelSU and used only for the flip. Replace the absolute "zero permissions / no root" phrasing with: no Android permissions declared; root used only for the tile flip. Add the two new test scripts to the Testing section with their prerequisites.

- [ ] **Step 2: Update the CHANGELOG**

Add entries under `[Unreleased]` for the tile flip, the active-keyboard label, the long-press chooser route, and the KernelSU root requirement.

- [ ] **Step 3: Run the full verification set**

Run: `./gradlew assembleDebug && bash scripts/test-ime-pair.sh && bash scripts/flip-test.sh && bash scripts/smoke-test.sh 6`
Expected: all pass; SwiftKey restored as the default IME.

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document the Quick Settings flip tile"
```
