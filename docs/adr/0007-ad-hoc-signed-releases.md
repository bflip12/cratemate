# 0007. Ship ad-hoc signed DMGs from GitHub Releases

**Status:** Accepted

## Context

Most DJs won't build from source, so CrateMate needs a download. A Mac app downloaded from the web opens without warnings only if it's signed with a Developer ID and notarized by Apple. An ad-hoc signed app opens too, but the first launch needs an extra step in System Settings.

## Decision

- Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`. It checks the tag against `Info.plist` and `CHANGELOG.md`, runs the tests, builds the universal app, packs a drag-to-Applications DMG with `hdiutil`, and publishes a GitHub release.
- The release always includes `CrateMate.dmg`, so `releases/latest/download/CrateMate.dmg` is a stable download link.
- Builds are ad-hoc signed. The workflow signs with a Developer ID and notarizes as soon as the `APPLE_*` repository secrets are added, with no other changes.

## Consequences

- Releases are reproducible from a tag, with nothing built on a personal machine.
- Until builds are notarized, users see "Apple could not verify…" on first launch and have to click Open Anyway. The install page, README and release notes walk through it.
- With ad-hoc signing, each update looks like a new app to macOS, so it asks for Apple Music access again.
