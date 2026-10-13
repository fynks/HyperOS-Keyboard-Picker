# Releasing

A short checklist. The point of the first item is that the last two releases
disagreed with themselves: `v1.1.0` shipped with `versionName = "1.0.0"`.

## Before tagging

1. **Decide the version.** Bump `versionName` and `versionCode` in
   `app/build.gradle` together. `versionCode` must increase for an update to be
   offered; never lower it.

   ```properties
   versionCode = 6
   versionName = "1.2.0"
   ```

2. **Update `CHANGELOG.md`.** Move everything under `Unreleased` into a new
   dated section and leave `Unreleased` empty. Keep a `### Fixed` section when
   behaviour changes, not just new features.

3. **Build and lint.**

   ```bash
   ./gradlew clean assembleRelease lintVitalRelease
   ```

4. **Check the metadata.**

   ```bash
   scripts/check-release-version.sh v1.2.0
   ```

   This fails if the tag and `versionName` disagree, so it is worth running
   before tagging rather than after.

5. **Device testing, if hardware is available.** Without a device, say so
   explicitly in the release notes rather than implying otherwise.

   ```bash
   adb install -r app/build/outputs/apk/release/app-release.apk
   scripts/smoke-test.sh 10
   ```

   Also check both entry points by hand: the home-screen icon and the Quick
   Settings tile, and that dismissing the chooser leaves no window behind.

6. **Confirm the signing key**, so the release upgrades over the previous one.

   ```bash
   apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
   ```

   Compare the certificate SHA-256 with the previous release. If it differs, users
   will need to uninstall first — worth knowing before publishing.

## Tagging

```bash
git tag -a v1.2.0 -m "Keyboard Picker 1.2.0"
git push --tags
```

CI then builds, validates the tag against `versionName`, verifies the signature,
generates the SHA-256, and publishes the release with its notes.

The workflow refuses to publish a tagged release that is not signed with the
release key, because such an APK could never upgrade over the previous one.

## After publishing

7. **Verify the published assets**, not just the workflow log:

   ```bash
   gh release download v1.2.0 -R fynks/HyperOS-Keyboard-Picker
   sha256sum -c app-release.apk.sha256
   apksigner verify --print-certs app-release.apk | grep 'certificate SHA-256'
   ```

   The APK checksum and the certificate fingerprint are different things: the
   first changes with every rebuild, the second only if the key changes.

8. **Do not move a published tag.** If a release is wrong, cut a new one. Moving
   a tag leaves anyone who already downloaded the old asset with a checksum that
   no longer matches anything you publish.