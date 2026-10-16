# Keyboard Picker

[![Latest release](https://img.shields.io/github/v/release/fynks/HyperOS-Keyboard-Picker?label=release)](https://github.com/fynks/HyperOS-Keyboard-Picker/releases/latest)
[![Build](https://github.com/fynks/HyperOS-Keyboard-Picker/actions/workflows/android.yml/badge.svg)](https://github.com/fynks/HyperOS-Keyboard-Picker/actions/workflows/android.yml)
[![License: MIT](https://img.shields.io/github/license/fynks/HyperOS-Keyboard-Picker)](https://github.com/fynks/HyperOS-Keyboard-Picker/blob/main/LICENSE)

An Android launcher that opens the system's own keyboard chooser — the same
"Choose input method" dialog as the keyboard-switch button in the navigation
bar — with one tap from the home screen or the Quick Settings shade.

The activity calls exactly one public API:

```java
InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
imm.showInputMethodPicker();
```

![The system keyboard chooser, opened by Keyboard Picker](docs/screenshot.png)

## What it does

- Opens Android's native keyboard chooser
- Closes itself as soon as you dismiss the chooser
- Adds an optional Quick Settings tile, so the chooser can be opened from the
  shade without going to the home screen

There are two ways in, and one implementation behind both:

- **Home-screen icon** — `MainActivity` calls
  `InputMethodManager.showInputMethodPicker()` directly.
- **Quick Settings tile** — `PickerTileService` does *not* touch the input method
  API. Android's tile integration collapses the shade and launches that same
  `MainActivity` via `startActivityAndCollapse`.

## What it does not do

- It does not switch to a keyboard for you — the choice is always yours
- It does not draw its own dialog or imitate the system one
- It does not open Settings
- It has no settings screen, no onboarding, no configuration
- It has no network access, no analytics and no ads
- It does not log anything

## Requirements and compatibility

**Minimum supported: Android 14 (API 34).** `minSdk` is 34; the app will not
install on anything older.

Two or more keyboards must be enabled, or the chooser lists a single entry:
*Settings → Additional settings → Languages & input → Keyboard management*.

| Configuration | Status |
|---|---|
| Android 14 / HyperOS 1 (API 34) | **Unverified** — permitted by `minSdk`, but never run on this hardware |
| Android 15 / HyperOS 2 (API 35) | **Verified** — chooser opened on 18/18 launches; Quick Settings tile 6/6 |
| Android 16+ (API 36+) | **Unverified** — `targetSdk` is held at 35 pending testing |

"Unverified" means the app is allowed to run there by `minSdk`, but no test was
performed on such a device. If you have one, please [open an issue](https://github.com/fynks/HyperOS-Keyboard-Picker/issues/new/choose).

`targetSdk` is deliberately 35 rather than 36: the chooser is the entire app, and
raising it without hardware to test on would risk the one behaviour that matters.

No runtime permissions are requested, because `showInputMethodPicker()` is
public API. The Quick Settings tile uses a system permission described under
[Privacy](#privacy).

## Install and use

1. Download `app-release.apk` from the [Releases](../../releases) page, and install it.
2. **From the home screen:** tap **Keyboard Picker**, pick a keyboard, and the appis gone.
3. **From Quick Settings:** pull the shade down, tap the pencil/edit icon, find **Keyboard Picker**, and drag it into the tile area. Tapping it opens the same chooser and collapses the shade. To remove it later, edit the shade again and drag it back out.

> Releases are signed with a long-lived key and upgrade cleanly over each other.
> If you have a build installed that was signed with a *different* key (an early
> debug-signed build, or one from another machine), the install will fail with
> `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Remove the old copy firstadn then install the new one from the release page.

## Troubleshooting

**Nothing appears when I tap the icon.**
The request was refused. This is the app's main failure mode and it is silent by
design. Check, in order:

1. *Are two or more keyboards enabled?* With only one, there is nothing to pick.
   *Settings → Additional settings → Languages & input → Keyboard management.*
2. *Are you on Android 14 or newer?* Anything below API 34 cannot install it.
3. On MIUI/HyperOS, try the per-app **"Display pop-up windows while running in
   the background"** setting (*Settings → Apps → Keyboard Picker → Other
   permissions*). Not normally required, since the activity is foreground when the
   request is made, but it is the first thing to try on heavily modified ROMs.

**A dark screen appears and then disappears.**
That is the app working: the opaque activity is visible for a moment while it
waits, and it closes itself if the chooser does not open within 10 seconds.

**The app does not appear in the Quick Settings edit list.**
Only installed, enabled builds appear. Reinstall, then open the shade's edit mode
again.

**The chooser flashes and closes immediately.**
Report it with your device model and Android/HyperOS version via the [issue
template](.github/ISSUE_TEMPLATE/bug_report.yml) — this is a bug, not expected
behaviour.


## Build

Requires JDK 17 or newer (verified on 17 and 27) and the Android SDK with
`platforms;android-36` and `build-tools;37.0.0`.

```bash
export ANDROID_HOME="$HOME/android-sdk"
git clone <this-repo>
cd <this-repo>
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release.apk`

Point Gradle at your SDK with the `ANDROID_HOME` environment variable, or a
git-ignored `local.properties` containing `sdk.dir=/path/to/sdk`.

### Signing

Release builds use a real signing key if one is configured, and fall back to the
Android debug key otherwise, so a fresh clone always builds. To sign properly,
generate a keystore once and keep it — losing it means you can never update an
already-published build without uninstalling first.

```bash
keytool -genkeypair -v -keystore ~/keyboard-picker-release.jks \
  -alias keyboardpicker -keyalg RSA -keysize 4096 -validity 10950
```

Then create `keystore.properties` next to the project root (git-ignored):

```properties
storeFile=/home/you/keyboard-picker-release.jks
storePassword=...
keyAlias=keyboardpicker
keyPassword=...
```

Check which key a build used:

```bash
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

For CI, add these repository secrets — `KEYSTORE_BASE64` (base64 of the `.jks`),
`KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Tagged releases are then signed
with the same long-lived key, so they upgrade over each other. Without them CI
falls back to a per-run debug key and every build has a different signature.

**Never commit the keystore or `keystore.properties`.** Both are git-ignored.

### Testing

**Version consistency** (no device needed):

```bash
scripts/check-release-version.sh v1.1.0   # or omit the tag for a dev check
```

It compares the tag against Gradle's `versionName`, and with `APK=` set also
checks the built APK's own metadata. This runs in CI and fails the build on a
mismatch.

**Functional smoke test** (needs a device or emulator):

```bash
scripts/smoke-test.sh 10
```

The app's behaviour is a side effect on another process — a system dialog — so
this launches the app and checks that a system dialog took focus while our
activity stayed frontmost. It deliberately does **not** match the chooser's title
text, so it works on a device set to a non-English language.

Prerequisites:

- `adb` on `PATH`, one authorised device, the app installed
- Two or more IMEs enabled
- A way to inject input events to press HOME. Plain `adb shell input` is tried
  first; on MIUI/HyperOS the shell is denied `INJECT_EVENTS`, so the script falls
  back to `su -c`, which needs root (KernelSU, Magisk). Alternatively enable
  *Developer options → USB debugging (Security settings)*, which may avoid root.

**Limitations.** This cannot run on GitHub-hosted CI without provisioning an
emulator or a self-hosted device, so CI does build, lint and validate release
metadata but does **not** run the smoke test. Passing the smoke test proves the
chooser opens on the device you ran it on; it is not evidence about other devices
or Android versions. See the [compatibility table](#requirements-and-compatibility)
for what has actually been exercised.

CI builds every push and publishes tagged releases; see
[`.github/workflows/android.yml`](.github/workflows/android.yml).

## Project layout

```
app/src/main/
├── AndroidManifest.xml
├── java/com/fynks/keyboardpicker/
│   ├── MainActivity.java        # opens the chooser, owns the window lifecycle
│   └── PickerTileService.java   # Quick Settings tile; launches MainActivity
└── res/
    ├── drawable/       # adaptive icon layers and the dedicated tile icon
    ├── layout/         # the opaque window the chooser attaches to
    ├── mipmap-anydpi/  # adaptive icon (the only icon form needed at minSdk 34)
    ├── values/         # strings.xml, colors.xml (light icon palette)
    └── values-night/   # night icon palette
scripts/
├── check-release-version.sh   # tag vs Gradle version vs APK metadata
└── smoke-test.sh              # on-device functional check
docs/                          # screenshot.png, icon-512.png
```

The icon is the `keyboard` glyph from [Tabler Icons](https://tabler.io/icons)
(MIT) — the only vector artwork in the project, and the source of
`docs/icon-512.png`, a raster preview for READMEs. Because
`minSdk` is 34, every device is past API 26, so no legacy density mipmaps are
shipped.

The launcher icon is adaptive with a night-qualified palette: a soft white
shade and the navy glyph in light mode, the opposite dark shade and the white
glyph at night. The `monochrome` layer lets Material You themed icons tint the
glyph live. The Quick Settings tile carries a dedicated 24dp full-bleed icon —
reusing the launcher foreground's 108dp canvas renders the glyph tiny in the
shade.

Two VectorDrawable pitfalls are encoded in comments in the drawables
themselves: the key dots must be absolute arcs with `fillColor` on each path
(written as relative arcs inside a group with an inherited `fillColor`,
VectorDrawable silently drops all six dots), and zero-length stroked subpaths
render unreliably, so the dots are circles instead.

## Things to know before changing this

- **Do not add `android:noHistory` or `android:finishOnTaskLaunch`.** Either
  destroys the window before the chooser is dismissed.
- **Do not make the root view translucent or empty**, and do not remove the
  delay before requesting the chooser. Both silently break the app.
- **Do not treat focus loss as proof the chooser opened** unless a request has
  already been made. See `IDLE` vs `PENDING` in `MainActivity`.
- **Do not call the input method API from `PickerTileService`.** The tile exists
  to launch the activity, which is the only place that lifecycle lives.
- **Do not add logging.** There is intentionally none, and the app's value is
  partly that it does nothing else.
- `excludeFromRecents` is intentional: there is no UI to navigate back to.

## Privacy

The app declares **no runtime permissions** and requests no network access,
contains no analytics, and stores no data. `android:allowBackup="false"` keeps it
out of cloud backup as well. Checkable against the shipped APK:

```bash
aapt2 dump permissions app-release.apk   # no uses-permission lines
```

The Quick Settings tile is gated by `android.permission.BIND_QUICK_SETTINGS_TILE`
declared on the service, which is how Android restricts tile binding. That is a
signature-level system permission granted at install time; it is not a runtime
permission and never produces a permission prompt.

## License

MIT — see [LICENSE](LICENSE).

Third-party assets:

- The launcher icon glyph is `keyboard` from [Tabler Icons](https://tabler.io/icons),
  © Paweł Kuna, MIT licensed. The screenshot in `docs/` is a capture of the app
  running on a test device.