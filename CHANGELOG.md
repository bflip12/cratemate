# Changelog

All notable changes to CrateMate are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

The first public release will be 0.1.0.

### Added

- A native SwiftUI app that reads Apple Music playlists, including cloud-only ones, through `iTunesLibrary`.
- Metadata matching against a local DJ folder, scored on title, artist, version and track length.
- A review list with a "Needs attention" filter, alternative candidates, DJ folder search and skip.
- Duplicate detection for the same recording stored more than once in the DJ folder.
- `.m3u8` export with absolute paths, ready for Rekordbox's Import Playlist.
- A fallback for Apple Music's Unicode Text playlist export (⌘O).
- A tag cache, so only new or changed files are read after the first scan.
- A download: a universal app for Apple silicon and Intel Macs in a drag-to-Applications DMG, published to GitHub Releases by `.github/workflows/release.yml` when a version tag is pushed.
- The CrateMate name, app icon, logo and wordmark. The icon is drawn by `scripts/make-icon.sh`; the rest is in `docs/brand`.

### Changed

- Renamed from am2rb to CrateMate. The bundle identifier is now `com.bobbyf.cratemate`, so macOS asks for Apple Music access again. The DJ folder and export folder settings carry over; the tag cache moves to `~/Library/Application Support/CrateMate` and is rebuilt on the first scan. Exports now go to `~/Music/CrateMate` by default.

[Unreleased]: https://github.com/bflip12/cratemate/commits/main
