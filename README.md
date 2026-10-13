# Fynks Picker

A tiny Android launcher that opens **the real system keyboard chooser** — the same
"Choose input method" dialog you get from the keyboard-switch button in the
navigation bar — with one tap from the home screen.

It calls exactly one public API:

```java
InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
imm.showInputMethodPicker();
```

No custom dialog. No Settings detour. It never switches to a keyboard by itself,
and it requests **no permissions at all**.

<p align="center">
  <img src="docs/screenshot.png" width="280" alt="The system keyboard chooser opened by Fynks Picker">
</p>

## Why this is not a two-line app

`showInputMethodPicker()` attaches its dialog to the calling activity's window.
Give it an activity that never becomes a real, focused, visible window and the
request is dropped **silently** — no exception, no log line, nothing on screen.
Two things are required, both learned from Tasker's working implementation:

1. **A real host window.** Call `setContentView()` with an opaque view. A
   translucent, content-less activity is not enough.
2. **Timing.** Wait 500 ms before calling. Firing immediately from
   `decorView.post {}` is a race that HyperOS frequently wins.

On top of that, the activity must *stay alive* while the chooser is open,
otherwise the window hosting the dialog is torn down mid-selection. That is what
the `onWindowFocusChanged` state machine does:

```
WAITING ──focus lost──> PICKER_SHOWN ──focus returned──> CLOSED ──> finish()
```

Plus two safeguards: one retry at 1.5 s if focus never changed, and a 10 s
watchdog so a failed launch cannot leave an invisible activity hanging around.

## Install

Grab `app-release.apk` from the [Releases](../../releases) page, or build it
yourself (below).

```bash
adb install -r app-release.apk
```

> **Already installed from another machine?**
> Release builds here are signed with a local **debug key**. Debug-key
> fingerprints are stable per machine, so a copy signed elsewhere will not
> upgrade cleanly and will fail with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
> Remove the old one first:
>
> ```bash
> adb uninstall com.fynks.keyboardpicker
> ```

## Requirements

- Android 5.0 (API 21) or newer
- **At least two input methods enabled**, otherwise the chooser may list a single
  entry: *Settings → Additional settings → Languages & input → Keyboard management*

No runtime permissions are needed. Some heavily-modified ROMs (MIUI / HyperOS)
offer a per-app "display pop-up windows while running in the background" toggle.
This app does not require it, since its activity is always foreground when the
chooser is requested — but if the dialog ever fails to appear on such a ROM,
that toggle is the first thing to try.

## Build from source

Requires JDK 17 and the Android SDK (`platforms;android-35`,
`build-tools;35.0.0`).

```bash
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/35.0.0"

git clone <this-repo>
cd <this-repo>
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release.apk`

Set `ANDROID_HOME`, or drop a `local.properties` with `sdk.dir=/path/to/sdk`
(it is git-ignored — never commit it).

CI builds and publishes tagged releases automatically; see
[`.github/workflows/android.yml`](.github/workflows/android.yml).

## Project layout

```
.
├── app/
│   ├── build.gradle
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/fynks/keyboardpicker/MainActivity.java   # the whole app
│       └── res/
│           ├── drawable/          # adaptive icon layers
│           ├── layout/            # opaque host window
│           ├── mipmap-*/          # legacy bitmap icons, API 21-25
│           ├── values/strings.xml
│           └── xml/               # backup exclusion rules
├── CHANGELOG.md
├── LICENSE                         # MIT
└── settings.gradle / build.gradle
```

## Design constraints worth knowing before you change things

- **Do not add `android:noHistory` or `android:finishOnTaskLaunch`.** Either
  destroys the window before the chooser is dismissed — the exact failure mode
  this app was written to avoid.
- **Do not raise `targetSdk` above 34** without re-testing on Android 15. The
  stricter background-activity-launch rules there can suppress a system dialog
  launched from a cold-start launcher activity.
- **Do not make the root view translucent or empty.** See "Why this is not a
  two-line app" above.
- `excludeFromRecents` is intentional: the app has no UI to go back to.

## License

MIT — see [LICENSE](LICENSE).