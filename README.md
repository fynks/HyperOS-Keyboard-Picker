# Keyboard Picker

An Android launcher that opens the system's own keyboard chooser — the same
"Choose input method" dialog as the keyboard-switch button in the navigation
bar — with one tap from the home screen.

It calls exactly one public API:

```java
InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
imm.showInputMethodPicker();
```

![The system keyboard chooser, opened by Keyboard Picker](docs/screenshot.png)

## What it does

- Opens Android's native keyboard chooser
- Closes itself as soon as you dismiss the chooser

## What it does not do

- It does not switch to a keyboard for you — the choice is always yours
- It does not draw its own dialog or imitate the system one
- It does not open Settings
- It has no settings screen, no onboarding, no configuration
- It has no network access, no analytics and no ads

## Requirements

- Android 14 (API 34) or newer
- At least two keyboards enabled, otherwise the chooser may list a single
  entry: *Settings → Additional settings → Languages & input → Keyboard
  management*

No runtime permissions are requested, because `showInputMethodPicker()` is
public API.

## Install and use

Download `app-release.apk` from the [Releases](../../releases) page, then:

```bash
adb install -r app-release.apk
```

or copy the APK to the phone and open it (you will need to allow installs from
your file manager).

Tap **Keyboard Picker** on the home screen, pick a keyboard, and the app is
gone. That is the whole interaction.

> If you already have a build of this app installed that was signed on another
> machine, the install will fail with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
> Release builds are signed with a local debug key. Remove the old copy first:
>
> ```bash
> adb uninstall com.fynks.keyboardpicker
> ```

## Why the native picker

Using the system dialog means the app behaves exactly like the navigation bar
button, on every device and in the user's own language, and it cannot drift out
of sync with the platform. Building an equivalent dialog by hand would mean
reimplementing IME enumeration, locale handling, per-app restrictions and
accessibility behaviour — and would still be wrong the moment Android changes.

The catch is that the chooser is a system dialog *attached to the calling
activity's window*. An app that opens it badly looks like it does nothing at
all: the request is dropped silently, with no exception and no log line. Two
things are required, both established by measurement on Android 15 / HyperOS 2.0:

1. **A real window.** The activity must `setContentView()` with an opaque view.
   A translucent or empty window is ignored.
2. **Timing.** The chooser must be requested after a short delay. Requesting it
   immediately, or from the first focus callback, failed on every attempt
   (0/12 runs), because the window has not been registered with the window
   manager yet. A delayed first request plus one retry opened it on every run.

The activity then has to stay alive while the chooser is up, or the window
hosting the dialog is destroyed mid-selection. `onWindowFocusChanged` provides
that signal: focus is lost when the chooser opens and returned when it closes.

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

### Testing

The app's behaviour is a side effect on another process, so it is verified by
launching it and checking which window holds focus:

```bash
scripts/smoke-test.sh 10
```

It needs `adb` and a way to inject input events — either *Developer options →
USB debugging (Security settings)*, or root.

CI builds every push and publishes tagged releases; see
[`.github/workflows/android.yml`](.github/workflows/android.yml).

## Project layout

```
app/src/main/
├── AndroidManifest.xml
├── java/com/fynks/keyboardpicker/MainActivity.java   # the entire app
└── res/
    ├── drawable/       # adaptive icon layers
    ├── layout/         # the opaque window the chooser attaches to
    ├── mipmap-anydpi/  # adaptive icon (the only icon form needed at minSdk 34)
    └── values/strings.xml
scripts/smoke-test.sh
```

The icon is the `keyboard` glyph from [Tabler Icons](https://tabler.io/icons)
(MIT) — the only vector artwork in the project, and the source of
`docs/icon-512.png`, a raster preview for READMEs and store listings. Because
`minSdk` is 34, every device is past API 26, so no legacy density mipmaps are
shipped.

The glyph's key dots had to be encoded as absolute arcs with `fillColor` on each
path. Written as relative arcs inside a group with an inherited `fillColor` — the
obvious translation — VectorDrawable silently renders the keyboard outline and
spacebar and drops all six dots.

## Things to know before changing this

- **Do not add `android:noHistory` or `android:finishOnTaskLaunch`.** Either
  destroys the window before the chooser is dismissed.
- **Do not make the root view translucent or empty**, and do not remove the
  delay before requesting the chooser. Both silently break the app.
- `excludeFromRecents` is intentional: there is no UI to navigate back to.

## Privacy

The app requests **zero permissions**, declares no network access, contains no
analytics, and stores no data. `android:allowBackup="false"` keeps it out of
cloud backup as well. This can be checked against the shipped APK:

```bash
aapt2 dump permissions app-release.apk
```

## Store listing copy

Short description (25 characters, within Play's 30-character limit):

```
One-tap keyboard switcher
```

Full description:

```
Keyboard Picker puts the system keyboard chooser one tap away.

Tap the icon and Android's own "Choose input method" dialog opens — the exact
same dialog as the keyboard-switch button in your navigation bar. Pick a
keyboard, and Keyboard Picker gets out of the way.

That's the whole app.

WHAT IT DOES
• Opens the real system keyboard chooser
• Nothing else

WHAT IT DOES NOT DO
• It will not switch to a keyboard for you
• It does not show a custom or look-alike dialog
• It does not open Settings
• It does not run in the background, send anything over the network, or
  collect anything about you

PRIVACY
Keyboard Picker requests zero permissions. It has no analytics, no ads and no
network access, and it stores no data at all.

HOW IT WORKS
Technically interesting, if you like this sort of thing: the chooser dialog is
attached to the calling app's window, so a naive implementation is silently
ignored by Android. Keyboard Picker gives it a real window, waits for that
window to settle, and keeps the activity alive until the dialog closes — which
is why it doesn't vanish the moment you tap it.

REQUIREMENTS
Android 14 or newer. Have at least two keyboards enabled (Settings →
Additional settings → Languages & input → Keyboard management) or the chooser
may only list one.

Open source, MIT licensed.
```

## License

MIT — see [LICENSE](LICENSE).

Third-party assets:

- The launcher icon glyph is `keyboard` from [Tabler Icons](https://tabler.io/icons),
  © Paweł Kuna, MIT licensed. The screenshot in `docs/` is a capture of the app
  running on a test device.