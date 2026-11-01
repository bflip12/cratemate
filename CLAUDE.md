# CrateMate: notes for AI coding agents

CrateMate is a native SwiftUI Mac app. It reads Apple Music playlists through `iTunesLibrary.framework`, matches each song by metadata against the user's local DJ folder, and writes an `.m3u8` with absolute paths that Rekordbox imports, linking each entry to tracks already in its collection.

Read these before changing anything:

- [README.md](README.md): what it does, for users.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): modules, data flow, the matching algorithm and its thresholds.
- [docs/CODE_STYLE.md](docs/CODE_STYLE.md): conventions, safety rules and UI copy.
- [CONTRIBUTING.md](CONTRIBUTING.md): build, test and PR workflow.

## Hard rules

- **Never move, rename or retag files in the DJ folder.** Rekordbox tracks files by path, so any change breaks the user's collection. Only read from it.
- **No network access and no third-party dependencies.**
- **Don't use SwiftUI `@State`.** In the macOS 27 SDK it's a macro whose plugin ships only with Xcode, so a build with only the Command Line Tools fails. Keep UI state on the `@Observable` models (e.g. `RowReview.searching`, `AppModel.playlistFilter`). `@Observable`, `@Bindable` and `@Environment` are fine.

## Git workflow

- **Never commit to `main`.** It's protected on GitHub: no direct pushes or force-pushes, and merging needs a pull request with the "Lint, test and build" check passing.
- Start every change on a new branch from an up-to-date `main` (`fix/…`, `feature/…`, `docs/…`, `ci/…`), push it, and open a pull request with the template filled in.
- Pull requests are squash-merged and the branch is deleted automatically. After a merge, run `git switch main && git pull` before starting the next branch.

## Build and test gotchas

- The project builds with the Command Line Tools alone; there's no Xcode project. `scripts/build-app.sh` assembles and ad-hoc signs `build/CrateMate.app` (`--install` copies it to /Applications). The signature lets macOS remember the Media & Apple Music permission.
- The build script restamps the binary's SDK version with `vtool`. SwiftPM records the deployment target (14.0) as the SDK version, which makes macOS run the app in compatibility mode with the old window chrome. Don't remove that step.
- The app is universal (`--arch arm64 --arch x86_64`, which works with the Command Line Tools). Ignore SwiftPM's "x86_64 is deprecated for macOS 27.0" warning: the binary's minimum is still 14.0 (check with `vtool -show-build`).
- `scripts/make-dmg.sh` packs `build/CrateMate.app` into `build/CrateMate-<version>.dmg` and `build/CrateMate.dmg` with `hdiutil`. On macOS 27, `hdiutil` prints deprecation warnings, but the `diskutil image` replacement doesn't exist on the macOS 26 CI runner, so keep `hdiutil`.
- Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which publishes the DMG to GitHub Releases. The website links to `releases/latest/download/CrateMate.dmg`, so keep that asset name. Builds are ad-hoc signed until the `APPLE_*` secrets in CONTRIBUTING.md are added.
- `iTunesLibrary` only works when the .app is launched through LaunchServices (`open build/CrateMate.app`). Running the binary from a shell fails with an XPC or permission error.
- Use `scripts/test.sh`, not `swift test`. With the Command Line Tools, incremental builds can lose the Swift Testing macro plugin, and the script passes `-plugin-path`.
- For the end to end test, run `scripts/make-test-library.sh <dir>` (needs ffmpeg), then `scripts/test.sh <dir>`. The expected result is 9 matched and 1 not found ("Nobody - Not In Library").
- Run `scripts/format.sh` before committing. CI runs `scripts/format.sh --check`, and swift-format requires doc comments on every `public` declaration in `CrateMateCore`.
- The app icon is drawn in code by `scripts/make-icon.swift`. Run `scripts/make-icon.sh` after changing it and commit the outputs. Brand guidelines and logo files are in [docs/brand](docs/brand/README.md).

## Website

- The project website lives in `site/`: plain HTML and CSS, no build step, no JavaScript, no third-party requests or analytics. Preview it with `python3 -m http.server -d site`.
- `.github/workflows/pages.yml` deploys it to GitHub Pages on pushes to `main` that touch `site/`. Keep `site/CNAME`.
- The version and download size on the home page (text and JSON-LD) and the install page are hand-written. Update them at each release, as CONTRIBUTING.md's Releasing section says.
- Every page repeats the header and footer; keep the trademark disclaimer in each footer. Show Apple Music and rekordbox as text only, never logos.

## Status

The matcher is tested against the generated fake library only. It hasn't yet been checked against a large real-world DJ folder or a real Rekordbox import, so treat changes to scoring and thresholds with care. Add a test for each real-world case.
