# Manual release workflow + version 2.0.0 — design

Date: 2026-11-19
Status: proposed, awaiting approval

## Intent and why

Releases currently only happen when a `v*` tag is pushed. The existing
`workflow_dispatch` trigger builds an APK but cannot publish it. The user wants
to publish a release on demand from CI, and wants 2.0 published now with the
2.0.0 changelog and screenshots captured while testing the flip tile.

## Goals

- A manual GitHub Actions run publishes a GitHub Release with the APK, its
  SHA-256, release notes and screenshots.
- Release 2.0.0 is built and published through that workflow.
- The 2.0.0 changelog describes the flip-tile work.

## Non-goals

- No change to the existing tag-driven release path in `android.yml`.
- No new signing key, no new repository secrets beyond the existing `KEYSTORE_*`
  and `GITHUB_TOKEN`.
- No automation that pushes tags from CI.

## Constraints

- `scripts/check-release-version.sh` requires `versionName` in
  `MAJOR.MINOR.PATCH` form and compares it with the requested tag.
- Tagged releases refuse to publish without the release-key secrets; the manual
  path must have the same guard.
- The APK must remain upgrade-compatible with previous releases (same key).
- `gh` is authenticated locally as `fynks` with `repo` and `workflow` scopes.
- Publishing and pushing to `main` are external side effects and need explicit
  confirmation at the time they happen.

## Approaches considered

1. **Extend `android.yml`** with a version input and a shared release job.
   Least duplication, but rejected by the user.
2. **Separate `release-manual.yml`** (chosen). Independent workflow for manual
   publishes; `android.yml` stays as-is. Cost: SDK setup, signing and notes
   generation are duplicated between the two workflows.
3. **Manual run pushes a `v*` tag** to reuse the tag workflow. Rejected: needs a
   PAT because `GITHUB_TOKEN` pushes do not trigger other workflows.

## Decided design

### `docs/release/` screenshots

- Copy the two test captures into `docs/release/` and crop them to the Quick
  Settings panel so notification content (music, system notices, data usage) is
  not published:
  - `docs/release/tile-swiftkey.png` — tile showing the active "SwiftKey" label.
  - `docs/release/chooser.png` — the app's chooser-opening screen.
- Add a short `docs/release/README.md` explaining what each image shows.

### `.github/workflows/release-manual.yml`

- Trigger: `workflow_dispatch` with one required string input, `version`
  (e.g. `2.0.0`), described as "must match versionName in app/build.gradle".
- `permissions: contents: write`.
- Single `release` job on `ubuntu-latest`:
  1. Checkout, JDK 21, Gradle setup, SDK components (same versions/cache idea as
     `android.yml`: `platforms;android-36`, `build-tools;37.0.0`).
  2. Compute `RELEASE_TAG=v${{ inputs.version }}` into `$GITHUB_ENV`.
  3. `scripts/check-release-version.sh "$RELEASE_TAG"` — fails on mismatch.
  4. Refuse to continue if `KEYSTORE_BASE64` is missing, with the same reasoning
     as the tagged-release guard (debug-signed APK cannot upgrade).
  5. Reconstruct the keystore into `$RUNNER_TEMP` and write a git-ignored
     `keystore.properties`, as `android.yml` does.
  6. `./gradlew assembleRelease`, then verify and fingerprint with `apksigner`,
     and write `app-release.apk.sha256`.
  7. Assert `v${{ inputs.version }}` does not already exist (`gh release view`);
     fail early rather than overwriting.
  8. Generate notes (What's changed → CHANGELOG link, Requirements, Install,
     Verify with checksum + certificate, Screenshots as release-asset image
     links), then `gh release create "$RELEASE_TAG"` with `--target $GITHUB_SHA`,
     the APK, checksum and both PNGs.
- Report the signing certificate in the job summary.

### Version 2.0.0

- `app/build.gradle`: `versionCode = 7`, `versionName = "2.0.0"`.
- `CHANGELOG.md`: move `Unreleased` into `## [2.0.0] - 2026-11-19` with the
  flip-tile additions, changes and verification; leave `Unreleased` empty.
- `RELEASING.md`: add the manual-release path (bump version + changelog, commit
  and push, run the workflow with the matching version).

### Verification before publishing

- `scripts/check-release-version.sh v2.0.0`
- `./gradlew assembleRelease` and verify the APK's own metadata with
  `APK=... scripts/check-release-version.sh v2.0.0`
- Confirm both cropped PNGs are present and contain no notification text.
- Pushing to `main` and triggering the workflow are done only after the user
  confirms, since they publish externally.

## What's left to the builder

- Exact release-note copy and screenshot crop geometry are implementation
  details; keep them consistent with the existing tag release notes.
